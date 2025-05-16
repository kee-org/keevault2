import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:kdbx/kdbx.dart' as kdbx show FieldType;
import 'package:kdbx/kdbx.dart' hide FieldType;
import 'package:tuple/tuple.dart';
import '../generated/l10n.dart';
import '../extension_methods.dart';

class FieldViewModel {
  bool _isDirty = false;

  KdbxKey? key;
  String localisedCommonName;
  bool protect = false;
  TextInputType keyboardType = TextInputType.text;
  bool autocorrect = false;
  bool enableSuggestions = false;
  TextCapitalization textCapitalization = TextCapitalization.none;
  IconData? icon;
  bool showIfEmpty = false;
  Field? browserModel;

  StringValue value;

  String? _name;

  FieldStorage get fieldStorage =>
      key != null && browserModel != null
          ? FieldStorage.BOTH
          : key != null
          ? FieldStorage.CUSTOM
          : FieldStorage.JSON;

  FieldViewModel(
    this._isDirty,
    this.key,
    this.localisedCommonName,
    this.protect,
    this.keyboardType,
    this.autocorrect,
    this.enableSuggestions,
    this.textCapitalization,
    this.icon,
    this.showIfEmpty,
    this.browserModel,
    this.value,
    this._name, //TODO:f: What is this actually for? Seems we set it to the same as localisedCommonName and then never use the value. We have the key for normal field ID purposes and have no need for localising user's own data if the name or fieldId of the browserModel is used. For new browserModel field entries, can't we use the localisedCommonName anyway (maybe via _getBrowserFieldDisplayName instead of _name?)
  );

  factory FieldViewModel.fromCustomAndBrowser(KdbxKey? key, StringValue? value, Field? browserModel) {
    if (key == null && value == null && browserModel == null) {
      throw Exception('No field can be created when there is no data');
    }
    if ((key == null || value == null) && browserModel == null) {
      throw Exception('Value must be supplied with KdbxKey');
    }
    String localisedCommonName;
    bool protect = false;
    TextInputType keyboardType = TextInputType.text;
    bool autocorrect = false;
    bool enableSuggestions = false;
    TextCapitalization textCapitalization = TextCapitalization.none;
    IconData? icon = Icons.label_outline;
    bool showIfEmpty = false;
    late StringValue fieldValue = value!;

    S str = S();

    switch (key?.key) {
      case KdbxKeyCommon.KEY_TITLE:
        localisedCommonName = str.title;
        icon = null;
        autocorrect = true;
        enableSuggestions = true;
        textCapitalization = TextCapitalization.sentences;
        showIfEmpty = true;
        break;
      case KdbxKeyCommon.KEY_URL:
        localisedCommonName = str.openUrl;
        icon = Icons.link;
        autocorrect = true;
        enableSuggestions = true;
        keyboardType = TextInputType.url;
        showIfEmpty = true;
        break;
      case KdbxKeyCommon.KEY_USER_NAME:
        localisedCommonName = str.user;
        icon = Icons.account_circle;
        keyboardType = TextInputType.emailAddress;
        showIfEmpty = true;
        break;
      case KdbxKeyCommon.KEY_PASSWORD:
        localisedCommonName = str.password;
        protect = true;
        keyboardType = TextInputType.visiblePassword;
        icon = Icons.lock;
        showIfEmpty = true;
        break;
      case KdbxKeyCommon.KEY_OTP:
        localisedCommonName = str.otp;
        icon = Icons.lock_clock;
        protect = true;
        break;
      case KdbxKeyCommon.KEY_NOTES:
        localisedCommonName = str.notes;
        keyboardType = TextInputType.multiline;
        icon = Icons.note;
        protect = false;
        showIfEmpty = true;
        break;
    }

    if (key == null && browserModel != null) {
      // We might come across old bad data so make every effort to select a new displayName for such
      // fields. Ultimately, we'll have to ignore and eventually delete any fields that contain no useful data.
      localisedCommonName =
          browserModel.name?.nullIfBlank() ??
          browserModel.uuid?.nullIfBlank() ??
          browserModel.matcherConfigs
              ?.firstWhereOrNull((mc) => mc.matcherType == FieldMatcherType.Custom)
              ?.customMatcher
              ?.names
              .firstOrNull
              ?.nullIfBlank() ??
          browserModel.matcherConfigs
              ?.firstWhereOrNull((mc) => mc.matcherType == FieldMatcherType.Custom)
              ?.customMatcher
              ?.ids
              .firstOrNull
              ?.nullIfBlank() ??
          (browserModel.type == kdbx.FieldType.Toggle || browserModel.value?.nullIfBlank() == null ? '' : '[no name]');
      fieldValue =
          browserModel.type == kdbx.FieldType.Password
              ? ProtectedValue.fromString(browserModel.value ?? '')
              : PlainValue(browserModel.value ?? '');
      protect = browserModel.type == kdbx.FieldType.Password;
    } else {
      localisedCommonName = key!.key;
    }

    return FieldViewModel(
      false,
      key,
      localisedCommonName,
      protect,
      keyboardType,
      autocorrect,
      enableSuggestions,
      textCapitalization,
      icon,
      showIfEmpty,
      browserModel,
      fieldValue,
      localisedCommonName,
    );
  }

