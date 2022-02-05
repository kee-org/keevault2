import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

import '../generated/l10n.dart';

S _str = S();

class PasswordGeneratorProfile {
  final String name; // unique ID
  final String title; // display name
  final int length;
  final bool upper;
  final bool lower;
  final bool digits;
  final bool special;
  final bool brackets;
  final bool high;
  final bool ambiguous;
  final String include; // custom chars

  PasswordGeneratorProfile({
    required this.name,
    required this.title,
    required this.length,
    required this.upper,
    required this.lower,
    required this.digits,
    required this.special,
    required this.brackets,
    required this.high,
    required this.ambiguous,
    required this.include,
  });

  static List<String> builtInNames = ['High', 'VeryHigh', 'Med', 'Pronounceable', 'Mac', 'Hex', 'Pin4'];
  bool get supportsCharacterChoosing => !['Pronounceable', 'Mac', 'Hex', 'Pin4'].contains(name);
  bool get supportsLengthChoosing => !['Mac', 'Pin4'].contains(name);
  bool get isUserDefined => !builtInNames.contains(name);

  PasswordGeneratorProfile copyWith({
    String? name,
    String? title,
    int? length,
    bool? upper,
    bool? lower,
    bool? digits,
    bool? special,
    bool? brackets,
    bool? high,
    bool? ambiguous,
    String? include,
  }) {
    return PasswordGeneratorProfile(
      name: name ?? this.name,
      title: title ?? this.title,
      length: length ?? this.length,
      upper: upper ?? this.upper,
      lower: lower ?? this.lower,
      digits: digits ?? this.digits,
      special: special ?? this.special,
      brackets: brackets ?? this.brackets,
      high: high ?? this.high,
      ambiguous: ambiguous ?? this.ambiguous,
      include: include ?? this.include,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'title': title,
      'length': length,
      'upper': upper,
      'lower': lower,
      'digits': digits,
      'special': special,
      'brackets': brackets,
      'high': high,
      'ambiguous': ambiguous,
      'include': include,
    };
  }

  factory PasswordGeneratorProfile.fromMap(Map<String, dynamic> map) {
    return PasswordGeneratorProfile(
      name: map['name'],
      title: map['title'],
      length: map['length'] ?? 1,
      upper: map['upper'] ?? false,
      lower: map['lower'] ?? false,
      digits: map['digits'] ?? false,
      special: map['special'] ?? false,
      brackets: map['brackets'] ?? false,
      high: map['high'] ?? false,
      ambiguous: map['ambiguous'] ?? false,
      include: map['include'] ?? '',
    );
  }

  factory PasswordGeneratorProfile.emptyTemplate() {
    return PasswordGeneratorProfile(
      name: '',
      title: '',
      length: 20,
      upper: true,
      lower: true,
      digits: true,
      special: false,
      brackets: false,
      high: false,
      ambiguous: false,
      include: '',
    );
  }

  String toJson() => json.encode(toMap());

  factory PasswordGeneratorProfile.fromJson(String source) => PasswordGeneratorProfile.fromMap(json.decode(source));

  @override
  String toString() {
    return 'PasswordGeneratorProfile(name: $name, title: $title, length: $length, upper: $upper, lower: $lower, digits: $digits, special: $special, brackets: $brackets, high: $high, ambiguous: $ambiguous, include: $include)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PasswordGeneratorProfile &&
        other.name == name &&
        other.title == title &&
        other.length == length &&
        other.upper == upper &&
        other.lower == lower &&
        other.digits == digits &&
        other.special == special &&
        other.brackets == brackets &&
        other.high == high &&
        other.ambiguous == ambiguous &&
        other.include == include;
  }

  @override
  int get hashCode {
    return name.hashCode ^
        title.hashCode ^
        length.hashCode ^
        upper.hashCode ^
        lower.hashCode ^
        digits.hashCode ^
        special.hashCode ^
        brackets.hashCode ^
        high.hashCode ^
        ambiguous.hashCode ^
        include.hashCode;
  }
}

final defaultPasswordGeneratorProfile = PasswordGeneratorProfile(
  name: 'High',
  ambiguous: false,
  brackets: false,
  digits: true,
  high: false,
  include: '',
  length: 26,
  lower: true,
  special: true,
  title: _str.genPresetHigh,
  upper: true,
);

