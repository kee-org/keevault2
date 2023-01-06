import 'dart:math';

import 'login_parameters.dart';
import 'account_verification_status.dart';
import 'features.dart';
import 'tokens.dart';
import 'utils.dart';

class User {
  String? email;
  String? emailHashed;
  String? id;
  String? idB64url;
  String? salt;
  String? passKey;
  List<String>? kms;
  Features? features;
  Tokens? tokens;
  LoginParameters? loginParameters;
  AccountVerificationStatus verificationStatus = AccountVerificationStatus.never;

  // hashedMasterKey may come from a combination of password and keyfile in
  // future but for now, we require a text password
  // static Future<User> fromEmailAndKey(String email, List<int> hashedMasterKey) async {
  //   final user = User();
  //   user.email = email;
  //   user.passKey = await derivePassKey(email, hashedMasterKey);
  //   user.emailHashed = await hashString(email, EMAIL_ID_SALT);
  //   user.idB64url =
  //       user.emailHashed!.replaceAll(RegExp(r'\+'), '-').replaceAll(RegExp(r'/'), '_').replaceAll(RegExp(r'='), '.');
  //   return user;
  // }

  static Future<User> fromEmail(String email, String? userId) async {
    final user = User();
    user.email = email;
    user.emailHashed = await hashString(email, EMAIL_ID_SALT);

    // On upgrade from earlier version, subscribers may only have a locally stored copy of the email
    // address, rather than their user ID, however, since they can't have modified their email address
    // using the old version, we can safely assume their emailHashed still equals their user.emailHashed
    // property. Perhaps someone upgrading a different device after an email address change will
    // experience a problem but that'll be rare and signing out and back in again should resolve it
    // for them since they'll then load the user id after loginFinish.
    user.id = userId ?? user.emailHashed;

    user.idB64url = user.id!.replaceAll(RegExp(r'\+'), '-').replaceAll(RegExp(r'/'), '_').replaceAll(RegExp(r'='), '.');
    return user;
  }

  Future<void> attachKey(List<int> hashedMasterKey) async {
    passKey = await derivePassKey(email!, hashedMasterKey);
  }

  AccountSubscriptionStatus get subscriptionStatus {
    final subValidUntil = features?.validUntil;
    if (subValidUntil != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final newestSubExpiryAllowedForNewTrial = max(
          now - (86400 * 548 * 1000), DateTime.utc(2022, 4, 1).millisecondsSinceEpoch); // 18 months or 1st April 2022
      if (subValidUntil >= now) {
        return AccountSubscriptionStatus.current;
      } else if (subValidUntil < newestSubExpiryAllowedForNewTrial) {
        return AccountSubscriptionStatus.freeTrialAvailable;
      } else {
        return AccountSubscriptionStatus.expired;
      }
    }
    // Could be that we have yet to authenticate or that this user object represents
    // a user that does not exist in the Kee Vault service
    return AccountSubscriptionStatus.unknown;
  }
}

enum AccountSubscriptionStatus { unknown, current, expired, freeTrialAvailable }

// ignore: constant_identifier_names
const EMAIL_ID_SALT = 'a7d60f672fc7836e94dabbd7000f7ef4e5e72bfbc66ba4372add41d7d46a1c24';
