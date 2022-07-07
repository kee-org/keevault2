import 'dart:convert';

import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:keevault/cubit/autofill_cubit.dart';

import 'package:keevault/cubit/interaction_cubit.dart';
import 'package:keevault/logging/logger.dart';

import '../cubit/account_cubit.dart';

class InAppMessage {
  final DateTime lastDisplayed;
  final Duration maximumRedisplayFrequency;
  final Duration suppressUntilDurationAfterInstall;
  final DateTime suppressUntilTime;
  final int suppressUntilEntriesSavedCount;
  final int suppressUntilDatabaseSavedCount;
  final bool suppressForRegisteredUser;
  final bool suppressWhenAutofillEnabled;

  InAppMessage(
    this.lastDisplayed,
    this.maximumRedisplayFrequency,
    this.suppressUntilDurationAfterInstall,
    this.suppressUntilTime,
    this.suppressUntilEntriesSavedCount,
    this.suppressUntilDatabaseSavedCount,
    this.suppressForRegisteredUser,
    this.suppressWhenAutofillEnabled,
  );

  InAppMessage copyWith({
    DateTime? lastDisplayed,
    Duration? maximumRedisplayFrequency,
    Duration? suppressUntilDurationAfterInstall,
    DateTime? suppressUntilTime,
    int? suppressUntilEntriesSavedCount,
    int? suppressUntilDatabaseSavedCount,
    bool? suppressForRegisteredUser,
    bool? suppressWhenAutofillEnabled,
  }) {
    return InAppMessage(
      lastDisplayed ?? this.lastDisplayed,
      maximumRedisplayFrequency ?? this.maximumRedisplayFrequency,
      suppressUntilDurationAfterInstall ?? this.suppressUntilDurationAfterInstall,
      suppressUntilTime ?? this.suppressUntilTime,
      suppressUntilEntriesSavedCount ?? this.suppressUntilEntriesSavedCount,
      suppressUntilDatabaseSavedCount ?? this.suppressUntilDatabaseSavedCount,
      suppressForRegisteredUser ?? this.suppressForRegisteredUser,
      suppressWhenAutofillEnabled ?? this.suppressWhenAutofillEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lastDisplayed': lastDisplayed.millisecondsSinceEpoch,
      'maximumRedisplayFrequency': maximumRedisplayFrequency.inMilliseconds,
      'suppressUntilDurationAfterInstall': suppressUntilDurationAfterInstall.inMilliseconds,
      'suppressUntilTime': suppressUntilTime.millisecondsSinceEpoch,
      'suppressUntilEntriesSavedCount': suppressUntilEntriesSavedCount,
      'suppressUntilDatabaseSavedCount': suppressUntilDatabaseSavedCount,
      'suppressForRegisteredUser': suppressForRegisteredUser,
      'suppressWhenAutofillEnabled': suppressWhenAutofillEnabled,
    };
  }

