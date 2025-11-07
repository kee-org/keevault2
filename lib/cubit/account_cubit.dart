import 'package:bloc/bloc.dart';
import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/config/platform.dart';
import 'package:keevault/payment_service.dart';
import 'package:keevault/user_repository.dart';
import 'package:keevault/vault_backend/account_verification_status.dart';
import 'package:keevault/vault_backend/exceptions.dart';
import 'package:keevault/vault_backend/user.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../logging/logger.dart';
import '../vault_backend/utils.dart';

part 'account_state.dart';

class AccountCubit extends Cubit<AccountState> {
  final UserRepository _userRepo;

  AccountCubit(this._userRepo) : super(AccountInitial());

  User get currentUser {
    final AccountState currentState = state;
    User user;
    if (currentState is AccountChosen) {
      user = currentState.user;
    } else {
      throw Exception('Account in invalid state - user not available');
    }
    return user;
  }

  User? get currentUserIfKnown {
    final AccountState currentState = state;
    if (currentState is AccountChosen) {
      return currentState.user;
    } else {
      return null;
    }
  }

  User? get currentUserIfIdKnown {
    final AccountState currentState = state;
    if (currentState is AccountChosen && currentState.user.id != null) {
      return currentState.user;
    } else {
      return null;
    }
  }

  Future<User?> startup() async {
    if (state is! AccountInitial) return null;
    l.d('starting account cubit');
    final prefs = await SharedPreferences.getInstance();
    String? email;
    try {
      email = prefs.getString('user.current.email');
    } on Exception {
      // no action required
    }

    if (email != null && email.isNotEmpty) {
      l.d('user found');
      var user = await User.fromEmail(email);
      await _userRepo.setQuickUnlockUser(user, force: true);
      emit(AccountChosen(user));
      l.d('account cubit started');
      return user;
    } else {
      l.d('no user found');
      bool isFreeUser = false;
      try {
        isFreeUser = prefs.getBool('user.current.isFree') ?? false;
      } on Exception {
        // no action required
      }
      if (isFreeUser) {
        emit(AccountLocalOnly());
      } else {
        emit(AccountUnknown());
      }
      l.d('account cubit started');
      return null;
    }
  }

  void requestLocalOnly() {
    emit(AccountLocalOnlyRequested());
  }

