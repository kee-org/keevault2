import 'dart:convert';
import 'package:keevault/vault_backend/remote_service.dart';
import '../locked_vault_file.dart';
import 'exceptions.dart';
import 'storage_item.dart';
import 'tokens.dart';
import 'user.dart';

typedef TokenRefreshFunctionForUser = Future<Tokens> Function(User user, bool notifyListeners);

class StorageService {
  late RemoteService _service;
  List<StorageItem>? _cachedStorageItemLinks;
  String? _cachedStorageToken;
  late DateTime _cachedTime;
  final Stage? _stage;
  final TokenRefreshFunctionForUser _userRefresh;
  StorageService(this._stage, this._userRefresh) {
    _service = RemoteService(_stage, 'storage');
    _cachedTime = DateTime.fromMillisecondsSinceEpoch(0);
  }

  // any client utilising this library should perform a sanity check that ensures we're not called if
  // we have no storage token but if not for any reason, the underlying request will be made without
  // the necessary authentication token and a max-retry (3ish) algorithm will kick in, returning an
  // authorisation error to the calling client.
  //
  // An interesting edge case is when the user's account expires while their app session is still
  // active. Once the storage token expires and a request is made for a new one, the end result
  // will be an authorisation exception and the user will have to sign in again, at which point
  // the usual sign-in message explaining the problem can be displayed to them.

  Future<List<StorageItem>> list(User user) async {
    String? storageToken;
    if (user.tokens != null && user.tokens!.storage != null) storageToken = user.tokens!.storage;

    if (storageToken != _cachedStorageToken ||
        _cachedStorageItemLinks == null ||
        _cachedTime.isBefore(DateTime.now().subtract(Duration(minutes: 4)))) {
      final request = _service.getRequest<String>('meta/', storageToken, () => _userRefresh(user, true));
      final response = await request;
      final list = json.decode(response.data!);
      List<StorageItem> siList = list.map<StorageItem>((s) => StorageItem.fromJson(s)).toList();

      // Don't cache empty responses (indicates user is part-way through an account reset process
      // and will want a more interactive update than we usually offer)
      if (siList.isNotEmpty) {
        _cachedStorageItemLinks = siList;
        _cachedStorageToken = user.tokens?.storage;
        _cachedTime = DateTime.now();
      } else {
        _cachedStorageItemLinks = null;
      }
    }
    return _cachedStorageItemLinks ?? [];
  }

  Future<StorageItem> create(User user, LockedVaultFile vault, {String name = 'My Kee Vault'}) async {
    String? storageToken;
    if (user.tokens != null && user.tokens!.storage != null) storageToken = user.tokens!.storage;
    if (user.id == null) {
      throw Exception('User ID of owner not known');
    }

    final si = StorageItem.fromUserId(user.id!);
    si.name = name;
    final emptyVault = base64.encode(vault.kdbxBytes);
    final request = _service.postRequest<String>(
      'meta/',
      {'si': si, 'emptyVault': emptyVault, 'optional': true},
      storageToken,
      () => _userRefresh(user, true),
    );
    final response = await request;
    if (response.statusCode == 204) {
      throw PrimaryKdbxAlreadyExistsException();
    }
    final body = json.decode(response.data!);
    StorageItem siResponse = StorageItem.fromJson(body);
    return siResponse;
  }
}
