import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:base32/base32.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/logging/logger.dart';
import 'package:keevault/urls.dart';
import '../colors.dart';
import '../extension_methods.dart';
import '../otpauth.dart';
import '../predefined_icons.dart';
import 'field.dart';

class EntryListItemViewModel {
  EntryListItemViewModel(this.entry)
      : label = entry.label,
        labelComparable = entry.label.toLowerCase(),
        groupNames = _createGroupNames(entry.parent),
        color = entry.color;

  final KdbxEntry entry;
  KeeVaultURL? _keeVaultUrl;

  String? get website => _url?.publicSuffixUrl.sourceUrl.toString();
  String? get domain => _url?.publicSuffixUrl.domain;
  KeeVaultURL? get _url => _keeVaultUrl ??= urls.parse(entry.getString(KdbxKeyCommon.URL)?.getText().trim());
  final String label;
  final String labelComparable;
  final List<String> groupNames;
  final EntryColor? color;

//TODO:f Look for KeeFormField text items if no username exists
  get usernameCustom => entry.getString(KdbxKeyCommon.USER_NAME)?.getText().trim() ?? '';
  get username => usernameCustom;

  static List<String> _createGroupNames(KdbxGroup group) =>
      group.breadcrumbs.map((e) => e.name.get()).whereNotNull().toList();

  Widget getIcon(double size, bool isDark) {
    return entry.customIcon != null
        ? Image.memory(
            entry.customIcon!.data,
            width: size,
            height: size,
            fit: BoxFit.contain,
          )
        : Icon(
            PredefinedIcons.iconFor(entry.icon.get()!),
            color: isDark ? entryColorsContrast[color] : entryColors[color],
            size: size,
          );
  }
}

class EntryViewModel {
  KdbxCustomIcon? customIcon;
  KdbxIcon icon;
  KdbxUuid? uuid;
  List<FieldViewModel> _fields;
  List<FieldViewModel> get fields => _fields;
  BrowserEntrySettings browserSettings;
  String label;
  EntryColor? color;
  List<Tag> tags;
  DateTime createdTime;
  DateTime modifiedTime;
  List<String> androidPackageNames;
  List<MapEntry<KdbxKey, KdbxBinary>> binaryMapEntries;

  EntryViewModel(
    this.customIcon,
    this.icon,
    this.uuid,
    this._fields,
    this.label,
    this.color,
    this.browserSettings,
    this.tags,
    this.createdTime,
    this.modifiedTime,
    this.androidPackageNames,
    this.binaryMapEntries,
  );

  factory EntryViewModel.fromKdbxEntry(KdbxEntry entry) {
    return _kdbxEntryToViewModel(entry);
  }

