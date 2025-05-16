import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/logging/logger.dart';
import 'package:keevault/vault_backend/exceptions.dart';
import 'package:keevault/vault_backend/login_parameters.dart';
import 'package:keevault/vault_backend/remote_service.dart';
import 'package:srp/client.dart';
import '../config/platform.dart';
import '../payment_service.dart';
import 'account_verification_status.dart';
import 'features.dart';
import 'jwt.dart';
import 'srp.dart';
import 'tokens.dart';
import 'user.dart';
import 'utils.dart';

class UserService {
  Function? onTokenChange;
  late RemoteService _service;
  final Stage? _stage;
  UserService(this._stage, this.onTokenChange) {
    _service = RemoteService(_stage, 'identity');
  }

  Future<User> loginStart(User user) async {
    final request1 = _service.postRequest<String>('loginStart', {'emailHashed': user.emailHashed});
    final clientEphemeral = generateEphemeral();
    final response1 = await request1;
    final srp1 = SRP1.fromJson(json.decode(response1.data!));
    user.salt = srp1.salt;
    final nonce =
        (srp1.costFactor != null && srp1.costFactor! > 0)
            ? await calculateCostNonce(srp1.costFactor!, srp1.costTarget!)
            : '';

    user.loginParameters = LoginParameters(
      clientEphemeral: clientEphemeral,
      B: srp1.B,
      authId: srp1.authId,
      nonce: nonce,
    );
    user.kms = srp1.kms;
    return user;
  }

  Future<void> loginFinish(User user, {List<int>? hashedMasterKey, required bool notifyListeners}) async {
    if (user.loginParameters == null) throw KeeMaybeOfflineException();
    if (user.emailHashed?.isEmpty ?? true) throw KeeInvalidStateException();
    if (user.salt?.isEmpty ?? true) throw KeeInvalidStateException();
    if (user.loginParameters?.clientEphemeral == null) throw KeeInvalidStateException();
    if (user.loginParameters?.B == null) throw KeeInvalidStateException();
    if (user.loginParameters?.authId == null) throw KeeInvalidStateException();

    if (hashedMasterKey != null) {
      if (user.email?.isEmpty ?? true) throw KeeInvalidStateException();
      user.passKey = await derivePassKey(user.email!, hashedMasterKey);
    }
    if (user.passKey?.isEmpty ?? true) throw KeeInvalidStateException();

    final privateKey = derivePrivateKey(base642hex(user.salt!), user.emailHashed!, user.passKey!);
    final clientSession = deriveSession(
      user.loginParameters!.clientEphemeral.secret,
      base642hex(user.loginParameters!.B),
      base642hex(user.salt!),
      user.emailHashed!,
      privateKey,
    );

    final response2 = await _service.postRequest('loginFinish', {
      'emailHashed': user.emailHashed,
      'clientSessionEphemeral': hex2base64(user.loginParameters!.clientEphemeral.public),
      'authId': user.loginParameters!.authId,
      'costNonce': user.loginParameters!.nonce,
      'clientSessionProof': hex2base64(clientSession.proof),
    });

    final srp2 = SRP2.fromJson(response2.data);

    try {
      verifySession(user.loginParameters!.clientEphemeral.public, clientSession, base642hex(srp2.proof));
    } catch (e) {
      throw KeeLoginFailedMITMException();
    }

    await _parseJWTs(user, srp2.JWTs, notifyListeners: notifyListeners);
    user.verificationStatus = srp2.verificationStatus;

    await _finishIosIapTransaction(user);
    return;
  }

