import 'dart:typed_data';
import 'package:kdbx/kdbx.dart';
import 'vault_backend/utils.dart';
import 'package:argon2_ffi_base/argon2_ffi_base.dart';

class KeeVaultKdfCache extends KdfCache {
  static final KeeVaultKdfCache _singleton = KeeVaultKdfCache._internal();

  factory KeeVaultKdfCache() {
    return _singleton;
  }

  KeeVaultKdfCache._internal();

  final _cache = <String, Uint8List>{};

  void putItemByKey(String key, Uint8List result) {
    _cache[key] = result;
  }

  Uint8List? getItemByKey(String key) {
    return _cache[key];
  }

  @override
  Future<void> putItem(Argon2Arguments a, Uint8List result) async {
    final key = await argon2ArgumentsKey(a);
    _cache[key] = result;
  }

  @override
  Future<Uint8List?> getResult(Argon2Arguments a) async {
    final key = await argon2ArgumentsKey(a);
    return _cache[key];
  }

  @override
  Future<String> argon2ArgumentsKey(Argon2Arguments a) async {
    return await hashBytes(
        Uint8List.fromList([...a.key, ...a.salt, a.memory, a.iterations, a.length, a.parallelism, a.type, a.version]));
  }
}
