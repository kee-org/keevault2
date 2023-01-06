import 'package:bloc/bloc.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/user_repository.dart';
import 'package:keevault/vault_backend/exceptions.dart';
import 'package:keevault/vault_backend/user.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../logging/logger.dart';

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
    String? userId;
    try {
      userId = prefs.getString('user.current.id');
    } on Exception {
      // no action required
    }

    if (email != null && email.isNotEmpty) {
      l.d('user found');
      var user = await User.fromEmail(email, userId);
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

  Future<void> startSignin(String email) async {
    l.d('starting the 1st part of the sign in procedure');

    // User ID may not be known at this stage (if user has never signed in on this device before) so we will default to emailHashed but if user has changed their email address in the past, the id will be corrected when we finish the sign in
    var user = await User.fromEmail(email, userId);
    emit(AccountIdentifying(user));
    try {
      user = await _userRepo.startSignin(user);
      l.d('sign in procedure now awaits a password and resulting SRP parameters');
      emit(AccountIdentified(user, false));
    } on KeeServiceTransportException catch (e) {
      // I can't think of any circumstance in which the user can have previously stored their vault offline but they ended up here rather than using the path which retrieves their email address and id from storage and thus allows the id to find the correct location for the kdbx file, etc.
      // Maybe if they sign out and then sign in again while offline!!! We will have deleted their email and id but need to keep the id somewhere permenantly so that we can map from their email address to their id.
      //TODO: change id storage to a map of emails to ids instead
      // that will work but what about if they change their email address on a different device? They will have to sign in with the old email address until they reconnect to the network, when the old one will then stop working, new one wills tart and the email address to id mapping will be changed.
      l.i('Unable to identify user due to a transport error. App should continue to work offline if user has previously stored their Vault unless they have changed their email address previously. Details: $e');
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
      l.i('Unable to authenticate due to a transport error. App should continue to work offline if user has previously stored their Vault. Details: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user.current.email', user.email!);
      if (user.id?.isNotEmpty ?? false) {
        await prefs.setString('user.current.id', user.id!);
      }
      emit(AccountAuthenticationBypassed(user));
    } on KeeMaybeOfflineException {
      l.i('Unable to authenticate since initial identification failed, probably due to a transport error. App should continue to work offline if user has previously stored their Vault.');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user.current.email', user.email!);
      if (user.id?.isNotEmpty ?? false) {
        await prefs.setString('user.current.id', user.id!);
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
      l.i('Unable to authenticate due to a transport error. App should continue to work offline if user has previously stored their Vault. Details: $e');
      emit(AccountChosen(user));
    } on KeeMaybeOfflineException {
      l.e('Unable to authenticate since initial identification failed, possibly due to a transport error but this is probably a bug in Kee Vault too. App should continue to work offline if user has previously stored their Vault.');
      emit(AccountChosen(user));
    }
    return user;
  }

  Future<User> _finaliseSignin(User user, String password) async {
    ProtectedValue key = ProtectedValue.fromString(password);
    user = await _userRepo.finishSignin(key, user);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user.current.email', user.email!);
    await prefs.setString('user.current.id', user.id!);
    await _userRepo.setQuickUnlockUser(user);
    final subscriptionStatus = user.subscriptionStatus;
    if (subscriptionStatus == AccountSubscriptionStatus.current) {
      emit(AccountAuthenticated(user));
    } else if (subscriptionStatus == AccountSubscriptionStatus.freeTrialAvailable) {
      emit(AccountExpired(user, true));
    } else if (user.subscriptionStatus == AccountSubscriptionStatus.expired) {
      emit(AccountExpired(user, false));
    } else {
      throw Exception(
          'Unknown account status. Unable to proceed. This is probably a bug so please report it along with details of the Kee Vault service subscription you are trying to use (if any)');
    }
    l.d('sign in complete');
    return user;
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

  Future<void> signout() async {
    final AccountState currentState = state;
    if (currentState is AccountChosen && (currentState.user.email?.isNotEmpty ?? false)) {
      l.d('clearing user key material');
      var user = await User.fromEmail(currentState.user.email!, currentState.user.id);
      // Quick Unlock gets locked when Vault is locked which must happen when
      // user account is signed out so we don't need to do that here too.
      emit(AccountChosen(user));
    }
  }

  Future<void> forgetUser(void Function() signoutVault) async {
    l.d('removing stored user email address');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user.current.email');
    await prefs.remove('user.current.id');
    l.d('removed stored user email address and id');
    await prefs.setBool('user.current.isFree', false);
    signoutVault();
    emit(AccountUnknown());
  }
}