  Future<void> _finishIosIapTransaction(User user) async {
    final psi = PaymentService.instance;
    await psi.ensureReady();
    if (KeeVaultPlatform.isIOS &&
        user.subscriptionStatus == AccountSubscriptionStatus.current &&
        psi.activePurchaseItem != null &&
        (user.subscriptionId?.startsWith('ap_') ?? false)) {
      // It's impossible to know what the expected subscriptionId is because apple don't
      // give us the originaltransactionid unless it is a pointless restoration operation
      // to a new phone. So all subscription renewals would sit in the queue forever while
      // we have no way to know that we have dealt with them. Thus we just accept that
      // everything is probably fine as long as the user has a subscription from the App Store.
      // Maybe a problem for subscription restarts after an expiry. User's subscription ID
      // is going to stay the same even after expiry but then a new one should come along
      // with a whole new original transaction id... or not, if there is some reuse during
      // grace periods, etc. But surely in all other cases, any valid app store subscription
      // id associated with a user that has a non-expired set of authentication tokens is
      // going to be just a renewal operation that we can ignore because we handle it server-side.
      await psi.finishTransaction(psi.activePurchaseItem!);
    }
  }

  Future<User> createAccount(User user, int marketingEmailStatus, int subscriptionSource) async {
    final hexSalt = generateSalt();
    user.salt = hex2base64(hexSalt);
    final privateKey = derivePrivateKey(hexSalt, user.emailHashed!, user.passKey!);
    final verifier = deriveVerifier(privateKey);
    final response = await _service.postRequest<String>('register', {
      'emailHashed': user.emailHashed,
      'verifier': hex2base64(verifier),
      'salt': user.salt,
      'email': user.email,
      'introEmailStatus': 1,
      'marketingEmailStatus': marketingEmailStatus,
      'provider': subscriptionSource,
    });
    final jwts = List<String>.from(json.decode(response.data!)['JWTs']);
    await _parseJWTs(user, jwts);
    return user;
  }

  Future<Tokens> refresh(User user, bool notifyListeners) async {
    try {
      if (user.tokens != null && user.tokens!.identity != null && user.tokens!.identity!.isNotEmpty) {
        final response = await _service.postRequest<String>('refresh', {}, user.tokens!.identity);
        final refreshResult = json.decode(response.data!);

        final jwts = List<String>.from(refreshResult['JWTs']);
        await _parseJWTs(user, jwts, notifyListeners: notifyListeners);
        final verificationStatus = refreshResult['verificationStatus'];
        if (verificationStatus != null) {
          user.verificationStatus = AccountVerificationStatus.values[verificationStatus];
          if (user.verificationStatus != AccountVerificationStatus.success && user.tokens?.storage == null) {
            // May well be expired too but we will expect the user to fix the validation
            // of their email address before resubscribing if required.
            throw KeeAccountUnverifiedException();
          }
        }
        return user.tokens!;
      } else {
        throw KeeLoginRequiredException();
      }
    } on KeeLoginRequiredException {
      // We need to reauthenticate. If we have a cached User object with
      // a hashedPassword and emailHashed, we can trigger the login process automatically...
      // but if not, or it it fails, we need to force the user's session to logout and ask them
      // to login again. Initially this will involve logging out of the vault DBs too but perhaps could relax that one day.
      try {
        if (user.emailHashed != null &&
            user.passKey != null &&
            user.emailHashed!.isNotEmpty &&
            user.passKey!.isNotEmpty) {
          await loginStart(user);
          await loginFinish(user, notifyListeners: notifyListeners);
          // Unlike with the refresh operation above, user.verificationStatus is updated as part of the loginFinish function
          if (user.tokens != null) {
            return user.tokens!;
          } else {
            throw KeeLoginRequiredException();
          }
        } else {
          throw KeeLoginRequiredException();
        }
      } on KeeServiceTransportException {
        rethrow;
      } catch (error) {
        throw KeeLoginRequiredException();
      }
    } on KeeServiceTransportException {
      rethrow;
    } on KeeAccountUnverifiedException {
      rethrow;
    } catch (e) {
      // We can't handle any other errors
      throw KeeLoginRequiredException();
    }
  }

  Future<bool> restartTrial(User user, [List<int>? hashedMasterKey]) async {
    if (user.emailHashed?.isEmpty ?? true) throw KeeInvalidStateException();

    try {
      await _service.getRequest<String>('restartTrial/', user.tokens?.identity);
    } catch (error) {
      l.e('Trial reset failed because: $error');
      return false;
    }
    return true;
  }

