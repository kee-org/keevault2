import 'dart:convert';
import 'package:biometric_storage/biometric_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:kdbx/kdbx.dart';
import '../config/platform.dart';
import '../kdf_cache.dart';
import 'expiring_cached_credential_hash.dart';
import 'expiring_cached_credential_hash_map.dart';
import '../config/environment_config.dart';
import '../logging/logger.dart';
import 'package:keevault/generated/l10n.dart';

class QuickUnlocker {
  Future<BiometricStorageFile>? _storageFileCached;
  bool? _supported;
  String? _currentUser;
  final String localUserMagicString = 'localUserMagicString@v1';
  ExpiringCachedCredentials? _currentCreds;
  String? newUserPassKey;
  final kdfCache = KeeVaultKdfCache();

  static const _autoFillMethodChannel = MethodChannel('com.keevault.keevault/autofill');

  // We cache all credentials that the current platform user has entered. In some
  // cases this will result in prolonged internal memory persistence for credentials
  // that actually aren't required for the current user session. Protecting against
  // internal memory platform security bugs isn't part of our threat model so this
  // is a reasonable tradeoff to ensure that the user doesn't have to re-authenticate
  // for every single interactive and non-interactive operation we undertake.
  ExpiringCachedCredentialHashMap? _currentCredsMap;

  final storageFileName =
      'KeeVaultQuickUnlock_v2_${EnvironmentConfig.stage}${KeeVaultPlatform.isAndroid ? '_${EnvironmentConfig.channel}' : ''}';

  // iOS limits possible app version configurations, essentially forcing development builds to share a keychain
  // regardless of which remote server platform channel is in use. In practice, therefore, we will map dev
  // builds to the dev environment, beta to beta and release to release. And hope no bugs ever need a more complex
  // environment to investigate.
  final iosAccessGroupPlistKey = 'KeeVaultSharedDefaultAccessGroup';

  // changes to authenticationValidityDurationSeconds only take effect when creating
  // a new storage file, not for every read or write to it.
  int get authGracePeriod {
    final val = int.tryParse(Settings.getValue<String>('authGracePeriod') ?? '60') ?? 60;
    l.d('Will require reauthentication every $val seconds');
    return val;
  }

  Future<BiometricStorageFile> _storageFile() => _storageFileCached ??= BiometricStorage().getStorage(
        storageFileName,
        forceInit: true,
        options: StorageFileInitOptions(
            authenticationValidityDurationSeconds: authGracePeriod, iosAccessGroupPlistKey: iosAccessGroupPlistKey),
        promptInfo: PromptInfo(
          iosPromptInfo: IosPromptInfo(accessTitle: S.current.unlock, saveTitle: S.current.rememberVaultPassword),
        ),
      );

  Future<QUStatus> initialiseForUser(String user, bool force) async {
    if (!force && _currentCreds != null && _currentUser != null && _currentUser == user) {
      return QUStatus.credsAvailable;
    }
    _currentCreds = null;
    _currentUser = null;
    if (!(Settings.getValue<bool>('biometrics-enabled') ?? true)) {
      l.d('Quick unlock disabled by user');
      return QUStatus.unavailable;
    }
    if (!(await supportsBiometricKeyStore())) {
      l.i('Biometric store not supported. no quickunlock.');
      return QUStatus.unavailable;
    }
    _currentUser = user;
    final storage = await _storageFile();
    final jsonContent = await _read(storage);
    if (jsonContent == null) {
      l.d('No quick unlock available yet. Missing stored data.');
      _currentCredsMap = ExpiringCachedCredentialHashMap({});
      return QUStatus.mapAvailable;
    }
    try {
      final raw = json.decode(jsonContent);
      if (raw is Map<String, dynamic>) {
        _currentCredsMap = ExpiringCachedCredentialHashMap.fromJson(raw);
      } else {
        l.d('No quick unlock available yet. Invalid stored JSON.');
        _currentCredsMap = ExpiringCachedCredentialHashMap({});
        return QUStatus.mapAvailable;
      }
    } on FormatException {
      l.d('No quick unlock available yet. Invalid stored data.');
      _currentCredsMap = ExpiringCachedCredentialHashMap({});
      return QUStatus.mapAvailable;
    }
    _currentCredsMap ??= ExpiringCachedCredentialHashMap({});
    final storedCreds = _currentCredsMap!.forUser(user);
    if (storedCreds == null) {
      l.d('No quick unlock available yet. User not stored.');
      return QUStatus.mapAvailable;
    }

    if (storedCreds.expiry <= DateTime.now().millisecondsSinceEpoch) {
      _currentCredsMap!.update(user, null);
      l.i('Quick unlock credentials expired. User must re-enter password.');
      return QUStatus.mapAvailable;
    }
    _currentCreds = storedCreds;
    return QUStatus.credsAvailable;
  }

