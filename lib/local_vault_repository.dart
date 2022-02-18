import 'dart:io';
import 'dart:typed_data';

import 'package:argon2_ffi_base/argon2_ffi_base.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/password_strength.dart';
import 'package:path_provider/path_provider.dart';

import 'package:keevault/config/synced_app_settings.dart';
import 'package:keevault/locked_vault_file.dart';
import 'package:keevault/vault_backend/exceptions.dart';

import 'argon2_params.dart';
import 'kdbx_argon2_ffi.dart';
import 'kdf_cache.dart';
import 'logging/logger.dart';
import 'quick_unlocker.dart';
import 'vault_backend/user.dart';
import 'vault_file.dart';

class LocalVaultRepository {
  final QuickUnlocker qu;

  LocalVaultRepository(this.qu);

  // KdbxFormat orchestrates methods for dealing with files and data streams in the form of a kdbx file
  static KdbxFormat kdbxFormat() {
    Argon2.resolveLibraryForceDynamic = true;
    return KdbxFormat(KeeVaultKdfCache(), FlutterArgon2());
  }

  Future<LockedVaultFile?> _loadFile(String fileName, [DateTime? ifNewerThan]) async {
    Uint8List kdbxData;
    DateTime persistedDate;
    try {
      final file = File(fileName);
      persistedDate = await file.lastModified();
      if (ifNewerThan != null && !persistedDate.isAfter(ifNewerThan)) {
        return null;
      }
      kdbxData = await file.readAsBytes();
    } catch (e) {
      return null;
    }
    if (kdbxData.isEmpty) return null;
    return LockedVaultFile(
      kdbxData,
      persistedDate,
      null,
      null,
      null,
    );
  }

  Future<LocalVaultFile?> _loadLocalFile(Future<Credentials?> Function() getCredentials, String fileName,
      [DateTime? ifNewerThan]) async {
    final file = await _loadFile(fileName, ifNewerThan);
    if (file == null) {
      return null;
    }
    final creds = await getCredentials();
    if (creds == null) {
      throw KeeLoginRequiredException();
    }
    return await LocalVaultFile.unlock(file.copyWith(credentials: creds));
  }

  Future<RemoteVaultFile?> _loadRemoteFile(Future<Credentials?> Function() getCredentials, String fileName,
      [DateTime? ifNewerThan]) async {
    final file = await _loadFile(fileName, ifNewerThan);
    if (file == null) {
      return null;
    }
    final creds = await getCredentials();
    if (creds == null) {
      throw KeeLoginRequiredException();
    }
    return await RemoteVaultFile.unlock(file.copyWith(credentials: creds));
  }

  Future<LocalVaultFile?> loadFreeUser(Future<Credentials?> Function() getCredentials) async {
    final directory = await getApplicationSupportDirectory();
    final file = await _loadLocalFile(getCredentials, '${directory.path}/local_user/current.kdbx');
    return file;
  }

  Future<LockedVaultFile?> loadFreeUserLocked() async {
    final directory = await getApplicationSupportDirectory();
    final file = await _loadFile('${directory.path}/local_user/current.kdbx');
    return file;
  }

  Future<LocalVaultFile?> load(User user, Future<Credentials?> Function() getCredentials) async {
    final directory = await getApplicationSupportDirectory();
    final file = await _loadLocalFile(getCredentials, '${directory.path}/${user.emailHashedB64url}/current.kdbx');
    return file;
  }

