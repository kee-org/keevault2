import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/cubit/entry_cubit.dart';
import 'package:keevault/logging/logger.dart';
import 'package:keevault/model/entry.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' show Permission;
import 'package:share_plus/share_plus.dart';
import '../generated/l10n.dart';
import '../permissions.dart';
import 'dialog_utils.dart';

abstract class AttachmentSource {
  Future<Uint8List> readAttachmentBytes(KdbxBinary binary);
  Future<void> attachFile({
    required KdbxEntry entry,
    required String fileName,
    required Uint8List bytes,
  });
}

class AttachmentSourceKdbx extends AttachmentSource {
  @override
  Future<Uint8List> readAttachmentBytes(KdbxBinary binary) async {
    return binary.value;
  }

  @override
  Future<void> attachFile({
    required KdbxEntry entry,
    required String fileName,
    required Uint8List bytes,
  }) async {
    entry.createBinary(
      isProtected: false,
      name: fileName,
      bytes: bytes,
    );
  }
}

//TODO:f: Create file storage service and communicate with it from here
// class AttachmentSourceKeeVaultAccount extends AttachmentSource {
//   @override
//   Future<void> attachFile({
//     required KdbxEntry entry,
//     required String fileName,
//     required Uint8List bytes,
//   }) async {
//     final attached = await attachFileToAccount(
//       entry: entry,
//       fileName: fileName,
//       bytes: bytes,
//     );
//     if (attached) {
//       return;
//     }
//     entry.createBinary(
//       isProtected: false,
//       name: fileName,
//       bytes: bytes,
//     );
//   }

// Future<bool> attachFileToAccount({
//   required KdbxEntry entry,
//   required String fileName,
//   required Uint8List bytes,
// }) async {
//   try {
//     final attachmentInfo = await kvAccount.createAttachment(name: fileName, bytes: bytes);
//     final attachmentInfo =
//         KeeVaultAccountAttachmentMetadata(format: AttachmentFormat.gzipChaCha7539, id: "", secret: "", size: 0);
//     final info = "";
//     //[attachmentInfo.identifier, json.encode(attachmentInfo.toJson())].join();
//     entry.createBinary(
//       isProtected: false,
//       name: fileName,
//       bytes: utf8.encode(info) as Uint8List,
//     );
//     return true;
//   } catch (e, stack) {
//     l.e('Error while uploading attachment.', e, stack);
//     rethrow;
//   }
// }

//   @override
//   Future<Uint8List> readAttachmentBytes(KdbxBinary binary) async {
//     throw Exception("Not implemented");
//     //TODO:f: check in local cache first and then communicate with file storage service over the network
//   }
// }

class KeeVaultAccountAttachmentMetadata {
  KeeVaultAccountAttachmentMetadata({
    required this.id,
    required this.secret,
    required this.format,
    required this.size,
  });

  final String id;
  final String secret;
  // enum
  final AttachmentFormat format;
  final int size;

  String get identifier => prefixIdentifier;

//TODO:f: finalise prefix identifier choice
  static const prefixIdentifier = 'https://s.kee.pm/a ';

