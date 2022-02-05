import 'package:srp/types.dart';

class LoginParameters {
  Ephemeral clientEphemeral;
  String B;
  String authId;
  String nonce;

  LoginParameters({required this.clientEphemeral, required this.B, required this.authId, required this.nonce});
}
