import 'dart:io';
import 'dart:typed_data';
import 'package:argon2_ffi_base/argon2_ffi_base.dart';
import 'package:dio/dio.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keevault/password_strength.dart';
import 'package:keevault/vault_backend/user.dart';
import 'kdf_cache.dart';
import 'locked_vault_file.dart';
import 'vault_backend/exceptions.dart';
import 'vault_backend/storage_item.dart';
import 'vault_backend/storage_service.dart';
import 'vault_backend/user_service.dart';
import 'kdbx_argon2_ffi.dart';
import 'package:keevault/extension_methods.dart';

// Orchestrate loading a kdbx file from some service and process that into a model that this app can work with
class RemoteVaultRepository {
  final UserService userService;
  final StorageService storageService;

  RemoteVaultRepository(this.userService, this.storageService);

  // KdbxFormat orchestrates methods for dealing with files and data streams in the form of a kdbx file
  static KdbxFormat kdbxFormat() {
    Argon2.resolveLibraryForceDynamic = true;
    return KdbxFormat(KeeVaultKdfCache(), FlutterArgon2());
  }

  Future<LockedVaultFile?> download(User user, Credentials? credentials, String? lastRemoteEtag) async {
    final lockedFile = await _downloadPrimaryFile(user, credentials, lastRemoteEtag);
    return lockedFile;
  }

  Future<LockedVaultFile> downloadWithoutEtagCheck(User user, Credentials? credentials) async {
    final lockedFile = await _downloadPrimaryFile(user, credentials, null);
    return lockedFile!;
  }

  Future<String> latestEtag(User user) async {
    var siList = await storageService.list(user);
    if (siList.isEmpty) {
      throw KeeMissingPrimaryDBException();
    }
    final latestEtag = await _headPrimaryFile(user, siList);
    return latestEtag;
  }

  Future<LockedVaultFile> upload(User user, LockedVaultFile vault) async {
    var siList = await storageService.list(user);
    if (siList.isEmpty) {
      throw KeeMissingPrimaryDBException();
    }
    var result = await _putPrimaryFile(user, vault.kdbxBytes, siList, vault.credentials);
    return result;
  }

  Future<LockedVaultFile> create(User user, StrengthAssessedCredentials credentialsWithStrength) async {
    final credentials = credentialsWithStrength.credentials;
    final vault = kdbxFormat().create(
      credentials,
      'My Kee Vault',
      generator: 'Kee Vault 2',
      header: credentialsWithStrength.createNewKdbxHeader(),
    );
    final lockedFile = LockedVaultFile(await vault.save(), DateTime.now(), credentials, null, null);
    await storageService.create(user, lockedFile);

    // We skip the redownloading of the file we just uploaded. That means we can't know
    // the etag, etc. from S3 but it is faster this way and we don't risk AWS race
    // conditions causing failures to download the file. Only consider implementing
    // a reliable download operation if we can't avoid the need for that metadata.

    // We don't call list again because we already have the SI list from the create response.
    // However, that means we bypass some of the storage token caching code paths and
    // thus if bugs after sign-up occur, this is worth closer inspection.
    //final lockedFile = await _getPrimaryFile(user, credentials, [si]);
    return lockedFile;
  }

  Future<LockedVaultFile?> _downloadPrimaryFile(User user, Credentials? kdbxCredentials, String? lastRemoteEtag) async {
    var siList = await storageService.list(user);
    if (siList.isEmpty) {
      throw KeeMissingPrimaryDBException();
    }
    if (lastRemoteEtag != null) {
      final latestEtag = await _headPrimaryFile(user, siList);
      if (latestEtag == lastRemoteEtag) {
        return null;
      }
    }
    final lockedFile = await _getPrimaryFile(user, kdbxCredentials, siList);
    return lockedFile;
  }

  Future<LockedVaultFile> _getPrimaryFile(User user, Credentials? kdbxCredentials, List<StorageItem> siList) async {
    if (siList[0].urls == null) {
      throw Exception('Missing URLs from storage service.');
    }
    final dlUrl = siList[0].urls!.dl;
    final dio =
        Dio(BaseOptions(connectTimeout: Duration(milliseconds: 20000), receiveTimeout: Duration(milliseconds: 30000)));
    var retriesRemaining = 3;
    do {
      retriesRemaining--;
      try {
        var response = await dio.get(dlUrl, options: Options(responseType: ResponseType.bytes));
        final fileModifiedAt = HttpDate.parse(response.headers['last-modified']![0]);
        final etag = response.headers['etag']![0];
        final versionId = response.headers['x-amz-version-id']![0];
        return LockedVaultFile(
          response.data,
          fileModifiedAt,
          kdbxCredentials,
          etag,
          versionId,
        );
      } on DioError catch (e, s) {
        await e.handle('Get primary file', s, retriesRemaining, () async {
          throw KeeLoginRequiredException();
        });
      } on Exception {
        continue;
      }
    } while (retriesRemaining > 0);
    throw KeeUnexpectedException('Failed to get primary file for unknown reason');
  }

  Future<LockedVaultFile> _putPrimaryFile(
      User user, Uint8List fileData, List<StorageItem> siList, Credentials? credentials) async {
    if (siList[0].urls == null) {
      throw Exception('Missing URLs from storage service.');
    }
    final ulUrl = siList[0].urls!.ul;
    final dio =
        Dio(BaseOptions(connectTimeout: Duration(milliseconds: 20000), sendTimeout: Duration(milliseconds: 30000)));
    var retriesRemaining = 3;
    do {
      retriesRemaining--;
      try {
        final response = await dio.put(
          ulUrl,
          data: Stream.fromIterable(fileData.map((e) => [e])),
          options: Options(
            responseType: ResponseType.bytes,
            headers: {
              HttpHeaders.contentTypeHeader: 'binary/octet-stream',
              HttpHeaders.contentLengthHeader: fileData.length,
            },
          ),
        );
        final etag = response.headers['etag']![0];
        final versionId = response.headers['x-amz-version-id']![0];
        return LockedVaultFile(
          fileData,
          DateTime.now(),
          credentials,
          etag,
          versionId,
        );
      } on DioError catch (e, s) {
        await e.handle('Put primary file', s, retriesRemaining, () async {
          throw KeeLoginRequiredException();
        });
      } on Exception {
        continue;
      }
    } while (retriesRemaining > 0);
    throw KeeUnexpectedException('Failed to put primary file for unknown reason');
  }

  Future<String> _headPrimaryFile(User user, List<StorageItem> siList) async {
    if (siList[0].urls == null) {
      throw Exception('Missing URLs from storage service.');
    }
    final headUrl = siList[0].urls!.st;
    final dio =
        Dio(BaseOptions(connectTimeout: Duration(milliseconds: 20000), receiveTimeout: Duration(milliseconds: 15000)));
    var retriesRemaining = 3;
    do {
      retriesRemaining--;
      try {
        var response = await dio.head(headUrl, options: Options(responseType: ResponseType.bytes));
        final etag = response.headers['etag']![0];
        return etag;
      } on DioError catch (e, s) {
        await e.handle('Head primary file', s, retriesRemaining, () async {
          throw KeeLoginRequiredException();
        });
      } on Exception {
        continue;
      }
    } while (retriesRemaining > 0);
    throw KeeUnexpectedException('Failed to head primary file for unknown reason');
  }
}
