import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:animations/animations.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jiffy/jiffy.dart';
import 'package:kdbx/kdbx.dart';
import 'package:barcode_scan2/barcode_scan2.dart' as barcode;
import 'package:base32/base32.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

import 'package:keevault/cubit/entry_cubit.dart';
import 'package:keevault/cubit/vault_cubit.dart';
import 'package:keevault/logging/logger.dart';
import 'package:keevault/model/entry.dart';
import 'package:keevault/model/field.dart';
import 'package:keevault/uuid_util.dart';
import 'package:keevault/widgets/icon_chooser.dart';
import 'package:keevault/widgets/labels.dart';
import 'package:keevault/widgets/password_generator.dart';
import 'package:permission_handler/permission_handler.dart' show Permission;

import '../colors.dart';
import '../generated/l10n.dart';
import '../otpauth.dart';
import '../permissions.dart';
import 'binaries.dart';
import 'bottom.dart';
import 'color_chooser.dart';
import 'dialog_utils.dart';
import 'entry_field.dart';
import 'entry_history.dart';
import 'entry_integration_settings.dart';
import 'group_move_tree.dart';

class EntryWidget extends StatelessWidget {
  final Function endEditing;
  final Function? onDelete;
  final Map<KdbxCustomIcon, Image> allCustomIcons;
  final Function(int index) revertTo;
  final Function(int index) deleteAt;
  final AppBar? appBar;
  const EntryWidget(
      {Key? key,
      required this.endEditing,
      this.onDelete,
      required this.allCustomIcons,
      required this.revertTo,
      required this.deleteAt,
      this.appBar})
      : super(key: key);

