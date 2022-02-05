import 'login_parameters.dart';
import 'account_verification_status.dart';
import 'features.dart';
import 'tokens.dart';
import 'utils.dart';

class User {
  String? email;
  String? emailHashed;
  String? emailHashedB64url;
  String? salt;
  String? passKey;
  List<String>? kms;
  Features? features;
  Tokens? tokens;
  LoginParameters? loginParameters;
  AccountVerificationStatus verificationStatus = AccountVerificationStatus.never;

  // hashedMasterKey may come from a combination of password and keyfile in
  // future but for now, we require a text password
  static Future<User> fromEmailAndKey(String email, List<int> hashedMasterKey) async {
    final user = User();
    user.email = email;
    user.passKey = await derivePassKey(email, hashedMasterKey);
    user.emailHashed = await hashString(email, EMAIL_ID_SALT);
    user.emailHashedB64url =
        user.emailHashed!.replaceAll(RegExp(r'\+'), '-').replaceAll(RegExp(r'/'), '_').replaceAll(RegExp(r'='), '.');
    return user;
  }

  static Future<User> fromEmail(String email) async {
    final user = User();
    user.email = email;
    user.emailHashed = await hashString(email, EMAIL_ID_SALT);
    user.emailHashedB64url =
        user.emailHashed!.replaceAll(RegExp(r'\+'), '-').replaceAll(RegExp(r'/'), '_').replaceAll(RegExp(r'='), '.');
    return user;
  }

  Future<void> attachKey(List<int> hashedMasterKey) async {
    passKey = await derivePassKey(email!, hashedMasterKey);
  }
}

// ignore: constant_identifier_names
const EMAIL_ID_SALT = 'a7d60f672fc7836e94dabbd7000f7ef4e5e72bfbc66ba4372add41d7d46a1c24';