  void lock() {
    _currentCredsMap = null;
    _currentCreds = null;
    _currentUser = null;
  }

  Future<bool> delete() async {
    try {
      final storage = await _storageFile();
      await storage.delete();
      _storageFileCached = null;
      return true;
    } on Exception catch (e, stackTrace) {
      l.e('Failed to delete QU storage. $e : ${stackTrace.toString()}');
    }
    return false;
  }

  Future<String?> _read(BiometricStorageFile storage) async {
    try {
      final contents = await storage.read(
          promptInfo: PromptInfo(
              androidPromptInfo: AndroidPromptInfo(title: S.current.unlock, description: S.current.confirmItsYou)));
      return contents;
    } on AuthException catch (e, stackTrace) {
      if (e.code == AuthExceptionCode.timeout) {
        l.w('Authentication timeout. Try again. More quickly this time please.');
      } else if (e.code == AuthExceptionCode.userCanceled) {
        l.d('User cancelled authentication.');
      } else {
        l.e('''Authentication system error (read).
Biometrics are unlikely to work until the user resolves the cause of the following message: ${e.message}
(CODE: ${e.code})
Stack trace:
$stackTrace''');
      }
      return null;
    }
  }

  Future<void> _write(BiometricStorageFile storage, String contents) async {
    try {
      await storage.write(contents,
          promptInfo: PromptInfo(
              androidPromptInfo: AndroidPromptInfo(
                  title: S.current.rememberVaultPassword, description: S.current.biometricsStoreDescription)));
      if (KeeVaultPlatform.isIOS) {
        await _autoFillMethodChannel.invokeMethod('setUserId', <String, dynamic>{
          'userId': _currentUser,
        });
      }
    } on AuthException catch (e, stackTrace) {
      if (e.code == AuthExceptionCode.timeout) {
        l.w('Authentication timeout. Try again. More quickly this time please.');
      } else if (e.code == AuthExceptionCode.userCanceled) {
        l.d('User cancelled authentication.');
      } else {
        l.e('''Authentication system error (write).
Biometrics are unlikely to work until the user resolves the cause of the following message: ${e.message}
(CODE: ${e.code})
Stack trace:
$stackTrace''');
      }
    } catch (e) {
      l.e('Unexpected error while writing quick unlock credentials.');
    }
  }

  Future<Credentials?> loadQuickUnlockFileCredentials() async {
    if (!(Settings.getValue<bool>('biometrics-enabled') ?? true)) {
      l.d('Quick unlock disabled by user');
      return null;
    }
    if (_currentCreds == null || _currentUser == null) {
      l.d('Quick unlock unavailable');
      return null;
    }
    kdfCache.putItemByKey(_currentCreds!.kdbxKdfCacheKey, base64.decode(_currentCreds!.kdbxKdfResultBase64));

    // It's actually unlikely we will need the credentials anymore since we have the KDF result instead but we
    // at least need a sensible target for any future password change operations the user undertakes.
    return HashCredentials(base64.decode(_currentCreds!.kdbxBase64Hash));
  }

  Future<String?> loadQuickUnlockUserPassKey() async {
    if (!(Settings.getValue<bool>('biometrics-enabled') ?? true)) {
      l.d('Quick unlock disabled by user');
      return null;
    }
    if (_currentCreds == null || _currentUser == null) {
      l.d('Quick unlock unavailable');
      return null;
    }
    return _currentCreds!.userPassKey;
  }

