import 'expiring_cached_credential_hash.dart';

class ExpiringCachedCredentialHashMap {
  final Map<String, ExpiringCachedCredentials> _map;

  ExpiringCachedCredentialHashMap(this._map);

  ExpiringCachedCredentialHashMap.fromJson(Map<String, dynamic> data)
      : _map = data.map((u, c) => MapEntry(u, ExpiringCachedCredentials.fromJson(c)));

  Map<String, dynamic> toJson() => _map.map((u, c) => MapEntry(u, c.toJson()));

  update(String user, ExpiringCachedCredentials? creds) {
    if (creds == null) {
      _map.remove(user);
    } else {
      _map[user] = creds;
    }
  }

  ExpiringCachedCredentials? forUser(String user) {
    return _map[user];
  }
}
