import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:keevault/vault_backend/exceptions.dart';
import 'package:keevault/extension_methods.dart';
import 'tokens.dart';

// ignore: constant_identifier_names
enum HttpMethod { GET, POST, PUT }

enum Stage { dev, beta, prod }

typedef TokenRefreshFunction = Future<Tokens> Function();

const Map<Stage, Map<String, String>> endpoints = {
  Stage.dev: {
    'storage': 'https://s-dev.kee.pm/',
    'identity': 'https://id-dev.kee.pm/',
    'messages': 'https://msg-dev.kee.pm/',
    'reset': 'https://resetacc-dev.kee.pm/',
    'mailer': 'https://mailerapi-dev.kee.pm/'
  },
  Stage.beta: {
    'storage': 'https://s-beta.kee.pm/',
    'identity': 'https://id-beta.kee.pm/',
    'messages': 'https://msg-beta.kee.pm/',
    'reset': 'https://resetacc-beta.kee.pm/',
    'mailer': 'https://mailerapi-beta.kee.pm/'
  },
  Stage.prod: {
    'storage': 'https://s.kee.pm/',
    'identity': 'https://id.kee.pm/',
    'messages': 'https://msg.kee.pm/',
    'reset': 'https://resetacc.kee.pm/',
    'mailer': 'https://mailerapi.kee.pm/'
  }
};

class RemoteService {
  final Dio _dio;
  final String _name;

  RemoteService._(this._name, this._dio);

  factory RemoteService(_stage, _name) {
    var endpoint = endpoints[_stage]![_name]!;
    var options = BaseOptions(
      baseUrl: endpoint,
      connectTimeout: 20000,
      receiveTimeout: 30000,
      contentType: 'text/plain',
    );
    return RemoteService._(_name, Dio(options));
  }

  Future<Response<T>> getRequest<T>(String path, [String? token, TokenRefreshFunction? tokenRefresh]) async {
    var config = Options(method: 'GET');
    return _doRequest<T>(config, path, token: token, tokenRefresh: tokenRefresh);
  }

  Future<Response<T>> postRequest<T>(String path, Object obj, [String? token, TokenRefreshFunction? tokenRefresh]) {
    var config = Options(method: 'POST');
    obj = json.encode(obj);
    return _doRequest<T>(config, path, token: token, tokenRefresh: tokenRefresh, obj: obj);
  }

  Future<Response<T>> putRequest<T>(String path, Object obj, [String? token, TokenRefreshFunction? tokenRefresh]) {
    var config = Options(method: 'PUT');
    obj = json.encode(obj);
    return _doRequest<T>(config, path, token: token, tokenRefresh: tokenRefresh, obj: obj);
  }

  String? _findRequestToken(Tokens tokens) {
    switch (_name) {
      case 'identity':
        return tokens.identity;
      case 'forms':
        return tokens.forms;
      case 'client':
        return tokens.client;
      case 'storage':
        return tokens.storage;
      case 'messages':
        return tokens.identity;
      case 'mailer':
        return null;
      default:
        throw Exception('Invalid RemoteService configuration. $_name token not known.');
    }
  }

  //TODO:f: Perhaps introduce a delay for all but the first retry? varying based on type of error received.
  Future<Response<T>> _doRequest<T>(Options config, String path,
      {String? token, TokenRefreshFunction? tokenRefresh, Object? obj}) async {
    var shouldGetNewTokenIfRequired = tokenRefresh != null;
    var haveAToken = token?.isNotEmpty ?? false;
    if (shouldGetNewTokenIfRequired && !haveAToken) {
      // If this fails, the exception will flow up to whatever made the original request
      // Retries are handled within the refresh function
      var tokens = await tokenRefresh();
      token = _findRequestToken(tokens);
      haveAToken = token?.isNotEmpty ?? false;
      if (!haveAToken) {
        // Can happen if user's subscription has expired while signed-in to the app
        throw KeeSubscriptionExpiredException();
      }
    }
    var retriesRemaining = 3;
    do {
      retriesRemaining--;
      try {
        var response =
            await _dio.request<T>(path, queryParameters: {if (haveAToken) 't': token}, options: config, data: obj);
        return response;
      } on DioError catch (e, s) {
        await e.handle(_name, s, retriesRemaining, () async {
          if (shouldGetNewTokenIfRequired && retriesRemaining == 2) {
            // We make one attempt to reauthenticate in case the token has
            // just expired since last used
            // Any exceptions thrown here won't be caught by the general
            // catch below so will be raised to the service caller
            var tokens = await tokenRefresh();
            token = _findRequestToken(tokens);
            haveAToken = token?.isNotEmpty ?? false;
            return;
          }
          throw KeeLoginRequiredException();
        });
      } on Exception {
        continue;
      }
    } while (retriesRemaining > 0);
    throw KeeUnexpectedException('Failed to send message for unknown reason');
  }
}