  Future<LocalVaultFile?> createNewKdbxOnStorage(StrengthAssessedCredentials credentialsWithStrength) async {
    final directory = await getApplicationSupportDirectory();
    final credentials = credentialsWithStrength.credentials;
    final kdbx = kdbxFormat().create(
      credentials,
      'My Kee Vault',
      generator: 'Kee Vault 2',
      header: createNewKdbxHeader(credentialsWithStrength),
    );
    final saved = await kdbx.save();

    final file = File('${directory.path}/local_user/current.kdbx');
    await file.create(recursive: true);
    await file.writeAsBytes(saved, flush: true);
    final persistedDate = await file.lastModified();

    final requireFullPasswordPeriod = int.tryParse(Settings.getValue<String>('requireFullPasswordPeriod', '60')) ?? 60;
    l.d('Will require a full password to be entered every $requireFullPasswordPeriod days');
    await qu.saveQuickUnlockFileCredentials(
        credentials, DateTime.now().add(Duration(days: requireFullPasswordPeriod)).millisecondsSinceEpoch);

    final lockedKdbx = LockedVaultFile(
      saved,
      persistedDate,
      credentials,
      null,
      null,
    );
    //TODO:f Check whether the output of create() can be used instead of unlocking again
    final loadedKdbx = await kdbxFormat().read(saved, credentials);
    return LocalVaultFile(
      VaultFileVersions(
        current: loadedKdbx,
        remoteMergeTargetLocked: lockedKdbx,
      ),
      DateTime.now(),
      lockedKdbx.persistedAt,
      loadedKdbx.body.rootGroup.uuid.uuid,
      null,
      null,
    );
  }

  Future<bool> localFreeExists() async {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/local_user/current.kdbx');
    final exists = await file.exists();
    return exists;
  }

  Future<void> create(User user, LockedVaultFile lockedKdbx) async {
    final requireFullPasswordPeriod = int.tryParse(Settings.getValue<String>('requireFullPasswordPeriod', '60')) ?? 60;
    l.d('Will require a full password to be entered every $requireFullPasswordPeriod days');
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/${user.emailHashedB64url}/current.kdbx');
    await file.create(recursive: true);
    await file.writeAsBytes(lockedKdbx.kdbxBytes, flush: true);
    await qu.saveQuickUnlockFileCredentials(
        lockedKdbx.credentials, DateTime.now().add(Duration(days: requireFullPasswordPeriod)).millisecondsSinceEpoch);
  }

  Future<VaultFileVersions> merge(User user, LocalVaultFile local, RemoteVaultFile remote) async {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/${user.emailHashedB64url}/current.kdbx');
    final firstKdbx = await local.files.remoteMergeTarget;
    if (firstKdbx == null) {
      throw Exception("Missing remote merge target. Can't proceed with merge.");
    }
    final secondKdbx = remote.kdbx;
    Uint8List kdbxData;
    KdbxFile finalKdbx;
    try {
      firstKdbx.merge(secondKdbx);
      finalKdbx = firstKdbx;
      kdbxData = await kdbxFormat().save(firstKdbx);
    } on KdbxUnsupportedException catch (e) {
      final backupFilename =
          '${directory.path}/${user.emailHashedB64url}/backup-${DateTime.now().millisecondsSinceEpoch}.kdbx';
      l.w('Merge from remote failed! Most likely this is due to the user resetting their account on another device and then signing in to this device AND they reset their password to the same as it was before. We will create a backup file at $backupFilename just in case manual recovery becomes critical. Detailed reason: ${e.hint}');
      final backupFile = File(backupFilename);
      await file.copy(backupFilename);
      finalKdbx = secondKdbx;
      kdbxData = await kdbxFormat().save(secondKdbx);
    }

    await file.writeAsBytes(kdbxData, flush: true);
    final persistedTime = DateTime.now();

    // finalKdbx.credentials were updated by the KDBX library to match the set with the latest modifiedAt timestamp
    return local.files.copyWithMergeResult(
      finalKdbx,
      LockedVaultFile(kdbxData, persistedTime, finalKdbx.credentials, null, null),
      LockedVaultFile(kdbxData, persistedTime, finalKdbx.credentials, null, null),
    );
  }

