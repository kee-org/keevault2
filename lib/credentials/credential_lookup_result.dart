import 'package:kdbx/kdbx.dart';

import 'quick_unlocker.dart';

class CredentialLookupResult {
  final Credentials? credentials;
  final QUStatus quStatus;

  CredentialLookupResult({required this.credentials, required this.quStatus});
}
