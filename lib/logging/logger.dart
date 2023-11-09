import 'package:logger/logger.dart';
import 'package:logging/logging.dart' as logging;

class KeeVaultLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    assert(() {
      // ignore: avoid_print
      event.lines.forEach(print);
      return true;
    }());
    LogConsole.add(event, bufferSize: 1000);
  }
}

Logger getLogger() {
  return Logger(
    printer: SimplePrinter(printTime: false, colors: false),
    output: KeeVaultLogOutput(),
    filter: ProductionFilter(),
  );
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
