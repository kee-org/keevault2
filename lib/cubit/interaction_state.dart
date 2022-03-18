part of 'interaction_cubit.dart';

@immutable
abstract class InteractionState {}

class InteractionBasic extends InteractionState {
  final int anyEntrySavedCount;
  final int anyDatabaseSavedCount;
  final int anyDatabaseOpenedCount;
  final DateTime installedBefore;
  final DateTime anyDatabaseLastOpenedAt;

  InteractionBasic(
    this.anyEntrySavedCount,
    this.anyDatabaseSavedCount,
    this.anyDatabaseOpenedCount,
    this.installedBefore,
    this.anyDatabaseLastOpenedAt,
  );

  InteractionBasic copyWith({
    int? anyEntrySavedCount,
    int? anyDatabaseSavedCount,
    int? anyDatabaseOpenedCount,
    DateTime? installedBefore,
    DateTime? anyDatabaseLastOpenedAt,
  }) {
    return InteractionBasic(
      anyEntrySavedCount ?? this.anyEntrySavedCount,
      anyDatabaseSavedCount ?? this.anyDatabaseSavedCount,
      anyDatabaseOpenedCount ?? this.anyDatabaseOpenedCount,
      installedBefore ?? this.installedBefore,
      anyDatabaseLastOpenedAt ?? this.anyDatabaseLastOpenedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'anyEntrySavedCount': anyEntrySavedCount,
      'anyDatabaseSavedCount': anyDatabaseSavedCount,
      'anyDatabaseOpenedCount': anyDatabaseOpenedCount,
      'installedBefore': installedBefore.millisecondsSinceEpoch,
      'anyDatabaseLastOpenedAt': anyDatabaseLastOpenedAt.millisecondsSinceEpoch,
    };
  }

  factory InteractionBasic.fromMap(Map<String, dynamic> map) {
    return InteractionBasic(
      map['anyEntrySavedCount']?.toInt() ?? 0,
      map['anyDatabaseSavedCount']?.toInt() ?? 0,
      map['anyDatabaseOpenedCount']?.toInt() ?? 0,
      DateTime.fromMillisecondsSinceEpoch(map['installedBefore']),
      DateTime.fromMillisecondsSinceEpoch(map['anyDatabaseLastOpenedAt']),
    );
  }

  String toJson() => json.encode(toMap());

  factory InteractionBasic.fromJson(String source) => InteractionBasic.fromMap(json.decode(source));

  @override
  String toString() {
    return 'InteractionBasic(anyEntrySavedCount: $anyEntrySavedCount, anyDatabaseSavedCount: $anyDatabaseSavedCount, anyDatabaseOpenedCount: $anyDatabaseOpenedCount, installedBefore: $installedBefore, anyDatabaseLastOpenedAt: $anyDatabaseLastOpenedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is InteractionBasic &&
        other.anyEntrySavedCount == anyEntrySavedCount &&
        other.anyDatabaseSavedCount == anyDatabaseSavedCount &&
        other.anyDatabaseOpenedCount == anyDatabaseOpenedCount &&
        other.installedBefore == installedBefore &&
        other.anyDatabaseLastOpenedAt == anyDatabaseLastOpenedAt;
  }

  @override
  int get hashCode {
    return anyEntrySavedCount.hashCode ^
        anyDatabaseSavedCount.hashCode ^
        anyDatabaseOpenedCount.hashCode ^
        installedBefore.hashCode ^
        anyDatabaseLastOpenedAt.hashCode;
  }
}
