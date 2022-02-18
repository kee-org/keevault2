import 'dart:core';

class Features {
  List<String> enabled;
  int validUntil; // milliseconds
  String source;
  Features({required this.enabled, required this.validUntil, required this.source});
}
