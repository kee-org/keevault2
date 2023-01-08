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
  String userId;
  int schemaVersion;
  String? id;
  String? location;
  String type;
  URLlist? urls;
  String? name;

  StorageItem(
      {required this.userId,
      this.id,
      this.location,
      this.name,
      required this.schemaVersion,
      required this.type,
      this.urls});

  static fromUserId(String userId) {
    return StorageItem(userId: userId, schemaVersion: 1, type: StorageType.keeS3);
  }

  static fromUserIdAndId(String userId, String id) {
    return StorageItem(userId: userId, schemaVersion: 1, type: StorageType.keeS3, id: id);
  }

  StorageItem.fromJson(Map<String, dynamic> data)
      : id = data['id'],
        name = data['name'],
        location = data['location'],
        type = data['type'],
        userId = data['emailHashed'],
        schemaVersion = data['schemaVersion'],
        urls = URLlist.fromJson(data['urls']);
}
