import 'package:argon2_ffi_base/argon2_ffi_base.dart';
import 'package:flutter/foundation.dart';
import 'package:keevault/logging/logger.dart';

class FlutterArgon2 extends Argon2 {
  static final singleton = Argon2FfiFlutter();

  @override
  Uint8List argon2(Argon2Arguments args) {
    throw StateError('Use [argon2Async]');
  }

  @override
  Future<Uint8List> argon2Async(Argon2Arguments args) async {
    final started = Stopwatch()..start();
    try {
      l.t('Starting argon2');
      // As of 20250619 and dev environment present at that time (e.g. Flutter 3.29)
      // All of the below implementations take 7-10 seconds to execute, with essentially all of the time taken by Dart internals and none by the actual computation such as _runArgon2. When the same code is executed from a debug session in Android studio, it works instantly.
      //return await Isolate.run(() => _runArgon2(args), debugName: 'argon2');
      return await compute(FlutterArgon2._runArgon2, args);
      //return await compute((args) async => Uint8List.fromList([...args.salt]), args);
      //return await compute((args) async => Uint8List.fromList([...args]), [1, 2]);
    } finally {
      l.d('Finished argon2 in ${started.elapsedMilliseconds}ms');
    }
  }

  static Uint8List _runArgon2(Argon2Arguments args) {
    return singleton.argon2(args);
  }

  @override
  bool get isFfi => true;

  @override
  bool get isImplemented => true;
}
