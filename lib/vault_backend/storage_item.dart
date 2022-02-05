class StorageType {
  static const String keeS3 = 'kee-s3';
}

class URLlist {
  String ul;
  String dl;
  String st;

  URLlist.fromJson(Map<String, dynamic> data)
      : ul = data['ul'],
        dl = data['dl'],
        st = data['st'];
}

class StorageItem {
  String emailHashed;
  int schemaVersion;
  String? id;
  String? location;
  String type;
  URLlist? urls;
  String? name;

  StorageItem(
      {required this.emailHashed,
      this.id,
      this.location,
      this.name,
      required this.schemaVersion,
      required this.type,
      this.urls});

  static fromEmailHash(String emailHashed) {
    return StorageItem(emailHashed: emailHashed, schemaVersion: 1, type: StorageType.keeS3);
  }

  static fromEmailHashAndId(String emailHashed, String id) {
    return StorageItem(emailHashed: emailHashed, schemaVersion: 1, type: StorageType.keeS3, id: id);
  }

  StorageItem.fromJson(Map<String, dynamic> data)
      : id = data['id'],
        name = data['name'],
        location = data['location'],
        type = data['type'],
        emailHashed = data['emailHashed'],
        schemaVersion = data['schemaVersion'],
        urls = URLlist.fromJson(data['urls']);
}