  static EntryViewModel _kdbxEntryToViewModel(KdbxEntry entry) {
    final label = entry.label;
    final icon = entry.icon.get()!;
    final customIcon = entry.customIcon;
    final color = entry.color;
    final uuid = entry.uuid;
    BrowserEntrySettings settings = entry.browserSettings.copyWith();
    final tags = (entry.tags.get() ?? []).map((t) => Tag(t, true)).toList();
    final created = entry.times.creationTime.get() ?? DateTime.now();
    final modified = entry.times.lastModificationTime.get() ?? created;
    final androidPackageNames = entry.androidPackageNames;
    final binaryMapEntries = entry.binaryEntries.toList();

    final userBrowserField = settings.fields.firstWhereOrNull((field) => field.displayName == 'KeePass username');
    final passBrowserField = settings.fields.firstWhereOrNull((field) => field.displayName == 'KeePass password');

    final fields = entry.stringEntries
        .where((me) => !['KPRPC JSON', 'TOTP Seed', 'TOTP Settings', 'OTPAuth'].contains(me.key.key))
        .map((me) {
          if (me.key == KdbxKeyCommon.USER_NAME) {
            return FieldViewModel.fromCustomAndBrowser(me.key, me.value ?? PlainValue(''), userBrowserField);
          } else if (me.key == KdbxKeyCommon.PASSWORD) {
            return FieldViewModel.fromCustomAndBrowser(
                me.key, me.value ?? ProtectedValue.fromString(''), passBrowserField);
          } else {
            // Any other Kdbx string field does not have any browser config
            // (at least until we add first class support for OTPs)
            return FieldViewModel.fromCustomAndBrowser(me.key, me.value ?? PlainValue(''), null);
          }
        })
        .where((vm) => vm.localisedCommonName.isNotEmpty)
        .toList();

    for (var key in [
      KdbxKeyCommon.TITLE,
      KdbxKeyCommon.USER_NAME,
      KdbxKeyCommon.PASSWORD,
      KdbxKeyCommon.URL,
      KdbxKeyCommon.NOTES,
    ]) {
      if (fields.none((f) => f.key == key)) {
        fields.add(FieldViewModel.fromCustomAndBrowser(key, PlainValue(''), null));
      }
    }

    // If we don't find our OTP config, we can fallback to some formats from other kdbx generators
    if (!entry.stringEntries.any((s) => s.key == KdbxKeyCommon.OTP)) {
      String? otp;
      final otpAuthCompat1 = entry.stringEntries.firstWhereOrNull((s) => s.key.key == 'TOTP Seed')?.value;
      if (otpAuthCompat1 != null) {
        final otpAuthCompat1Settings = entry.stringEntries.firstWhereOrNull((s) => s.key.key == 'TOTP Settings')?.value;
        otp = _normaliseTOTP(otpAuthCompat1.getText(), otpAuthCompat1Settings?.getText());
      } else {
        final otpAuthCompat2 = entry.stringEntries.firstWhereOrNull((s) => s.key.key == 'OTPAuth')?.value;
        otp = _normaliseTOTP(otpAuthCompat2?.getText(), null);
      }
      if (otp != null) {
        fields.add(FieldViewModel.fromCustomAndBrowser(KdbxKeyCommon.OTP, ProtectedValue.fromString(otp), null));
      }
    }

    // We know there are no field key duplicates so far because we've only read from
    // the kdbx Strings dictionary. Now we read from custom JSON field configuration
    // we may hit some duplication, although hopefully only when reading in data
    // from older versions of Kee Vault or other KDBX generators.
    // Since we can't see a situation where there are duplicates within the JSON
    // settings field list, we can keep the deduplication algorithm simple.
    fields.addAll(settings.fields
        .where((field) => field.displayName != 'KeePass username' && field.displayName != 'KeePass password')
        .map((field) {
      if (fields.any((f) => f.fieldKey == field.displayName)) {
        l.w('Duplicated field key found: ${field.displayName}. Will force deduplication.');
        field = field.copyWith(
            displayName: '${field.displayName} - deduplicated at ${DateTime.now().millisecondsSinceEpoch}');
      }
      return FieldViewModel.fromCustomAndBrowser(null, null, field);
    }).where((vm) => vm.localisedCommonName.isNotEmpty));

    final fixedSortIndexes = [
      KdbxKeyCommon.TITLE,
      KdbxKeyCommon.USER_NAME,
      KdbxKeyCommon.PASSWORD,
      KdbxKeyCommon.OTP,
      KdbxKeyCommon.URL,
      KdbxKeyCommon.NOTES,
    ];
    fields.sort((a, b) {
      final aIndex = a.key == null ? -1 : fixedSortIndexes.indexOf(a.key!);
      final bIndex = b.key == null ? -1 : fixedSortIndexes.indexOf(b.key!);
      if (aIndex == bIndex) {
        if (aIndex == -1) {
          // Custom fields are sorted alphabetically by name
          return (a.name ?? '').compareTo(b.name ?? '');
        }
      } else {
        // Custom fields always come after standard fields
        if (aIndex == -1) {
          return 1;
        } else if (bIndex == -1) {
          return -1;
        } else {
          return aIndex.compareTo(bIndex);
        }
      }
      return 0;
    });

    if (entry.isHistoryEntry) {
      return EntryViewModel(
        customIcon,
        icon,
        uuid,
        fields,
        label,
        color,
        settings,
        tags,
        created,
        modified,
        androidPackageNames,
        binaryMapEntries,
      );
    } else {
      return EditEntryViewModel(
        customIcon,
        icon,
        uuid,
        fields,
        false,
        entry.parent,
        label,
        color,
        settings,
        tags,
        created,
        modified,
        androidPackageNames,
        binaryMapEntries,
        entry.history.map((he) => _kdbxEntryToViewModel(he)).toList(),
      );
    }
  }

