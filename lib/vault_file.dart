import 'package:argon2_ffi_base/argon2_ffi_base.dart';
import 'package:kdbx/kdbx.dart';

import 'package:keevault/locked_vault_file.dart';

import 'kdbx_argon2_ffi.dart';
import 'kdf_cache.dart';

class VaultFileVersions {
  // Current unlocked kdbx must always be available
  late KdbxFile _current;
  KdbxFile get current => _current;
  KdbxFile? _pending;
  Future<KdbxFile?> get pending async => _pending ??= (pendingLocked != null ? await unlock(pendingLocked!) : null);
  LockedVaultFile? pendingLocked;
  KdbxFile? _remoteMergeTarget;
  Future<KdbxFile?> get remoteMergeTarget async => _remoteMergeTarget ??= (await unlock(remoteMergeTargetLocked));
  LockedVaultFile remoteMergeTargetLocked;
  VaultFileVersions({
    required KdbxFile current,
    KdbxFile? pending,
    this.pendingLocked,
    KdbxFile? remoteMergeTarget,
    required this.remoteMergeTargetLocked,
  }) {
    _current = current;
    _pending = pending;
    _remoteMergeTarget = remoteMergeTarget;
  }

  bool get hasPendingChanges => _pending != null || pendingLocked != null;

  Future<KdbxFile> unlock(LockedVaultFile locked) async {
    final kdbx = await VaultFile._kdbxFormat().read(locked.kdbxBytes, locked.credentials!);
    return kdbx;
  }

  Future<List<KdbxFile>> unlockTwice(LockedVaultFile locked) async {
    final kdbxList = await VaultFile._kdbxFormat().readTwice(locked.kdbxBytes, locked.credentials!);
    return kdbxList;
  }

  VaultFileVersions copyWithMergeResult(
    KdbxFile pending,
    LockedVaultFile pendingLocked,
    LockedVaultFile remoteMergeTargetLocked,
  ) {
    return VaultFileVersions(
      current: _current,
      pending: pending,
      pendingLocked: pendingLocked,
      remoteMergeTarget: null,
      remoteMergeTargetLocked: remoteMergeTargetLocked,
    );
  }

  VaultFileVersions copyWithAppliedPendingUpdate(KdbxFile newCurrent) {
    return VaultFileVersions(
      current: newCurrent,
      pending: null,
      pendingLocked: null,
      remoteMergeTarget: _remoteMergeTarget,
      remoteMergeTargetLocked: remoteMergeTargetLocked,
    );
  }

//  remoteMergeTarget and current are identical at this time because user has just supplied a new password through the UI so can't have any outstanding modifications in the current vault file. There must also be no pending files.
  Future<VaultFileVersions> copyWithNewCredentials(Credentials credentials) async {
    // final unlockedFiles = await unlockTwice(this.remoteMergeTargetLocked!);
    // final unlockedCurrent = unlockedFiles[0];
    //unlockedCurrent.overwriteCredentials(credentials, DateTime.now());
    final unlockedFile = await unlock(remoteMergeTargetLocked);
    unlockedFile.changeCredentials(credentials);
    // final unlockedMergeTarget = unlockedFiles[1];
    // unlockedMergeTarget.changeCredentials(credentials);
    final kdbxData = await unlockedFile.save();
    return VaultFileVersions(
        current: _current,
        pending: null,
        pendingLocked: null,
        remoteMergeTarget: null,
        remoteMergeTargetLocked: LockedVaultFile(kdbxData, DateTime.now(), credentials, null, null));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is VaultFileVersions &&
        other._current == _current &&
        other._pending == _pending &&
        other.pendingLocked == pendingLocked &&
        other._remoteMergeTarget == _remoteMergeTarget &&
        other.remoteMergeTargetLocked == remoteMergeTargetLocked;
  }

  @override
  int get hashCode {
    return _current.hashCode ^
        _pending.hashCode ^
        pendingLocked.hashCode ^
        _remoteMergeTarget.hashCode ^
        remoteMergeTargetLocked.hashCode;
  }
}

abstract class VaultFile {
  DateTime? modifiedAt;
  final DateTime persistedAt;
  final String uuid;
  final DateTime lastOpenedAt;
  final String? etag;
  final String? versionId;

  VaultFile(this.lastOpenedAt, this.persistedAt, this.uuid, this.etag, this.versionId) {
    modifiedAt = persistedAt;
  }

  static KdbxFormat _kdbxFormat() {
    Argon2.resolveLibraryForceDynamic = true;
    return KdbxFormat(KeeVaultKdfCache(), FlutterArgon2());
  }
}

class RemoteVaultFile extends VaultFile {
  final KdbxFile kdbx;
  RemoteVaultFile(this.kdbx, DateTime lastOpenedAt, DateTime persistedAt, String uuid, String? etag, String? versionId)
      : super(lastOpenedAt, persistedAt, uuid, etag, versionId);

  static Future<RemoteVaultFile> unlock(LockedVaultFile lockedKdbx) async {
    final kdbx = await VaultFile._kdbxFormat().read(lockedKdbx.kdbxBytes, lockedKdbx.credentials!);
    return RemoteVaultFile(
      kdbx,
      DateTime.now(),
      lockedKdbx.persistedAt,
      kdbx.body.rootGroup.uuid.uuid,
      lockedKdbx.etag,
      lockedKdbx.versionId,
    );
  }
}

class DemoVaultFile extends VaultFile {
  final KdbxFile kdbx;
  DemoVaultFile(this.kdbx, DateTime lastOpenedAt, DateTime persistedAt, String uuid, String? etag, String? versionId)
      : super(lastOpenedAt, persistedAt, uuid, etag, versionId);

  static Future<DemoVaultFile> unlock(LockedVaultFile lockedKdbx) async {
    final kdbx = await VaultFile._kdbxFormat().read(lockedKdbx.kdbxBytes, lockedKdbx.credentials!);
    return DemoVaultFile(
      kdbx,
      DateTime.now(),
      lockedKdbx.persistedAt,
      kdbx.body.rootGroup.uuid.uuid,
      lockedKdbx.etag,
      lockedKdbx.versionId,
    );
  }
}

class LocalVaultFile extends VaultFile {
  VaultFileVersions files;
  LocalVaultFile(
    this.files,
    DateTime lastOpenedAt,
    DateTime persistedAt,
    String uuid,
    String? etag,
    String? versionId,
  ) : super(lastOpenedAt, persistedAt, uuid, etag, versionId);

  bool get hasPendingChanges => files.hasPendingChanges;

  static Future<LocalVaultFile> unlock(LockedVaultFile lockedKdbx, {bool importOnly = false}) async {
    KdbxFile current;
    KdbxFile? remoteMergeTarget;
    if (importOnly) {
      current = await VaultFile._kdbxFormat().read(lockedKdbx.kdbxBytes, lockedKdbx.credentials!);
    } else {
      final files = await VaultFile._kdbxFormat().readTwice(lockedKdbx.kdbxBytes, lockedKdbx.credentials!);
      current = files[0];
      remoteMergeTarget = files[1];
    }
    return LocalVaultFile(
      VaultFileVersions(
        current: current,
        remoteMergeTarget: remoteMergeTarget,
        remoteMergeTargetLocked: lockedKdbx,
      ),
      DateTime.now(),
      lockedKdbx.persistedAt,
      current.body.rootGroup.uuid.uuid,
      lockedKdbx.etag,
      lockedKdbx.versionId,
    );
  }
}