  void changeIcon(BuildContext context, EntryColor? color) async {
    final iconPicked = await showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) => IconChooser(
        customIcons: allCustomIcons,
        iconColor: Theme.of(context).brightness == Brightness.dark ? entryColorsContrast[color] : entryColors[color],
      ),
    );
    if (iconPicked != null) {
      final cubit = BlocProvider.of<EntryCubit>(context);
      cubit.changeIcon(iconPicked is KdbxIcon ? iconPicked : null, iconPicked is KdbxCustomIcon ? iconPicked : null);
    }
  }

  void changeColor(BuildContext context, EntryColor color) async {
    final cubit = BlocProvider.of<EntryCubit>(context);
    cubit.changeColor(color);
  }

  Future<void> _attachFile(BuildContext context) async {
    final str = S.of(context);
    final permissionResult = await tryToGetPermission(
      context,
      Permission.storage,
      'Storage',
      str.permissionReasonAttachFile,
      str.alertCancel,
    );
    if (permissionResult == PermissionResult.approved) {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          withData: true,
        );
        await FilePicker.platform.clearTemporaryFiles(); //TODO:f concurrently with below await operation

        final bytes = result?.files.firstOrNull?.bytes;
        if (bytes != null) {
          final fileName = result?.files.firstOrNull?.name ?? UuidUtil.createNonCryptoUuid();
          await _attachFileContent(context, fileName, bytes);
        } else {
          // User canceled the picker
        }
      } on Exception {
        DialogUtils.showErrorDialog(context, str.attachmentError, str.attachmentErrorDetails);
      }
    }
  }

  Future<void> _attachFileContent(BuildContext context, String fileName, Uint8List bytes) async {
    final str = S.of(context);

    if (bytes.lengthInBytes > 250 * 1024) {
      await DialogUtils.showErrorDialog(
        context,
        str.vaultStatusError,
        str.entryAttachmentSizeError,
      );
      return;
    }

    if (bytes.lengthInBytes > 20 * 1024) {
      if (!await DialogUtils.showConfirmDialog(
        context: context,
        params: ConfirmDialogParams(
          content: str.entryAttachmentSizeWarning,
        ),
      )) {
        return;
      }
    }

    final cubit = BlocProvider.of<EntryCubit>(context);
    cubit.attachFile(
      fileName: fileName,
      bytes: bytes,
    );
  }

  Future<void> _selectCustomKey(BuildContext context) async {
    final str = S.of(context);
    final key = await SimplePromptDialog(
      title: str.detNetField,
      labelText: str.fieldName,
    ).show(context);
    if (key != null && key.isNotEmpty) {
      final field = FieldViewModel.fromCustomAndBrowser(
          null,
          null,
          BrowserFieldModel(
            displayName: key,
            value: '',
          ));
      final cubit = BlocProvider.of<EntryCubit>(context);
      cubit.addField(field);
      //TODO:f focus keyboard on new field - maybe with an onNextAnimationFrame type of callback or maybe a bloclistener to inspect the old and new state

    }
  }

  Future<OtpAuth?> _askForTotpSecret(BuildContext context) async {
    final str = S.of(context);
    Future<OtpAuth?> _cleanOtpCodeCode(String totpCode) async {
      try {
        if (totpCode.startsWith(OtpAuth.URI_PREFIX)) {
          return OtpAuth.fromUri(Uri.parse(totpCode));
        }
        final cleaned = totpCode.replaceAll(' ', '');
        final value = base32.decode(cleaned);
        l.d('Got totp secret with ${value.lengthInBytes} bytes.');
        return OtpAuth(secret: value);
      } catch (e, stackTrace) {
        l.w('Invalid base32 code?', e, stackTrace);
        return null;
      }
    }

    final permissionResult = await tryToGetPermission(
      context,
      Permission.camera,
      'Camera',
      str.permissionReasonScanBarcodes,
      str.detSetupOtpManualButton,
    );
    if (permissionResult == PermissionResult.pending) {
      return null;
    }

    if (permissionResult == PermissionResult.approved) {
      try {
        bool tryManualCodeEntryNext = false;
        while (!tryManualCodeEntryNext) {
          l.d('Opening barcode scanner.');

          final barcodeResult = await barcode.BarcodeScanner.scan();
          if (barcodeResult.type == barcode.ResultType.Barcode) {
            final result = await _cleanOtpCodeCode(barcodeResult.rawContent);
            if (result == null) {
              final tryAgain = await DialogUtils.showConfirmDialog(
                  context: context,
                  params: ConfirmDialogParams(
                    title: str.detOtpQrWrong,
                    content: str.detOtpQrWrongBody,
                    positiveButtonText: str.tryAgain,
                    negativeButtonText: str.detSetupOtpManualButton,
                  ));
              if (!tryAgain) {
                tryManualCodeEntryNext = true;
              }
            } else {
              return result;
            }
          }
          if (barcodeResult.type == barcode.ResultType.Error) {
            final tryAgain = await DialogUtils.showConfirmDialog(
                context: context,
                params: ConfirmDialogParams(
                  title: str.detOtpQrError,
                  content: str.detOtpQrErrorBody,
                  positiveButtonText: str.tryAgain,
                  negativeButtonText: str.detSetupOtpManualButton,
                ));
            if (!tryAgain) {
              tryManualCodeEntryNext = true;
            }
          }
          if (barcodeResult.type == barcode.ResultType.Cancelled) {
            tryManualCodeEntryNext = true;
          }
        }
      } on PlatformException catch (e, stackTrace) {
        if (e.code == barcode.BarcodeScanner.cameraAccessDenied) {
          // We already tried to get the user to grant permission so if they really don't want to
          // by this point, they'll have to enter the code manually.
          l.i('User denied camera permission.. Automatically continuing to manual code entry.', e);
        } else {
          l.e('Unknown PlatformException. Automatically continuing to manual code entry.', e, stackTrace);
        }
      } catch (e, stackTrace) {
        l.w('Error during barcode scanning. Automatically continuing to manual code entry.', e, stackTrace);
      }
    }

    while (true) {
      final totpCode = await SimplePromptDialog(
              title: str.otpManualTitle,
              bodyText: str.otpExplainer1,
              labelText: str.otpCodeLabel,
              icon: Icon(Icons.lock_clock))
          .show(context);
      if (totpCode == null) {
        return null;
      }
      final result = await _cleanOtpCodeCode(totpCode);
      if (result == null) {
        await DialogUtils.showSimpleAlertDialog(
          context,
          str.otpManualError,
          str.otpManualErrorBody,
          routeAppend: 'totpInvalidKey',
        );
      } else {
        return result;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    return BlocBuilder<EntryCubit, EntryState>(builder: (context, state) {
      if (state is! EntryLoaded) return Container();
      final EditEntryViewModel entry = state.entry;
      return BlocBuilder<VaultCubit, VaultState>(
        builder: (context, state) {
          final loadedState = state;
          if (loadedState is VaultLoaded) {
            return Scaffold(
              key: key,
              appBar: appBar ??
                  AppBar(
                    title: Visibility(
                        visible: entry.isDirty,
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.check_circle, color: Colors.white),
                          label: Text(
                            str.saveChanges,
                            style: TextStyle(color: Colors.white),
                          ),
                          onPressed: () => endEditing(true),
                        )),
                    actions: [
                      Visibility(
                        visible: onDelete != null,
                        child: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              onDelete!();
                            }),
                      ),
                      OpenContainer<bool>(
                        key: ValueKey('history view icon container'),
                        tappable: false,
                        closedShape: RoundedRectangleBorder(),
                        closedElevation: 0,
                        closedColor: Colors.transparent,
                        transitionType: ContainerTransitionType.fade,
                        transitionDuration: const Duration(milliseconds: 300),
                        openBuilder: (context, close) {
                          return EntryHistoryWidget(
                            key: ValueKey('history view'),
                            revertTo: revertTo,
                            deleteAt: deleteAt,
                          );
                        },
                        closedBuilder: (context, open) {
                          return Visibility(
                            visible: entry.history.isNotEmpty,
                            child: IconButton(
                                icon: Icon(Icons.history),
                                onPressed: () {
                                  open();
                                }),
                          );
                        },
                      )
                    ],
                  ),
              body: WillPopScope(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: SafeArea(
                      top: false,
                      left: false,
                      child: Column(
                        children: <Widget>[
                          //TODO:f: mention that Android failed to supply accurate
                          // password data if we can detect when it happens.
                          //
                          // Note: Starting with Android 10, you can use the
                          //FillRequest.FLAG_COMPATIBILITY_MODE_REQUEST flag to
                          //determine whether an autofill request was generated
                          // via compatibility mode.
                          //
                          // That may be helpful in some cases but not sure if
                          // the gaps in coverage of that approach will make it
                          // essentially useless while we still support Android 9
                          //TODO:f: change property name - unclear semantics here.
                          appBar == null
                              ? const SizedBox(height: 8)
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        child: Padding(
                                      padding: const EdgeInsets.fromLTRB(16.0, 12, 16, 32),
                                      child: Text(
                                        str.autofillNewEntryMakeChangesThenDone,
                                        style: theme.textTheme.bodyText1,
                                      ),
                                    ))
                                  ],
                                ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              const SizedBox(width: 16),
                              GestureDetector(
                                  onTap: () {
                                    changeIcon(context, entry.color);
                                  },
                                  child: entry.getIcon(48, Theme.of(context).brightness == Brightness.dark)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: entry.fields
                                    .take(1)
                                    .map(
                                      (f) => EntryField(
                                        fieldType: FieldType.string,
                                        key: ValueKey(f.fieldKey ?? 'first field of a corrupt entry'),
                                        entry: entry,
                                        field: f,
                                        onDelete: () => {},
                                        onChangeIcon: () => changeIcon(context, entry.color),
                                      ),
                                    )
                                    .first,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...entry.fields.skip(1).map(
                            (f) {
                              final key = f.fieldKey;
                              if (key == null) {
                                l.e('field key is unknown. Failed field configuration: ${f.browserModel?.toJson()}');
                                return Text(str.openError + str.errorCorruptField);
                              }
                              return EntryField(
                                fieldType: f.isTotp
                                    ? FieldType.otp
                                    : f.isCheckbox
                                        ? FieldType.checkbox
                                        : FieldType.string,
                                key: ValueKey(key),
                                entry: entry,
                                field: f,
                                onDelete: () {
                                  final cubit = BlocProvider.of<EntryCubit>(context);
                                  cubit.removeField(f);
                                },
                                onChangeIcon: () => {},
                              );
                            },
                          ).expand((el) => [el, const SizedBox(height: 8)]),
                          ...entry.binaryMapEntries.isEmpty
                              ? []
                              : entry.binaryMapEntries.map((e) {
                                  return BinaryCardWidget(
                                    key: ValueKey('${e.key.key}-${e.value.valueHashCode}'),
                                    entry: entry,
                                    attachment: e,
                                    readOnly: false,
                                  );
                                }),
                          Divider(
                            indent: 16,
                            endIndent: 16,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                                child: Text(str.detGroup),
                              ),
                              Expanded(
                                child: Tooltip(
                                  message: entry.groupNames.join(' » '),
                                  child: Text(entry.groupNames.last),
                                ),
                              ),
                              OpenContainer<bool>(
                                key: ValueKey('move entry to new group screen'),
                                tappable: false,
                                closedShape: RoundedRectangleBorder(),
                                closedElevation: 0,
                                closedColor: Colors.transparent,
                                transitionType: ContainerTransitionType.fade,
                                transitionDuration: const Duration(milliseconds: 300),
                                openBuilder: (context, close) {
                                  return EntryMoveTreeWidget(title: str.chooseNewParentGroupForEntry);
                                },
                                closedBuilder: (context, open) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 12.0, right: 16.0),
                                    child: OutlinedButton.icon(
                                      label: Text(str.move),
                                      icon: const Icon(Icons.drive_file_move),
                                      onPressed: () => open(),
                                    ),
                                  );
                                },
                              )
                            ],
                          ),
                          LabelsWidget(
                            tags: entry.tags,
                            otherKnownTags: loadedState.vault.files.current.tags
                                .map((t) => Tag(t, true))
                                .where((t) => !entry.tags.any((et) => et.lowercase == t.lowercase))
                                .toList(),
                          ),
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                                child: Text(str.color),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0.0, 16.0, 0.0, 16.0),
                                child: ColorChooser(
                                    currentColor: entry.color,
                                    onChangeColor: (EntryColor color) => changeColor(context, color)),
                              ),
                            ],
                          ),
                          Divider(
                            indent: 16,
                            endIndent: 16,
                          ),
                          IntegrationSettingsWidget(),
                          Divider(
                            indent: 16,
                            endIndent: 16,
                          ),
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                                child: Text(str.detCreated),
                              ),
                              Tooltip(
                                message: Jiffy(entry.createdTime.toLocal()).yMMMMEEEEd +
                                    ' ' +
                                    Jiffy(entry.createdTime.toLocal()).jms,
                                child: Text(Jiffy(entry.createdTime).fromNow()),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                                child: Text(str.detUpdated),
                              ),
                              Tooltip(
                                message: Jiffy(entry.modifiedTime.toLocal()).yMMMMEEEEd +
                                    ' ' +
                                    Jiffy(entry.modifiedTime.toLocal()).jms,
                                child: Text(Jiffy(entry.modifiedTime).fromNow()),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                onWillPop: () async {
                  if (!entry.isDirty) {
                    return true;
                  }
                  final result = await showDialog(
                      routeSettings: RouteSettings(),
                      context: context,
                      builder: (context) => AlertDialog(title: Text(str.keep_your_changes_question), actions: <Widget>[
                            OutlinedButton(
                                child: Text(str.keep.toUpperCase()), onPressed: () => Navigator.of(context).pop(true)),
                            OutlinedButton(
                                child: Text(str.discard.toUpperCase()),
                                onPressed: () => Navigator.of(context).pop(false)),
                          ]));
                  if (result != null) {
                    endEditing(result);
                  }
                  return false;
                },
              ),
              extendBody: true,
              floatingActionButton: SpeedDial(
                children: [
                  SpeedDialChild(
                    label: str.addField,
                    child: Icon(Icons.label),
                    onTap: () => _selectCustomKey(context),
                  ),
                  if (!entry.fields.any((f) => f.isTotp))
                    SpeedDialChild(
                      label: str.addTOTPSecret,
                      child: Icon(Icons.lock_clock),
                      onTap: () async {
                        final totp = await _askForTotpSecret(context);
                        if (totp != null) {
                          final field = FieldViewModel.fromCustomAndBrowser(
                            KdbxKeyCommon.OTP,
                            ProtectedValue.fromString(totp.toUri().toString()),
                            null,
                          );
                          final cubit = BlocProvider.of<EntryCubit>(context);
                          cubit.addField(field);
                        }
                      },
                    ),
                  SpeedDialChild(
                    label: str.addAttachment,
                    child: Icon(Icons.attach_file),
                    onTap: () async {
                      await _attachFile(context);
                    },
                  ),
                ],
                icon: Icons.add,
                activeIcon: Icons.close,
                useRotationAnimation: true,
                childPadding: const EdgeInsets.all(5),
                spaceBetweenChildren: 4,
                spacing: 3,
                overlayColor: Colors.black,
              ),
              floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
              bottomNavigationBar: BottomBarWidget(
                () {
                  showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.only(topLeft: Radius.circular(10.0), topRight: Radius.circular(10.0)),
                      ),
                      builder: (BuildContext context) {
                        return BottomDrawerWidget();
                      });
                },
              ),
            );
          }
          return Scaffold(
            key: key,
            appBar: AppBar(
              title: Text(str.openError),
            ),
            body: Center(
              child: Text('Entry not found. Please close and re-launch the app.'),
            ),
          );
        },
      );
    });
  }
}

