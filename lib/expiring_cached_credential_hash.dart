class ExpiringCachedCredentials {
  String kdbxBase64Hash;
  String userPassKey;

  // After this time, the user will need to enter their master password again
  int expiry;

  ExpiringCachedCredentials(this.kdbxBase64Hash, this.userPassKey, this.expiry);

  ExpiringCachedCredentials.fromJson(Map<String, dynamic> data)
      : kdbxBase64Hash = data['kdbxBase64Hash'],
        userPassKey = data['userPassKey'],
        expiry = data['expiry'];

  Map<String, dynamic> toJson() => {
        'kdbxBase64Hash': kdbxBase64Hash,
        'userPassKey': userPassKey,
        'expiry': expiry,
      };
}
