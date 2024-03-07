import 'dart:convert' show base64Url, json, utf8;
import 'dart:typed_data';
import 'package:keevault/vault_backend/exceptions.dart';
import 'package:keevault/logging/logger.dart';
import 'package:crypto_keys/crypto_keys.dart';
import 'claim.dart';
import 'remote_service.dart';

class VerificationResult {
  String audience;
  VerificationResult({required this.audience});
}

class ClientVerificationResult extends VerificationResult {
  Claim claim;
  ClientVerificationResult({required super.audience, required this.claim});
}

class JWT {
  static Claim parse(String sig) {
    final sigParts = sig.split('.');

    if (sigParts.length != 3) {
      throw KeeInvalidJWTException();
    }

    final claimJSON = utf8.decode(base64Url.decode(base64Url.normalize(sigParts[1])));
    return Claim.fromJson(json.decode(claimJSON));
  }

  static Future<VerificationResult> verify(String sig, Stage? expectedStage) async {
    final sigParts = sig.split('.');

    if (sigParts.length != 3) {
      throw KeeInvalidJWTException();
    }

    final claimJSON = utf8.decode(base64Url.decode(base64Url.normalize(sigParts[1])));
    Claim claim;

    try {
      claim = Claim.fromJson(json.decode(claimJSON));
      if (claim.aud != 'client') {
        return VerificationResult(audience: claim.aud);
      }
    } catch (e) {
      throw KeeInvalidClaimException();
    }

    final data = utf8.encode('${sigParts[0]}.${sigParts[1]}');

    // Untrusted source might tell us which key to use but they can't actually pick the
    // key material so we only have to defend against cross-stage server-side breaches
    if ((expectedStage == Stage.dev && claim.iss != 'idDev') ||
        (expectedStage == Stage.beta && claim.iss != 'idBeta') ||
        (expectedStage == Stage.prod && claim.iss != 'idProd')) {
      throw KeeInvalidClaimIssuerException();
    }
/* spell-checker: disable */
    Map<String, String> jwk;
    switch (claim.iss) {
      case 'idProd':
        jwk = {
          'kty': 'EC',
          'crv': 'P-256',
          'x': 'O6bWMktjPnOtZAkmz9NzMTO9O2VzuECTa9Jj5g90QSA',
          'y': 'aIE-8dLpJIoAnLIzH1XDCPxK_asKtIC_fVlSLJyGpcg',
        };
        break;
      case 'idBeta':
        jwk = {
          'kty': 'EC',
          'crv': 'P-256',
          'x': 'CinRkFHv6IGNcd52YlzD3BF_WruIMs-6Nn5oI7QmgjU',
          'y': 'pJ66MRPoCC2MUBFdYyRqGPfw3pZEnPGtHVhvspLTVDA',
        };
        break;
      case 'idDev':
        jwk = {
          'kty': 'EC',
          'crv': 'P-256',
          'x': 'mk8--wDgrkPyHttzjQH6jxmjfZS9MaHQ5Qzj53OnNLo',
          'y': 'XAFQCFwKL7qrV27vI1tug3X2v50grAk_ioieHRe8h18',
        };
        break;
      default:
        throw KeeInvalidClaimIssuerException();
    }
/* spell-checker: enable */

    var isValid = false;
    try {
      final keyPair = KeyPair.fromJwk(jwk);
      final key = keyPair.publicKey;
      final verifier = key!.createVerifier(algorithms.signing.ecdsa.sha256);
      final signature = Signature(base64Url.decode(base64Url.normalize(sigParts[2])));
      isValid = verifier.verify(Uint8List.fromList(data), signature);
    } catch (e, stacktrace) {
      l.e('Cryptography error during JWT verification', error: e, stackTrace: stacktrace);
      throw KeeInvalidJWTException();
    }

    if (!isValid) {
      l.e('JWT signature did not verify');
      throw KeeInvalidJWTException();
    }

    return ClientVerificationResult(claim: claim, audience: claim.aud);
  }
}
