class ExpiringCachedCredentials {
  String kdbxBase64Hash;
  String userPassKey;

  // After this time, the user will need to enter their master password again
  int expiry;

  // Result of Argon2 stretching (only stored locally and only in locations in which everything
  // necessary to trivially re-derive this is already present)
  String kdbxKdfResultBase64;

  // The key in which we can prepopulate the above KDF result to accelerate quick unlocking
  String kdbxKdfCacheKey;

  ExpiringCachedCredentials(
      this.kdbxBase64Hash, this.kdbxKdfCacheKey, this.kdbxKdfResultBase64, this.userPassKey, this.expiry);

  ExpiringCachedCredentials.fromJson(Map<String, dynamic> data)
      : kdbxBase64Hash = data['kdbxBase64Hash'],
        kdbxKdfCacheKey = data['kdbxKdfCacheKey'],
        kdbxKdfResultBase64 = data['kdbxKdfResultBase64'],
        userPassKey = data['userPassKey'],
        expiry = data['expiry'];

  Map<String, dynamic> toJson() => {
        'kdbxBase64Hash': kdbxBase64Hash,
        'kdbxKdfCacheKey': kdbxKdfCacheKey,
        'kdbxKdfResultBase64': kdbxKdfResultBase64,
        'userPassKey': userPassKey,
        'expiry': expiry,
      };
}