  Future<void> saveQuickUnlockUserPassKey(String? userPassKey) async {
    if (!(Settings.getValue<bool>('biometrics-enabled') ?? true)) {
      l.d('Quick unlock disabled by user');
      return;
    }
    if (_currentUser == null) {
      l.d('Quick unlock unavailable');
      return;
    }

    if (_currentCreds == null) {
      newUserPassKey = userPassKey;
      return;
    }

    ExpiringCachedCredentials updatedCreds = _currentCreds!;
    if (userPassKey == _currentCreds!.userPassKey) {
      l.d('UserPassKey has not changed');
    } else {
      final storage = await _storageFile();
      updatedCreds = ExpiringCachedCredentials(updatedCreds.kdbxBase64Hash, updatedCreds.kdbxKdfCacheKey,
          updatedCreds.kdbxKdfResultBase64, userPassKey!, updatedCreds.expiry);
      _currentCreds = updatedCreds;
      _currentCredsMap!.update(_currentUser!, updatedCreds);
      await _write(storage, json.encode(_currentCredsMap));
    }
  }

  Future<void> saveQuickUnlockFileCredentials(Credentials? creds, int expiryTime, String kdfCacheKey) async {
    if (!(Settings.getValue<bool>('biometrics-enabled') ?? true)) {
      l.d('Quick unlock disabled by user');
      return;
    }
    if (_currentUser == null) {
      l.d('Quick unlock unavailable');
      return;
    }

    ExpiringCachedCredentials? updatedCreds = _currentCreds;
    if (updatedCreds == null) {
      if (newUserPassKey?.isEmpty ?? true) {
        if (_currentUser != localUserMagicString) {
          l.i("Kdbx credentials can't be saved before setting newUserPassKey. This is expected if the user has yet to sign-in following the enablement of a platform biometric.");
          return;
        }
        newUserPassKey = 'notARealPassword';
      }
      final encodedCreds = base64.encode(creds!.getHash());
      final kdfResult = base64.encode(kdfCache.getItemByKey(kdfCacheKey)!);
      updatedCreds = ExpiringCachedCredentials(encodedCreds, kdfCacheKey, kdfResult, newUserPassKey!, expiryTime);
    } else {
      final encodedCreds = base64.encode(creds!.getHash());
      if (encodedCreds == _currentCreds!.kdbxBase64Hash) {
        l.d('FileCredentials has not changed');
        return;
      }
      updatedCreds.kdbxBase64Hash = encodedCreds;
    }

    final storage = await _storageFile();
    _currentCreds = updatedCreds;
    _currentCredsMap!.update(_currentUser!, updatedCreds);
    await _write(storage, json.encode(_currentCredsMap));
  }

  Future<void> saveBothSecrets(String userPassKey, Credentials creds, int expiryTime, String kdfCacheKey) async {
    if (!(Settings.getValue<bool>('biometrics-enabled') ?? true)) {
      l.d('Quick unlock disabled by user');
      return;
    }
    if (_currentUser == null) {
      l.d('Quick unlock unavailable');
      return;
    }

    final encodedCreds = base64.encode(creds.getHash());
    final kdfResult = base64.encode(kdfCache.getItemByKey(kdfCacheKey)!);
    final newCreds = ExpiringCachedCredentials(encodedCreds, kdfCacheKey, kdfResult, userPassKey, expiryTime);

    final storage = await _storageFile();
    _currentCreds = newCreds;
    _currentCredsMap!.update(_currentUser!, newCreds);
    await _write(storage, json.encode(_currentCredsMap));
  }

  Future<bool> supportsBiometricKeyStore() async {
    if (_supported != null) {
      return _supported!;
    }
    final canAuthenticate = await BiometricStorage().canAuthenticate();
    l.d('supportBiometricKeyStore: $canAuthenticate');
    return _supported = (canAuthenticate == CanAuthenticateResponse.success);
  }
}

enum QUStatus { unknown, unavailable, mapAvailable, credsAvailable }
