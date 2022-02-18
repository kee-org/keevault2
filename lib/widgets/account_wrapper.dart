import 'package:keevault/widgets/vault_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cubit/account_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/vault_cubit.dart';
import 'account_expired.dart';
import 'loading_spinner.dart';
import 'vault_account_credentials.dart';
import 'vault_local_password_create.dart';
import 'vault_password_credentials.dart';
import '../generated/l10n.dart';

class AccountWrapperWidget extends StatefulWidget {
  const AccountWrapperWidget({Key? key}) : super(key: key);

  @override
  AccountWrapperState createState() => AccountWrapperState();
}

class AccountWrapperState extends State<AccountWrapperWidget> {
  Future<void> _initVault(String password) async {
    final accountCubit = BlocProvider.of<AccountCubit>(context);
    if (accountCubit.state is AccountIdentified) {
      final user = await accountCubit.finishSignin(password);
      await BlocProvider.of<VaultCubit>(context).startup(user, password);
    } else {
      throw Exception('Account not identified yet');
    }
  }

  Future<void> _startSignin(String email) async {
    await BlocProvider.of<AccountCubit>(context).startSignin(email);
  }

  Future<void> _requestLocalOnly() async {
    final accountCubit = BlocProvider.of<AccountCubit>(context);
    final vaultCubit = BlocProvider.of<VaultCubit>(context);
    if (await vaultCubit.localFreeKdbxExists()) {
      await accountCubit.confirmLocalOnly();
      await BlocProvider.of<VaultCubit>(context).startupFreeMode(null);
    } else {
      accountCubit.requestLocalOnly();
    }
  }

  Future<void> _createLocalOnlyVault(String newPassword) async {
    await BlocProvider.of<AccountCubit>(context).confirmLocalOnly();
    await BlocProvider.of<VaultCubit>(context).create(newPassword);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user.current.freeImportedAt');
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return Column(
      children: [
        BlocConsumer<AccountCubit, AccountState>(builder: (context, state) {
          if (state is AccountInitial) {
            return LoadingSpinner(tooltip: str.loading);
          } else if (state is AccountUnknown) {
            return VaultAccountCredentialsWidget(onSubmit: _startSignin, onLocalOnlyRequested: _requestLocalOnly);
          } else if (state is AccountLocalOnlyRequested) {
            return VaultLocalOnlyCreateWidget(
              onSubmit: _createLocalOnlyVault,
              showError: false,
            );
          } else if (state is AccountIdentifying) {
            return LoadingSpinner(tooltip: str.identifying);
          } else if (state is AccountIdentified) {
            return VaultPasswordCredentialsWidget(
              reason: str.welcome_message(state.user.email ?? ''),
              onSubmit: _initVault,
              showError: state.causedByInteraction,
            );
          } else if (state is AccountAuthenticating) {
            return LoadingSpinner(tooltip: str.authenticating);
          } else if (state is AccountExpired) {
            return AccountExpiredWidget(trialAvailable: state.trialAvailable);
          } else if (state is AccountChosen || state is AccountLocalOnly) {
            return VaultLoaderWidget();
          }
          return Text(str.vaultStatusUnknownState);
        }, listener: (context, state) {
          if (state is AccountError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('account error')));
          }
        }),
      ],
    );
  }
}
