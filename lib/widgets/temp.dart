import 'package:keevault/widgets/binaries.dart';

class KeeVaultAccountAttachmentMetadata {
  KeeVaultAccountAttachmentMetadata({required this.id, required this.secret, required this.format, required this.size});

  final String id;
  final String secret;
  final AttachmentFormat format;
  final int size;
}
