import 'dart:developer';

import 'package:logger/logger.dart';
import 'package:logging/logging.dart' as dart_log;

class PrettierConsoleOutput extends LogOutput {
  final _lvlMapping = {
    Level.nothing: dart_log.Level.ALL.value,
    Level.verbose: dart_log.Level.FINE.value,
    Level.debug: dart_log.Level.CONFIG.value,
    Level.info: dart_log.Level.INFO.value,
    Level.warning: dart_log.Level.WARNING.value,
    Level.error: dart_log.Level.SEVERE.value,
    Level.wtf: dart_log.Level.SHOUT.value,
  };

  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      log(line, level: _lvlMapping[event.level]!);
    }
  }
}
