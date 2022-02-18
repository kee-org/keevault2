import 'dart:convert';
import 'package:keevault/logging/logger.dart';
import 'package:keevault/vault_backend/exceptions.dart';
import 'package:keevault/vault_backend/login_parameters.dart';
import 'package:keevault/vault_backend/remote_service.dart';
import 'package:srp/client.dart';
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
    final nonce = (srp1.costFactor != null && srp1.costFactor! > 0)
        ? await calculateCostNonce(srp1.costFactor!, srp1.costTarget!)
        : '';

    user.loginParameters =
        LoginParameters(clientEphemeral: clientEphemeral, B: srp1.B, authId: srp1.authId, nonce: nonce);
    user.kms = srp1.kms;
    return user;
  }

  // Actually can't ever be false - just throws instead
  Future<bool> loginFinish(User user, [List<int>? hashedMasterKey]) async {
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
    final clientSession = deriveSession(user.loginParameters!.clientEphemeral.secret,
        base642hex(user.loginParameters!.B), base642hex(user.salt!), user.emailHashed!, privateKey);

    final response2 = await _service.postRequest('loginFinish', {
      'emailHashed': user.emailHashed,
      'clientSessionEphemeral': hex2base64(user.loginParameters!.clientEphemeral.public),
      'authId': user.loginParameters!.authId,
      'costNonce': user.loginParameters!.nonce,
      'clientSessionProof': hex2base64(clientSession.proof)
    });

    final srp2 = SRP2.fromJson(response2.data);

    try {
      verifySession(user.loginParameters!.clientEphemeral.public, clientSession, base642hex(srp2.proof));
    } catch (e) {
      throw KeeLoginFailedMITMException();
    }

    await _parseJWTs(user, srp2.JWTs);
    user.verificationStatus = srp2.verificationStatus;
    return true;
  }

  Future<Tokens> refresh(User user) async {
    try {
      if (user.tokens != null && user.tokens!.identity != null && user.tokens!.identity!.isNotEmpty) {
        final response = await _service.postRequest<String>('refresh', {}, user.tokens!.identity);

        final jwts = List<String>.from(json.decode(response.data!)['JWTs']);
        await _parseJWTs(user, jwts);
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
          final loginResult = await loginFinish(user);
          if (loginResult && user.tokens != null) {
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

  Future<void> _parseJWTs(User user, List<String> jwts) async {
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
                user.tokens!.client = jwt;
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
        l.w('Token error: ' + e.toString());
      }
    }

    if (onTokenChange != null) onTokenChange!(user.tokens);
  }
}
