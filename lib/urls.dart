import 'dart:collection';
import 'package:public_suffix/public_suffix.dart';

class KeeVaultURL {
  PublicSuffix publicSuffixUrl;
  KeeVaultURL(this.publicSuffixUrl);
}

class Urls {
  Urls._privateConstructor();

  static final Urls _instance = Urls._privateConstructor();

  static Urls get instance => _instance;

  final HashMap<String, KeeVaultURL> _cache = HashMap<String, KeeVaultURL>();

  KeeVaultURL? parse(String? text) {
    if (text == null) {
      return null;
    }
    if (_cache.containsKey(text)) {
      return _cache[text];
    }
    final uri = _normalizeUrl(text);
    if (uri == null) {
      return null;
    }
    final parsedUrl = PublicSuffix.fromString(text, leniency: Leniency.allowAll);

    final kvurl = parsedUrl != null ? KeeVaultURL(parsedUrl) : null;
    return kvurl;
  }

  Uri? _normalizeUrl(String url) {
    if (url.isEmpty) {
      return null;
    }
    try {
      var urlToParse = url;
      if (!url.contains('://')) {
        urlToParse = 'http://$url';
      }
      final parsed = Uri.parse(urlToParse);
      var ret = parsed;
      if (!parsed.hasScheme) {
        ret = parsed.replace(scheme: 'https');
      }
      final resolved = ret.resolve('/');
      return resolved;
    } catch (e) {
      return null;
    }
  }
}

final Urls urls = Urls.instance;