  bool get isDirty => _isDirty;
  String? get name => browserModel?.name ?? _name ?? localisedCommonName;
  String? get fieldKey => key?.key ?? browserModel?.name;

  String get textValue => value.getText();

  bool get isTotp => fieldStorage == FieldStorage.CUSTOM && ['otp', 'OTPAuth', 'TOTP Seed'].contains(key!.key);
  bool get isCheckbox => browserModel?.type == kdbx.FieldType.Toggle;

  bool get isStandard =>
      fieldStorage != FieldStorage.JSON &&
      [
        KdbxKeyCommon.KEY_PASSWORD,
        KdbxKeyCommon.KEY_USER_NAME,
        KdbxKeyCommon.KEY_NOTES,
        KdbxKeyCommon.KEY_TITLE,
        KdbxKeyCommon.KEY_URL,
      ].contains(key!.key);
  bool get protectionChangeable => !isStandard && !isTotp;
  bool get keyChangeable => !isTotp && !showIfEmpty;

  Tuple2<MapEntry<KdbxKey, StringValue>?, Field?> commit() {
    final customField = key != null ? MapEntry<KdbxKey, StringValue>(key!, value) : null;
    return Tuple2(customField, browserModel);
  }

  //TODO:f If necessary, call this as part of creating a new browserModel when user first enables browser integration on the field (or creates a new field full stop if we will always default to enabling browser integration)
  // ignore: unused_element
  _getBrowserFieldDisplayName() {
    if (key == KdbxKeyCommon.PASSWORD) {
      return 'KeePass password';
    } else if (key == KdbxKeyCommon.USER_NAME) {
      return 'KeePass username';
    } else {
      return _name;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FieldViewModel &&
        other._name == _name &&
        other._isDirty == _isDirty &&
        other.autocorrect == autocorrect &&
        other.browserModel == browserModel &&
        other.enableSuggestions == enableSuggestions &&
        other.icon == icon &&
        other.key == key &&
        other.keyboardType == keyboardType &&
        other.localisedCommonName == localisedCommonName &&
        other.protect == protect &&
        other.showIfEmpty == showIfEmpty &&
        other.textCapitalization == textCapitalization &&
        other.value == value;
  }

  @override
  int get hashCode =>
      _name.hashCode ^
      _isDirty.hashCode ^
      autocorrect.hashCode ^
      browserModel.hashCode ^
      enableSuggestions.hashCode ^
      icon.hashCode ^
      key.hashCode ^
      keyboardType.hashCode ^
      localisedCommonName.hashCode ^
      protect.hashCode ^
      showIfEmpty.hashCode ^
      textCapitalization.hashCode ^
      value.hashCode;

  FieldViewModel copyWith({
    bool? isDirty,
    KdbxKey? key,
    String? localisedCommonName,
    bool? protect,
    TextInputType? keyboardType,
    bool? autocorrect,
    bool? enableSuggestions,
    TextCapitalization? textCapitalization,
    IconData? icon,
    bool? showIfEmpty,
    Field? browserModel,
    StringValue? value,
    String? name,
  }) {
    return FieldViewModel(
      isDirty ?? _isDirty,
      key ?? this.key,
      localisedCommonName ?? this.localisedCommonName,
      protect ?? this.protect,
      keyboardType ?? this.keyboardType,
      autocorrect ?? this.autocorrect,
      enableSuggestions ?? this.enableSuggestions,
      textCapitalization ?? this.textCapitalization,
      icon ?? this.icon,
      showIfEmpty ?? this.showIfEmpty,
      browserModel ?? this.browserModel,
      value ?? this.value,
      name ?? _name,
    );
  }
}

/*

for when outputting to json (persistence or keepassrpc):
$Password etc is old way of identifying the user and pass common fields in KeeWeb . probably useless now.

    getBrowserFieldDisplayNameDefault: function() {
        if (this.model.name === '$Password') return 'KeePass password';
        else if (this.model.name === '$UserName') return 'KeePass username';
        else return '';
    },

    getBrowserFieldTypeDefault: function() {
        if (this.model.name === '$Password') return 'FFTpassword';
        else if (this.model.name === '$UserName') return 'FFTusername';
        else return 'FFTtext';
    },
*/
