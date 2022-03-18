import 'package:keevault/vault_backend/remote_service.dart';

import '../logging/logger.dart';

class MailerService {
  Function? onTokenChange;
  late RemoteService _service;
  final Stage? _stage;
  MailerService(this._stage, this.onTokenChange) {
    _service = RemoteService(_stage, 'mailer');
  }

  Future<bool> signup(String email) async {
    try {
      final response = await _service.postRequest<String>('signup', {'email': email});
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } on Exception catch (ex) {
      l.e('Failed to sign up $email - $ex');
      return false;
    }
  }
}
