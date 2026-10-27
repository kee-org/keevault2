import 'package:flutter/services.dart';

class KeeClipboard {
  static const _channel = MethodChannel('com.keevault.keevault/secure_clipboard');

  static Future<bool> set(String text, bool hideContent) async {
    if (hideContent) {
      try {
        return await _channel.invokeMethod('copySensitive', {'text': text});
      } catch (e) {
        // Fallback to standard clipboard if platform call fails
        await Clipboard.setData(ClipboardData(text: text));
        return false;
      }
    } else {
      await Clipboard.setData(ClipboardData(text: text));
      return false;
    }
  }
}
