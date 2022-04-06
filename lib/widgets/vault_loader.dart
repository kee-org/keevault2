import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:keevault/config/app.dart';
import 'package:keevault/config/routes.dart';
import 'package:keevault/cubit/autofill_cubit.dart';
import 'package:keevault/cubit/filter_cubit.dart';
import 'package:keevault/vault_backend/user.dart';
import 'package:keevault/widgets/vault_imported.dart';
import '../cubit/account_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/interaction_cubit.dart';
import '../cubit/vault_cubit.dart';
import 'package:kdbx/kdbx.dart';
import 'loading_spinner.dart';
import 'vault_password_credentials.dart';
import '../generated/l10n.dart';

class VaultLoaderWidget extends StatefulWidget {
  const VaultLoaderWidget({Key? key}) : super(key: key);

  @override
  VaultLoaderState createState() => VaultLoaderState();
}

class VaultLoaderState extends State<VaultLoaderWidget> {
  Future<void> _downloadAuthenticate(String password) async {
    final accountCubit = BlocProvider.of<AccountCubit>(context);
    final vaultCubit = BlocProvider.of<VaultCubit>(context);
    final AccountState state = accountCubit.state;
    User user;
    if (state is AccountIdentified) {
      user = await accountCubit.finishSignin(password);
    } else if (state is AccountChosen) {
      user = await accountCubit.fullSignin(password);
    } else {
      throw Exception('Account not chosen yet');
    }
    await vaultCubit.download(user, Credentials(ProtectedValue.fromString(password)));
  }

  Future<void> _localAuthenticate(String password) async {
    final AccountState state = BlocProvider.of<AccountCubit>(context).state;
    if (state is AccountChosen) {
      final protectedValue = ProtectedValue.fromString(password);
      await BlocProvider.of<VaultCubit>(context).openLocal(state.user, protectedValue);
    } else if (state is AccountLocalOnly) {
      final protectedValue = ProtectedValue.fromString(password);
      await BlocProvider.of<VaultCubit>(context).openLocal(null, protectedValue);
    }
  }

  Future<bool> _localAuthenticateWithStoredCreds() async {
    final AccountState state = BlocProvider.of<AccountCubit>(context).state;
    if (state is AccountChosen) {
      return await BlocProvider.of<VaultCubit>(context).openLocal(state.user, null);
    } else if (state is AccountLocalOnly) {
      return await BlocProvider.of<VaultCubit>(context).openLocal(null, null);
    }
    return false;
  }

  Future<void> _remoteAuthenticate(String password) async {
    final AccountState accountState = BlocProvider.of<AccountCubit>(context).state;
    final VaultState vaultState = BlocProvider.of<VaultCubit>(context).state;
    if (accountState is AccountAuthenticated && vaultState is VaultRemoteFileCredentialsRequired) {
      await BlocProvider.of<VaultCubit>(context).changeLocalPasswordFromRemote(
        accountState.user,
        password,
      );
    }
  }

  Future<void> _importAuthenticate(String password) async {
    final VaultState vaultState = BlocProvider.of<VaultCubit>(context).state;
    if (vaultState is VaultImportingCredentialsRequired) {
      await BlocProvider.of<VaultCubit>(context).importKdbx(
        vaultState.destination,
        vaultState.source,
        Credentials(ProtectedValue.fromString(password)),
        true,
        vaultState.manual,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    return BlocConsumer<VaultCubit, VaultState>(builder: (context, state) {
      if (state is VaultInitial || state is VaultLoaded) {
        // Initial rendering of Vault contents can take more than one frame so keep the
        // spinner until this wrapper widget is destroyed by navigation
        return LoadingSpinner(tooltip: str.loading);
      } else if (state is VaultDownloadCredentialsRequired) {
        return VaultPasswordCredentialsWidget(
          reason: str.unlockRequired,
          onSubmit: _downloadAuthenticate,
          showError: state.causedByInteraction,
        );
      } else if (state is VaultLocalFileCredentialsRequired) {
        return VaultPasswordCredentialsWidget(
          reason: str.unlockRequired,
          onSubmit: _localAuthenticate,
          forceBiometric: _localAuthenticateWithStoredCreds,
          showError: state.causedByInteraction,
        );
      } else if (state is VaultRemoteFileCredentialsRequired) {
        return VaultPasswordCredentialsWidget(
          reason: str.unlockRequired,
          onSubmit: _remoteAuthenticate,
          showError: state.causedByInteraction,
        );
      } else if (state is VaultImportingCredentialsRequired) {
        return VaultPasswordCredentialsWidget(
          reason: str.importUnlockRequired,
          onSubmit: _importAuthenticate,
          showError: state.causedByInteraction,
        );
      } else if (state is VaultError) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Error: ${state.message}',
            style: theme.textTheme.bodyText1,
          ),
        );
      } else if (state is VaultDownloading) {
        return LoadingSpinner(tooltip: str.downloading);
      } else if (state is VaultOpening) {
        return LoadingSpinner(tooltip: str.opening);
      } else if (state is VaultCreating) {
        return LoadingSpinner(tooltip: str.creating);
      } else if (state is VaultImported) {
        return VaultImportedWidget();
      }
      return LoadingSpinner(tooltip: 'Unknown app state: ${state.toString()}');
    }, listener: (context, state) async {
      if (state is VaultLoaded) {
        final AutofillState autofillState = BlocProvider.of<AutofillCubit>(context).state;
        if (autofillState is AutofillRequested && autofillState.enabled) {
          if (!autofillState.forceInteractive) {
            final matchFound = await BlocProvider.of<AutofillCubit>(context).autofillWithList(state.vault);
            if (matchFound) {
              return;
            }
          }
        }
        BlocProvider.of<FilterCubit>(context)
            .start(state.vault.files.current.body.rootGroup.uuid.uuid, Settings.getValue<bool>('expandGroups', true));
        await BlocProvider.of<InteractionCubit>(context).databaseOpened();
        // context my have become detached from widget tree by this point
        AppConfig.router.navigateTo(AppConfig.navigatorKey.currentContext!, Routes.vault, replace: true);
      }
    });
  }
}