  Future<void> stageUpdate<T>(User user, T vaultFile) async {
    Uint8List bytes;
    if (vaultFile is LockedVaultFile) {
      l.d('staging LockedVaultFile');
      bytes = vaultFile.kdbxBytes;
    } else if (vaultFile is RemoteVaultFile) {
      l.d('staging RemoteVaultFile');
      bytes = await kdbxFormat().save(vaultFile.kdbx);
    } else {
      throw Exception('Invalid object passed to stageUpdate');
    }

    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/${user.emailHashedB64url}/staged.kdbx');
    await file.writeAsBytes(bytes, flush: true);
    l.d('staging complete');
  }

  Future<RemoteVaultFile?> loadStagedUpdate(
      User user, Future<Credentials?> Function() getCredentials, DateTime ifNewerThan) async {
    final directory = await getApplicationSupportDirectory();
    return await _loadRemoteFile(
      getCredentials,
      '${directory.path}/${user.emailHashedB64url}/staged.kdbx',
      ifNewerThan,
    );
  }

  remove(User user) async {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/${user.emailHashedB64url}/current.kdbx');
    final stagedFile = File('${directory.path}/${user.emailHashedB64url}/staged.kdbx');
    try {
      await file.delete();
    } on Exception {
      // can fail if OS/hardware failure has caused the file to be already deleted but that's OK
    }
    try {
      await stagedFile.delete();
    } on Exception {
      // can fail if OS/hardware failure has caused the file to be already deleted but that's OK
    }
  }

  Future<bool> removeFreeUser() async {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/local_user/current.kdbx');
    try {
      await file.delete();
      return true;
    } on Exception {
      // can fail if OS/hardware failure has caused the file to be already deleted but that's OK
    }
    return false;
  }

  Future<KdbxFile> beforeSave(
      KdbxFile file, Future<KdbxFile> Function(KdbxFile vaultFile) applyAndConsumePendingAutofillAssociations) async {
    final fileWithAutofill = await applyAndConsumePendingAutofillAssociations(file);
    fileWithAutofill.body.meta.keeVaultSettings = SyncedAppSettings.export(fileWithAutofill.body.meta.keeVaultSettings);
    return fileWithAutofill;
  }

  Future<LocalVaultFile> save(User? user, LocalVaultFile vault,
      Future<KdbxFile> Function(KdbxFile vaultFile) applyAndConsumePendingAutofillAssociations) async {
    final directory = await getApplicationSupportDirectory();
    final userFolder = user?.emailHashedB64url ?? 'local_user';
    final file = File('${directory.path}/$userFolder/current.kdbx');
    (await vault.files.pending)?.merge(vault.files.current);
    final kdbxToSave = await beforeSave(
        (await vault.files.pending) ?? vault.files.current, applyAndConsumePendingAutofillAssociations);
    final kdbxData = await kdbxFormat().save(kdbxToSave);
    await file.writeAsBytes(kdbxData, flush: true);
    final persistedTime = DateTime.now();
    final files = VaultFileVersions(
        current: kdbxToSave,
        remoteMergeTargetLocked: LockedVaultFile(
          kdbxData,
          persistedTime,
          kdbxToSave.credentials,
          null,
          null,
        ));
    return LocalVaultFile(files, persistedTime, persistedTime, vault.uuid, null, null);
  }

  KdbxHeader createNewKdbxHeader(StrengthAssessedCredentials credentialsWithStrength) {
    final argon2Params = Argon2Params.forStrength(credentialsWithStrength.strength);
    final kdfParameters = VarDictionary([
      KdfField.uuid.item(KeyEncrypterKdf.kdfUuidForType(KdfType.Argon2d).toBytes()),
      KdfField.salt.item(ByteUtils.randomBytes(argon2Params.saltLength)),
      KdfField.parallelism.item(argon2Params.parallelism),
      KdfField.iterations.item(argon2Params.iterations),
      KdfField.memory.item(argon2Params.memory),
      KdfField.version.item(argon2Params.version),
    ]);
    return KdbxHeader.createV4()..writeKdfParameters(kdfParameters);
  }
}