class StringEntryFieldEditor extends StatelessWidget {
  const StringEntryFieldEditor({
    Key? key,
    required this.onChange,
    required this.controller,
    required this.formFieldKey,
    required this.focusNode,
    this.fieldKey,
    required this.delegate,
    required this.field,
  }) : super(key: key);

  final Key formFieldKey;
  final FocusNode focusNode;
  final KdbxKey? fieldKey;
  final TextEditingController controller;
  final FormFieldSetter<String> onChange;
  final FieldDelegate delegate;
  final FieldViewModel field;

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    return Stack(alignment: Alignment.centerRight, children: [
      TextFormField(
        key: formFieldKey,
        maxLines: field.keyboardType == TextInputType.multiline ? 7 : 3,
        minLines: 1,
        focusNode: focusNode,
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          labelText: field.name ?? fieldKey?.key,
          prefixIcon: field.icon != null ? Icon(field.icon) : null,
        ),
        keyboardType: field.keyboardType,
        autocorrect: field.autocorrect,
        enableSuggestions: field.enableSuggestions,
        textCapitalization: field.textCapitalization,
        controller: controller,
        onChanged: onChange,
      ),
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          if (fieldKey == KdbxKeyCommon.PASSWORD) {
            return OpenContainer<bool>(
              key: ValueKey('generate single password screen'),
              tappable: false,
              closedShape: RoundedRectangleBorder(),
              closedElevation: 0,
              closedColor: Colors.transparent,
              transitionType: ContainerTransitionType.fade,
              transitionDuration: const Duration(milliseconds: 300),
              openBuilder: (context, close) {
                return PasswordGeneratorWidget(
                  key: ValueKey('password generator'),
                  apply: (String password) {
                    controller.text = password;
                    onChange(password);
                  },
                );
              },
              closedBuilder: (context, open) {
                return IconButton(
                  tooltip: str.footerTitleGen,
                  icon: const Icon(Icons.flash_on),
                  onPressed: () => open(),
                );
              },
            );
          }
          return const SizedBox();
        },
      ),
    ]);
  }
}

