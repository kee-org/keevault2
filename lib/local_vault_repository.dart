import 'dart:io';

import 'package:argon2_ffi_base/argon2_ffi_base.dart';
import 'package:flutter/services.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/extension_methods.dart';
import 'package:keevault/password_strength.dart';
import 'package:path_provider/path_provider.dart';

import 'package:keevault/config/synced_app_settings.dart';
import 'package:keevault/locked_vault_file.dart';
import 'package:keevault/vault_backend/exceptions.dart';

import 'config/platform.dart';
import 'credentials/credential_lookup_result.dart';
import 'kdbx_argon2_ffi.dart';
import 'kdf_cache.dart';
import 'logging/logger.dart';
import 'credentials/quick_unlocker.dart';
import 'vault_backend/user.dart';
import 'vault_file.dart';

class LocalVaultRepository {
  final QuickUnlocker qu;
  static const _autoFillMethodChannel = MethodChannel('com.keevault.keevault/autofill');

  LocalVaultRepository(this.qu);

  // KdbxFormat orchestrates methods for dealing with files and data streams in the form of a kdbx file
  static KdbxFormat kdbxFormat() {
    Argon2.resolveLibraryForceDynamic = true;
    return KdbxFormat(KeeVaultKdfCache(), FlutterArgon2());
  }

  Future<Directory> getStorageDirectory() async {
    if (KeeVaultPlatform.isIOS) {
      final path = await _autoFillMethodChannel.invokeMethod('getAppGroupDirectory');
      return Directory(path);
    }
    final directory = await getApplicationSupportDirectory();
    return directory;
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
    return LockedVaultFile(kdbxData, persistedDate, null, null, null);
  }

  Future<LocalVaultFile?> _loadLocalFile(
    Future<CredentialLookupResult> Function() getCredentials,
    String fileName, [
    DateTime? ifNewerThan,
  ]) async {
    final file = await _loadFile(fileName, ifNewerThan);
    if (file == null) {
      return null;
    }
    final credsLookupResult = await getCredentials();
    if (credsLookupResult.credentials == null) {
      throw KeeLoginRequiredException(quStatus: credsLookupResult.quStatus);
    }
    return await LocalVaultFile.unlock(file.copyWith(credentials: credsLookupResult.credentials));
  }

  Future<RemoteVaultFile?> _loadRemoteFile(
    Future<CredentialLookupResult> Function() getCredentials,
    String fileName, [
    DateTime? ifNewerThan,
  ]) async {
    final file = await _loadFile(fileName, ifNewerThan);
    if (file == null) {
      return null;
    }
    final credsLookupResult = await getCredentials();
    if (credsLookupResult.credentials == null) {
      throw KeeLoginRequiredException(quStatus: credsLookupResult.quStatus);
    }
    return await RemoteVaultFile.unlock(file.copyWith(credentials: credsLookupResult.credentials));
  }

  Future<LocalVaultFile?> loadFreeUser(Future<CredentialLookupResult> Function() getCredentials) async {
    final directory = await getStorageDirectory();
    final file = await _loadLocalFile(getCredentials, '${directory.path}/local_user/current.kdbx');
    return file;
  }

  Future<LockedVaultFile?> loadFreeUserLocked() async {
    final directory = await getStorageDirectory();
    final file = await _loadFile('${directory.path}/local_user/current.kdbx');
    return file;
  }

  Future<LocalVaultFile?> load(User user, Future<CredentialLookupResult> Function() getCredentials) async {
    final directory = await getStorageDirectory();
    final file = await _loadLocalFile(getCredentials, '${directory.path}/${user.idB64url}/current.kdbx');
    return file;
  }

