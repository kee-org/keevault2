import 'package:logger/logger.dart';
import 'package:logging/logging.dart' as logging;

import 'kee_log_printer.dart';
import 'log_console.dart';

class KeeVaultLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // Avoid printing to console in production (UI console / share feature can be used instead)
    assert(() {
      // ignore: avoid_print
      event.lines.forEach(print);
      return true;
    }());
  }
}

Logger getLogger() {
  // Maybe output to a file in future? Need to work out where to safely log it,
  // and refactor log startup to be async and ensure writing from multiple
  // isolates doesn't corrupt the log file or crash.
  final lg = Logger(
    printer: KeeLogPrinter(printTime: true, colors: false),
    output: KeeVaultLogOutput(),
    filter: ProductionFilter(),
  );
  LogConsole.init(bufferSize: 10000);
  return lg;
}

final l = getLogger();

void recordLibraryLogs() {
  logging.Logger.root.level = logging.Level.FINEST;
  logging.Logger.root.onRecord.listen((record) {
    final message = '${record.loggerName}: ${record.message}';
    if (record.level == logging.Level.SHOUT) {
      l.f(message);
    } else if (record.level == logging.Level.SEVERE) {
      l.e(message);
    } else if (record.level == logging.Level.WARNING) {
      l.w(message);
    } else if (record.level == logging.Level.CONFIG || record.level == logging.Level.INFO) {
      l.i(message);
    } else if (record.level == logging.Level.FINE) {
      l.d(message);
    } else {
      l.t(message);
    }
  });
}
