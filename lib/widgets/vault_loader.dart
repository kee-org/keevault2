import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:keevault/config/app.dart';
import 'package:keevault/config/routes.dart';
import 'package:keevault/credentials/quick_unlocker.dart';
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
import '../password_strength.dart';
import 'import_credentials.dart';
import 'loading_spinner.dart';
import 'vault_password_credentials.dart';
import '../generated/l10n.dart';

class VaultLoaderWidget extends StatefulWidget {
  const VaultLoaderWidget({super.key});

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
    final latestState = accountCubit.state;

    if ((latestState is AccountAuthenticated &&
            latestState is! AccountEmailChangeRequested &&
            latestState is! AccountEmailNotVerified &&
            latestState is! AccountExpired) ||
        latestState is AccountAuthenticationBypassed) {
      // If user enters incorrect password when prompted after resubscribing following account expiry,
      // an error saying their account password is out of sync with the Kdbx may get thrown by download().
      // If they follow the suggested resolution of signing in again or kill the app first to do that,
      // it seems to resolve itself. In future would be good to get to the bottom of why that happens
      // and maybe workaround the issue in a neater way for the user.
      await vaultCubit.download(user,
          credentialsWithStrength: StrengthAssessedCredentials(ProtectedValue.fromString(password), user.emailParts));
    }
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
          showError: state.causedByInteraction || state.quStatus == QUStatus.mapAvailable,
          quStatus: state.quStatus,
        );
      } else if (state is VaultRemoteFileCredentialsRequired) {
        return VaultPasswordCredentialsWidget(
          reason: str.unlockRequired,
          onSubmit: _remoteAuthenticate,
          showError: state.causedByInteraction,
        );
      } else if (state is VaultImportingCredentialsRequired) {
        return ImportCredentialsWidget(
          vaultState: state,
          submitPassword: _importAuthenticate,
        );
      } else if (state is VaultError) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Error: ${state.message}',
            style: theme.textTheme.bodyLarge,
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
      // Once the state becomes VaultLoaded we want to redirect to the main vault widget
      // (and thus clear the loading spinner that is rendering in this widget). This
      // can take a moment to complete and in the mean time we will typically have
      // changed state to VaultRefreshing and thus entered this listener function a
      // second time. To prevent wasted effort and duplicated metrics being recorded,
      // we take no action when in VaultRefreshing state. Perhaps we should have
      // exceptions for other states too but I'm yet to find any real-world need.
      if (state is VaultLoaded && state is! VaultRefreshing) {
        final AutofillState autofillState = BlocProvider.of<AutofillCubit>(context).state;
        final filterContext = BlocProvider.of<FilterCubit>(context);
        final interactionContext = BlocProvider.of<InteractionCubit>(context);
        if (autofillState is AutofillRequested && autofillState.enabled) {
          if (!autofillState.forceInteractive) {
            final matchFound = await BlocProvider.of<AutofillCubit>(context).autofillWithList(state.vault);
            if (matchFound) {
              return;
            }
          }
        }
        filterContext.start(
            state.vault.files.current.body.rootGroup.uuid.uuid, Settings.getValue<bool>('expandGroups') ?? true);
        await interactionContext.databaseOpened();
        // context my have become detached from widget tree by this point
        // but router requires we have it so have to use this hack
        await AppConfig.router.navigateTo(AppConfig.navigatorKey.currentContext!, Routes.vault, replace: true);
      }
    });
  }
}
