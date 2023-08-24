import 'package:sensitive_clipboard/sensitive_clipboard.dart';

class KeeClipboard {
  static Future<bool> set(String text, bool hideContent) async {
    return SensitiveClipboard.copy(text, hideContent: hideContent);
  }
}