final builtinPasswordGeneratorProfiles = [
  PasswordGeneratorProfile(
    name: 'Pronounceable',
    ambiguous: false,
    brackets: false,
    digits: false,
    high: false,
    include: '',
    length: 14,
    lower: true,
    special: false,
    title: _str.genPresetPronounceable,
    upper: true,
  ),
  PasswordGeneratorProfile(
    name: 'Med',
    ambiguous: false,
    brackets: false,
    digits: true,
    high: false,
    include: '',
    length: 15,
    lower: true,
    special: true,
    title: _str.genPresetMed,
    upper: true,
  ),
  defaultPasswordGeneratorProfile,
  PasswordGeneratorProfile(
    name: 'VeryHigh',
    ambiguous: false,
    brackets: false,
    digits: true,
    high: false,
    include: '',
    length: 48,
    lower: true,
    special: true,
    title: _str.genPresetVeryHigh,
    upper: true,
  ),
  PasswordGeneratorProfile(
    name: 'Pin4',
    ambiguous: false,
    brackets: false,
    digits: true,
    high: false,
    include: '',
    length: 4,
    lower: false,
    special: false,
    title: _str.genPresetPin4,
    upper: false,
  ),
  PasswordGeneratorProfile(
    name: 'Mac',
    ambiguous: false,
    brackets: false,
    digits: false,
    high: false,
    include: '',
    length: 17,
    lower: false,
    special: true,
    title: _str.genPresetMac,
    upper: true,
  ),
  PasswordGeneratorProfile(
    name: 'Hex',
    ambiguous: false,
    brackets: false,
    digits: false,
    high: false,
    include: '0123456789abcdef',
    length: 32,
    lower: false,
    special: false,
    title: _str.hexadecimal,
    upper: false,
  ),
];

class PasswordGeneratorProfileSettings {
  final List<PasswordGeneratorProfile> user;
  final List<String> disabled;
  final String defaultProfileName;

  PasswordGeneratorProfileSettings(
    this.user,
    this.disabled,
    this.defaultProfileName,
  );

  PasswordGeneratorProfileSettings copyWith({
    List<PasswordGeneratorProfile>? user,
    List<String>? disabled,
    String? defaultProfileName,
  }) {
    return PasswordGeneratorProfileSettings(
      user ?? this.user,
      disabled ?? this.disabled,
      defaultProfileName ?? this.defaultProfileName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user': user.map((x) => x.toMap()).toList(),
      'disabled': <String, dynamic>{for (var v in disabled) v: true},
      'default': defaultProfileName,
    };
  }

  factory PasswordGeneratorProfileSettings.fromMap(Map<String, dynamic> map) {
    return PasswordGeneratorProfileSettings(
      List<PasswordGeneratorProfile>.from(map['user']?.map((x) => PasswordGeneratorProfile.fromMap(x))),
      List<String>.from(map['disabled']?.keys),
      map['default'],
    );
  }

  factory PasswordGeneratorProfileSettings.fromStorage() {
    final loadedString = Settings.getValue<String>('generatorPresets', '');
    if (loadedString.isNotEmpty) {
      try {
        return PasswordGeneratorProfileSettings.fromJson(loadedString);
      } catch (e) {
        // Dealt with below
      }
    }
    return PasswordGeneratorProfileSettings([], [], 'High');
  }

  String toJson() => json.encode(toMap());

  factory PasswordGeneratorProfileSettings.fromJson(String source) =>
      PasswordGeneratorProfileSettings.fromMap(json.decode(source));

  @override
  String toString() =>
      'PasswordGeneratorProfileSettings(user: $user, disabled: $disabled, defaultProfileName: $defaultProfileName)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PasswordGeneratorProfileSettings &&
        listEquals(other.user, user) &&
        listEquals(other.disabled, disabled) &&
        other.defaultProfileName == defaultProfileName;
  }

  @override
  int get hashCode => ListEquality().hash(user) ^ ListEquality().hash(disabled) ^ defaultProfileName.hashCode;
}

class PasswordGeneratorCharRanges {
  static const String upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const String lower = 'abcdefghijkmnpqrstuvwxyz';
  static const String digits = '123456789';
  static const String special = '!@#\$%^&*_+-=,./?;:`"~\'\\';
  static const String brackets = '(){}[]<>';
  static const String high =
      '¡¢£¤¥¦§©ª«¬®¯°±²³´µ¶¹º»¼½¾¿ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõö÷øùúûüýþ';
  static const String ambiguous = 'O0oIl';
}


//TODO:f: something like below for a tooltip display of exact chars included in each range
//
//     getSelectedRanges: function() {
//         const sel = this.getPreset(this.selected);
//         const rangeOverride = {
//             high: '¡¢£¤¥¦§©ª«¬®¯°±¹²´µ¶»¼÷¿ÀÖîü...'
//         };
//         return ['Upper', 'Lower', 'Digits', 'Special', 'Brackets', 'High', 'Ambiguous'].map(name => {
//             const nameLower = name.toLowerCase();
//             return {
//                 name: nameLower,
//                 title: Locale['genPs' + name],
//                 enabled: sel[nameLower],
//                 sample: rangeOverride[nameLower] || PasswordGenerator.charRanges[nameLower]
//             };
//         });
//     },