  Future<bool> resendVerificationEmail(User user) async {
    if (user.emailHashed?.isEmpty ?? true) throw KeeInvalidStateException();

    try {
      await _service.postRequest<String>('resendVerificationEmail', {}, user.tokens?.identity);
    } catch (error) {
      l.e('Resending verification email failed because: $error');
      return false;
    }
    return true;
  }

  // We make no changes to the User model since we will sign the user out and ask them to
  // sign in again, partly so that we can ensure they have verified their new email address.
  Future<void> changeEmailAddress(
    User user,
    String newEmailAddress,
    String newEmailHashed,
    ProtectedValue password,
  ) async {
    final key = password.hash;
    final oldPassKey = await derivePassKey(user.email!, key);
    final newPassKey = await derivePassKey(newEmailAddress, key);

    if (user.passKey != oldPassKey) {
      throw FormatException('Password does not match');
    }

    final newHexSalt = generateSalt();
    final newSalt = hex2base64(newHexSalt);
    final newPrivateKey = derivePrivateKey(newHexSalt, newEmailHashed, newPassKey);
    final newVerifier = deriveVerifier(newPrivateKey);

    final oldPrivateKey = derivePrivateKey(base642hex(user.salt!), user.emailHashed!, oldPassKey);
    final oldVerifier = deriveVerifier(oldPrivateKey);
    final oldVerifierHashed = await hashBytes(Uint8List.fromList(hex.decode(oldVerifier)));

    await _service.postRequest<String>('changeEmailAddress', {
      'emailHashed': newEmailHashed,
      'verifier': hex2base64(newVerifier),
      'salt': newSalt,
      'email': newEmailAddress,
      'oldVerifierHashed': oldVerifierHashed,
    }, user.tokens!.identity);
    return;
  }

  Future<void> changePasswordStart(User user, String newPassKey) async {
    final newPrivateKey = derivePrivateKey(base642hex(user.salt!), user.emailHashed!, newPassKey);
    final newVerifier = deriveVerifier(newPrivateKey);

    await _service.postRequest<String>('changePasswordStart', {
      'verifier': hex2base64(newVerifier),
    }, user.tokens!.identity);
    return;
  }

  Future<void> changePasswordFinish(User user, String newPassKey) async {
    final response = await _service.postRequest<String>('changePasswordFinish', {}, user.tokens!.identity);
    user.passKey = newPassKey;

    final jwts = List<String>.from(json.decode(response.data!)['JWTs']);
    await _parseJWTs(user, jwts);
    return;
  }

  Future<void> _parseJWTs(User user, List<String> jwts, {bool notifyListeners = false}) async {
    user.tokens = Tokens();

    // Extract features from the client claim supplied by the server and cache
    // the other claims for later forwarding back to the server
    for (final jwt in jwts) {
      try {
        final verificationResult = await JWT.verify(jwt, _stage);
        switch (verificationResult.audience) {
          case 'client':
            {
              final claim = (verificationResult as ClientVerificationResult).claim;
              // Don't do anything in the unlikely event that the JWT has already expired
              if (claim.exp > DateTime.now().millisecondsSinceEpoch) {
                user.features = Features(enabled: claim.features, source: 'unknown', validUntil: claim.featureExpiry);
                user.id = claim.sub;
                user.idB64url = user.id!
                    .replaceAll(RegExp(r'\+'), '-')
                    .replaceAll(RegExp(r'/'), '_')
                    .replaceAll(RegExp(r'='), '.');
                user.tokens!.client = jwt;
                user.subscriptionId = claim.subscriptionId;
              }
            }
            break;
          case 'storage':
            user.tokens!.storage = jwt;
            break;
          case 'forms':
            user.tokens!.forms = jwt;
            break;
          case 'identity':
            user.tokens!.identity = jwt;
            break;
          case 'sso':
            user.tokens!.sso = jwt;
            break;
        }
      } catch (e) {
        l.w('Token error: $e');
      }
    }

    if (notifyListeners && onTokenChange != null) onTokenChange!(user);
  }
}