  Widget getIcon(double size, bool isDark) {
    return customIcon != null
        ? Image.memory(
            customIcon!.data,
            width: size,
            height: size,
            fit: BoxFit.contain,
          )
        : Icon(
            PredefinedIcons.iconFor(icon),
            color: isDark ? entryColorsContrast[color] : entryColors[color],
            size: size,
          );
  }

  static String? _addBase32Padding(String? base32data) {
    if (base32data == null) {
      return null;
    }
    final padding = (8 - (base32data.length % 8)) % 8;
    if (padding == 0) {
      return base32data;
    }
    return base32data + ('=' * padding);
  }

  static String? _normaliseTOTP(String? value, String? settings) {
    if (value == null) return null;
    if (value.contains('key=')) {
      // KeeOTP format:key={base32Key}&size=12&step=33&type=Totp&counter=3
      final data = Uri.splitQueryString(value);
      try {
        return OtpAuth(
          secret: base32.decode(_addBase32Padding(data['key'])!),
          period: data['step']?.toInt() ?? OtpAuth.DEFAULT_PERIOD,
          digits: data['size']?.toInt() ?? OtpAuth.DEFAULT_DIGITS,
        ).toUri().toString();
      } on FormatException catch (e, stackTrace) {
        l.d('Error parsing data while normalising OTP value', e, stackTrace);
        rethrow;
      }
    }
    // assume base32 encoded secret, with more settings stored in a second field.
    try {
      final binarySecret = base32.decode(value.replaceAll(' ', ''));
      final settingsOptions = (settings?.isEmpty ?? true) ? <String>[] : settings!.split(';');
      return OtpAuth(
        secret: binarySecret,
        period: settingsOptions.optGet(0)?.toInt() ?? OtpAuth.DEFAULT_PERIOD,
        digits: settingsOptions.optGet(1)?.toInt() ?? OtpAuth.DEFAULT_DIGITS,
      ).toUri().toString();
    } on FormatException catch (e, stackTrace) {
      // ignore format exception from base32 decoding.
      l.w('Error decoding base32 secret', e, stackTrace);
      return null;
    } catch (e, stackTrace) {
      l.w('Error while parsing OTP format', e, stackTrace);
      throw FormatException('Error parsing Tray OTP Format $e');
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is EntryViewModel &&
        other.icon == icon &&
        other.color == color &&
        other.customIcon == customIcon &&
        other.label == label &&
        other.browserSettings == browserSettings &&
        other.uuid == uuid &&
        other.createdTime == createdTime &&
        other.modifiedTime == modifiedTime &&
        const ListEquality().equals(other._fields, _fields) &&
        const ListEquality().equals(other.tags, tags) &&
        const ListEquality().equals(other.androidPackageNames, androidPackageNames) &&
        const ListEquality().equals(other.binaryMapEntries, binaryMapEntries);
  }

  @override
  int get hashCode =>
      icon.hashCode ^
      color.hashCode ^
      customIcon.hashCode ^
      label.hashCode ^
      browserSettings.hashCode ^
      uuid.hashCode ^
      createdTime.hashCode ^
      modifiedTime.hashCode ^
      const ListEquality().hash(_fields) ^
      const ListEquality().hash(tags) ^
      const ListEquality().hash(androidPackageNames) ^
      const ListEquality().hash(binaryMapEntries);

  EntryViewModel copyWith({
    KdbxUuid? uuid,
    List<FieldViewModel>? fields,
    String? label,
    EntryColor? color,
    BrowserEntrySettings? browserSettings,
    List<Tag>? tags,
    DateTime? createdTime,
    DateTime? modifiedTime,
    List<String>? androidPackageNames,
    List<MapEntry<KdbxKey, KdbxBinary>>? binaryMapEntries,
  }) {
    return EntryViewModel(
      customIcon,
      icon,
      uuid ?? this.uuid,
      fields ?? _fields,
      label ?? this.label,
      color ?? this.color,
      browserSettings ?? this.browserSettings,
      tags ?? this.tags,
      createdTime ?? this.createdTime,
      modifiedTime ?? this.modifiedTime,
      androidPackageNames ?? this.androidPackageNames,
      binaryMapEntries ?? this.binaryMapEntries,
    );
  }
}

class EditEntryViewModel extends EntryViewModel {
  final List<EntryViewModel> history;
  bool _isDirty = false;

