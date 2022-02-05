import 'account_verification_status.dart';

class SRP1 {
  int? costFactor;
  String? costTarget;
  String B;
  String authId;
  String salt;
  List<String> kms;

  SRP1.fromJson(Map<String, dynamic> data)
      : costFactor = data['costFactor'],
        costTarget = data['costTarget'],
        B = data['B'],
        authId = data['authId'],
        salt = data['salt'],
        kms = List<String>.from(data['kms']);
}

class SRP2 {
  String proof;
  String authId;
  // ignore: non_constant_identifier_names
  List<String> JWTs;
  AccountVerificationStatus verificationStatus;

  SRP2.fromJson(Map<String, dynamic> data)
      : proof = data['proof'],
        authId = data['authId'],
        verificationStatus = AccountVerificationStatus.values[data['verificationStatus']],
        JWTs = List<String>.from(data['JWTs']);
}
