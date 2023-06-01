import 'package:keevault/logging/logger.dart';

import '../credentials/quick_unlocker.dart';

class KeeException implements Exception {
  final String? cause;
  final dynamic exception;
  StackTrace? stackTrace;

  KeeException([this.cause, this.exception, this.stackTrace]);

  @override
  String toString() => '${runtimeType.toString()} : $cause \nCaused by:\n$exception\nStack Trace:\n$stackTrace';
}

class KeeUnexpectedException extends KeeException {
  KeeUnexpectedException(String cause, [dynamic exception, StackTrace? stackTrace])
      : super(cause, exception, stackTrace);
}

class KeeServiceTransportException extends KeeException {
  String handle(String category) {
    String message;
    if (this is KeeExceededQuotaException) {
      message =
          "$category. There is probably a fault with this app. Please let us know and we'll try to fix it soon. Reason: KeeExceededQuotaException";
      l.w(message);
    } else if (this is KeeInvalidRequestException) {
      message =
          "$category. There is probably a fault with this app. Please let us know and we'll try to fix it soon. Reason: KeeInvalidRequestException";
      l.w(message);
    } else if (this is KeeServerConflictException) {
      message =
          "$category. There is probably a fault with this app. Please let us know and we'll try to fix it soon. Reason: KeeServerConflictException";
      l.w(message);
    } else if (this is KeeServerFailException) {
      message =
          "$category. There may be a fault with the Kee Vault service. Please let us know and we'll try to fix it soon.";
      l.w('$message (500)');
    } else if (this is KeeNotFoundException) {
      message =
          "$category. There may be a fault with the Kee Vault service. Please let us know and we'll try to fix it soon.";
      l.w('$message (404)');
    } else if (this is KeeServerTimeoutException) {
      message =
          '$category. It took too long, probably because your network connection is currently slow or unreliable. Please try again in a minute from a different location.';
      l.i(message);
    } else if (this is KeeServerUnreachableException) {
      message =
          '$category. This is probably because your network connection is currently slow or unreliable. Please try again in a minute from a different location.';
      l.i(message);
    } else {
      message = '$category. Unknown error!';
    }
    return message;
  }
}

class KeeInvalidStateException extends KeeException {}

class KeeLoginRequiredException extends KeeException {
  final QUStatus? quStatus;

  KeeLoginRequiredException({String? cause, this.quStatus, dynamic exception, StackTrace? stackTrace})
      : super(cause, exception, stackTrace);
}

class KeeLoginFailedException extends KeeException {}

class KeeAlreadyRegisteredException extends KeeException {}

class KeeMissingPrimaryDBException extends KeeException {}

class PrimaryKdbxAlreadyExistsException extends KeeException {}

class KeeLoginFailedMITMException extends KeeException {}

class KeeServerFailException extends KeeServiceTransportException {}

class KeeServerUnreachableException extends KeeServiceTransportException {}

class KeeServerTimeoutException extends KeeServiceTransportException {}

class KeeNotFoundException extends KeeServiceTransportException {}

class KeeServerConflictException extends KeeServiceTransportException {}

class KeeExceededQuotaException extends KeeServiceTransportException {}

class KeeInvalidRequestException extends KeeServiceTransportException {}

class KeeMaybeOfflineException extends KeeException {}

class KeeInvalidJWTException extends KeeException {}

class KeeInvalidClaimException extends KeeException {}

class KeeInvalidClaimIssuerException extends KeeException {}

class KeeSubscriptionExpiredException extends KeeException {}

class KeeAccountUnverifiedException extends KeeException {}
