import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/config/app.dart';
import 'package:keevault/config/environment_config.dart';
import 'package:keevault/config/routes.dart';
import 'package:keevault/cubit/account_cubit.dart';
import 'package:keevault/cubit/vault_cubit.dart';
import '../generated/l10n.dart';
import 'dialog_utils.dart';

typedef SubmitCallback = Future<void> Function(String string);

class AccountExpiredWidget extends StatefulWidget {
  const AccountExpiredWidget({
    Key? key,
    required this.trialAvailable,
  }) : super(key: key);

  final bool trialAvailable;

  @override
  _AccountExpiredWidgetState createState() => _AccountExpiredWidgetState();
}

class _AccountExpiredWidgetState extends State<AccountExpiredWidget> {
  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            str.subscriptionExpired,
            style: theme.textTheme.headline6,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            widget.trialAvailable ? str.subscriptionExpiredTrialAvailable : str.subscriptionExpiredDetails,
          ),
        ),
        BlocBuilder<AccountCubit, AccountState>(
          builder: (context, state) {
            if (state is AccountTrialRestartFinished) {
              return state.success
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(str.startNewTrialSuccess),
                        ElevatedButton(
                          onPressed: () async {
                            await BlocProvider.of<VaultCubit>(context).signout();
                            final accountCubit = BlocProvider.of<AccountCubit>(context);
                            await accountCubit.signout();
                            AppConfig.router.navigateTo(context, Routes.root, clearStack: true);
                          },
                          child: Text(str.signin),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          str.startNewTrialError,
                          style: theme.textTheme.bodyText1,
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await BlocProvider.of<VaultCubit>(context).signout();
                            final accountCubit = BlocProvider.of<AccountCubit>(context);
                            await accountCubit.signout();
                            AppConfig.router.navigateTo(context, Routes.root, clearStack: true);
                          },
                          child: Text(str.signout),
                        ),
                      ],
                    );
            } else if (state is AccountExpired) {
              final userEmail = state.user.email;
              final loading = state is AccountTrialRestartStarted;
              return widget.trialAvailable
                  ? ElevatedButton.icon(
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
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Icon(Icons.favorite),
                    )
                  : TextButton.icon(
                      icon: Text(str.restartSubscription),
                      label: Icon(Icons.open_in_new),
                      onPressed: () async {
                        await DialogUtils.openUrl(EnvironmentConfig.webUrl + '/#pfEmail=$userEmail,dest=manageAccount');
                        await BlocProvider.of<VaultCubit>(context).signout();
                        final accountCubit = BlocProvider.of<AccountCubit>(context);
                        await accountCubit.signout();
                        AppConfig.router.navigateTo(context, Routes.root, clearStack: true);
                      },
                    );
            } else {
              return Text(str.unexpected_error('Account in invalid state for ExpiredWidget'));
            }
          },
        ),
      ]),
    );
  }
}
