import 'package:collection/collection.dart' show IterableExtension;
import 'package:keevault/vault_backend/remote_service.dart';

class EnvironmentConfig {
  static const stage = String.fromEnvironment('KEEVAULT_STAGE', defaultValue: 'dev');
  static const channel = String.fromEnvironment('KEEVAULT_CHANNEL', defaultValue: 'dev');

  static get webUrl {
    switch (stage) {
      case 'dev':
        return 'https://app-dev.kee.pm';
      case 'beta':
        return 'https://app-beta.kee.pm';
      case 'prod':
        return 'https://keevault.pm';
      default:
        throw Exception('Unknown stage defined');
    }
  }
}

extension EnumParserStage on String {
  Stage? toStage() {
    return Stage.values.firstWhereOrNull((e) => e.toString().toLowerCase() == 'stage.$this'.toLowerCase());
  }
}
