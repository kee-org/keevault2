import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

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
  String? subscriptionId;

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

  static Future<User> fromEmail(String email) async {
    final user = User();
    user.email = email;
    final prefsFuture = SharedPreferences.getInstance();
    user.emailHashed = await hashString(email, EMAIL_ID_SALT);
    final prefs = await prefsFuture;

    // We need to persistently store the map of email address hash to user ID so that we can
    // allow offline access in the increasingly common case that a user's ID is not that same
    // as their hashed email address. When we "forget" a user, this mapping of non-personally
    // identifiable information will remain on the device ready for if/when they sign in again
    // in future.

    // If a user changes email address and then another person signs up with it later, they
    // would be able to use the original user's device to associate their sign-in credentials
    // with the user ID of the original user. This can't result in abuse of either the KDBX
    // file or Kee Vault authentication service because the remote server can see the real
    // up to date relationship and the KDBX file can only be decrypted if the new user has
    // selected the same password as the old user (in which case they could access the
    // data in any number of alternative ways).
    String? userId;
    try {
      userId = prefs.getString('user.authMaterialUserIdMap.${user.emailHashed}');
    } on Exception {
      // no action required
      // User ID may not be known (e.g. if user has never signed in on this device before)
    }

    // On upgrade from an earlier version, subscribers may only have a locally stored copy of the email
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
      final expiryTimeWithGracePeriod = subValidUntil + 1200000; // 20 mins
      final newestSubExpiryAllowedForNewTrial = max(
          now - (86400 * 548 * 1000), DateTime.utc(2022, 4, 1).millisecondsSinceEpoch); // 18 months or 1st April 2022
      if (expiryTimeWithGracePeriod >= now) {
        return AccountSubscriptionStatus.current;
      } else if (subValidUntil < newestSubExpiryAllowedForNewTrial &&
          subscriptionSource == AccountSubscriptionSource.chargeBee) {
        // We don't allow retrials for anything except Chargebee and user must have
        // set up a subscription first. Thus users who get given a temporary subscription
        // when registering can't later enable a Chargebee trial, even if they never
        // completed their subscription setup from a different source. We'll render
        // "create new subscription" features in future using knowledge of the current
        // device platform rather than the user object.
        return AccountSubscriptionStatus.freeTrialAvailable;
      } else {
        return AccountSubscriptionStatus.expired;
      }
    }
    // Could be that we have yet to authenticate or that this user object represents
    // a user that does not exist in the Kee Vault service
    return AccountSubscriptionStatus.unknown;
  }

  AccountSubscriptionSource get subscriptionSource {
    if (subscriptionId != null) {
      if (subscriptionId!.startsWith('adhoc_')) {
        return AccountSubscriptionSource.adHoc;
      } else if (subscriptionId!.startsWith('cb_')) {
        return AccountSubscriptionSource.chargeBee;
      } else if (subscriptionId!.startsWith('gp_')) {
        return AccountSubscriptionSource.googlePlay;
      } else if (subscriptionId!.startsWith('ap_')) {
        return AccountSubscriptionSource.appleAppStore;
      }
    }
    return AccountSubscriptionSource.unknown;
  }

  List<String> get emailParts {
    if (email?.isEmpty ?? true) return [];
    final parts = email!.split(RegExp(r"[.!#$%&'*+\/=?^_`{|}~@-]"));
    return [...parts, parts.join(''), email!].where((x) => x.length >= 3).toList();
  }
}

enum AccountSubscriptionStatus {
  unknown,
  current,
  expired,
  freeTrialAvailable;

  String displayName() {
    if (this == AccountSubscriptionStatus.current) {
      return 'Active';
    }
    if (this == AccountSubscriptionStatus.expired) {
      return 'Expired';
    }
    if (this == AccountSubscriptionStatus.freeTrialAvailable) {
      return 'Expired (a new free trial is available via Kee Vault / Chargebee)';
    }
    return 'Unknown';
  }
}

enum AccountSubscriptionSource {
  unknown,
  adHoc,
  chargeBee,
  googlePlay,
  appleAppStore;

  String displayName() {
    if (this == AccountSubscriptionSource.adHoc) {
      return 'Custom provider';
    }
    if (this == AccountSubscriptionSource.chargeBee) {
      return 'Kee Vault (Chargebee)';
    }
    if (this == AccountSubscriptionSource.googlePlay) {
      return 'Google';
    }
    if (this == AccountSubscriptionSource.appleAppStore) {
      return 'Apple';
    }
    return 'Unknown';
  }
}

// ignore: constant_identifier_names
const EMAIL_ID_SALT = 'a7d60f672fc7836e94dabbd7000f7ef4e5e72bfbc66ba4372add41d7d46a1c24';