  Future<void> confirmLocalOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('user.current.isFree', true);
    emit(AccountLocalOnly());
  }

  Future<bool> subscriptionSuccess(
    Purchase purchasedItem,
    bool isAndroid,
    Future<void> Function() ensureRemoteCreated,
    Future<void> Function() finishTransaction,
  ) async {
    try {
      if (purchasedItem.purchaseToken == null) {
        emit(
          AccountSubscribeError(
            currentUser,
            'Unexpected error associating your subscription - we found no purchaseToken',
          ),
        );
        return false;
      }
      final success = await _userRepo.associate(currentUser, isAndroid ? 2 : 3, purchasedItem.purchaseToken!);
      if (success) {
        // Our association request was successful but we rely on the subscription
        // provider to respond too. Ideally we'd set up a websocket to receive an
        // immediate notification that this has completed, since that could even
        // be notified to the user many hours later in extreme situations.
        // For now we'll just poll a handful of times and then give up.
        final updatedUser = await _userRepo.waitUntilValidSubscription(currentUser, purchasedItem);
        if (updatedUser == null) {
          //TODO:f: Is there anything we can do with the associate stage to return information
          // that the sub id is already associated with a different user?
          // "We've recorded your new subscription but some parts of the internet are slower than usual at the moment so we can't yet finalise your account. We will keep trying in the background. Try to sign in again a bit later and if it's not all ready by then, we will pick up where we've left off and get everything working as soon as possible."));

          emit(
            AccountSubscribeError(
              currentUser,
              "We've recorded your new subscription but we can't yet finalise your account. Sometimes this is because you have accidentally tried to associate your device's Subscription with a different account to the one you previously used. Alternatively, this may be a temporary problem with the internet. Please check your email archives and try again later, making sure you use the correct email address.",
            ),
          );
        } else {
          await finishTransaction();
          try {
            // Can't do this in parallel with the subscription association
            // because we need the new JWT for storage access
            await ensureRemoteCreated();
          } catch (ex) {
            l.w(
              "Initial storage creation failed. Probably a network interruption. We don't retry but it should all get sorted out automatically when the user signs in next time.: $ex",
            );
          } finally {
            emit(AccountSubscribed(updatedUser));
          }
        }
      } else {
        emit(AccountSubscribeError(currentUser, 'Association error.'));
      }
    } on KeeSubscriptionExpiredException {
      l.e(
        'IAP store reports that the supplied subscription has already expired. This should be rare but could happen if we never had a chance to finish a purchase transaction a long time ago (e.g. user did not sign-in during their final subscription renewal period). We will finish the transaction now. User now needs to re-subscribe.',
      );
      await finishTransaction();
      return true;
    } on Exception catch (e) {
      emit(AccountSubscribeError(currentUser, 'Association error: $e'));
    }
    return false;
  }

  void subscriptionError(String msg) {
    emit(AccountSubscribeError(currentUser, msg));
  }

  Future<void> finaliseRegistration(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user.current.email', user.email!);
    await prefs.setString('user.authMaterialUserIdMap.${user.emailHashed}', user.id!);
    emit(AccountAuthenticated(user));
  }

  Future<void> startRegistration(String email) async {
    l.d('starting registration');
    var user = await User.fromEmail(email);
    emit(AccountCreateRequested(user));
  }

  void startSubscribing(User user) {
    emit(AccountSubscribing(user));
  }

  Future<User> createUserAccount(String email, String password, bool marketingEmails, int subscriptionSource) async {
    l.d('starting creation of user account');
    var user = currentUserIfKnown?.email != email ? await User.fromEmail(email) : currentUser;
    final protectedValue = ProtectedValue.fromString(password);
    final key = protectedValue.hash;
    await user.attachKey(key);
    emit(AccountCreating(user));
    try {
      await _userRepo.createUserAccount(user, marketingEmails, subscriptionSource);
      return user;
    } on KeeServerConflictException catch (e) {
      l.w('User already registered. Details: $e');
      throw KeeException(
        'This email address is already registered. Choose a different one or go back and sign in using your existing Kee Vault password, then we will work out any next steps you need to take.',
        e,
      );
    } on KeeServiceTransportException catch (e) {
      l.w('Unable to register user due to a transport error. Details: $e');
      throw KeeException(
        'The network connection was interrupted during registration. Usually that can be resolved by moving your device to somewhere with a stronger signal but rarely this could be due to technical problems elsewhere on the internet. If you keep having problems, please try again later in the day or tomorrow.',
      );
    } on Exception catch (e) {
      throw KeeException('Unknown error. Details: $e');
    }
  }

  Future<void> startSignin(String email) async {
    l.d('starting the 1st part of the sign in procedure');
    var user = await User.fromEmail(email);
    emit(AccountIdentifying(user));
    try {
      user = await _userRepo.startSignin(user);
      l.d('sign in procedure now awaits a password and resulting SRP parameters');
      emit(AccountIdentified(user, false));
    } on KeeServiceTransportException catch (e) {
      l.i(
        'Unable to identify user due to a transport error. App should continue to work offline if user has previously stored their Vault unless they have changed their email address previously. Details: $e',
      );
      emit(AccountIdentified(user, false));
    }
  }

  Future<User> finishSignin(String password) async {
    l.d('starting the 2nd part of the sign in procedure');
    User user = currentUser;
    emit(AccountAuthenticating(user));
    try {
      user = await _finaliseSignin(user, password);
    } on KeeLoginFailedMITMException {
      rethrow;
    } on KeeLoginRequiredException {
      emit(AccountIdentified(user, true));
    } on KeeServiceTransportException catch (e) {
      l.i(
        'Unable to authenticate due to a transport error. App should continue to work offline if user has previously stored their Vault. Details: $e',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user.current.email', user.email!);
      if (user.id?.isNotEmpty ?? false) {
        await prefs.setString('user.authMaterialUserIdMap.${user.emailHashed}', user.id!);
      }
      emit(AccountAuthenticationBypassed(user));
    } on KeeMaybeOfflineException {
      l.i(
        'Unable to authenticate since initial identification failed, probably due to a transport error. App should continue to work offline if user has previously stored their Vault.',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user.current.email', user.email!);
      if (user.id?.isNotEmpty ?? false) {
        await prefs.setString('user.authMaterialUserIdMap.${user.emailHashed}', user.id!);
      }
      emit(AccountAuthenticationBypassed(user));
    }
    return user;
  }

  // Differences from finishSignin:
  // 1. starts signin too, with no intermediate AccountIdentified state since we don't
  // want to update the UI until the process has completed.
  // 2. network errors result in a reset to the AccountChosen state rather than bypassing the need for
  // authentication because... not sure. Probably we previously signed in successfully
  // to have reached this point so an error would be unexpected... but this warrants
  // closer inspection one day, especially if offline authentication bugs are found.
  Future<User> fullSignin(String password) async {
    l.d('starting a full sign in procedure');
    User user = currentUser;
    emit(AccountIdentifying(user));
    try {
      user = await _userRepo.startSignin(user);
      emit(AccountAuthenticating(user));
      user = await _finaliseSignin(user, password);
    } on KeeLoginFailedMITMException {
      rethrow;
    } on KeeLoginRequiredException {
      emit(AccountIdentified(user, true));
    } on KeeServiceTransportException catch (e) {
      l.i(
        'Unable to authenticate due to a transport error. App should continue to work offline if user has previously stored their Vault. Details: $e',
      );
      emit(AccountChosen(user));
    } on KeeMaybeOfflineException {
      l.e(
        'Unable to authenticate since initial identification failed, possibly due to a transport error but this is probably a bug in Kee Vault too. App should continue to work offline if user has previously stored their Vault.',
      );
      emit(AccountChosen(user));
    }
    return user;
  }

  Future<User> _finaliseSignin(User user, String password) async {
    ProtectedValue key = ProtectedValue.fromString(password);
    user = await _userRepo.finishSignin(key, user);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user.current.email', user.email!);
    await prefs.setString('user.authMaterialUserIdMap.${user.emailHashed}', user.id!);
    await _userRepo.setQuickUnlockUser(user);
    emitAuthenticatedOrExpiredOrUnvalidated(user);

    l.d('sign in complete');
    return user;
  }

  void emitAuthenticatedOrExpiredOrUnvalidated(User user) {
    if (user.verificationStatus != AccountVerificationStatus.success && user.tokens?.storage == null) {
      emit(AccountEmailNotVerified(user));
      return;
    }
    final subscriptionStatus = user.subscriptionStatus;
    if (subscriptionStatus == AccountSubscriptionStatus.current) {
      emit(AccountAuthenticated(user));
    } else if (subscriptionStatus == AccountSubscriptionStatus.freeTrialAvailable) {
      emit(AccountExpired(user, true));
    } else if (user.subscriptionStatus == AccountSubscriptionStatus.expired) {
      emit(AccountExpired(user, false));
    } else {
      throw Exception(
        'Unknown account status. Unable to proceed. This is probably a bug so please report it along with details of the Kee Vault service subscription you are trying to use (if any)',
      );
    }
  }

  Future<void> restartTrial() async {
    final AccountState currentState = state;
    if (currentState is AccountExpired && (currentState.user.email?.isNotEmpty ?? false)) {
      emit(AccountTrialRestartStarted(currentState.user, currentState.trialAvailable));
      l.d('restarting user subscription trial');
      final success = await _userRepo.restartTrial(currentState.user);
      l.d('restarted user subscription trial: $success');
      emit(AccountTrialRestartFinished(currentState.user, currentState.trialAvailable, success));
    }
  }

  void startEmailChange() {
    emit(AccountEmailChangeRequested(currentUser, null));
  }

  Future<bool> changePassword(ProtectedValue password, Future<bool> Function(User user) onChangeStarted) async {
    if (currentUser.emailHashed == null) throw KeeInvalidStateException();
    if (currentUser.email?.isEmpty ?? true) throw KeeInvalidStateException();
    if (currentUser.salt?.isEmpty ?? true) throw KeeInvalidStateException();

    final key = password.hash;
    final newPassKey = await derivePassKey(currentUser.email!, key);

    try {
      await _userRepo.changePasswordStart(currentUser, newPassKey);

      final success = await onChangeStarted(currentUser);

      if (!success) {
        throw VaultPasswordChangeException('Password change aborted.');
      }

      await _userRepo.changePasswordFinish(currentUser, newPassKey);
      return true;
    } on KeeLoginFailedMITMException {
      rethrow;
    } on KeeLoginRequiredException {
      l.w('Unable to change password due to a 403.');
      throw VaultPasswordChangeException(
        'Due to an authentication problem, we were unable to change your password. Probably it has been too long since you last signed in. Please sign out and then sign in again with your previous password and try again when you have enough time to complete the operation within 10 minutes.',
      );
    } on KeeNotFoundException {
      l.i('Unable to change password due to 404 response.');
      throw VaultPasswordChangeException('We cannot find your account. Have you recently deleted it?');
    } on KeeServiceTransportException catch (e) {
      l.w(
        'Unable to change password due to a transport error. Cannot be sure if the request was successful or not. Details: $e',
      );
      throw VaultPasswordChangeException(
        'Due to a network failure, we cannot say whether your request succeeded or not. If possible, try signing in to a different device with your new password to find out if the change took effect. If unsure if it worked, sign in with your previous password next time and try again when you have a more stable network connection.',
      );
    }
  }

  Future<bool> changeEmailAddress(String password, String newEmailAddress) async {
    l.d('starting the changeEmailAddress procedure');
    User user = currentUser;
    try {
      final newEmailHashed = await hashString(newEmailAddress, EMAIL_ID_SALT);

      final protectedValue = ProtectedValue.fromString(password);

      await _userRepo.changeEmailAddress(user, newEmailAddress, newEmailHashed, protectedValue);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user.current.email', newEmailAddress);
      if (user.id?.isNotEmpty ?? false) {
        await prefs.setString('user.authMaterialUserIdMap.${user.emailHashed}', user.id!);
      }
      final newUser = await User.fromEmail(newEmailAddress);
      emit(AccountChosen(newUser));
      await signout();
      return true;
    } on KeeLoginFailedMITMException {
      rethrow;
    } on KeeLoginRequiredException {
      l.w('Unable to changeEmailAddress due to a 403.');
      emit(
        AccountEmailChangeRequested(
          user,
          'Due to an authentication problem, we were unable to change your email address. Probably it has been too long since you last signed in with your previous email address. Please click Cancel and then sign in again with your previous email address and try this email change again when you have enough time to complete the operation within 10 minutes.',
        ),
      );
    } on FormatException {
      // Local validation
      l.i('Unable to changeEmailAddress due to FormatException.');
      emit(AccountEmailChangeRequested(user, 'Please enter the correct password for your Kee Vault account.'));
    } on KeeInvalidRequestException {
      // Local validation should mean this is unlikely to happen outside of malicious acts
      l.i('Unable to changeEmailAddress due to 400 response.');
      emit(
        AccountEmailChangeRequested(
          user,
          'Please double check that you have entered the correct password for your Kee Vault account. Also check that you have entered a valid email address of no more than 70 characters.',
        ),
      );
    } on KeeServerConflictException {
      l.i('Unable to changeEmailAddress due to 409 response.');
      emit(
        AccountEmailChangeRequested(
          user,
          'Sorry, that email address is already associated with a different Kee Vault account (or is reserved due to earlier use by a deleted account). Try signing in to that account, and consider importing your exported KDBX file from this account if you wish to transfer your data to the other account. If you have access to the requested email address but are unable to remember your password, you could use the account reset feature to delete the contents of the other account and assign it a new password that you will remember.',
        ),
      );
    } on KeeNotFoundException {
      l.i('Unable to changeEmailAddress due to 404 response.');
      emit(AccountEmailChangeRequested(user, 'We cannot find your account. Have you recently deleted it?'));
    } on KeeServiceTransportException catch (e) {
      l.w(
        'Unable to changeEmailAddress due to a transport error. Cannot be sure if the request was successful or not. Details: $e',
      );
      emit(
        AccountEmailChangeRequested(
          user,
          'Due to a network failure, we cannot say whether your request succeeded or not. Please check your new email address for a verification request. It might take a moment to arrive but if it does, that suggests the process did work so just verify your new address, click Cancel below and then sign-in using the new email address. If unsure if it worked, sign in with your previous email address next time and try again when you have a more stable network connection.',
        ),
      );
    }
    return false;
  }

  Future<void> signout() async {
    final AccountState currentState = state;
    if (currentState is AccountChosen && (currentState.user.email?.isNotEmpty ?? false)) {
      l.d('clearing user key material');
      var user = await User.fromEmail(currentState.user.email!);
      // Quick Unlock gets locked when Vault is locked which must happen when
      // user account is signed out so we don't need to do that here too.
      emit(AccountChosen(user));
    }
  }

  Future<void> forgetUser(void Function() signoutVault) async {
    l.d('removing stored user email address');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user.current.email');
    l.d('removed stored user email address');
    await prefs.setBool('user.current.isFree', false);
    signoutVault();
    emit(AccountUnknown());
  }

  void emailUnverified() {
    emit(AccountEmailNotVerified(currentUser));
  }

  Future<void> refreshUserAndTokens() async {
    try {
      final tokens = await _userRepo.userService.refresh(currentUser, false);

      currentUser.tokens = tokens;
      try {
        emitAuthenticatedOrExpiredOrUnvalidated(currentUser);
      } on Exception {
        // blah
      }
    } on KeeAccountUnverifiedException {
      rethrow;
    } on KeeLoginRequiredException {
      // Perhaps user took a very long time before pressing the button and all tokens have expired.
      // Thus, it's not unreasonable to ask them to start the process again, and if they have
      // completed verification in the mean time, they won't even end up back at the verification widget.
      await signout();
    }
  }

  Future<bool> resendVerificationEmail() async {
    return await _userRepo.userService.resendVerificationEmail(currentUser);
  }
}
