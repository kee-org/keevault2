class Claim {
  String sub;
  String iss;
  String aud;
  int exp;
  int iat;
  List<String> features;
  int featureExpiry;

  Claim.fromJson(Map<String, dynamic> data)
      : sub = data['sub'],
        iss = data['iss'],
        aud = data['aud'],
        exp = data['exp'],
        iat = data['iat'],
        featureExpiry = data['featureExpiry'],
        features = List<String>.from(data['features']);
}
