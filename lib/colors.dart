import 'package:flutter/material.dart';
import 'package:collection/collection.dart' show IterableExtension;
// ignore: implementation_imports
import 'package:kdbx/src/kdbx_xml.dart' show KdbxColor;

enum EntryColor { red, orange, yellow, green, blue, violet }

EntryColor? entryColorFromHex(String? hex) {
  if (hex == null) {
    return null;
  }
  final colorValue = int.tryParse('0xff$hex');
  if (colorValue == null) {
    return null;
  }
  final suppliedColor = Color(colorValue);
  final exactMatch = entryColors.entries.firstWhereOrNull((mapEntry) => mapEntry.value == suppliedColor);
  if (exactMatch != null) {
    return exactMatch.key;
  }
  final suppliedColorHue = HSLColor.fromColor(suppliedColor).hue;
  EntryColor? closestColor;
  double smallestDistance = double.maxFinite;
  entryHSLColors.forEach((entryColor, hslColor) {
    final colorDistance = (hslColor.hue - suppliedColorHue).abs();
    if (smallestDistance > colorDistance) {
      smallestDistance = colorDistance;
      closestColor = entryColor;
    }
  });
  return closestColor;
}

/* spell-checker: disable */
const entryHexColors = {
  EntryColor.yellow: 'cfcf00',
  EntryColor.green: '00ff00',
  EntryColor.red: 'ff0000',
  EntryColor.orange: 'ff8800',
  EntryColor.blue: '0000ff',
  EntryColor.violet: 'ff00ff',
};

const entryHexColorsContrast = {
  EntryColor.yellow: 'ffff88',
  EntryColor.green: '88ff88',
  EntryColor.red: 'ff8888',
  EntryColor.orange: 'ffcc88',
  EntryColor.blue: '8888ff',
  EntryColor.violet: 'ff88ff',
};

final kdbxColors = {
  EntryColor.yellow: KdbxColor.parse('ffff88'),
  EntryColor.green: KdbxColor.parse('88ff88'),
  EntryColor.red: KdbxColor.parse('ff8888'),
  EntryColor.orange: KdbxColor.parse('ffcc88'),
  EntryColor.blue: KdbxColor.parse('8888ff'),
  EntryColor.violet: KdbxColor.parse('ff88ff'),
  null: KdbxColor.nullColor,
};
/* spell-checker: enable */

const entryColors = {
  EntryColor.yellow: Color(0xffcfcf00),
  EntryColor.green: Color(0xff00ff00),
  EntryColor.red: Color(0xffff0000),
  EntryColor.orange: Color(0xffff8800),
  EntryColor.blue: Color(0xff0000ff),
  EntryColor.violet: Color(0xffff00ff),
};

const entryColorsContrast = {
  EntryColor.yellow: Color(0xffffff88),
  EntryColor.green: Color(0xff88ff88),
  EntryColor.red: Color(0xffff8888),
  EntryColor.orange: Color(0xffffcc88),
  EntryColor.blue: Color(0xff8888ff),
  EntryColor.violet: Color(0xffff88ff),
};

final entryHSLColors = {
  EntryColor.yellow: HSLColor.fromColor(const Color(0xffcfcf00)),
  EntryColor.green: HSLColor.fromColor(const Color(0xff00ff00)),
  EntryColor.red: HSLColor.fromColor(const Color(0xffff0000)),
  EntryColor.orange: HSLColor.fromColor(const Color(0xffff8800)),
  EntryColor.blue: HSLColor.fromColor(const Color(0xff0000ff)),
  EntryColor.violet: HSLColor.fromColor(const Color(0xffff00ff)),
};

class AppPalettes {
  static const MaterialColor keeVaultPalette = MaterialColor(_keeVaultPalettePrimaryValue, <int, Color>{
    50: Color(0xFFE4E9ED),
    100: Color(0xFFBAC8D3),
    200: Color(0xFF8DA3B5),
    300: Color(0xFF5F7E97),
    400: Color(0xFF3C6281),
    500: Color(_keeVaultPalettePrimaryValue),
    600: Color(0xFF173F63),
    700: Color(0xFF133758),
    800: Color(0xFF0F2F4E),
    900: Color(0xFF08203C),
  });
  static const int _keeVaultPalettePrimaryValue = 0xFF1A466B;

  static const MaterialColor keeVaultPaletteAccent = MaterialColor(_keeVaultPaletteAccentValue, <int, Color>{
    100: Color(0xFF74ACFF),
    200: Color(_keeVaultPaletteAccentValue),
    400: Color(0xFF0E6FFF),
    700: Color(0xFF0062F3),
  });
  static const int _keeVaultPaletteAccentValue = 0xFF418EFF;
}