  Future<LocalVaultFile> createNewKdbxOnStorage(StrengthAssessedCredentials credentialsWithStrength) async {
    final directory = await getStorageDirectory();
    final credentials = credentialsWithStrength.credentials;
    final kdbx = kdbxFormat().create(
      credentials,
      'My Kee Vault',
      generator: 'Kee Vault 2',
      header: credentialsWithStrength.createNewKdbxHeader(),
    );
    final saved = await kdbx.save();

    final file = File('${directory.path}/local_user/current.kdbx');
    await file.create(recursive: true);
    await file.writeAsBytes(saved, flush: true);
    final persistedDate = await file.lastModified();

    final requireFullPasswordPeriod =
        int.tryParse(Settings.getValue<String>('requireFullPasswordPeriod') ?? '60') ?? 60;
    l.d('Will require a full password to be entered every $requireFullPasswordPeriod days');
    // this fails every time cos we don't know the currentuser yet. Remove in 2024 if no unexpected issues crop up.
    // await qu.saveQuickUnlockFileCredentials(credentials,
    //     DateTime.now().add(Duration(days: requireFullPasswordPeriod)).millisecondsSinceEpoch, await kdbx.kdfCacheKey);

    final lockedKdbx = LockedVaultFile(saved, persistedDate, credentials, null, null);
    // Potentially could use the output of create() above instead of unlocking again but
    // this extra work does also act as a sanity check to fail early if something has
    // gone wrong with the credentials or initial KDBX storage so the one-off performance
    // gain is probably not worth even thinking about in any more detail.
    final loadedKdbx = await kdbxFormat().read(saved, credentials);
    return LocalVaultFile(
      VaultFileVersions(current: loadedKdbx, remoteMergeTargetLocked: lockedKdbx),
      DateTime.now(),
      lockedKdbx.persistedAt,
      loadedKdbx.body.rootGroup.uuid.uuid,
      null,
      null,
    );
  }

  Future<bool> localFreeExists() async {
    final directory = await getStorageDirectory();
    final file = File('${directory.path}/local_user/current.kdbx');
    final exists = await file.exists();
    return exists;
  }

  Future<void> create(User user, LockedVaultFile lockedKdbx) async {
    final directory = await getStorageDirectory();
    final file = File('${directory.path}/${user.idB64url}/current.kdbx');
    await file.create(recursive: true);
    await file.writeAsBytes(lockedKdbx.kdbxBytes, flush: true);
  }

  Future<void> createQUCredentials(Credentials credentials, KdbxFile file) async {
    final requireFullPasswordPeriod =
        int.tryParse(Settings.getValue<String>('requireFullPasswordPeriod') ?? '60') ?? 60;
    l.d('Will require a full password to be entered every $requireFullPasswordPeriod days');
    await qu.saveQuickUnlockFileCredentials(
      credentials,
      DateTime.now().add(Duration(days: requireFullPasswordPeriod)).millisecondsSinceEpoch,
      await file.kdfCacheKey,
    );
  }

  Future<VaultFileVersions> merge(User user, LocalVaultFile local, RemoteVaultFile remote) async {
    final directory = await getStorageDirectory();
    final file = File('${directory.path}/${user.idB64url}/current.kdbx');
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
      final backupFilename = '${directory.path}/${user.idB64url}/backup-${DateTime.now().millisecondsSinceEpoch}.kdbx';
      l.w(
        'Merge from remote failed! Most likely this is due to the user resetting their account on another device and then signing in to this device AND they reset their password to the same as it was before. We will create a backup file at $backupFilename just in case manual recovery becomes critical. Detailed reason: ${e.hint}',
      );
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

    final directory = await getStorageDirectory();
    final file = File('${directory.path}/${user.idB64url}/staged.kdbx');
    await file.writeAsBytes(bytes, flush: true);
    l.d('staging complete');
  }

  Future<RemoteVaultFile?> loadStagedUpdate(
    User user,
    Future<CredentialLookupResult> Function() getCredentials,
    DateTime ifNewerThan,
  ) async {
    final directory = await getStorageDirectory();
    return await _loadRemoteFile(getCredentials, '${directory.path}/${user.idB64url}/staged.kdbx', ifNewerThan);
  }

  Future<void> removeStagedUpdate(User user) async {
    final directory = await getStorageDirectory();
    final stagedFile = File('${directory.path}/${user.idB64url}/staged.kdbx');
    try {
      await stagedFile.delete();
    } on Exception {
      // can fail if OS/hardware failure has caused the file to be already deleted but that's OK
    }
  }

