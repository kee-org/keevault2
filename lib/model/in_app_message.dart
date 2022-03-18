import 'dart:convert';

import 'package:keevault/cubit/interaction_cubit.dart';
import 'package:keevault/logging/logger.dart';

class InAppMessage {
  final DateTime lastDisplayed;
  final Duration maximumRedisplayFrequency;
  final Duration suppressUntilDurationAfterInstall;
  final DateTime suppressUntilTime;
  final int suppressUntilEntriesSavedCount;
  final int suppressUntilDatabaseSavedCount;

  InAppMessage(
    this.lastDisplayed,
    this.maximumRedisplayFrequency,
    this.suppressUntilDurationAfterInstall,
    this.suppressUntilTime,
    this.suppressUntilEntriesSavedCount,
    this.suppressUntilDatabaseSavedCount,
  );

  InAppMessage copyWith({
    DateTime? lastDisplayed,
    Duration? maximumRedisplayFrequency,
    Duration? suppressUntilDurationAfterInstall,
    DateTime? suppressUntilTime,
    int? suppressUntilEntriesSavedCount,
    int? suppressUntilDatabaseSavedCount,
  }) {
    return InAppMessage(
      lastDisplayed ?? this.lastDisplayed,
      maximumRedisplayFrequency ?? this.maximumRedisplayFrequency,
      suppressUntilDurationAfterInstall ?? this.suppressUntilDurationAfterInstall,
      suppressUntilTime ?? this.suppressUntilTime,
      suppressUntilEntriesSavedCount ?? this.suppressUntilEntriesSavedCount,
      suppressUntilDatabaseSavedCount ?? this.suppressUntilDatabaseSavedCount,
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
    );
  }

  String toJson() => json.encode(toMap());

  factory InAppMessage.fromJson(String source) => InAppMessage.fromMap(json.decode(source));

  @override
  String toString() {
    return 'InAppMessage(lastDisplayed: $lastDisplayed, maximumRedisplayFrequency: $maximumRedisplayFrequency, suppressUntilDurationAfterInstall: $suppressUntilDurationAfterInstall, suppressUntilTime: $suppressUntilTime, suppressUntilEntriesSavedCount: $suppressUntilEntriesSavedCount, suppressUntilDatabaseSavedCount: $suppressUntilDatabaseSavedCount)';
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
        other.suppressUntilDatabaseSavedCount == suppressUntilDatabaseSavedCount;
  }

  @override
  int get hashCode {
    return lastDisplayed.hashCode ^
        maximumRedisplayFrequency.hashCode ^
        suppressUntilDurationAfterInstall.hashCode ^
        suppressUntilTime.hashCode ^
        suppressUntilEntriesSavedCount.hashCode ^
        suppressUntilDatabaseSavedCount.hashCode;
  }

  bool isSuppressed(InteractionBasic interactionState) {
    final now = DateTime.now().toUtc();
    if (suppressUntilTime.isAfter(now)) {
      l.d('Suppressed because $suppressUntilTime is after now');
      return true;
    }
    if (interactionState.anyDatabaseSavedCount < suppressUntilDatabaseSavedCount) {
      l.d('Suppressed because anyDatabaseSavedCount (${interactionState.anyDatabaseSavedCount}) is too low');
      return true;
    }
    if (interactionState.anyEntrySavedCount < suppressUntilEntriesSavedCount) {
      l.d('Suppressed because anyEntrySavedCount (${interactionState.anyEntrySavedCount}) is too low');
      return true;
    }
    if (interactionState.installedBefore.add(suppressUntilDurationAfterInstall).isAfter(now)) {
      l.d('Suppressed because installedBefore is too recent');
      return true;
    }
    if (lastDisplayed.add(maximumRedisplayFrequency).isAfter(now)) {
      l.d('Suppressed because lastDisplayed is too recent');
      return true;
    }
    return false;
  }
}