  factory InAppMessage.fromMap(Map<String, dynamic> map) {
    return InAppMessage(
      DateTime.fromMillisecondsSinceEpoch(map['lastDisplayed']),
      Duration(milliseconds: map['maximumRedisplayFrequency']),
      Duration(milliseconds: map['suppressUntilDurationAfterInstall']),
      DateTime.fromMillisecondsSinceEpoch(map['suppressUntilTime']),
      map['suppressUntilEntriesSavedCount']?.toInt() ?? 0,
      map['suppressUntilDatabaseSavedCount']?.toInt() ?? 0,
      map['suppressForRegisteredUser'] ?? false,
      map['suppressWhenAutofillEnabled'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory InAppMessage.fromJson(String source) => InAppMessage.fromMap(json.decode(source));

  factory InAppMessage.fromAppSetting(String settingKey) {
    switch (settingKey) {
      case 'iamEmailSignup':
        {
          final storedSetting = Settings.getValue<String>('iamEmailSignup') ?? '';
          return storedSetting.isNotEmpty
              ? InAppMessage.fromJson(storedSetting)
              : InAppMessage(
                  DateTime.fromMillisecondsSinceEpoch(0),
                  Duration(days: 1),
                  Duration(days: 3),
                  DateTime.now().toUtc(),
                  7,
                  3,
                  true,
                  false,
                );
        }
      case 'iamMakeMoreChangesOrSave':
        {
          final storedSetting = Settings.getValue<String>('iamMakeMoreChangesOrSave') ?? '';
          return storedSetting.isNotEmpty
              ? InAppMessage.fromJson(storedSetting)
              : InAppMessage(
                  DateTime.fromMillisecondsSinceEpoch(0),
                  Duration(hours: 1),
                  Duration(seconds: 1),
                  DateTime.now().toUtc(),
                  0,
                  0,
                  false,
                  false,
                );
        }
      case 'iamSavingVault':
        {
          final storedSetting = Settings.getValue<String>('iamSavingVault') ?? '';
          return storedSetting.isNotEmpty
              ? InAppMessage.fromJson(storedSetting)
              : InAppMessage(
                  DateTime.fromMillisecondsSinceEpoch(0),
                  Duration(hours: 1),
                  Duration(minutes: 1),
                  DateTime.now().toUtc(),
                  1,
                  2,
                  false,
                  false,
                );
        }
      case 'iamAutofillDisabled':
        {
          final storedSetting = Settings.getValue<String>('iamAutofillDisabled') ?? '';
          return storedSetting.isNotEmpty
              ? InAppMessage.fromJson(storedSetting)
              : InAppMessage(
                  DateTime.fromMillisecondsSinceEpoch(0),
                  Duration(days: 1),
                  Duration(minutes: 1),
                  DateTime.now().toUtc(),
                  1,
                  1,
                  false,
                  true,
                );
        }
    }
    throw Exception('Unknown InAppMessage key: $settingKey');
  }

  @override
  String toString() {
    return 'InAppMessage(lastDisplayed: $lastDisplayed, maximumRedisplayFrequency: $maximumRedisplayFrequency, suppressUntilDurationAfterInstall: $suppressUntilDurationAfterInstall, suppressUntilTime: $suppressUntilTime, suppressUntilEntriesSavedCount: $suppressUntilEntriesSavedCount, suppressUntilDatabaseSavedCount: $suppressUntilDatabaseSavedCount, suppressForRegisteredUser: $suppressForRegisteredUser, suppressWhenAutofillEnabled: $suppressWhenAutofillEnabled)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is InAppMessage &&
        other.lastDisplayed == lastDisplayed &&
        other.maximumRedisplayFrequency == maximumRedisplayFrequency &&
        other.suppressUntilDurationAfterInstall == suppressUntilDurationAfterInstall &&
        other.suppressUntilTime == suppressUntilTime &&
        other.suppressUntilEntriesSavedCount == suppressUntilEntriesSavedCount &&
        other.suppressUntilDatabaseSavedCount == suppressUntilDatabaseSavedCount &&
        other.suppressForRegisteredUser == suppressForRegisteredUser &&
        other.suppressWhenAutofillEnabled == suppressWhenAutofillEnabled;
  }

  @override
  int get hashCode {
    return lastDisplayed.hashCode ^
        maximumRedisplayFrequency.hashCode ^
        suppressUntilDurationAfterInstall.hashCode ^
        suppressUntilTime.hashCode ^
        suppressUntilEntriesSavedCount.hashCode ^
        suppressUntilDatabaseSavedCount.hashCode ^
        suppressForRegisteredUser.hashCode ^
        suppressWhenAutofillEnabled.hashCode;
  }

  bool isSuppressed(AccountCubit accountCubit, AutofillState autofillState, InteractionBasic interactionState) {
    if (suppressForRegisteredUser && accountCubit.currentUserIfKnown == null) {
      l.v('Suppressed because user is signed in');
      return true;
    }
    if (suppressWhenAutofillEnabled && (autofillState is! AutofillAvailable || autofillState.enabled)) {
      l.v('Suppressed because autofill is already enabled or unavailable');
      return true;
    }
    final now = DateTime.now().toUtc();
    if (suppressUntilTime.isAfter(now)) {
      l.v('Suppressed because $suppressUntilTime is after now');
      return true;
    }
    if (interactionState.anyDatabaseSavedCount < suppressUntilDatabaseSavedCount) {
      l.v('Suppressed because anyDatabaseSavedCount (${interactionState.anyDatabaseSavedCount}) is too low');
      return true;
    }
    if (interactionState.anyEntrySavedCount < suppressUntilEntriesSavedCount) {
      l.v('Suppressed because anyEntrySavedCount (${interactionState.anyEntrySavedCount}) is too low');
      return true;
    }
    if (interactionState.installedBefore.add(suppressUntilDurationAfterInstall).isAfter(now)) {
      l.v('Suppressed because installedBefore is too recent');
      return true;
    }
    if (lastDisplayed.add(maximumRedisplayFrequency).isAfter(now)) {
      l.v('Suppressed because lastDisplayed is too recent');
      return true;
    }
    return false;
  }
}