abstract class FieldDelegate {
  Future<void> openUrl();
}

enum FieldType { string, otp, checkbox }

class ObscuredEntryFieldEditor extends StatelessWidget {
  const ObscuredEntryFieldEditor({
    Key? key,
    required this.onPressed,
    required this.field,
  }) : super(key: key);

  final VoidCallback onPressed;
  final FieldViewModel field;

  @override
  Widget build(BuildContext context) {
    final color = Colors.black87;
    final theme = Theme.of(context);
    final str = S.of(context);

    return Stack(
      alignment: Alignment.centerRight,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            labelText: field.name ?? field.key?.key,
            prefixIcon: field.icon != null ? Icon(field.icon) : null,
          ),
          child: Text(
            '*anythIng*',
            style: TextStyle(color: color.withOpacity(0)),
          ),
        ),
        Positioned.fill(
          top: 12,
          bottom: 12,
          left: 8,
          right: 8,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 2,
                sigmaY: 2,
              ),
              child: TextButton(
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(
                    left: 32.0,
                    right: 24.0,
                  ),
                  child: Text(
                    str.protectedClickToReveal,
                    style: TextStyle(
                      color: theme.brightness == Brightness.dark ? Colors.white : theme.primaryColor,
                    ),
                  ),
                ),
                onPressed: onPressed,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.visibility),
          color: theme.brightness == Brightness.dark ? Colors.white : theme.primaryColor,
          tooltip: str.showProtectedField,
          onPressed: onPressed,
        ),
      ],
    );
  }
}

enum EntryAction {
  changeIcon,
  copy,
  copyRawData,
  rename,
  protect,
  delete,
}
