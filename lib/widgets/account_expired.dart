import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/config/app.dart';
import 'package:keevault/config/environment_config.dart';
import 'package:keevault/config/routes.dart';
import 'package:keevault/cubit/account_cubit.dart';
import 'package:keevault/cubit/vault_cubit.dart';
import 'package:keevault/vault_backend/user.dart';
import '../config/platform.dart';
import '../generated/l10n.dart';
import 'dialog_utils.dart';

typedef SubmitCallback = Future<void> Function(String string);

class AccountExpiredWidget extends StatefulWidget {
  const AccountExpiredWidget({super.key, required this.trialAvailable});

  final bool trialAvailable;

  @override
  State<AccountExpiredWidget> createState() => _AccountExpiredWidgetState();
}

class _AccountExpiredWidgetState extends State<AccountExpiredWidget> {
  final registrationEnabled =
      (EnvironmentConfig.iapGooglePlay && KeeVaultPlatform.isAndroid) ||
      (EnvironmentConfig.iapAppleAppStore && KeeVaultPlatform.isIOS);

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(str.subscriptionExpired, style: theme.textTheme.titleLarge),
          ),
          BlocBuilder<AccountCubit, AccountState>(
            builder: (context, state) {
              if (state is AccountExpired) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    widget.trialAvailable
                        ? str.subscriptionExpiredTrialAvailable
                        : expiryMessageForSubscriptionSource(state.user.subscriptionSource, str),
                    textAlign: TextAlign.center,
                  ),
                );
              } else {
                return Text(str.unexpected_error('Account in invalid state for ExpiredWidget'));
              }
            },
          ),
          BlocBuilder<AccountCubit, AccountState>(
            builder: (context, state) {
              if (state is AccountTrialRestartFinished) {
                return state.success
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(str.startNewTrialSuccess),
                          FilledButton(
                            onPressed: () async {
                              final accountCubit = BlocProvider.of<AccountCubit>(context);
                              BlocProvider.of<VaultCubit>(context).signout();
                              await accountCubit.signout();
                              await AppConfig.router.navigateTo(
                                AppConfig.navigatorKey.currentContext!,
                                Routes.root,
                                clearStack: true,
                              );
                            },
                            child: Text(str.signin),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(str.startNewTrialError, style: theme.textTheme.bodyLarge),
                          FilledButton(
                            onPressed: () async {
                              final accountCubit = BlocProvider.of<AccountCubit>(context);
                              BlocProvider.of<VaultCubit>(context).signout();
                              await accountCubit.signout();
                              await AppConfig.router.navigateTo(
                                AppConfig.navigatorKey.currentContext!,
                                Routes.root,
                                clearStack: true,
                              );
                            },
                            child: Text(str.signout),
                          ),
                        ],
                      );
              } else if (state is AccountExpired) {
                final userEmail = state.user.email;
                final loading = state is AccountTrialRestartStarted;
                if (state.user.subscriptionSource == AccountSubscriptionSource.chargeBee) {
                  return widget.trialAvailable
                      ? FilledButton.icon(
                          onPressed: loading
                              ? null
                              : () async {
                                  final accountCubit = BlocProvider.of<AccountCubit>(context);
                                  await accountCubit.restartTrial();
                                },
                          label: Text(str.startFreeTrial),
                          icon: loading
                              ? Container(
                                  width: 24,
                                  height: 24,
                                  padding: const EdgeInsets.all(2.0),
                                  child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                )
                              : Icon(Icons.favorite),
                        )
                      : TextButton.icon(
                          icon: Text(str.restartSubscription),
                          label: Icon(Icons.open_in_new),
                          onPressed: () async {
                            final accountCubit = BlocProvider.of<AccountCubit>(context);
                            final vaultCubit = BlocProvider.of<VaultCubit>(context);
                            await DialogUtils.openUrl(
                              '${EnvironmentConfig.webUrl}/#pfEmail=$userEmail,dest=manageAccount',
                            );
                            vaultCubit.signout();
                            await accountCubit.signout();
                            await AppConfig.router.navigateTo(
                              AppConfig.navigatorKey.currentContext!,
                              Routes.root,
                              clearStack: true,
                            );
                          },
                        );
                } else if (registrationEnabled &&
                    (state.user.subscriptionSource == AccountSubscriptionSource.googlePlay ||
                        state.user.subscriptionSource == AccountSubscriptionSource.appleAppStore ||
                        state.user.subscriptionSource == AccountSubscriptionSource.unknown)) {
                  return TextButton.icon(
                    icon: Text(str.restartSubscription),
                    label: Icon(Icons.favorite),
                    onPressed: () async {
                      final vaultCubit = BlocProvider.of<VaultCubit>(context);
                      vaultCubit.signout();
                      await AppConfig.router.navigateTo(
                        AppConfig.navigatorKey.currentContext!,
                        Routes.createAccount,
                        clearStack: true,
                      );
                    },
                  );
                } else {
                  return TextButton.icon(
                    icon: Text(str.visitTheForum),
                    label: Icon(Icons.open_in_new),
                    onPressed: () async {
                      final accountCubit = BlocProvider.of<AccountCubit>(context);
                      final vaultCubit = BlocProvider.of<VaultCubit>(context);
                      await DialogUtils.openUrl('https://forum.kee.pm');
                      vaultCubit.signout();
                      await accountCubit.signout();
                      await AppConfig.router.navigateTo(
                        AppConfig.navigatorKey.currentContext!,
                        Routes.root,
                        clearStack: true,
                      );
                    },
                  );
                }
              } else {
                return Text(str.unexpected_error('Account in invalid state for ExpiredWidget'));
              }
            },
          ),
        ],
      ),
    );
  }

  String expiryMessageForSubscriptionSource(AccountSubscriptionSource subscriptionSource, S str) {
    if (subscriptionSource == AccountSubscriptionSource.chargeBee) {
      return str.subscriptionExpiredDetails;
    }
    if (subscriptionSource == AccountSubscriptionSource.appleAppStore ||
        subscriptionSource == AccountSubscriptionSource.googlePlay ||
        registrationEnabled) {
      return str.subscriptionExpiredIapDetails;
    }
    return str.subscriptionExpiredNoAction;
  }
}
