import 'package:kdbx/kdbx.dart';
import 'package:keevault/vault_backend/user.dart';
import 'quick_unlocker.dart';
import 'vault_backend/exceptions.dart';
import 'vault_backend/user_service.dart';

class UserRepository {
  final QuickUnlocker qu;
  final UserService userService;
  UserRepository(this.userService, this.qu);

  Future<void> setQuickUnlockUser(User user, {bool force = false}) async {
    if (user.emailHashed == null) return;
    final quStatus = await qu.initialiseForUser(user.emailHashed!, force);
    if (quStatus == QUStatus.mapAvailable || quStatus == QUStatus.credsAvailable) {
      if (user.passKey?.isNotEmpty ?? false) {
        await qu.saveQuickUnlockUserPassKey(user.passKey);
      } else if (quStatus == QUStatus.credsAvailable) {
        final existingPassKey = await qu.loadQuickUnlockUserPassKey();
        if (existingPassKey != null) {
          user.passKey = existingPassKey;
        }
      }
    }
  }

  Future<User> startSignin(User user) async {
    await userService.loginStart(user);
    return user;
  }

  Future<User> finishSignin(ProtectedValue key, User user) async {
    if (user.emailHashed == null) throw KeeInvalidStateException();
    if (user.email?.isEmpty ?? true) throw KeeInvalidStateException();
    if (user.passKey?.isEmpty ?? true) {
      await user.attachKey(key.hash);
    }

    await userService.loginFinish(user);
    return user;
  }
}
