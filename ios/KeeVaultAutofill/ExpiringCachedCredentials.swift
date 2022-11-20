import Foundation

struct ExpiringCachedCredentials: Decodable {
    let kdbxBase64Hash: String;
    let userPassKey: String;
    let kdbxKdfResultBase64: String;
    let kdbxKdfCacheKey: String;
    let expiry: Int;
}