  Future<bool> hasStagedUpdate(User user) async {
    final directory = await getStorageDirectory();
    final stagedFile = File('${directory.path}/${user.idB64url}/staged.kdbx');
    try {
      final exists = await stagedFile.exists();
      return exists;
    } on Exception {
      // maybe can fail but that's OK, just assume does not exist since are unlikely to be able to do anything with it anyway
    }
    return false;
  }

  Future<void> remove(User user) async {
    final directory = await getStorageDirectory();
    final file = File('${directory.path}/${user.idB64url}/current.kdbx');
    final stagedFile = File('${directory.path}/${user.idB64url}/staged.kdbx');
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
    final directory = await getStorageDirectory();
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
    KdbxFile file,
    Future<KdbxFile> Function(KdbxFile vaultFile) applyAndConsumePendingAutofillAssociations,
  ) async {
    final fileWithAutofill = await applyAndConsumePendingAutofillAssociations(file);
    fileWithAutofill.body.meta.keeVaultSettings = SyncedAppSettings.export(fileWithAutofill.body.meta.keeVaultSettings);
    return fileWithAutofill;
  }

  Future<LocalVaultFile> save(
    User? user,
    LocalVaultFile vault,
    Future<KdbxFile> Function(KdbxFile vaultFile) applyAndConsumePendingAutofillAssociations,
  ) async {
    final directory = await getStorageDirectory();
    final userFolder = user?.idB64url ?? 'local_user';
    final file = File('${directory.path}/$userFolder/current.kdbx');
    (await vault.files.pending)?.merge(vault.files.current);
    final kdbxToSave = await beforeSave(
      (await vault.files.pending) ?? vault.files.current,
      applyAndConsumePendingAutofillAssociations,
    );
    final kdbxData = await kdbxFormat().save(kdbxToSave);
    await file.writeAsBytes(kdbxData, flush: true);
    final persistedTime = DateTime.now();
    final files = VaultFileVersions(
      current: kdbxToSave,
      remoteMergeTargetLocked: LockedVaultFile(kdbxData, persistedTime, kdbxToSave.credentials, null, null),
    );
    return LocalVaultFile(files, persistedTime, persistedTime, vault.uuid, null, null);
  }

  Future<LocalVaultFile?> tryAutofillMerge(User? user, Credentials creds, LocalVaultFile vault) async {
    final directory = await getStorageDirectory();
    final userFolder = user?.idB64url ?? 'local_user';
    final fileNameCurrent = File('${directory.path}/$userFolder/current.kdbx');
    final fileNameAutofill = '${directory.path}/$userFolder/autofill.kdbx';
    final fileAutofill = File(fileNameAutofill);

    if (!(await fileAutofill.exists())) {
      // normal happy path - nothing to merge from recent autofill activity
      return null;
    }
    l.d('merging current vault from autofill source');

    try {
      final autofillData = await fileAutofill.readAsBytes();
      if (autofillData.isEmpty) return null;
      final autofillLocked = LockedVaultFile(autofillData, DateTime.now(), creds, null, null);
      final autofill = await LocalVaultFile.unlock(autofillLocked);

      // pending may be valid and latest data if user has recently downloaded new
      // data from remote while they had dirty changes locally. If we ignore it,
      //user will lose that new remote data because we will have recorded that it
      //was already applied and ready for them to save once they have finished
      //their current edits. We can't preserve their current edits while
      //simultaneously accepting edits from their autofill activity. That's
      //something that a background service might be able to achieve if Apple
      //and Google are able to offer a suitable API.
      final kdbxToMergeInto = (await vault.files.pending) ?? vault.files.current;

      kdbxToMergeInto.merge(autofill.files.current);
      final kdbxData = await kdbxFormat().save(kdbxToMergeInto);

      await fileNameCurrent.writeAsBytes(kdbxData, flush: true);
      final persistedTime = DateTime.now();
      final files = VaultFileVersions(
        current: kdbxToMergeInto,
        remoteMergeTargetLocked: LockedVaultFile(kdbxData, persistedTime, kdbxToMergeInto.credentials, null, null),
      );
      return LocalVaultFile(files, persistedTime, persistedTime, vault.uuid, null, null);
    } finally {
      // delete the autofill data no matter what, otherwise we'll be stuck in
      // a loop if a bug in autofill creates an invalid state.
      fileAutofill.deleteSync();
    }
  }
}
