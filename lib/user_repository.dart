import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/config/platform.dart';
import 'package:keevault/extension_methods.dart';
import 'package:keevault/vault_backend/subscription_service.dart';
import 'package:keevault/vault_backend/user.dart';
import 'credentials/quick_unlocker.dart';
import 'vault_backend/exceptions.dart';
import 'vault_backend/user_service.dart';

class UserRepository {
  final QuickUnlocker qu;
  final UserService userService;
  final SubscriptionService subscriptionService;
  UserRepository(this.userService, this.subscriptionService, this.qu);

  Future<QUStatus> setQuickUnlockUser(User user, {bool force = false}) async {
    if (user.id == null) return QUStatus.unknown;
    final quStatus = await qu.initialiseForUser(user.id!, force);
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
    return quStatus;
  }

  Future<User> startSignin(User user) async {
    await userService.loginStart(user);
    return user;
  }

  Future<bool> restartTrial(User user) async {
    return await userService.restartTrial(user);
  }

  Future<User> finishSignin(ProtectedValue key, User user) async {
    if (user.emailHashed == null) throw KeeInvalidStateException();
    if (user.email?.isEmpty ?? true) throw KeeInvalidStateException();
    if (user.passKey?.isEmpty ?? true) {
      await user.attachKey(key.hash);
    }

    await userService.loginFinish(user, notifyListeners: false);
    if (user.id?.isEmpty ?? true) throw KeeInvalidStateException();
    return user;
  }

  Future<User> createUserAccount(User user, bool marketingEmail, int subscriptionSource) async {
    await userService.createAccount(user, marketingEmail ? 1 : 0, subscriptionSource);
    return user;
  }

  Future<void> changeEmailAddress(
    User user,
    String newEmailAddress,
    String newEmailHashed,
    ProtectedValue password,
  ) async {
    await userService.changeEmailAddress(user, newEmailAddress, newEmailHashed, password);
    return;
  }

  Future<void> changePasswordStart(User user, String newPassKey) async {
    if (user.emailHashed == null) throw KeeInvalidStateException();
    if (user.email?.isEmpty ?? true) throw KeeInvalidStateException();
    if (newPassKey.isEmpty) throw KeeInvalidStateException();
    await userService.changePasswordStart(user, newPassKey);
    return;
  }

  Future<void> changePasswordFinish(User user, String newPassKey) async {
    if (user.emailHashed == null) throw KeeInvalidStateException();
    if (user.email?.isEmpty ?? true) throw KeeInvalidStateException();
    if (newPassKey.isEmpty) throw KeeInvalidStateException();
    await userService.changePasswordFinish(user, newPassKey);
    return;
  }

  Future<bool> associate(User user, int subscriptionSource, String validationData) async {
    return await subscriptionService.associate(user, subscriptionSource, validationData);
  }

  // If user has submitted same subscription ID again, they'll just get stuck here
  // for ages and be told to try later. not ideal but not unsafe
  Future<User?> waitUntilValidSubscription(User user, PurchasedItem purchasedItem) async {
    for (final delay in [3, 4, 6, 10, 10, 15, 20]) {
      await Future.delayed(Duration(seconds: delay));
      try {
        final tokens = await userService.refresh(user, false);
        // We make sure the latest subscription ID matches, in case an older subscription ID was still present but
        // the user has purchased a newer one (e.g. with a longer expiry date) from this new subscription provider.
        // Apple do not provide us with the necessary information to verify this so we just ensure that the user has
        // a subscription of some sort supplied by the App Store.
        if (tokens.storage != null &&
            ((KeeVaultPlatform.isIOS && (user.subscriptionId?.startsWith('ap_') ?? false)) ||
                user.subscriptionId == purchasedItem.keeVaultSubscriptionId)) {
          user.tokens = tokens;
          return user;
        }
      } on KeeAccountUnverifiedException {
        // Either user has just registered or has just signed in past the verification status
        // checks so we can assume missing tokens must be because the user is still expired
        // (new sub has not taken effect yet)
      }
    }
    return null;
  }
}
