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

  Future<void> startSignin(String email) async {
    l.d('starting the 1st part of the sign in procedure');
    var user = await User.fromEmail(email);
    emit(AccountIdentifying(user));
    try {
      user = await _userRepo.startSignin(user);
      l.d('sign in procedure now awaits a password and resulting SRP parameters');
      emit(AccountIdentified(user, false));
    } on KeeServiceTransportException catch (e) {
      l.i('Unable to identify user due to a transport error. App should continue to work offline if user has previously stored their Vault. Details: $e');
      emit(AccountIdentified(user, false));
    }
  }

  Future<User> finishSignin(String password) async {
    l.d('starting the 2nd part of the sign in procedure');
    User user = currentUser;
    emit(AccountAuthenticating(user));
    try {
      ProtectedValue key = ProtectedValue.fromString(password);
      user = await _userRepo.finishSignin(key, user);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user.current.email', user.email!);
      await _userRepo.setQuickUnlockUser(user);
      emit(AccountAuthenticated(user));
      l.d('sign in complete');
    } on KeeLoginFailedMITMException {
      rethrow;
    } on KeeLoginRequiredException {
      emit(AccountIdentified(user, true));
    } on KeeServiceTransportException catch (e) {
      l.i('Unable to authenticate due to a transport error. App should continue to work offline if user has previously stored their Vault. Details: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user.current.email', user.email!);
      emit(AccountAuthenticationBypassed(user));
    } on KeeMaybeOfflineException {
      l.i('Unable to authenticate since initial identification failed, probably due to a transport error. App should continue to work offline if user has previously stored their Vault.');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user.current.email', user.email!);
      emit(AccountAuthenticationBypassed(user));
    }
    return user;
  }

  Future<User> fullSignin(String password) async {
    l.d('starting a full sign in procedure');
    User user = currentUser;
    emit(AccountIdentifying(user));
    try {
      user = await _userRepo.startSignin(user);
      emit(AccountAuthenticating(user));
      ProtectedValue key = ProtectedValue.fromString(password);
      user = await _userRepo.finishSignin(key, user);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user.current.email', user.email!);
      await _userRepo.setQuickUnlockUser(user);
      emit(AccountAuthenticated(user));
      l.d('sign in complete');
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

  Future<void> forgetUser(Future<void> Function() signoutVault) async {
    l.d('removing stored user email address');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user.current.email');
    l.d('removed stored user email address');
    await prefs.setBool('user.current.isFree', false);
    signoutVault();
    emit(AccountUnknown());
  }
}
