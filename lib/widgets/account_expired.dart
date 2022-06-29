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
    super.key,
    required this.trialAvailable,
  });

  final bool trialAvailable;

  @override
  State<AccountExpiredWidget> createState() => _AccountExpiredWidgetState();
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
                            final accountCubit = BlocProvider.of<AccountCubit>(context);
                            await BlocProvider.of<VaultCubit>(context).signout();
                            await accountCubit.signout();
                            // Potential loss of context here but I think because the account cubit emit is the
                            // last thing to happen in the signout task Flutter won't have had a chance to draw
                            // a new frame and detach this defunct widget from the context. If WTFs happen around
                            // here though, this is a strong candidate for the cause of the problem.
                            // ignore: use_build_context_synchronously
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
                            // Potential loss of context here as per above comment
                            final accountCubit = BlocProvider.of<AccountCubit>(context);
                            await BlocProvider.of<VaultCubit>(context).signout();
                            await accountCubit.signout();
                            // ignore: use_build_context_synchronously
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
                        final accountCubit = BlocProvider.of<AccountCubit>(context);
                        final vaultCubit = BlocProvider.of<VaultCubit>(context);
                        await DialogUtils.openUrl(EnvironmentConfig.webUrl + '/#pfEmail=$userEmail,dest=manageAccount');
                        // Potential loss of context here as per earlier comment
                        await vaultCubit.signout();
                        await accountCubit.signout();
                        // ignore: use_build_context_synchronously
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
