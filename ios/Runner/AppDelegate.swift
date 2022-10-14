import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let autofillChannel = FlutterMethodChannel(name: "com.keevault.keevault/autofill",
                                                   binaryMessenger: controller.binaryMessenger)
        autofillChannel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            // This method is invoked on the UI thread.
            switch call.method{
            case "setAllEntries":
                guard let args = call.arguments as? Dictionary<String, Any> else {
                    result(FlutterError.init(code: "bad args", message: nil, details: nil))
                    break
                  }
                guard let kvEntries = args["entries"] as? [String] else {
                    result(FlutterError.init(code: "missing entries argument", message: nil, details: nil))
                    break
                } //TODO: needs to be a JSON String instead?
                  
                let entries = kvEntries.compactMap {
                    try? JSONDecoder().decode(KeeVaultEntryIos.self, from: Data($0.utf8))
                }
                do {
                    try addEntries(entries: entries)
                } catch _ {
                    
                }
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        })
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}

private func addEntries(entries: [KeeVaultEntryIos]) throws {
    // hack deletes all keychain items
    let accessGroup = Bundle.main.infoDictionary!["KeeVaultSharedEntriesAccessGroup"] as! String
    let spec: NSDictionary = [kSecClass as String: kSecClassInternetPassword,
                              kSecAttrAccessGroup as String: accessGroup]
        SecItemDelete(spec)
    
    for entry in entries {
        try addEntry(entry: entry)
        //TODO: Find all in keychain and compare timestamps for updates and delete any that are no longer in list of entries
    }
//
//    try addEntry(account: "test username", passwordString: "password", server: "bbc.co.uk", uuid: "123450", title: "title bbc 1");
//    try addEntry(account: "test username 2", passwordString: "password", server: "account.bbc.com", uuid: "123451", title: "title bbc 2");
//    try addEntry(account: "test username", passwordString: "password", server: "app.bbc.co.uk", uuid: "123452", title: "title bbc 3");
//    try addEntry(account: "test username 2", passwordString: "password", server: "bbc.com", uuid: "123453", title: "title bbc 4");
//    try addEntry(account: "test username", passwordString: "password", server: "www.github.com", uuid: "123454", title: "title github 1");
//    try addEntry(account: "test username", passwordString: "password", server: "app.github.com", uuid: "123455", title: "title github 2");
//    try addEntry(account: "test username", passwordString: "password", server: "github.com", uuid: "123456", title: "title github 3");
//    try addEntry(account: "test username 4", passwordString: "password", server: "github.com", uuid: "123457", title: "title github 4");
//    try addEntry(account: "test username 1", passwordString: "password", server: "google.co.uk", uuid: "123458", title: "title google 1");
//    try addEntry(account: "test username 2", passwordString: "password", server: "google.co.uk", uuid: "123459", title: "title google 2");
//    try addEntry(account: "test username 3", passwordString: "password", server: "google.co.uk", uuid: "1234510", title: "title google 3");
//    try addEntry(account: "test username 4", passwordString: "password", server: "google.co.uk", uuid: "1234511", title: "title google 4");
//    try addEntry(account: "test username 5", passwordString: "password", server: "google.co.uk", uuid: "1234512", title: "title google 5");
//    try addEntry(account: "test username 6", passwordString: "password", server: "google.co.uk", uuid: "1234513", title: "title google 6");
//    try addEntry(account: "test username 7", passwordString: "password", server: "google.co.uk", uuid: "1234514", title: "title google 7");
//    try addEntry(account: "test username 8", passwordString: "password", server: "google.co.uk", uuid: "1234515", title: "title google 8");
//
}


private func addEntry(entry: KeeVaultKeychainEntry) throws {
    try addEntry(account: entry.username, passwordString: entry.password ?? "", server: entry.server, uuid: entry.uuid!, title: entry.title ?? "[ Untitled entry ]")
}

private func addEntry(account: String, passwordString: String, server: String, uuid: String, title: String) throws {
    let password = passwordString.data(using: String.Encoding.utf8)!
    let accessGroup = Bundle.main.infoDictionary!["KeeVaultSharedEntriesAccessGroup"] as! String
    
    let accessControl: SecAccessControl = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, [SecAccessControlCreateFlags.userPresence], nil)!

    
    let baseQuery: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                kSecAttrAccessGroup as String: accessGroup,
                                kSecAttrAccessControl as String: accessControl,
                                kSecAttrAccount as String: uuid,
                                kSecAttrServer as String: server]
    
    let addQuery: [String: Any] = baseQuery + [
                                kSecAttrDescription as String: account, // hack since custom attributes are not supported by Apple and we have to use Account for the uuid due to limitations of keychain primary keys
                                kSecAttrLabel as String: title,
                                kSecValueData as String: password]
    
    SecItemDelete(baseQuery as CFDictionary)
    let status = SecItemAdd(addQuery as CFDictionary, nil)
    guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
    
}


enum KeychainError: Error {
    case noPassword
    case unexpectedPasswordData
    case unhandledError(status: OSStatus)
}

func +<Key, Value> (lhs: [Key: Value], rhs: [Key: Value]) -> [Key: Value] {
     var result = lhs
     rhs.forEach{ result[$0] = $1 }
     return result
 }

 struct KeeVaultKeychainEntry {
     let uuid: String?
     let server: String
     let writtenByAutofill: Bool
     let title: String?
     let username: String
     let password: String? // keychain value (encrypted behind presense check in secure chip)
 }


struct KeeVaultEntryIos: Decodable {
    let uuid: String
    let server: String
    let created: Date
    let modified: Date
    let title: String?
    let username: String?
    let password: String?
}
