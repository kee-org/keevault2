import 'package:uuid/uuid.dart';

class UuidUtil {
  static final _uuid = Uuid();

  static String createNonCryptoUuid() => _uuid.v4();
}
