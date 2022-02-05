import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:kdbx/kdbx.dart';

@immutable
class LockedVaultFile {
  final Uint8List kdbxBytes;
  final DateTime persistedAt;
  final Credentials? credentials;
  final String? etag;
  final String? versionId;

  const LockedVaultFile(this.kdbxBytes, this.persistedAt, this.credentials, this.etag, this.versionId);

  LockedVaultFile copyWith({
    DateTime? persistedAt,
    Uint8List? kdbxBytes,
    Credentials? credentials,
    String? etag,
    String? versionId,
  }) {
    return LockedVaultFile(
      kdbxBytes ?? this.kdbxBytes,
      persistedAt ?? this.persistedAt,
      credentials ?? this.credentials,
      etag ?? this.etag,
      versionId ?? this.versionId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LockedVaultFile &&
        other.kdbxBytes == kdbxBytes &&
        other.persistedAt == persistedAt &&
        other.credentials == credentials &&
        other.etag == etag &&
        other.versionId == versionId;
  }

  @override
  int get hashCode {
    return kdbxBytes.hashCode ^ persistedAt.hashCode ^ credentials.hashCode ^ etag.hashCode ^ versionId.hashCode;
  }
}
