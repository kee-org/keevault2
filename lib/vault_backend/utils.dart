// ignore_for_file: constant_identifier_names

import 'dart:convert' show base64, utf8;
import 'dart:typed_data';
import 'package:convert/convert.dart' show hex;
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

final sha256Digester = SHA256Digest();

Future<String> hashString(String text, [String salt = '']) async {
  final msgBuffer = utf8.encode(salt + text);
  final hash = sha256Digester.process(Uint8List.fromList(msgBuffer));
  return base64.encode(hash);
}

Future<String> hashBytes(Uint8List bytes) async {
  final hash = sha256Digester.process(bytes);
  return base64.encode(hash);
}

Future<String> hashStringToHex(String text, [String salt = '']) async {
  final msgBuffer = utf8.encode(salt + text);
  final hash = sha256Digester.process(Uint8List.fromList(msgBuffer));
  return hex.encode(hash);
}

Future<String> stretchByteArray(List<int> byteArray, String salt) async {
  final saltArray = base64.decode(base64.normalize(salt));
  Uint8List derivedKey = Uint8List(32);
  final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
  pbkdf2.init(Pbkdf2Parameters(saltArray, 500, 32));
  pbkdf2.deriveKey(Uint8List.fromList(byteArray), 0, derivedKey, 0);
  return base64.encode(derivedKey);
}

Future<String> derivePassKey(String email, List<int> hashedMasterKey) async {
  final emailHash = sha256Digester.process(Uint8List.fromList(utf8.encode(EMAIL_AUTH_SALT + email)));
  final passHash = sha256Digester.process(Uint8List.fromList([...hex.decode(PASS_AUTH_SALT), ...hashedMasterKey]));
  return stretchByteArray([...emailHash, ...passHash], STRETCH_SALT);
}

Future<String> calculateCostNonce(int costFactor, String costTarget) async {
  var nonce = 0;
  var h = await hashStringToHex(costTarget + nonce.toString());
  while (!checkNonce(h, costFactor)) {
    nonce++;
    h = await hashStringToHex(costTarget + nonce.toString());
  }
  return nonce.toString();
}

bool checkNonce(String proposedSolution, int costFactor) {
  int i;
  for (i = 0; i < proposedSolution.length; i++) {
    if (proposedSolution[i] != '0') break;
  }
  return i >= costFactor;
}

String base642hex(String input) {
  return hex.encode(base64.decode(base64.normalize(input)));
}

String hex2base64(String input) {
  return base64.encode(hex.decode(input));
}

const EMAIL_AUTH_SALT = '4e1cc573ed8cd48a19beb6ec6729be6c7a19c91a40c6483be3c9d671b5fbae9a';
const PASS_AUTH_SALT = 'a90b6364315150a39a60d324bfafe6f4444deb15bee194a6d34726c31493dacc';
const STRETCH_SALT = '509d04a4c27ea9947335e7aa45aabe4fcc2222c87daf0f0520712cefb000124a';