  bool get isDirty => _isDirty || fields.any((f) => f.isDirty);
  KdbxGroup group;
  List<String> get groupNames => _createGroupNames(group);

  EditEntryViewModel(
    KdbxCustomIcon? customIcon,
    KdbxIcon icon,
    KdbxUuid? uuid,
    List<FieldViewModel> fields,
    this._isDirty,
    this.group,
    String label,
    EntryColor? color,
    BrowserEntrySettings browserSettings,
    List<Tag> tags,
    DateTime createdTime,
    DateTime modifiedTime,
    List<String> androidPackageNames,
    List<MapEntry<KdbxKey, KdbxBinary>> binaryMapEntries,
    this.history,
  ) : super(
          customIcon,
          icon,
          uuid,
          fields,
          label,
          color,
          browserSettings,
          tags,
          createdTime,
          modifiedTime,
          androidPackageNames,
          binaryMapEntries,
        );

  factory EditEntryViewModel.create(KdbxGroup group) {
    const label = '';
    const icon = KdbxIcon.Key;
    const customIcon = null;
    const color = null;
    const uuid = null;
    BrowserEntrySettings settings =
        BrowserEntrySettings(minimumMatchAccuracy: group.file!.body.meta.browserSettings.defaultMatchAccuracy);
    final tags = <Tag>[];
    final created = DateTime.now();
    final modified = created;
    final androidPackageNames = <String>[];

    final fields = [
      FieldViewModel.fromCustomAndBrowser(KdbxKeyCommon.TITLE, PlainValue(''), null),
      FieldViewModel.fromCustomAndBrowser(KdbxKeyCommon.USER_NAME, PlainValue(''), null),
      FieldViewModel.fromCustomAndBrowser(KdbxKeyCommon.PASSWORD, ProtectedValue(''), null),
      FieldViewModel.fromCustomAndBrowser(KdbxKeyCommon.URL, PlainValue(''), null),
      FieldViewModel.fromCustomAndBrowser(KdbxKeyCommon.NOTES, PlainValue(''), null),
    ];

    return EditEntryViewModel(customIcon, icon, uuid, fields, true, group, label, color, settings, tags, created,
        modified, androidPackageNames, [], []);
  }
  factory EditEntryViewModel.fromKdbxEntry(KdbxEntry entry) {
    final vm = EntryViewModel._kdbxEntryToViewModel(entry);
    if (vm is EditEntryViewModel) {
      return vm;
    }
    throw Exception("History KdbxEntries can't be edited.");
  }

  static List<String> _createGroupNames(KdbxGroup group) =>
      group.breadcrumbs.map((g) => g.name.get()).whereNotNull().toList();

