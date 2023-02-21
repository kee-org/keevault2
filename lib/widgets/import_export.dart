import 'package:collection/collection.dart' show IterableExtension;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/cubit/entry_cubit.dart';
import 'package:keevault/cubit/vault_cubit.dart';
import 'package:keevault/locked_vault_file.dart';
import 'package:keevault/logging/logger.dart';
import 'package:keevault/widgets/bottom.dart';
import 'package:keevault/widgets/dialog_utils.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
import '../generated/l10n.dart';
import 'package:permission_handler/permission_handler.dart' show Permission;
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

import '../permissions.dart';
import 'coloured_safe_area_widget.dart';

class ImportExportWidget extends StatelessWidget {
  const ImportExportWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final str = S.of(context);
    return TraceableWidget(
      traceTitle: 'ImportExport',
      child: BlocBuilder<VaultCubit, VaultState>(
        builder: (context, state) {
          return ColouredSafeArea(
            child: Scaffold(
              appBar: AppBar(title: Text(str.importExport)),
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SafeArea(
                    top: false,
                    left: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(str.keeVaultFormatExplainer),
                        ),
                        Divider(),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                          child: Text(
                            str.import,
                            style: theme.textTheme.headlineMedium,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(str.importOtherInstructions1),
                        ),
                        Text(str.importOtherInstructions4),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            elevation: 6,
                            child: Column(
                              children: [
                                ListTile(
                                  title: Text(str.importKdbx),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    str.willTrySamePasswordFirst,
                                  ),
                                ),
                                ButtonBar(
                                  alignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton(
                                      onPressed: state is VaultLoaded ? () => {_import(context, state)} : null,
                                      child: Text(str.import),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Divider(),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                          child: Text(
                            str.export,
                            style: theme.textTheme.headlineMedium,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            elevation: 6,
                            child: Column(
                              children: [
                                ListTile(
                                  title: Text(str.importKdbx),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    str.exportUsesCurrentPassword,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                                  child: Text(
                                    str.rememberExportsDoNotUpdate,
                                  ),
                                ),
                                ButtonBar(
                                  alignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton(
                                      onPressed: (state is VaultLoaded) ? () => {_export(context, state)} : null,
                                      child: Text(str.export),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              bottomNavigationBar: BottomBarWidget(() => toggleBottomDrawerVisibility(context)),
            ),
          );
        },
      ),
    );
  }

  _import(BuildContext context, VaultLoaded vaultState) async {
    final str = S.of(context);
    final vaultCubit = BlocProvider.of<VaultCubit>(context);
    final permissionResult = await tryToGetPermission(
      context,
      Permission.storage,
      'Storage',
      str.import.toLowerCase(),
      str.cancelExportOrImport(str.import.toLowerCase()),
    );
    if (permissionResult == PermissionResult.approved) {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          withData: true,
        );
        await FilePicker.platform.clearTemporaryFiles(); //TODO:f: concurrently with below

        final bytes = result?.files.firstOrNull?.bytes;
        if (bytes == null) {
          // User canceled the picker
          return;
        }
        final extension = result?.files.firstOrNull?.extension;
        if (extension != 'kdbx') {
          await DialogUtils.showErrorDialog(context, str.incorrectFile, str.selectKdbxFile);
          return;
        }
        final lockedSource = LockedVaultFile(
          bytes,
          DateTime.now(),
          vaultState.vault.files.current.credentials,
          null,
          null,
        );
        await vaultCubit.importKdbx(
            vaultState.vault, lockedSource, vaultState.vault.files.current.credentials, false, true);
      } on KdbxUnsupportedException catch (e) {
        l.e('Import failed: $e');
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await DialogUtils.showErrorDialog(context, str.importError, str.importErrorKdbx + e.hint);
        });
      } on Exception catch (e, st) {
        l.e('Import failed: $e ; $st');
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await DialogUtils.showErrorDialog(context, str.importError, str.importErrorDetails);
        });
      }
    }
  }

  _export(BuildContext context, VaultLoaded state) async {
    final str = S.of(context);
    final sm = ScaffoldMessenger.of(context);

    final EntryState entryState = BlocProvider.of<EntryCubit>(context).state;
    final loadedState = entryState is EntryLoaded ? entryState : null;
    final bool entryBeingEdited = loadedState?.entry.isDirty ?? false;
    if (state.vault.files.current.isDirty || entryBeingEdited) {
      l.i('Vault is dirty before an export');
      if (!await DialogUtils.showConfirmDialog(
          context: context,
          params: ConfirmDialogParams(
            title: str.export,
            content: str.exportDirtyFileWarning,
            negativeButtonText: str.cancelExportOrImport(str.export.toLowerCase()),
            positiveButtonText: str.exportAnyway,
          ))) {
        return;
      }
    }
    final permissionResult = await tryToGetPermission(
      context,
      Permission.storage,
      'Storage',
      str.export.toLowerCase(),
      str.cancelExportOrImport(str.export.toLowerCase()),
    );
    if (permissionResult == PermissionResult.approved) {
      try {
        final params = SaveFileDialogParams(
          data: state.vault.files.remoteMergeTargetLocked.kdbxBytes,
          fileName: 'kee-vault-export-${DateTime.now().millisecondsSinceEpoch}.kdbx',
        );
        final outputFilename = await FlutterFileDialog.saveFile(params: params);
        if (outputFilename == null) {
          l.d('File system integration reports that the export was cancelled.');
          return;
        }
        l.i('Exported vault to $outputFilename');
        sm.showSnackBar(SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(str.exported),
            ],
          ),
          duration: Duration(seconds: 3),
        ));
      } on Exception catch (e, st) {
        l.e('Export failed: $e', st);
        await DialogUtils.showErrorDialog(context, str.exportError, str.exportErrorDetails);
      }
    }
  }
}
