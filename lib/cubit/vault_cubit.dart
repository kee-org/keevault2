import 'dart:collection';
import 'dart:typed_data';
import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_persistent_queue/flutter_persistent_queue.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/config/platform.dart';
import 'package:keevault/config/synced_app_settings.dart';
import 'package:keevault/cubit/entry_cubit.dart';
import 'package:keevault/cubit/generator_profiles_cubit.dart';
import 'package:keevault/extension_methods.dart';
import 'package:keevault/local_vault_repository.dart';
import 'package:keevault/locked_vault_file.dart';
import 'package:keevault/password_mismatch_recovery_situation.dart';
import 'package:keevault/password_strength.dart';
import 'package:keevault/credentials/quick_unlocker.dart';
import 'package:keevault/vault_backend/exceptions.dart';
import 'package:keevault/vault_backend/user.dart';
import '../async_helpers.dart';
import '../credentials/credential_lookup_result.dart';
import '../remote_vault_repository.dart';
import '../user_repository.dart';
import '../vault_file.dart';
import '../logging/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keevault/generated/l10n.dart';

import 'account_cubit.dart';
import 'autocomplete_cubit.dart';

part 'vault_state.dart';

class VaultCubit extends Cubit<VaultState> {
  final RemoteVaultRepository _remoteVaultRepo;
  final LocalVaultRepository _localVaultRepo;
  final UserRepository _userRepo;
  final QuickUnlocker _qu;
  final EntryCubit _entryCubit;
  final GeneratorProfilesCubit _generatorProfilesCubit;
  final AutocompleteCubit _autocompleteCubit;
  PersistentQueue? _persistentQueueAfAssociations;
  final bool Function() isAutofilling;
  bool autoFillMergeAttemptDue = true;
  final AccountCubit _accountCubit;

  VaultCubit(
    this._userRepo,
    this._qu,
    this._remoteVaultRepo,
    this._localVaultRepo,
    this._entryCubit,
    this.isAutofilling,
    this._generatorProfilesCubit,
    this._accountCubit,
    this._autocompleteCubit,
  ) : super(const VaultInitial());

  LocalVaultFile? get currentVaultFile {
    final VaultState currentState = state;
    if (currentState is VaultLoaded) {
      return currentState.vault;
    } else {
      return null;
    }
  }

  void initAutofillPersistentQueue(String uuid) {
    if (KeeVaultPlatform.isAndroid) {
      _persistentQueueAfAssociations = PersistentQueue(
        'keevaultpendingautofillassociations-$uuid',
        flushAt: 1000000,
        flushTimeout: const Duration(days: 10000),
      );
    }
  }

  void _updateAutocompleteUsernames(KdbxFile kdbxFile) {
    _autocompleteCubit.setUsernames(kdbxFile.allUsernames);
  }

  Future<void> _applyAutofillPersistentQueueItems(List<dynamic> list, LinkedHashMap<String, KdbxEntry> entries) async {
    for (var item in list) {
      final entryUuid = item['entry'];
      final domain = item['domain'];
      final scheme = item['scheme'];
      final appId = item['appId'];
      final entry = entries['$entryUuid'];
      if (entry == null) continue;

      if (domain?.isNotEmpty ?? false) {
        entry.addAutofillUrl(domain, scheme);
      } else if (appId?.isNotEmpty ?? false) {
        entry.addAndroidPackageName(appId);
      }
    }
  }

  Future<void> addAutofillPersistentQueueItem(dynamic item) async {
    if (_persistentQueueAfAssociations != null) {
      await _persistentQueueAfAssociations!.ready;
      await _persistentQueueAfAssociations!.push(item);
    }
  }

  Future<KdbxFile> applyAndConsumePendingAutofillAssociations(KdbxFile kdbxFile) async {
    if (_persistentQueueAfAssociations != null) {
      // We need to reinitialise the queue because changes may have been made by the autofill
      // operation in another thread.
      await _persistentQueueAfAssociations!.reinitialise();
      await _persistentQueueAfAssociations!.ready;
      await _persistentQueueAfAssociations!.flush((List<dynamic> list) async {
        l.i('${list.length} pending autofill associations found');
        await _applyAutofillPersistentQueueItems(list, kdbxFile.body.rootGroup.getAllEntries());
      });
    }
    return kdbxFile;
  }

  // We may have no password, etc. but must at least know which user we are working with
  Future<void> startupFreeMode(String? overridePassword) async {
    if (state is! VaultInitial) return;

    l.d('starting vault cubit (free mode)');
    Credentials? creds;

    Future<CredentialLookupResult> credentialProvider() async {
      return await loadLocalUserQuickUnlockFileCredentialsIfNotSupplied(creds);
    }

    if (overridePassword != null) {
      l.d('we have a password explicitly supplied');
      final protectedValue = ProtectedValue.fromString(overridePassword);
      creds = Credentials(protectedValue);
    }

    LocalVaultFile? localFile;

    try {
      l.d('attempting to open a local vault');
      emit(const VaultOpening());
      localFile = await _localVaultRepo.loadFreeUser(credentialProvider);
    } on KeeLoginRequiredException {
      // User supplied no password and none was found in QU (or QU failed for some reason)
      emit(const VaultLocalFileCredentialsRequired('no message', false));
      return;
    } on KdbxInvalidKeyException {
      // User entered incorrect password, possibly because local KDBX file was changed without QU data being changed (maybe due to a system crash recently)
      emit(VaultLocalFileCredentialsRequired('no message', overridePassword != null));
      return;
    } on Exception {
      emitError('Kee Vault startup failed. Could not load your local vault from your device.', forceNotLoaded: true);
      return;
    }
    if (localFile == null) {
      emitError('Kee Vault startup failed. Could not load your local vault from your device.', forceNotLoaded: true);
      return;
    } else {
      await emitVaultLoaded(localFile, null, safe: false);
    }
    l.d('vault cubit (free mode) started');
  }

  // We may have no password, etc. but must at least know which user we are working with
  Future<void> startup(User user, String? overridePassword) async {
    if (state is! VaultInitial) return;

    l.d('starting vault cubit');
    Credentials? creds;

    Future<CredentialLookupResult> credentialProvider() async {
      return await loadQuickUnlockFileCredentialsIfNotSupplied(creds, user);
    }

    if (overridePassword != null) {
      l.d('we have a password explicitly supplied');
      final protectedValue = ProtectedValue.fromString(overridePassword);
      final key = protectedValue.hash;
      await user.attachKey(key);
      creds = Credentials(protectedValue);
    }

    LocalVaultFile? localFile;
    bool importRequired = false;

    try {
      l.d('attempting to open a local vault');
      emit(const VaultOpening());

      final storageIoResult = await waitConcurrently<LocalVaultFile?, bool>(
        _localVaultRepo.load(user, credentialProvider),
        _localVaultRepo.localFreeExists(),
      );
      localFile = storageIoResult.item1;
      importRequired = await manageLocalFreeFileImport(storageIoResult.item2);
    } on KeeLoginRequiredException {
      // User supplied no password and none was found in QU (or QU failed for some reason)
      emit(const VaultLocalFileCredentialsRequired('no message', false));
      return;
    } on KdbxInvalidKeyException {
      // User entered incorrect password, possibly because local KDBX file was changed without QU data being changed (maybe due to a system crash recently)
      emit(VaultLocalFileCredentialsRequired('no message', overridePassword != null));
      return;
    } on Exception {
      emitError('Kee Vault startup failed. Could not load your local vault from your device.', forceNotLoaded: true);
      return;
    }
    if (localFile == null) {
      // This should only happen when we have been supplied a new signin password by the user but
      // rarely might happen if app crashed or network failed during initial download (for example)
      l.d('local vault not found');

      // If we have no supplied credentials, we can try from QU
      if (creds == null) {
        await _userRepo.setQuickUnlockUser(user);
        creds = await _qu.loadQuickUnlockFileCredentials();
      }

      // If we still have no known credentials, we can't unlock the remote database so must ask user for a remote password
      if (creds == null) {
        emit(const VaultDownloadCredentialsRequired('no message', false));
        return;
      }
      // We end up testing for local free vault on disk a 2nd time but not a high
      // priority to improve this performance because this branch executes very rarely.
      await download(user, kdbxCredentials: creds);
      // Exceptions are handled within download() or so serious that we can't do anything meaningful with them.
    } else {
      try {
        l.d('local vault found; looking for any update pending from the last time we were running');
        LocalVaultFile? loadedFile;
        final pendingUpdateFile = await _localVaultRepo.loadStagedUpdate(
          user,
          credentialProvider,
          localFile.persistedAt,
        );
        if (pendingUpdateFile != null) {
          l.d('found a pending update from remote for local file');
          final newFile = await update(user, localFile, pendingUpdateFile);
          if (newFile != null) {
            loadedFile = newFile;
          }
        } else {
          l.d('no update for local file is pending');
          loadedFile = localFile;
        }
        if (loadedFile == null) {
          return;
        }
        if (importRequired) {
          l.i('opened; import is required');
          final localFreeFile = await _localVaultRepo.loadFreeUserLocked();
          if (localFreeFile == null) {
            emitError(
              'Import of existing data failed. We found some but then it went away while we were processing it. Please check for storage failures on your device and restore from a backup if necessary. Restart this app when you have checked this.',
              forceNotLoaded: true,
            );
            return;
          }
          await importKdbx(loadedFile, localFreeFile, loadedFile.files.current.credentials, false, false);
          return;
        } else {
          await emitVaultLoaded(loadedFile, user, safe: false);
        }
      } on KdbxInvalidKeyException {
        // This can happen if the remote file has new credentials. We'll have to try again with different user supplied passwords for the local and remote files.
        emit(VaultRemoteFileCredentialsRequired(localFile, false));
        return;
      } on Exception catch (e, stack) {
        l.e("Kee Vault startup failed. Couldn't apply a pending change to your local vault: $e \n\n stack: $stack");
        emitError(
          "Kee Vault startup failed. Sorry, we couldn't apply a pending change to your local vault for some unexpected reason. Please navigate to the Help menu item and then Share your application logs with us so that we can discuss and advise what to do next. If you have your Kee Vault on other devices, we recommend disconnecting them from the internet and exporting your vault to a KDBX file now, especially if you do not have a recent backup. We are likely to be able to restore all or most of your data but this may take a significant amount of time so the sooner you contact us to explain the details of what may have triggered the problem and share the error logs with us, the sooner we'll get you back up and running.",
          forceNotLoaded: true,
        );
        return;
      }
    }
    l.d('vault cubit started');
  }