  commit(KdbxEntry entry) {
    final Map<KdbxKey, StringValue> newFields = {};
    final List<BrowserFieldModel> jsonFields = [];

    for (var f in fields) {
      // returns a tuple of a kdbxstring keyvalue and a string of JSON for potential addition to KPRPCJSON kdbxstring
      final newField = f.commit();
      if (newField.item1 != null) {
        newFields[newField.item1!.key] = newField.item1!.value;
      }
      if (newField.item2 != null) {
        jsonFields.add(newField.item2!);
      }
    }

    browserSettings.fields = jsonFields;
    entry.browserSettings = browserSettings;

    final browserSettingsKey = KdbxKey('KPRPC JSON');
    newFields.forEach((key, value) {
      entry.setString(key, value);
    });
    entry.stringEntries
        .where((e) => newFields[e.key] == null && e.key != browserSettingsKey)
        .toList() // create a copy to avoid concurrent modifications
        .forEach((e) => entry.setString(e.key, null));

    entry.file!.move(entry, group);
    entry.icon.set(icon);
    entry.customIcon = customIcon;
    entry.color = color;
    entry.tags.set(tags.map((t) => t.name).toList());
    entry.file!.clearTagsCache();
    entry.androidPackageNames = androidPackageNames;

    final oldBinaries = entry.binaryEntries;
    final newBinaries =
        binaryMapEntries.where((nb) => !oldBinaries.any((ob) => ob.key == nb.key && ob.value == nb.value)).toList();
    final removedBinaries =
        oldBinaries.where((ob) => !binaryMapEntries.any((nb) => nb.key == ob.key && nb.value == ob.value)).toList();
    for (var rb in removedBinaries) {
      entry.removeBinary(rb.key);
    }
    for (var nb in newBinaries) {
      entry.createBinary(isProtected: false, name: nb.key.key, bytes: nb.value.value);
    }
  }

  KdbxKey _uniqueBinaryName(String fileName) {
    final lastIndex = fileName.lastIndexOf('.');
    final baseName = lastIndex > -1 ? fileName.substring(0, lastIndex) : fileName;
    final ext = lastIndex > -1 ? fileName.substring(lastIndex + 1) : 'ext';
    for (var i = 0; i < 1000; i++) {
      final k = i == 0 ? KdbxKey(fileName) : KdbxKey('$baseName$i.$ext');
      if (!binaryMapEntries.any((b) => b.key == k)) {
        return k;
      }
    }
    throw StateError('Unable to find unique name for $fileName');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is EditEntryViewModel &&
        super == other &&
        other._isDirty == _isDirty &&
        other.group == group &&
        ListEquality().equals(other.history, history);
  }

  @override
  int get hashCode => super.hashCode ^ _isDirty.hashCode ^ group.hashCode ^ ListEquality().hash(history);

  @override
  EditEntryViewModel copyWith({
    KdbxUuid? uuid,
    List<FieldViewModel>? fields,
    bool? isDirty,
    KdbxGroup? group,
    String? label,
    EntryColor? color,
    BrowserEntrySettings? browserSettings,
    List<Tag>? tags,
    DateTime? createdTime,
    DateTime? modifiedTime,
    List<String>? androidPackageNames,
    List<MapEntry<KdbxKey, KdbxBinary>>? binaryMapEntries,
    List<EntryViewModel>? history,
  }) {
    return EditEntryViewModel(
      customIcon,
      icon,
      uuid ?? this.uuid,
      fields ?? _fields,
      isDirty ?? _isDirty,
      group ?? this.group,
      label ?? this.label,
      color ?? this.color,
      browserSettings ?? this.browserSettings,
      tags ?? this.tags,
      createdTime ?? this.createdTime,
      modifiedTime ?? this.modifiedTime,
      androidPackageNames ?? this.androidPackageNames,
      binaryMapEntries ?? this.binaryMapEntries,
      history ?? this.history,
    );
  }

  MapEntry<KdbxKey, KdbxBinary> createBinaryForCopy({
    required String name,
    required Uint8List bytes,
  }) {
    final key = _uniqueBinaryName(path.basename(name));
    final binary = KdbxBinary(
      isInline: false,
      isProtected: false,
      value: bytes,
    );
    return MapEntry(key, binary);
  }
}

class Tag {
  final String name;
  final String lowercase;
  final bool isStored;

  Tag(this.name, this.isStored) : lowercase = name.toLowerCase();
}