  static late final prefixIdentifierBytes = utf8.encode(prefixIdentifier);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'secret': secret,
      'format': format.index,
      'size': size,
    };
  }

  factory KeeVaultAccountAttachmentMetadata.fromMap(Map<String, dynamic> map) {
    return KeeVaultAccountAttachmentMetadata(
      id: map['id'] ?? '',
      secret: map['secret'] ?? '',
      format: AttachmentFormat.values[map['format'] ?? 0],
      size: map['size']?.toInt() ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory KeeVaultAccountAttachmentMetadata.fromJson(String source) =>
      KeeVaultAccountAttachmentMetadata.fromMap(json.decode(source));

  @override
  String toString() {
    return 'KeeVaultAccountAttachmentMetadata(id: $id, secret: $secret, format: $format, size: $size)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is KeeVaultAccountAttachmentMetadata &&
        other.id == id &&
        other.secret == secret &&
        other.format == format &&
        other.size == size;
  }

  @override
  int get hashCode {
    return id.hashCode ^ secret.hashCode ^ format.hashCode ^ size.hashCode;
  }
}

enum AttachmentFormat {
  gzipChaCha7539,
  unsupported,
}

class BinaryCardWidget extends StatelessWidget {
  const BinaryCardWidget({
    Key? key,
    required this.entry,
    required this.attachment,
    required this.readOnly,
  }) : super(key: key);

  final EntryViewModel entry;
  final MapEntry<KdbxKey, KdbxBinary> attachment;
  final bool readOnly;

  void _deleteFile(BuildContext context, KdbxKey key) {
    final cubit = BlocProvider.of<EntryCubit>(context);
    cubit.removeFile(key: key);
  }

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final theme = Theme.of(context);
    return Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: theme.brightness == Brightness.dark ? Color(0xFF292929) : Color(0xFFffffff),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
            color: theme.brightness == Brightness.dark ? Colors.white60 : Color(0xffbababa),
            width: 1,
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 12),
            leading: Icon(Icons.attach_file),
            minLeadingWidth: 24,
            title: Text(attachment.key.key),
            subtitle: Text(
              str.sizeBytes(attachment.value.value.length),
              style: theme.textTheme.caption,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      final attachmentSource = AttachmentSourceKdbx();
                      final bytes = await attachmentSource.readAttachmentBytes(attachment.value);
                      final mimeType = lookupMimeType(
                        attachment.key.key,
                        headerBytes: bytes.length > defaultMagicNumbersMaxLength
                            ? Uint8List.sublistView(bytes, 0, defaultMagicNumbersMaxLength)
                            : null,
                      );
                      l.d('Sharing attachment with mimeType $mimeType');

                      final tempDir = await getTemporaryDirectory();
                      final file = File('${tempDir.path}/${attachment.key.key}');
                      await file.create(recursive: true);
                      await file.writeAsBytes(bytes, flush: true);
                      try {
                        await Share.shareFiles([file.path],
                            mimeTypes: mimeType != null ? [mimeType] : null, subject: 'Kee Vault attachment');
                      } finally {
                        await file.delete();
                      }
                    });
                  },
                  icon: Icon(Icons.share),
                  label: Text(str.share.toUpperCase()),
                ),
                // TextButton.icon(
                //   onPressed: () async {
                //     final attachmentSource = AttachmentSourceKdbx();
                //     final bytes = await attachmentSource.readAttachmentBytes(attachment.value);
                //     l.d('Opening attachment');

                //     final tempDir = await getTemporaryDirectory();
                //     final file = File('${tempDir.path}/{attachment.key.key}');
                //     await file.create(recursive: true);
                //     await file.writeAsBytes(bytes, flush: true);
                //     try {
                //       final result = await OpenFile.open(file.path,);
                //       if (result.type == ResultType.noAppToOpen) {
                //         //TODO:f: ...
                //       }
                //     } finally {
                //       await file.delete();
                //     }
                //   },
                //   icon: Icon(Icons.open_in_new),
                //   label: Text(str.openOpen.toUpperCase()),
                // ),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  offset: const Offset(0, 32),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      onTap: () async {
                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                          final permissionResult = await tryToGetPermission(
                            context,
                            Permission.storage,
                            'Storage',
                            'export',
                            str.cancelExportOrImport('export'),
                          );

                          if (permissionResult == PermissionResult.approved) {
                            try {
                              final attachmentSource = AttachmentSourceKdbx();
                              final bytes = await attachmentSource.readAttachmentBytes(attachment.value);
                              l.d('Exporting attachment');
                              final params = SaveFileDialogParams(
                                data: bytes,
                                fileName: attachment.key.key,
                              );
                              final outputFilename = await FlutterFileDialog.saveFile(params: params);
                              l.i('Exported attachment to $outputFilename');
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(S.of(context).exported),
                                  ],
                                ),
                                duration: Duration(seconds: 3),
                              ));
                            } on Exception catch (e, st) {
                              l.e('Export failed: $e', st);
                              DialogUtils.showErrorDialog(context, str.exportError, str.exportErrorDetails);
                            }
                          }
                        });
                      },
                      child: ListTile(
                        leading: const Icon(Icons.download),
                        title: Text(str.export),
                      ),
                    ),
                    if (!readOnly)
                      PopupMenuItem(
                        onTap: () async {
                          WidgetsBinding.instance.addPostFrameCallback((_) async {
                            final proceed = await DialogUtils.showConfirmDialog(
                                context: context,
                                params: ConfirmDialogParams(content: str.attachmentConfirmDelete(attachment.key.key)));
                            if (proceed) {
                              _deleteFile(context, attachment.key);
                            }
                          });
                        },
                        child: ListTile(
                          leading: const Icon(Icons.delete),
                          title: Text(str.delete),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ]));
  }
}
