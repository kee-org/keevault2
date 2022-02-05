import 'dart:convert';
import 'package:keevault/vault_backend/remote_service.dart';
import 'storage_item.dart';
import 'tokens.dart';
import 'user.dart';

typedef TokenRefreshFunctionForUser = Future<Tokens> Function(User user);

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
  // authorisation error to the calling client

  Future<List<StorageItem>> list(User user) async {
    String? storageToken;
    if (user.tokens != null && user.tokens!.storage != null) storageToken = user.tokens!.storage;

    if (storageToken != _cachedStorageToken ||
        _cachedStorageItemLinks == null ||
        _cachedTime.isBefore(DateTime.now().subtract(Duration(minutes: 4)))) {
      final request = _service.getRequest<String>('meta/', storageToken, () => _userRefresh(user));
      final response = await request;
      final list = json.decode(response.data!);
      _cachedStorageItemLinks = list.map<StorageItem>((s) => StorageItem.fromJson(s)).toList();
      _cachedStorageToken = user.tokens?.storage;
      _cachedTime = DateTime.now();
    }
    return _cachedStorageItemLinks ?? [];
  }
}
