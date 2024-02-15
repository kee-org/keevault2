import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keevault/cubit/account_cubit.dart';
import 'package:keevault/cubit/entry_cubit.dart';
import 'package:keevault/cubit/vault_cubit.dart';
import 'package:keevault/vault_backend/user.dart';
import 'package:keevault/widgets/dialog_utils.dart';
import '../cubit/interaction_cubit.dart';
import '../generated/l10n.dart';
import 'in_app_messenger.dart';

class VaultDrawerWidget extends StatelessWidget {
  const VaultDrawerWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return BlocBuilder<EntryCubit, EntryState>(builder: (context, entryState) {
      return BlocBuilder<VaultCubit, VaultState>(builder: (context, state) {
        final isSaveEnabled = entryState is! EntryLoaded &&
            (state is VaultLoaded && state.vault.files.current.isDirty) &&
            !(state is VaultSaving && state.locally);
        return Row(
          children: [
            Expanded(
              child: Container(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: _buildIcon(state, str),
                  label: _buildTitle(state, str),
                  onPressed: () async {
                    await DialogUtils.showSimpleAlertDialog(context, null, _buildDescription(state, str),
                        routeAppend: 'vaultStatusExplanation');
                  },
                ),
              ),
            ),
            ElevatedButton(
              onPressed: isSaveEnabled
                  ? () async {
                      final iam = InAppMessengerWidget.of(context);
                      final accountCubit = BlocProvider.of<AccountCubit>(context);
                      final vaultCubit = BlocProvider.of<VaultCubit>(context);
                      await BlocProvider.of<InteractionCubit>(context).databaseSaved();
                      await iam.showIfAppropriate(InAppMessageTrigger.vaultSaved);
                      User? user = accountCubit.currentUserIfKnown;
                      await vaultCubit.save(user);
                    }
                  : null,
              child: Text(str.save.toUpperCase()),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: ElevatedButton(
                onPressed: () async {
                  final vaultCubit = BlocProvider.of<VaultCubit>(context);
                  final accountCubit = BlocProvider.of<AccountCubit>(context);
                  if (state is VaultLoaded && state.vault.files.current.isDirty) {
                    final proceed = await DialogUtils.showConfirmDialog(
                        context: context,
                        params: ConfirmDialogParams(
                            content: str.appCannotLock,
                            negativeButtonText: str.alertNo,
                            positiveButtonText: str.discardChanges));
                    if (!proceed) {
                      return;
                    }
                  }
                  vaultCubit.lock();
                  await accountCubit.signout();
                },
                child: Text(str.lock.toUpperCase()),
              ),
            ),
          ],
        );
      });
    });
  }

  Icon _buildIcon(VaultState state, S str) {
    if (state is VaultUploadCredentialsRequired) {
      return Icon(Icons.error);
    } else if (state is VaultSaving && state.remotely) {
      return Icon(Icons.cloud_upload);
    } else if (state is VaultSaving && state.locally) {
      return Icon(Icons.save);
    } else if (state is VaultRefreshing) {
      return Icon(Icons.cloud_download);
    } else if (state is VaultBackgroundError) {
      return Icon(Icons.sync_problem);
    } else if (state is VaultLoaded) {
      if (state.vault.hasPendingChanges) {
        return Icon(Icons.sync_lock);
      }
      return Icon(Icons.check_circle);
    }
    return Icon(Icons.device_unknown);
  }

  Widget _buildTitle(VaultState state, S str) {
    if (state is VaultUploadCredentialsRequired) {
      return Text(str.vaultStatusActionNeeded);
    } else if (state is VaultSaving && state.remotely) {
      return Text(str.vaultStatusUploading);
    } else if (state is VaultSaving && state.locally) {
      return Text(str.vaultStatusSaving);
    } else if (state is VaultRefreshing) {
      return Text(str.vaultStatusRefreshing);
    } else if (state is VaultBackgroundError) {
      return Text(str.vaultStatusError);
    } else if (state is VaultLoaded) {
      if (state.vault.hasPendingChanges) {
        return Text(str.vaultStatusSaveNeeded);
      }
      return Text(str.vaultStatusLoaded);
    }
    return Text(str.vaultStatusUnknownState);
  }

  String _buildDescription(VaultState state, S str) {
    if (state is VaultUploadCredentialsRequired) {
      return str.vaultStatusDescPasswordChanged;
    } else if (state is VaultReconcilingUpload) {
      return str.vaultStatusDescMerging;
    } else if (state is VaultSaving && state.remotely) {
      return str.vaultStatusDescUploading;
    } else if (state is VaultSaving && state.locally) {
      return str.vaultStatusDescSaving;
    } else if (state is VaultRefreshing) {
      return str.vaultStatusDescRefreshing;
    } else if (state is VaultBackgroundError) {
      return state.message;
    } else if (state is VaultLoaded) {
      if (state.vault.hasPendingChanges) {
        return str.vaultStatusDescSaveNeeded;
      }
      return str.vaultStatusDescLoaded;
    }
    return str.vaultStatusDescUnknown;
  }
}
