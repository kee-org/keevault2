import 'package:keevault/vault_backend/exceptions.dart';
import 'package:keevault/vault_backend/remote_service.dart';
import 'tokens.dart';
import 'user.dart';

typedef TokenRefreshFunctionForUser = Future<Tokens> Function(User user, bool notifyListeners);

class SubscriptionService {
  late RemoteService _service;
  final Stage? _stage;
  final TokenRefreshFunctionForUser _userRefresh;
  SubscriptionService(this._stage, this._userRefresh) {
    _service = RemoteService(_stage, 'subscriptions');
  }

  Future<bool> associate(User user, int subscriptionSource, String validationData) async {
    if (user.tokens != null && user.tokens!.identity != null && user.tokens!.identity!.isNotEmpty) {
      try {
        final response = await _service.postRequest<String>(
            'associate',
            {'source': subscriptionSource, 'validationData': validationData},
            user.tokens!.identity,
            () => _userRefresh(user, false));
        return response.statusCode == 200;
      } on KeeExceededQuotaException {
        throw KeeSubscriptionExpiredException();
      }
    } else {
      throw KeeLoginRequiredException();
    }
  }
}