  Future<bool> hasPendingUpdateFile(User user) async {
    return await _localVaultRepo.hasStagedUpdate(user);
  }

  Future<void> deletePendingUpdateFile(User user) async {
    return await _localVaultRepo.removeStagedUpdate(user);
  }

  Future<void> emitVaultLoaded(
    LocalVaultFile vault,
    User? user, {
    bool immediateRemoteRefresh = true,
    required bool safe,
  }) async {
    _updateAutocompleteUsernames(vault.files.current);
    if (user?.subscriptionStatus == AccountSubscriptionStatus.expired ||
        user?.subscriptionStatus == AccountSubscriptionStatus.freeTrialAvailable) {
      return;
    }
    final rootGroup = vault.files.current.body.rootGroup;
    initAutofillPersistentQueue(rootGroup.uuid.uuidUrlSafe);
    if (isAutofilling()) {
      // Make sure that any previous autofill operations have their adjustments
      // applied before we present the entry list or entry saving interface to the user.
      await _persistentQueueAfAssociations?.ready;
      final pendingItems = (await _persistentQueueAfAssociations?.toList());
      if (pendingItems != null) {
        l.i('${pendingItems.length} pending autofill associations found');
        // It's OK that we only apply these to the current vault file (and not the remoteMergeTarget)
        // because we don't perform any remote update operations while in autofill mode.
        await _applyAutofillPersistentQueueItems(pendingItems, rootGroup.getAllEntries());
      }
    }
    if (safe) {
      final emitted = safeEmitLoaded(vault);
      if (!emitted) return;
    } else {
      emit(VaultLoaded(vault));
    }
    await SyncedAppSettings.import(_generatorProfilesCubit, vault.files.current.body.meta.keeVaultSettings);
    if (user != null && !isAutofilling() && immediateRemoteRefresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await refresh(user);
      });
    }
  }

  emitError(String message, {bool toast = false, bool forceNotLoaded = false}) {
    if (!forceNotLoaded && state is VaultLoaded) {
      emit(VaultBackgroundError((state as VaultLoaded).vault, message, toast));
    } else {
      emit(VaultError(message));
    }
  }

  emitKeeMissingPrimaryDBExceptionError() {
    const message =
        "Couldn't find your Kee Vault. Probably there is an incomplete account reset in progress. Please close this app and sign in to Kee Vault using a different device or your web browser. Once you can see your vault there, save it, sign out and then open this app again and everything should be working.";
    l.e(message);
    emitError(message, forceNotLoaded: true);
  }

  Future<void> changeLocalPasswordFromRemote(User user, String pass) async {
    if (state is! VaultRemoteFileCredentialsRequired) return;
    final vState = state as VaultRemoteFileCredentialsRequired;
    l.d('trying user-supplied new master password to access updated remote KDBX file');
    Credentials? creds;

    final protectedValue = ProtectedValue.fromString(pass);
    creds = Credentials(protectedValue);
    LocalVaultFile? newFile;

    try {
      l.d('loading the pending update locked with new master password');
      final pendingUpdateFile = await _localVaultRepo.loadStagedUpdate(user, () async {
        return CredentialLookupResult(credentials: creds, quStatus: QUStatus.unknown);
      }, vState.vaultLocal.persistedAt);
      if (pendingUpdateFile != null) {
        l.d('applying pending update from remote to local file');
        newFile = await update(user, vState.vaultLocal, pendingUpdateFile);
      } else {
        l.w(
          'pending update disappeared while user was entering password. No idea how this can happen but nothing we can do now except move on.',
        );
        newFile = vState.vaultLocal;
      }
    } on KdbxInvalidKeyException {
      // User must have got the new password wrong
      emit(VaultRemoteFileCredentialsRequired(vState.vaultLocal, true));
      return;
    } on Exception {
      emitError('Failed to update password from remote KDBX file', forceNotLoaded: true);
      return;
    }

    if (newFile == null) {
      l.e(
        'Unexpected error applying new password from remote. This app instance may now be broken but we'
        'll try just sticking with the current version just in case that works.',
      );
      newFile = vState.vaultLocal;
    }
    l.d('applying user-supplied new master password to account User');
    final key = protectedValue.hash;
    await user.attachKey(key);
    l.d('Updating QU with newly successful password');
    final requireFullPasswordPeriod =
        int.tryParse(Settings.getValue<String>('requireFullPasswordPeriod') ?? '60') ?? 60;
    l.d('Will require a full password to be entered every $requireFullPasswordPeriod days');
    await _qu.saveQuickUnlockUserPassKey(user.passKey);
    await _qu.saveQuickUnlockFileCredentials(
      creds,
      DateTime.now().add(Duration(days: requireFullPasswordPeriod)).millisecondsSinceEpoch,
      await newFile.files.current.kdfCacheKey,
    );

    await emitVaultLoaded(newFile, user, safe: false);
  }

  Future<void> download(
    User user, {
    StrengthAssessedCredentials? credentialsWithStrength,
    Credentials? kdbxCredentials,
  }) async {
    try {
      l.d('downloading remote file');
      emit(const VaultDownloading());
      LockedVaultFile downloadedFile;
      kdbxCredentials ??= credentialsWithStrength?.credentials;
      try {
        downloadedFile = await _remoteVaultRepo.downloadWithoutEtagCheck(user, kdbxCredentials);
      } on KeeMissingPrimaryDBException {
        // auto-recover by creating a new Kdbx file
        // We can't do this if we didn't have a copy of the user's master password
        // for strength calculation so we would have to ask them to type it again
        if (credentialsWithStrength == null) {
          emit(const VaultDownloadCredentialsRequired('no message', false));
          return;
        }
        try {
          downloadedFile = await _remoteVaultRepo.create(user, credentialsWithStrength);
        } on Exception {
          emit(
            const VaultError(
              'We were unable to complete the setup of your Kee Vault. Please close the app and try again later.',
            ),
          );
          return;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      // These can be null if the auto-recovery from a missing primary vault file path was followed
      // above but normally they will be set
      if (downloadedFile.etag != null) {
        await prefs.setString('user.${user.email}.lastRemoteEtag', downloadedFile.etag!);
      }
      if (downloadedFile.versionId != null) {
        await prefs.setString('user.${user.email}.lastRemoteVersionId', downloadedFile.versionId!);
      }
      l.d('creating new local file from downloaded file');
      final storageIoResult = await waitConcurrently<void, bool>(
        _localVaultRepo.create(user, downloadedFile),
        _localVaultRepo.localFreeExists(),
      );
      final importRequired = await manageLocalFreeFileImport(storageIoResult.item2);
      l.d('opening (unlocking) the new local file');
      emit(const VaultOpening());
      final vaultFile = await LocalVaultFile.unlock(downloadedFile);
      await _localVaultRepo.createQUCredentials(downloadedFile.credentials!, vaultFile.files.current);

      if (importRequired) {
        l.i('opened; import is required');
        final localFreeFile = await _localVaultRepo.loadFreeUserLocked();
        if (localFreeFile == null) {
          emitError(
            'Import of existing data failed. We found some but then it went away while we were processing it. Please check for storage failures on your device and restore from a backup if necessary. Restart this app when you have checked this.',
            forceNotLoaded: true,
          );
          return;
        }
        await importKdbx(vaultFile, localFreeFile, kdbxCredentials, false, false);
      } else {
        l.d('opened');
        await emitVaultLoaded(vaultFile, user, immediateRemoteRefresh: false, safe: false);
      }
    } on KeeLoginRequiredException {
      emit(const VaultDownloadCredentialsRequired('no message', false));
    } on KdbxInvalidKeyException catch (e, s) {
      throw KeeException(
        'Remote KDBX not in sync with account password. Please report this to Kee Vault support. While waiting for help, you may be able to resolve the problem by using a different device to change your Kee Vault password again.',
        e,
        s,
      );
    } on KeeLoginFailedMITMException {
      rethrow;
    } on KeeServiceTransportException catch (e) {
      final message = e.handle('Download error');
      emitError(message, forceNotLoaded: true);
    } on KeeMissingPrimaryDBException {
      emitKeeMissingPrimaryDBExceptionError();
      return;
    } on KeeSubscriptionExpiredException {
      emitError(S.current.expiredWhileSignedIn, forceNotLoaded: true);
      return;
    } on KeeAccountUnverifiedException {
      _accountCubit.emailUnverified();
      return;
    } on Exception catch (e) {
      final message = 'Download error. There may be more information in this message: $e';
      l.e(message);
      emitError(message, forceNotLoaded: true);
    }
  }

  Future<bool> openLocal(User? user, ProtectedValue? suppliedPassword) async {
    try {
      l.d('opening local vault');
      emit(const VaultOpening());
      final suppliedCreds = suppliedPassword != null ? Credentials(suppliedPassword) : null;

      Future<CredentialLookupResult> credentialProvider() async {
        if (user == null) {
          return await loadLocalUserQuickUnlockFileCredentialsIfNotSupplied(suppliedCreds);
        }
        return await loadQuickUnlockFileCredentialsIfNotSupplied(suppliedCreds, user);
      }

      LocalVaultFile? file;
      bool importRequired = false;

      if (user == null) {
        file = await _localVaultRepo.loadFreeUser(credentialProvider);
      } else {
        final storageIoResult = await waitConcurrently<LocalVaultFile?, bool>(
          _localVaultRepo.load(user, credentialProvider),
          _localVaultRepo.localFreeExists(),
        );
        file = storageIoResult.item1;
        importRequired = await manageLocalFreeFileImport(storageIoResult.item2);
      }
      if (file == null) {
        throw Exception(
          'Probably the file has been locally deleted due to local storage capacity or reliability problems.',
        );
      }
      if (importRequired) {
        l.i('opened; import is required');
        final localFreeFile = await _localVaultRepo.loadFreeUserLocked();
        if (localFreeFile == null) {
          emitError(
            'Import of existing data failed. We found some but then it went away while we were processing it. Please check for storage failures on your device and restore from a backup if necessary. Restart this app when you have checked this.',
            forceNotLoaded: true,
          );
          return false;
        }
        await importKdbx(file, localFreeFile, file.files.current.credentials, false, false);
        return false;
      }
      final requireFullPasswordPeriod =
          int.tryParse(Settings.getValue<String>('requireFullPasswordPeriod') ?? '60') ?? 60;
      l.d('Will require a full password to be entered every $requireFullPasswordPeriod days');
      if (user != null && suppliedPassword != null) {
        await user.attachKey(suppliedPassword.hash);
        await _qu.saveQuickUnlockUserPassKey(user.passKey);
        await _qu.saveQuickUnlockFileCredentials(
          suppliedCreds,
          DateTime.now().add(Duration(days: requireFullPasswordPeriod)).millisecondsSinceEpoch,
          await file.files.current.kdfCacheKey,
        );
      } else if (suppliedPassword != null) {
        await _qu.saveQuickUnlockFileCredentials(
          suppliedCreds,
          DateTime.now().add(Duration(days: requireFullPasswordPeriod)).millisecondsSinceEpoch,
          await file.files.current.kdfCacheKey,
        );
      }
      l.d('local vault opened');
      await emitVaultLoaded(file, user, safe: false);
      return true;
    } on KeeLoginRequiredException catch (e) {
      emit(
        VaultLocalFileCredentialsRequired(
          'no message',
          suppliedPassword != null,
          quStatus: e.quStatus ?? QUStatus.unknown,
        ),
      );
    } on KdbxInvalidKeyException {
      emit(VaultLocalFileCredentialsRequired('KDBX key incorrect', suppliedPassword != null));
    } on Exception catch (e) {
      emitError('Failed to open local vault. There may be more information in this message: $e', forceNotLoaded: true);
    }
    return false;
  }

  Future<CredentialLookupResult> loadQuickUnlockFileCredentialsIfNotSupplied(
    Credentials? suppliedCreds,
    User user,
  ) async {
    if (suppliedCreds != null) {
      return CredentialLookupResult(credentials: suppliedCreds, quStatus: QUStatus.unknown);
    } else {
      final quStatus = await _userRepo.setQuickUnlockUser(user);
      final creds = await _qu
          .loadQuickUnlockFileCredentials(); //TODO:f: gate on credsAvailable as per local user to reduce log noise?
      return CredentialLookupResult(credentials: creds, quStatus: quStatus);
    }
  }

  Future<CredentialLookupResult> loadLocalUserQuickUnlockFileCredentialsIfNotSupplied(
    Credentials? suppliedCreds,
  ) async {
    if (suppliedCreds != null) {
      return CredentialLookupResult(credentials: suppliedCreds, quStatus: QUStatus.unknown);
    }
    final quStatus = await _qu.initialiseForUser(_qu.localUserMagicString, false);
    final creds = quStatus == QUStatus.credsAvailable ? await _qu.loadQuickUnlockFileCredentials() : null;
    return CredentialLookupResult(credentials: creds, quStatus: quStatus);
  }

  /// We can't know in advance if the recovery should be for situation 4 since we can only try to unlock the remote file once the user has supplied a valid password for authentication.
  /// Our understanding of which situation we need to recover from can change as we proceed through the various attempts to recover.
  Future<void> refresh(
    User user, {
    String? overridePasswordRemote,
    PasswordMismatchRecoverySituation recovery = PasswordMismatchRecoverySituation.none,
  }) async {
    VaultState s = state;

    if (s is VaultLoaded) {
      if (s is VaultSaving && s.remotely) {
        l.i('refresh called during an ongoing upload. Will not refresh now.');
        return;
      }
      if (s is VaultRefreshing) {
        l.i('refresh called during an ongoing refresh operation. Will not start a new refresh now.');
        return;
      }
      if (s is VaultRefreshCredentialsRequired && recovery == PasswordMismatchRecoverySituation.none) {
        l.i('refresh called during an ongoing refresh credentials repair operation. Will not refresh now.');
        return;
      }
      if (s is VaultUploadCredentialsRequired && recovery == PasswordMismatchRecoverySituation.none) {
        l.i('refresh called during an ongoing upload credentials repair operation. Will not refresh now.');
        return;
      }
      if (s is VaultChangingPassword) {
        l.i('refresh called during a password change. Will not refresh now.');
        return;
      }

      Credentials credsLocal = s.vault.files.current.credentials;
      Credentials credsRemote = credsLocal;
      StrengthAssessedCredentials? credentialsOverrideWithStrength;

      if (recovery != PasswordMismatchRecoverySituation.none && overridePasswordRemote != null) {
        l.d('we will attempt a recovery from a mismatched password');
        final protectedValue = ProtectedValue.fromString(overridePasswordRemote);
        credentialsOverrideWithStrength = StrengthAssessedCredentials(protectedValue, user.emailParts);
        if (recovery == PasswordMismatchRecoverySituation.remoteUserDiffers) {
          l.d('we have a service password explicitly supplied');

          final key = protectedValue.hash;
          await user.attachKey(key);
        }
        if (recovery == PasswordMismatchRecoverySituation.remoteFileDiffers) {
          l.d('we have a KDBX password explicitly supplied');
          credsRemote = credentialsOverrideWithStrength.credentials;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      bool uploadPending = false;
      try {
        uploadPending = prefs.getBool('user.${user.email}.uploadPending') ?? false;
      } on Exception {
        // no action required
      }

      if (uploadPending) {
        l.i(
          'Found pending upload marker. Previous upload attempt must have been aborted by network or platform (e.g. app was closed)',
        );
        // We'll upload the latest local changes instead. Since that will merge in any recent remote
        // changes, the end result will be consistent and thus there's no need to continue with this refresh function.
        // Pending merge from autofill will thus be deferred until the next vault load or device task switch restoration
        await upload(user, s.vault, overridePasswordRemote: overridePasswordRemote, recovery: recovery);
        return;
      }

      late LockedVaultFile lockedFile;
      LocalVaultFile? updatedLocalFile;

      try {
        // This can fail if the remote file has new credentials (or the account,
        // even if no new file version is available). We would then emit a
        // state to trigger user being notified that they must save ASAP (this will then trigger
        // an upload, potentially deferred if network then drops out, which will in turn detect
        //that a new remote version is available and download it for merging when the user supplies
        // the new password); unless file is not dirty at the moment, in which case user
        // can enter new password immediately
        l.d('refreshing current vault from its remote source');
        emit(VaultRefreshing(s.vault));
        String? lastRemoteEtag;
        try {
          lastRemoteEtag = prefs.getString('user.${user.email}.lastRemoteEtag');
        } on Exception {
          // no action required
        }

        l.d('lastRemoteEtag: $lastRemoteEtag');
        final tempLockedFile = await _remoteVaultRepo.download(user, credsRemote, lastRemoteEtag);

        if (recovery == PasswordMismatchRecoverySituation.remoteUserDiffers) {
          // If we're in state 3 (or 4) this should get us into 2; User may need to
          // enter the other password again when the next refresh operation happens
          // (assuming we found no change to the kdbx to download this time) but
          // they'll get the problem resolved eventually.

          l.d('Updating QU with newly successful service password');
          await _qu.saveQuickUnlockUserPassKey(user.passKey);

          // If we're in state 2,3 or 4 we need to update the local file password.
          // In state 1, we don't, but I don't think we can definitively know if
          // we are in that situation so we do it anyway, even if it is essentially a NOOP

          l.d('Updating local kdbx with same password that just worked for remote user authentication.');
          // typically this is the right thing to do. Maybe rare bugs would mean we should
          // be treating the local KDBX file password as the user's chosen password but we
          // have to pick one and the impact of getting it wrong is only that the user
          // would have to use what they consider to be their old password, at least until
          // they change it to their new password successfully after this recovery is complete.

          updatedLocalFile = LocalVaultFile(
            await s.vault.files.copyWithNewCredentials(credentialsOverrideWithStrength!),
            s.vault.lastOpenedAt,
            s.vault.persistedAt,
            s.vault.uuid,
            s.vault.etag,
            s.vault.versionId,
          );

          // May be some cases where this is not necessary. Probably all are edge cases
          // but maybe could try harder to identify times we can safely skip this step
          // without disabling biometrics for the user.
          l.d('Updating QU with newly modified local KDBX password');
          final requireFullPasswordPeriod =
              int.tryParse(Settings.getValue<String>('requireFullPasswordPeriod') ?? '60') ?? 60;
          l.d('Will require a full password to be entered every $requireFullPasswordPeriod days');
          await _qu.saveQuickUnlockFileCredentials(
            credentialsOverrideWithStrength.credentials,
            DateTime.now().add(Duration(days: requireFullPasswordPeriod)).millisecondsSinceEpoch,
            await updatedLocalFile.files.current.kdfCacheKey,
          );

          if (tempLockedFile == null) {
            l.d("Latest remote file not changed so didn't download it");
            safeEmitLoaded(updatedLocalFile);

            // save and upload LK to become the RK.
            await save(user);
            if (KeeVaultPlatform.isIOS) {
              await autofillMerge(user, onlyIfAttemptAlreadyDue: true);
            }
            return;
          }
          // If there was a change that we downloaded, we will try later to merge it with
          // the newly edited local KDBX file that has the user's new password.
        } else if (tempLockedFile == null) {
          // We're not in a recovery mode that requires us to take account of a new user
          // account password and we have found no changes to the remote file. This is
          // the case almost all of the times that we execute this refresh function.
          l.d("Latest remote file not changed so didn't download it");
          safeEmitLoaded(s.vault);
          if (KeeVaultPlatform.isIOS) {
            await autofillMerge(user, onlyIfAttemptAlreadyDue: true);
          }
          return;
        }
        lockedFile = tempLockedFile;
      } on KdbxInvalidKeyException {
        // Pretty sure this can't happen - download doesn't actually attempt to unlock
        // the downloaded file and autofillMerge handles the exception itself.
        handleRefreshAuthError(s.vault, recovery: PasswordMismatchRecoverySituation.remoteFileDiffers);
        return;
      } on KeeLoginRequiredException {
        handleRefreshAuthError(s.vault, recovery: PasswordMismatchRecoverySituation.remoteUserDiffers);
        return;
      } on KeeSubscriptionExpiredException {
        emitError(
          '${S.current.expiredWhileSignedIn} Unfortunately if you were in the middle of making a change, you will have to make it again when your subscription has been re-activated so we recommend doing so quickly while it is still fresh in your mind.',
          forceNotLoaded: true,
        );
        return;
      } on KeeAccountUnverifiedException {
        handleRefreshEmailVerificationError();
        return;
      } on KeeLoginFailedMITMException {
        rethrow;
      } on KeeServiceTransportException catch (e) {
        final message = e.handle('Background refresh error');
        emitError(message);
        if (KeeVaultPlatform.isIOS) {
          await autofillMerge(user, onlyIfAttemptAlreadyDue: true);
        }
        return;
      } on KeeMissingPrimaryDBException {
        emitKeeMissingPrimaryDBExceptionError();
        return;
      } on Exception catch (e) {
        final message =
            'Background refresh error. Check your internet connection. There may be more information in this message: $e';
        l.e(message);
        emitError(message);
        if (KeeVaultPlatform.isIOS) {
          await autofillMerge(user, onlyIfAttemptAlreadyDue: true);
        }
        return;
      }
      try {
        await _localVaultRepo.stageUpdate(user, lockedFile);
        RemoteVaultFile file;
        Credentials? successfulCredentials;
        try {
          file = await RemoteVaultFile.unlock(lockedFile);
          successfulCredentials = lockedFile.credentials;
          // It is typical to reach this point successfully. Situations where we fail to
          // reach here would include recovery cases 1 (where we have used the remote
          // user account password to try to unlock the remote KDBX file, since we
          // first assume that we are in situation 3) and 2 (where only the remote
          // file password is different from the one the user has supplied to get this far)
        } on KdbxInvalidKeyException {
          // Try again with the other password or let the higher catch statement handle this

          // Usually the remote and local creds will match and the reason we got here
          // is that the user entered an incorrect password as part of the mismatched
          // password recovery process.

          // We know we tried the remote creds first so if they are different to local, we should try those too.
          if (credsRemote != credsLocal) {
            final lockedFileWithLocalCreds = lockedFile.copyWith(credentials: credsLocal);
            file = await RemoteVaultFile.unlock(lockedFileWithLocalCreds);
            successfulCredentials = lockedFileWithLocalCreds.credentials;
          } else {
            rethrow;
          }
        }

        // updatedLocalFile must be null if we are in remotefilediffers mode
        if (recovery == PasswordMismatchRecoverySituation.remoteFileDiffers && successfulCredentials != null) {
          l.d('Updating QU with newly successful KDBX password');
          final requireFullPasswordPeriod =
              int.tryParse(Settings.getValue<String>('requireFullPasswordPeriod') ?? '60') ?? 60;
          l.d('Will require a full password to be entered every $requireFullPasswordPeriod days');
          await _qu.saveQuickUnlockFileCredentials(
            successfulCredentials,
            DateTime.now().add(Duration(days: requireFullPasswordPeriod)).millisecondsSinceEpoch,
            await (updatedLocalFile ?? s.vault).files.current.kdfCacheKey,
          );
        }

        await prefs.setString('user.${user.email}.lastRemoteEtag', file.etag!);
        await prefs.setString('user.${user.email}.lastRemoteVersionId', file.versionId!);
        emit(VaultUpdatingLocalFromRemote(updatedLocalFile ?? s.vault));
        final newFile = await update(user, updatedLocalFile ?? s.vault, file);
        if (newFile != null) {
          await emitVaultLoaded(newFile, user, immediateRemoteRefresh: false, safe: true);
        }
      } on KdbxInvalidKeyException {
        // This is the first point we might be trying to unlock the remote file. If we reach
        // this point we have tried both the user's local and remote passwords (if they have
        // been prompted for a 2nd password for recovery purposes). They may have just entered
        // the 2nd password incorrectly. Or this may be the first time we are discovering that
        // their 1st password (local) can no longer open their remote file. We do know that it
        // can authenticate them though.
        // So we know we are in situation 2 if we tried the same password everywhere, or
        // situation 2, 3 or 4 if we tried a separate remote file password already (2 if the
        // user just put in the wrong password).

        l.w('Remote file failed to unlock using supplied password(s).');
        // We've staged the update so startup can handle trying to fix the problem later.
        // etags and version ids are lost when staging an update. Thus, when comparing for latest
        // etag during the next refresh or upload operation, we will re-download the update
        // and perform a merge. This should be a NOOP but is inefficient.
        handleRefreshAuthError(
          updatedLocalFile ?? s.vault,
          recovery: PasswordMismatchRecoverySituation.remoteFileDiffers,
        );
      } on Exception catch (e, stack) {
        l.e(
          "Kee Vault failed to apply a change to your local vault for some unexpected reason or hardware fault. Please Share these application logs with us so that we can discuss and advise what to do next. If you have your Kee Vault on other devices, we recommend disconnecting them from the internet and exporting your vault to a KDBX file now, especially if you do not have a recent backup. We are likely to be able to restore all or most of your data but this may take a significant amount of time so the sooner you contact us to explain the details of what may have triggered the problem and share the error logs with us, the sooner we'll get you back up and running. Background refresh error: $e \n\n stack: $stack",
        );
        emitError(
          'Background refresh error. Check your device has enough storage space. Otherwise, this may indicate a faulty operating system or hardware. Export your Vault now just in case. Then inspect extra error information in the Menu > Help > Logs.',
          toast: true,
        );
        return;
      }
    } else {
      if (s is VaultImported || s is VaultImportingCredentialsRequired) {
        l.d('refresh called during an import. Will not refresh now.');
        return;
      }
      l.w('Vault not loaded when refresh called');
    }
  }

  void handleRefreshAuthError(LocalVaultFile v, {required PasswordMismatchRecoverySituation recovery}) {
    bool entryBeingEdited = false;
    try {
      if (_entryCubit.state is EntryLoaded) {
        entryBeingEdited = true;
      }
    } catch (e) {
      // no action required
    }

    if (currentVaultFile == null || (!currentVaultFile!.files.current.isDirty && !entryBeingEdited)) {
      // Only emit if we aren't already showing the password field to the user
      if (state is! VaultRefreshCredentialsRequired) {
        emit(VaultRefreshCredentialsRequired(v, 'no message', false, recovery));
      }
    } else {
      emitError(
        'Please save your vault now and/or kill and restart the app (an authorisation error has occurred while refreshing, possibly because of a recent password or subscription change)',
        toast: true,
      );
    }
  }

  void handleRefreshEmailVerificationError() {
    bool entryBeingEdited = false;
    try {
      if (_entryCubit.state is EntryLoaded) {
        entryBeingEdited = true;
      }
    } catch (e) {
      // no action required
    }

    if (currentVaultFile == null || (!currentVaultFile!.files.current.isDirty && !entryBeingEdited)) {
      _accountCubit.emailUnverified();
      signout();
    } else {
      emitError(
        'Your email address has not yet been verified. Please check your emails and do that now. If you want us to resend the email, save your vault then sign out and back in again.',
        toast: true,
      );
    }
  }

  void handleUploadAuthError(LocalVaultFile v, bool local, PasswordMismatchRecoverySituation recovery) {
    bool entryBeingEdited = false;
    try {
      if (_entryCubit.state is EntryLoaded) {
        entryBeingEdited = true;
      }
    } catch (e) {
      // no action required
    }

    if (currentVaultFile == null || (!currentVaultFile!.files.current.isDirty && !entryBeingEdited)) {
      emit(VaultUploadCredentialsRequired(v, local, false, false, recovery));
    } else {
      emitError(
        'Please save your vault now and/or kill and restart the app (an authorisation error has occurred while uploading, possibly because of a recent password or subscription change)',
        toast: true,
      );
    }
  }

  Future<void> applyPendingChangesIfSafe(User? user) async {
    if (currentVaultFile != null &&
        currentVaultFile!.files.hasPendingChanges &&
        !currentVaultFile!.files.current.isDirty) {
      final newCurrent = await currentVaultFile!.files.pending;
      if (newCurrent != null) {
        await emitVaultLoaded(
          LocalVaultFile(
            currentVaultFile!.files.copyWithAppliedPendingUpdate(newCurrent),
            currentVaultFile!.lastOpenedAt,
            currentVaultFile!.persistedAt,
            currentVaultFile!.uuid,
            currentVaultFile!.etag,
            currentVaultFile!.versionId,
          ),
          user,
          immediateRemoteRefresh: false,
          safe: true,
        );
      }
    }
  }

  Future<void> ensureRemoteCreated(User user, String? password) async {
    if (password == null) {
      l.d(
        "skipping creation of new remote and local vault since we don't know the password. User needs to enter it as part of next sign-in instead.",
      );
      return;
    }
    l.d('creating new remote and local vault');
    final credentialsWithStrength = StrengthAssessedCredentials(ProtectedValue.fromString(password), user.emailParts);
    LockedVaultFile lockedFile;
    try {
      lockedFile = await _remoteVaultRepo.create(user, credentialsWithStrength);
      l.d('new remote vault created');
    } on PrimaryKdbxAlreadyExistsException {
      // We'll just stop here and user's next sign in will have to reconcile any
      // potential differences between the remote file and local file (which may
      // not exist, or may be an outdated copy)
      l.i('Remote file already existed. This must be a recent re-subscription.');
      return;
    }
    await _localVaultRepo.create(user, lockedFile);
    final unlockedFile = await LocalVaultFile.unlock(lockedFile);
    l.d('new local vault created');
    final requireFullPasswordPeriod =
        int.tryParse(Settings.getValue<String>('requireFullPasswordPeriod') ?? '60') ?? 60;
    l.d('Will require a full password to be entered every $requireFullPasswordPeriod days');

    final quStatus = await _qu.initialiseForUser(user.id!, false);
    if (quStatus != QUStatus.unavailable) {
      await _qu.saveBothSecrets(
        user.passKey!,
        credentialsWithStrength.credentials,
        DateTime.now().add(Duration(days: requireFullPasswordPeriod)).millisecondsSinceEpoch,
        await unlockedFile.files.current.kdfCacheKey,
      );
      l.d('New user password stored in Quick Unlock');
    }
  }

  Future<void> create(String password) async {
    try {
      l.d('creating new local vault');
      emit(VaultCreating());
      final credentialsWithStrength = StrengthAssessedCredentials(ProtectedValue.fromString(password), []);
      final file = await _localVaultRepo.createNewKdbxOnStorage(credentialsWithStrength);
      l.d('new local vault created');
      final requireFullPasswordPeriod =
          int.tryParse(Settings.getValue<String>('requireFullPasswordPeriod') ?? '60') ?? 60;
      l.d('Will require a full password to be entered every $requireFullPasswordPeriod days');

      final quStatus = await _qu.initialiseForUser(_qu.localUserMagicString, false);
      if (quStatus != QUStatus.unavailable) {
        await _qu.saveQuickUnlockFileCredentials(
          credentialsWithStrength.credentials,
          DateTime.now().add(Duration(days: requireFullPasswordPeriod)).millisecondsSinceEpoch,
          await file.files.current.kdfCacheKey,
        );
        l.d('New free user password stored in Quick Unlock');
      }
      await emitVaultLoaded(file, null, safe: false);
    } on Exception catch (e) {
      emitError(
        'Failed to create new local vault file. Check that you have allowed all permissions and that you have some available storage space. There may be more information in this message: $e',
      );
      l.d('new local vault creation failed');
    }
  }

  Future<LocalVaultFile?> update(User user, LocalVaultFile local, RemoteVaultFile remote) async {
    try {
      l.d('updating local vault with one from a remote location');
      final updatedFile = await _updateLocalVaultFile(user, local, remote);
      if (updatedFile == null) {
        l.w('local vault update failed.');
        return local;
      }
      l.d('local vault updated');
      return updatedFile;
    } on Exception catch (e) {
      emitError('Local update/merge error. There may be more information in this message: $e', toast: true);
    }
    return null;
  }

  // currentVaultFile is always present, even if we haven't yet issued our first VaultLoaded state.
  Future<LocalVaultFile?> _updateLocalVaultFile(User user, LocalVaultFile local, RemoteVaultFile remote) async {
    final mergeResult = await merge(user, local, remote);
    if (mergeResult == null) {
      return null;
    }

    // Do this before checking if user has begun editing the current vault so we know
    // that the editing state is up to date when we build the updated LocalVaultFile instance. Might
    // be premature if they have done so but it will need to be done before they can next save anyway so meh.
    final newCurrent = await mergeResult.pending;

    bool entryBeingEdited = false;
    try {
      if (_entryCubit.state is EntryLoaded) {
        entryBeingEdited = true;
      }
    } catch (e) {
      // no action required
    }
    if (local.files.current.body.rootGroup.uuid != newCurrent!.body.rootGroup.uuid) {
      // We must immediately apply the pending update to the active vault the user is viewing,
      // even it leads to data loss (which would be in the old, already remotely deleted file)
      return LocalVaultFile(
        mergeResult.copyWithAppliedPendingUpdate(newCurrent),
        DateTime.now(),
        remote.persistedAt,
        remote.uuid,
        null,
        null,
      );
    } else if (currentVaultFile == null || (!currentVaultFile!.files.current.isDirty && !entryBeingEdited)) {
      // We can immediately apply the pending update to the active vault the user is viewing
      return LocalVaultFile(
        mergeResult.copyWithAppliedPendingUpdate(newCurrent),
        local.lastOpenedAt,
        local.persistedAt,
        local.uuid,
        local.etag,
        local.versionId,
      );
    } else {
      // Keep the active vault the same but ensure we track that we have a pending merge
      // result ready for further merging once the user has finished their current task
      return LocalVaultFile(
        mergeResult,
        local.lastOpenedAt,
        local.persistedAt,
        local.uuid,
        local.etag,
        local.versionId,
      );
    }
  }

  Future<VaultFileVersions?> merge(User user, LocalVaultFile first, RemoteVaultFile second) async {
    try {
      l.d('merging');
      // We don't think we need to notify the UI/user that merge is underway. If we change that in future, beware that merging can occur during a VaultLoaded or VaultOpening state.
      final mergeResult = await _localVaultRepo.merge(user, first, second);
      l.d('merged');
      return mergeResult;
    } on Exception catch (e) {
      final message = 'Remote merge error. There may be more information in this message: $e';
      l.e(message);
      emitError(message, toast: true);
    }
    return null;
  }

  void lock() async {
    _qu.lock();
    _persistentQueueAfAssociations = null;
    autoFillMergeAttemptDue = true;
    emit(const VaultLocalFileCredentialsRequired('locked', false));
  }

  void signout() async {
    _qu.lock();
    _persistentQueueAfAssociations = null;
    autoFillMergeAttemptDue = true;
    emit(const VaultInitial());
  }

  Future<void> removeVault(User user) async {
    l.d("removing user's local vault");
    await _localVaultRepo.remove(user);
    _qu.lock();
    _persistentQueueAfAssociations = null;
    autoFillMergeAttemptDue = true;
    l.d('user vault removed');
    emit(const VaultInitial());
  }

  Future<void> disableQuickUnlock() async {
    l.d('Removing all quick unlock data. All users will now have to sign in with their master password.');
    if (!await _qu.delete()) {
      l.e('Failed to remove quick unlock data. Recent settings changes will not take affect in a predictable way');
    }
  }

  Future<void> enableQuickUnlock(User? user, KdbxFile? file) async {
    final credentials = file?.credentials;
    if (credentials == null) {
      l.w("No credentials available so can't save to quick unlock");
      return;
    }
    l.d(
      'Enabling quick unlock data for current user ($user). Other users will have to sign in with their master password next time.',
    );
    final requireFullPasswordPeriod =
        int.tryParse(Settings.getValue<String>('requireFullPasswordPeriod') ?? '60') ?? 60;
    l.d('Will require a full password to be entered every $requireFullPasswordPeriod days');
    final quStatus = await _qu.initialiseForUser(user?.id ?? _qu.localUserMagicString, true);
    if (quStatus != QUStatus.mapAvailable && quStatus != QUStatus.credsAvailable) {
      l.w(
        "Quick unlock credential provider is unavailable or unknown. Can't proceed to save credentials in this state.",
      );
      return;
    }
    await _qu.saveBothSecrets(
      user?.passKey ?? 'notARealPassword',
      credentials,
      DateTime.now().add(Duration(days: requireFullPasswordPeriod)).millisecondsSinceEpoch,
      await file!.kdfCacheKey,
    );
  }

  Future<void> save(User? user, {bool skipRemote = false}) async {
    VaultState s = state;
    if (s is! VaultLoaded) {
      l.e('Save requested while vault is not loaded');
    } else if (s is VaultSaving && s.locally) {
      l.e("Can't save while already saving");
    } else if (s is VaultReconcilingUpload ||
        s is VaultUpdatingLocalFromRemote ||
        s is VaultUpdatingLocalFromAutofill) {
      l.e("Can't save while merging from remote source or autofill");
    } else {
      l.d('saving vault');
      final vault = currentVaultFile!;
      emit(VaultSaving(vault, true, s is VaultSaving ? s.remotely : false));
      final mergedOrCurrentVaultFile = await _localVaultRepo.save(
        user,
        vault,
        applyAndConsumePendingAutofillAssociations,
      );
      // Update autocomplete usernames after save so we remove any stale ones
      _updateAutocompleteUsernames(mergedOrCurrentVaultFile.files.current);
      //TODO:f: Sync with iOS shared credentials keychain (also in other places like merge from autofill and refresh)
      // if (KeeVaultPlatform.isIOS) {
      //   final entries = mergedOrCurrentVaultFile.files.current.body.rootGroup
      //       .getAllEntries(enterRecycleBin: false)
      //       .values;
      //   await _autoFillMethodChannel.invokeMethod('setAllEntries', <String, dynamic>{
      //     'entries': entries.toJSONStringTODO(),
      //   });
      // }
      await uploadIfNeeded(user, mergedOrCurrentVaultFile, skipRemote);

      if (KeeVaultPlatform.isIOS) {
        await autofillMerge(user, onlyIfAttemptAlreadyDue: true);
      }
    }
  }

  Future<void> uploadIfNeeded(User? user, LocalVaultFile mergedOrCurrentVaultFile, bool skipRemote) async {
    if (user == null) {
      emit(VaultLoaded(mergedOrCurrentVaultFile));
      return;
    }
    if (skipRemote) {
      l.d('vault saved locally; skipping upload');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user.${user.email}.uploadPending', true);
      emit(VaultLoaded(mergedOrCurrentVaultFile));
      return;
    }
    await upload(user, mergedOrCurrentVaultFile);
    return;
  }

  //TODO:f: check history after upload and warn user or attempt reconciliation in case that they uploaded a newer version from a different device in between our check for the latest version and the network upload completing.
  Future<void> upload(
    User user,
    LocalVaultFile vault, {
    String? overridePasswordRemote,
    PasswordMismatchRecoverySituation recovery = PasswordMismatchRecoverySituation.none,
  }) async {
    l.d('uploading vault with recovery mode $recovery');
    VaultState s = state;
    if (s is VaultLoaded) {
      if (s is VaultSaving && s.remotely) {
        l.i('Already uploading. Will not upload now.');
        //TODO:f: Maybe could track this request and do it ASAP after the current upload has completed since user apparently wants to make a quick addition while still waiting for the network
        return;
      }
      // At this point we can refresh the visible vault to include the results of the merge from
      //any previous update from remote that was deferred due to vault or entry being dirty
      emit(VaultSaving(vault, state is VaultSaving ? (state as VaultSaving).locally : false, true));
      LocalVaultFile updatedLocalFile = vault;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user.${user.email}.uploadPending', true);

      Credentials? credsLocal = vault.files.remoteMergeTargetLocked.credentials;
      Credentials? credsRemote = credsLocal;
      StrengthAssessedCredentials? credentialsOverrideWithStrength;

      if (credsLocal == null) {
        throw KeeException(
          'Cannot upload when we do not know the credentials required to perform merge operation or update KDBX password. Please tell us about this error so we can resolve it for you.',
        );
      }

      if (recovery != PasswordMismatchRecoverySituation.none && overridePasswordRemote != null) {
        l.d('we will attempt a recovery from a mismatched password');
        final protectedValue = ProtectedValue.fromString(overridePasswordRemote);
        credentialsOverrideWithStrength = StrengthAssessedCredentials(protectedValue, user.emailParts);
        if (recovery == PasswordMismatchRecoverySituation.remoteUserDiffers) {
          l.d('we have a service password explicitly supplied');

          final key = protectedValue.hash;
          await user.attachKey(key);
        }
        if (recovery == PasswordMismatchRecoverySituation.remoteFileDiffers) {
          l.d('we have a KDBX password explicitly supplied');
          credsRemote = credentialsOverrideWithStrength.credentials;
        }
      }

      //TODO:f: In what case do we need to change the local file during an upload? When password
      // was successfully changed on a remote machine - so circumstance 3. But we already handle
      // that during refresh. So perhaps we never need to do it here. Unless the user also made a
      // change to this local password file before signing in with the new password... probably
      // very rare though so will defer support for that for now.

      String? lastRemoteEtag;
      try {
        lastRemoteEtag = prefs.getString('user.${user.email}.lastRemoteEtag');
      } on Exception {
        // no action required
      }

      String remoteEtag;
      try {
        remoteEtag = await _remoteVaultRepo.latestEtag(user);
      } on KeeLoginRequiredException {
        l.w(
          'Unable to determine latest remote file etag due to authentication error. User recently changed password elsewhere?',
        );
        handleUploadAuthError(
          updatedLocalFile,
          state is VaultSaving ? (state as VaultSaving).locally : false,
          PasswordMismatchRecoverySituation.remoteUserDiffers,
        );
        return;
      } on KeeServiceTransportException catch (e) {
        final message = e.handle('Error establishing current remote file version');
        emitError(message);
        return;
      } on KeeMissingPrimaryDBException {
        emitKeeMissingPrimaryDBExceptionError();
        return;
      } on KeeSubscriptionExpiredException {
        emitError(S.current.expiredWhileSignedIn, forceNotLoaded: true);
        return;
      } on KeeAccountUnverifiedException {
        _accountCubit.emailUnverified();
        return;
      } on Exception catch (e) {
        final message =
            'Error establishing current remote file version. There may be more information in this message: $e';
        l.e(message);
        emitError(message, toast: true);
        return;
      }
      if (state is! VaultLoaded) {
        l.w(
          'Upload aborted because Vault is no longer loaded. User forcibly locked while waiting on network activity?',
        );
        return;
      }
      if (remoteEtag != lastRemoteEtag) {
        // files.current and files.remoteMergeTarget start the same when this function begins but user may modify current at any time (e.g. if we wait for remote HEAD for a long time).

        emit(
          VaultReconcilingUpload(updatedLocalFile, state is VaultSaving ? (state as VaultSaving).locally : false, true),
        );
        RemoteVaultFile latestRemoteFile;
        LockedVaultFile? latestLockedRemoteFile;
        try {
          latestLockedRemoteFile = await _remoteVaultRepo.download(user, credsRemote, null);
        } on KeeLoginRequiredException {
          // This should be rare because we've recently retrieved or checked our download auth token but can happen sometimes, maybe on very slow networks when the user is changing their master password elsewhere concurrently.
          l.w(
            'Unable to download latest remote file for local merging due to authentication error. User recently changed password elsewhere?',
          );
          handleUploadAuthError(
            updatedLocalFile,
            state is VaultSaving ? (state as VaultSaving).locally : false,
            PasswordMismatchRecoverySituation.remoteUserDiffers,
          );
          return;
        } on KeeServiceTransportException catch (e) {
          final message = e.handle('Error while downloading more recent changes from remote');
          emitError(message);
          return;
        } on KeeMissingPrimaryDBException {
          emitKeeMissingPrimaryDBExceptionError();
          return;
        } on KeeSubscriptionExpiredException {
          emitError(S.current.expiredWhileSignedIn, forceNotLoaded: true);
          return;
        } on KeeAccountUnverifiedException {
          _accountCubit.emailUnverified();
          return;
        } on Exception catch (e) {
          final message =
              'Error while downloading more recent changes from remote. There may be more information in this message: $e';
          l.e(message);
          emitError(message, toast: true);
          return;
        }
        if (state is! VaultLoaded) {
          l.w(
            'Upload aborted because Vault is no longer loaded. User forcibly locked while waiting on network activity?',
          );
          return;
        }
        try {
          latestRemoteFile = await RemoteVaultFile.unlock(latestLockedRemoteFile!);
        } on KdbxInvalidKeyException catch (e, s) {
          //TODO:f: Maybe support trying with local creds in case we are in a mismatch situation?

          // Creds aren't able to unlock the remote file
          // Could be because creds were changed on a different device since the most recent download happened on this one.
          //Normally that won't happen because the user would have had to update their local creds to authenticate to the service
          // but maybe if they have a token that is still valid for a number of minutes after the credential change.
          // We decide to abort the upload process in this situation because the user is best able to resolve the issue by
          //reauthenticating with the new credentials and relying on the next loadStagedUpdate operation to resolve the key mismatch.

          await _localVaultRepo.stageUpdate(user, latestLockedRemoteFile);
          // We've staged the update so startup can handle trying to fix the problem later.
          // etags and version ids are lost when staging an update. Thus, when comparing for latest
          // etag during the next refresh or upload operation, we will re-download the update
          // and perform a merge. This should be a NOOP but is inefficient.

          l.w(
            'Remote file failed to unlock using latest password. User uploaded from other device using auth token created before recent password change?',
          );
          throw KeeException(
            'Remote file failed to unlock using latest password. When you kill and then restart the app, we will attempt to automatically fix the problem. If that does not work, please ask for help.',
            e,
            s,
          );
        } on Exception catch (e) {
          final message =
              'Error while unlocking more recent changes from remote. There may be more information in this message: $e';
          l.e(message);
          emitError(message, toast: true);
          return;
        }
        if (state is! VaultLoaded) {
          l.w(
            'Upload aborted because Vault is no longer loaded. User forcibly locked while waiting on unlock activity?',
          );
          return;
        }
        try {
          final updatedVaultFile = await _updateLocalVaultFile(user, updatedLocalFile, latestRemoteFile);
          if (updatedVaultFile == null) {
            throw Exception('Unexpected error while updating local vault file.');
          }
          updatedLocalFile = updatedVaultFile;
        } on Exception catch (e) {
          final message =
              'Error while merging more recent changes from remote. There may be more information in this message: $e';
          l.e(message);
          emitError(message, toast: true);
          return;
        }
        if (state is! VaultLoaded) {
          l.w(
            'Upload aborted because Vault is no longer loaded. User forcibly locked while waiting on merge activity?',
          );
          return;
        }
        // At this point we can refresh the visible vault to include the results of the merge from remote, although if the user was editing again by now, the current vault shown to them won't yet be changed.
        emit(VaultSaving(updatedLocalFile, state is VaultSaving ? (state as VaultSaving).locally : false, true));

        l.d('finished merging in more recent remote contents');
      } else {
        l.d('no merge with remote contents required');
      }

      // The server will enforce a maximum length but we don't want to waste bandwidth by sending
      // a file we know is too large. User could resolve in this app instance or on a
      // remote instance because the next upload attempt would find that a new smaller file
      // has been stored remotely. Of course, the merge operation from remote is broadly
      // conservative so they may not free up as much space as expected but it will
      // work in some situations.
      if (updatedLocalFile.files.remoteMergeTargetLocked.kdbxBytes.length > 10000000) {
        final message = S.current.vaultTooLarge;
        l.w('Maximum vault size of 10MB has been exceeded. $message');
        emitError(message, toast: true);
        return;
      }

      try {
        final uploadedLockedFile = await _remoteVaultRepo.upload(user, updatedLocalFile.files.remoteMergeTargetLocked);
        await prefs.setString('user.${user.email}.lastRemoteEtag', uploadedLockedFile.etag!);
        await prefs.setString('user.${user.email}.lastRemoteVersionId', uploadedLockedFile.versionId!);

        // A pending upload doesn't stop us from beginning a new upload attempt so it's OK that
        // we remain in that state until the process has completed successfully.
        await prefs.setBool('user.${user.email}.uploadPending', false);
        safeEmitLoaded(updatedLocalFile);

        // Perhaps could do this after a redownload/merge too, to cover the case where
        // that all works but the download fails and the user had made some remote changes
        // to synced app settings. Could be a little risky to change config during the
        // upload process though, if not now then when some future synced settings are
        // added to the system. Since things appear to work well at the moment, we
        // will defer this until a definitive real world benefit is confirmed.
        await SyncedAppSettings.import(
          _generatorProfilesCubit,
          updatedLocalFile.files.current.body.meta.keeVaultSettings,
        );
      } on KeeLoginRequiredException {
        handleUploadAuthError(
          updatedLocalFile,
          state is VaultSaving ? (state as VaultSaving).locally : false,
          PasswordMismatchRecoverySituation.remoteUserDiffers,
        );
        return;
      } on KeeMissingPrimaryDBException {
        emitKeeMissingPrimaryDBExceptionError();
        return;
      } on KeeServiceTransportException catch (e) {
        final message = e.handle('Error uploading');
        emitError(message);
        return;
      } on KeeSubscriptionExpiredException {
        emitError(S.current.expiredWhileSignedIn, forceNotLoaded: true);
        return;
      } on KeeAccountUnverifiedException {
        _accountCubit.emailUnverified();
        return;
      } on Exception catch (e) {
        final message = 'Error uploading. There may be more information in this message: $e';
        l.e(message);
        emitError(message, toast: true);
        return;
      }
    } else {
      l.e('upload called while vault is not loaded');
    }
  }

  KdbxEntry? findEntryByUuid(String uuid) {
    //TODO:f: Create a cache of this and group map, ideally within kdbx.dart in order to simplify invalidation upon entry changes
    return currentVaultFile!.files.current.body.rootGroup.getAllEntries()[uuid];
  }

  KdbxGroup? findGroupByUuid(String uuid) {
    return currentVaultFile!.files.current.body.rootGroup.getAllGroups()[uuid];
  }

  KdbxGroup findGroupByUuidOrRoot(String uuid) {
    return currentVaultFile!.files.current.body.rootGroup.getAllGroups()[uuid] ??
        currentVaultFile!.files.current.body.rootGroup;
  }

  KdbxEntry createEntry({required KdbxGroup group}) {
    l.t('VaultCubit.createEntry');
    final destinationGroup = group;
    final entry = KdbxEntry.create(currentVaultFile!.files.current, destinationGroup);
    destinationGroup.addEntry(entry);
    return entry;
  }

  void createGroup({required String parent, required String name}) {
    final parentGroup = currentVaultFile!.files.current.findGroupByUuid(KdbxUuid(parent));
    currentVaultFile!.files.current.createGroup(parent: parentGroup, name: name);
    reemitLoadedState();
  }

  void reportPasswordChangeError(String? error) {
    if (state is VaultChangingPassword) {
      emit(VaultChangingPassword((state as VaultChangingPassword).vault, error));
    }
  }

  void reemitLoadedState() {
    if (state is VaultUpdatingLocalFromRemote) {
      final castState = state as VaultUpdatingLocalFromRemote;
      emit(VaultUpdatingLocalFromRemote(castState.vault));
    } else if (state is VaultUpdatingLocalFromAutofill) {
      final castState = state as VaultUpdatingLocalFromAutofill;
      emit(VaultUpdatingLocalFromAutofill(castState.vault));
    } else if (state is VaultRefreshCredentialsRequired) {
      final castState = state as VaultRefreshCredentialsRequired;
      emit(
        VaultRefreshCredentialsRequired(
          castState.vault,
          castState.reason,
          castState.causedByInteraction,
          castState.recovery,
        ),
      );
    } else if (state is VaultRefreshing) {
      final castState = state as VaultRefreshing;
      emit(VaultRefreshing(castState.vault));
    } else if (state is VaultBackgroundError) {
      final castState = state as VaultBackgroundError;
      emit(VaultBackgroundError(castState.vault, castState.message, castState.toast));
    } else if (state is VaultUploadCredentialsRequired) {
      final castState = state as VaultUploadCredentialsRequired;
      emit(
        VaultUploadCredentialsRequired(
          castState.vault,
          castState.locally,
          castState.remotely,
          castState.causedByInteraction,
          castState.recovery,
        ),
      );
    } else if (state is VaultChangingPassword) {
      final castState = state as VaultChangingPassword;
      emit(VaultChangingPassword(castState.vault, castState.error));
    } else if (state is VaultReconcilingUpload) {
      final castState = state as VaultReconcilingUpload;
      emit(VaultReconcilingUpload(castState.vault, castState.locally, castState.remotely));
    } else if (state is VaultSaving) {
      final castState = state as VaultSaving;
      emit(VaultSaving(castState.vault, castState.locally, castState.remotely));
    } else if (state is VaultLoaded) {
      final castState = state as VaultLoaded;
      emit(VaultLoaded(castState.vault));
    }
  }

  bool safeEmitLoaded(LocalVaultFile v) {
    if (state.runtimeType == VaultRefreshing ||
        state.runtimeType == VaultUpdatingLocalFromRemote ||
        state.runtimeType == VaultUpdatingLocalFromAutofill ||
        state.runtimeType == VaultBackgroundError ||
        state.runtimeType == VaultLoaded ||
        state is VaultSaving) {
      emit(VaultLoaded(v));
      return true;
    }
    return false;
  }

  void renameGroup({required String groupUuid, required String name}) {
    final group = currentVaultFile!.files.current.findGroupByUuid(KdbxUuid(groupUuid));
    group.name.set(name);
    reemitLoadedState();
  }

  void deleteGroup({required String groupUuid}) {
    final group = currentVaultFile!.files.current.findGroupByUuid(KdbxUuid(groupUuid));
    currentVaultFile!.files.current.deleteGroup(group, group.isInRecycleBin);
    reemitLoadedState();
  }

  void moveGroup({required String groupUuid, required String newParentUuid}) {
    final group = currentVaultFile!.files.current.findGroupByUuid(KdbxUuid(groupUuid));
    final parent = currentVaultFile!.files.current.findGroupByUuid(KdbxUuid(newParentUuid));
    currentVaultFile!.files.current.move(group, parent);
    reemitLoadedState();
  }

  void emptyRecycleBin() {
    currentVaultFile!.files.current.emptyGroup(currentVaultFile!.files.current.recycleBin!, true);
    reemitLoadedState();
  }

  Future<void> importKdbx(
    LocalVaultFile destination,
    LockedVaultFile source,
    Credentials? sourceCredentials,
    bool causedByInteraction,
    bool manual,
  ) async {
    emit(VaultImporting());
    try {
      l.d('attempting to open source vault');
      final unlockedSourceFile = await LocalVaultFile.unlock(
        source.copyWith(credentials: sourceCredentials),
        importOnly: true,
      );
      l.d('source vault unlocked');
      destination.files.current.import(unlockedSourceFile.files.current);
      l.d('source vault imported');
      if (!manual) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user.current.freeImportedAt', (DateTime.now().millisecondsSinceEpoch / 1000).floor());
      }
      emit(VaultImported(destination, manual));
    } on KdbxInvalidKeyException {
      emit(VaultImportingCredentialsRequired(destination, source, causedByInteraction, manual));
      return;
    } on Exception {
      await emitVaultLoaded(destination, null, safe: false);
      rethrow;
    }
  }

  Future<void> skipLocalFreeKdbxImport(LocalVaultFile destination) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user.current.freeImportedAt', (DateTime.now().millisecondsSinceEpoch / 1000).floor());
    l.d('free vault import skipped. We faked the imported date.');
    await emitVaultLoaded(destination, null, safe: false);
  }

  Future<bool> localFreeKdbxExists() async {
    return await _localVaultRepo.localFreeExists();
  }

  Future<bool> manageLocalFreeFileImport(bool localFileExists) async {
    final prefs = await SharedPreferences.getInstance();
    int? importedAt;
    try {
      importedAt = prefs.getInt('user.current.freeImportedAt');
    } on Exception {
      // no action required
    }
    final importAlreadyPerformed = importedAt != null;
    final importedLocalFreeFileCanBeDeleted =
        localFileExists &&
        importAlreadyPerformed &&
        (importedAt * 1000) > DateTime.now().add(Duration(days: 90)).millisecondsSinceEpoch;
    if (importedLocalFreeFileCanBeDeleted) {
      final deleted = await _localVaultRepo.removeFreeUser();
      if (deleted) {
        await prefs.remove('user.current.freeImportedAt');
      }
      return false;
    }
    return localFileExists && !importAlreadyPerformed;
  }

  Future<bool> forceLocalFreeFileDelete() async {
    final prefs = await SharedPreferences.getInstance();

    final deleted = await _localVaultRepo.removeFreeUser();
    if (deleted) {
      await prefs.remove('user.current.freeImportedAt');
      return true;
    }
    return false;
  }

  Future<Uint8List?> loadFreeFileForExport() async {
    final localFreeFile = await _localVaultRepo.loadFreeUserLocked();
    return localFreeFile?.kdbxBytes;
  }

  Future<void> changeFreeUserPassword(String password) async {
    VaultState s = state;
    try {
      if (isPasswordChangingSuspended()) {
        const message =
            'User tried to change password while cubit prevented it. This is extremely unlikely to happen and retrying should resolve the issue.';
        l.w(message);
        throw VaultPasswordChangeException(message);
      }
      if (s is VaultSaving) {
        const message = 'Can\'t change password while vault is being saved. Try again later.';
        l.e(message);
        throw VaultPasswordChangeException(message);
      }
      if (s is VaultLoaded) {
        l.d('changing KDBX password');
        final protectedValue = ProtectedValue.fromString(password);
        final credentialsWithStrength = StrengthAssessedCredentials(protectedValue, []);
        s.vault.files.current
          ..changeCredentials(credentialsWithStrength.credentials)
          ..header.writeKdfParameters(credentialsWithStrength.createNewKdfParameters());
        await save(null);
        l.d('KDBX password changed');
      }
    } on VaultPasswordChangeException catch (e) {
      reportPasswordChangeError(e.cause);
    } on Exception catch (e) {
      reportPasswordChangeError(
        'There was a problem saving your new password. Please try again in a moment and then check that your device storage has free space and is not faulty. Further information may follow: ${e.toString()}',
      );
    }
  }

  Future<void> changeRemoteUserPassword(String password) async {
    VaultState s = state;
    if (isPasswordChangingSuspended()) {
      const message =
          'User tried to change password while cubit prevented it. This is extremely unlikely to happen and retrying should resolve the issue.';
      l.w(message);
      throw Exception(message);
    }
    if (s is VaultSaving) {
      const message = 'Can\'t change password while vault is being saved. Try again later.';
      l.e(message);
      throw Exception(message);
    }
    final user = _accountCubit.currentUserIfIdKnown;
    if (user == null) {
      const message = 'User not known. Cannot change remote user password if we don\'t know this.';
      l.e(message);
      throw Exception(message);
    }
    if (s is VaultChangingPassword) {
      final protectedValue = ProtectedValue.fromString(password);
      try {
        await _accountCubit.changePassword(protectedValue, (User user) async {
          l.d('changing KDBX password');
          final credentialsWithStrength = StrengthAssessedCredentials(protectedValue, user.emailParts);
          s.vault.files.current
            ..changeCredentials(credentialsWithStrength.credentials)
            ..header.writeKdfParameters(credentialsWithStrength.createNewKdfParameters());
          await save(user);
          l.d('KDBX password changed and uploaded');
          return true;
        });
      } on VaultPasswordChangeException catch (e) {
        reportPasswordChangeError(e.cause);
      }
    }
  }

  void startEmailChange() {
    if (currentVaultFile == null || (!currentVaultFile!.files.current.isDirty && _entryCubit.state is! EntryLoaded)) {
      _accountCubit.startEmailChange();
      signout();
    } else {
      emitError('You must save your changes first!', toast: true);
    }
  }

  bool beginChangePasswordIfPossible() {
    if (currentVaultFile == null) {
      return false;
    }
    if (state is! VaultLoaded ||
        state is VaultRefreshing ||
        state is VaultRefreshCredentialsRequired ||
        state is VaultBackgroundError ||
        state is VaultSaving) {
      emitError('Please wait a moment until background vault updates have completed.', toast: true);
      return false;
    }
    if (!currentVaultFile!.files.current.isDirty && _entryCubit.state is! EntryLoaded) {
      emit(VaultChangingPassword(currentVaultFile!, null));
      return true;
    }
    emitError('You must save your changes first!', toast: true);
    return false;
  }

  Future<void> autofillMerge(User? user, {bool onlyIfAttemptAlreadyDue = false}) async {
    if (onlyIfAttemptAlreadyDue && !autoFillMergeAttemptDue) {
      return;
    }

    VaultState s = state;
    if (s is! VaultLoaded || s is VaultRefreshing || s is VaultSaving) {
      autoFillMergeAttemptDue = true;
      return;
    }

    Credentials creds = s.vault.files.current.credentials;

    try {
      autoFillMergeAttemptDue = false;
      emit(VaultUpdatingLocalFromAutofill(s.vault));
      final newFile = await _localVaultRepo.tryAutofillMerge(user, creds, s.vault);

      if (newFile != null && user != null) {
        await upload(user, newFile);
      } else {
        await emitVaultLoaded(newFile ?? s.vault, user, immediateRemoteRefresh: false, safe: true);
      }
    } on KdbxInvalidKeyException {
      // We ignore this until we have a background service to keep all 3 sources in sync. Until then, it could happen if user changes their password while there are outstanding changes available in the autofill kdbx file. We prevent that locally but not if user makes password change on a different device.
      const message =
          "Merge from Autofill service failed. Changes recently made via your device's Autofill feature (i.e. from a different app) may have been lost so please inspect your vault and correct this manually. The most likely explanation for this problem is that you changed your password on another device before this one was able to integrate your changes from Autofill.";
      l.e(message);
      emitError(message, toast: true);
      return;
    } on Exception catch (e) {
      final message =
          "Merge from Autofill service failed. Changes recently made via your device's Autofill feature (i.e. from a different app) may have been lost so please inspect your vault and correct this manually. Check your device has enough storage space. Otherwise, this error may indicate a faulty operating system or hardware. There may be more information in this message: $e";
      l.e(message);
      emitError(message, toast: true);
      return;
    }
  }

  bool isPasswordChangingSuspended() {
    // Maybe could inspect the filesystem to see if we really need to suspend
    // changing but, especially for local-only users, the suspension period should
    // be very brief. Perhaps even briefer than it would take to wait for the
    // device to check the filesystem.
    return KeeVaultPlatform.isIOS && (autoFillMergeAttemptDue || state is VaultUpdatingLocalFromAutofill);
  }
}
