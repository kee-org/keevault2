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
                do {
                    try addEntries()
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

private func addEntries() throws {
    try addEntry(account: "test username", passwordString: "password", server: "bbc.co.uk", uuid: "123450", title: "title bbc 1");
    try addEntry(account: "test username 2", passwordString: "password", server: "bbc.com", uuid: "123451", title: "title bbc 2");
    try addEntry(account: "test username", passwordString: "password", server: "app.bbc.co.uk", uuid: "123452", title: "title bbc 3");
    try addEntry(account: "test username 2", passwordString: "password", server: "bbc.co.uk", uuid: "123453", title: "title bbc 4");
    try addEntry(account: "test username", passwordString: "password", server: "www.github.com", uuid: "123454", title: "title github 1");
    try addEntry(account: "test username", passwordString: "password", server: "app.github.com", uuid: "123455", title: "title github 2");
    try addEntry(account: "test username", passwordString: "password", server: "github.com", uuid: "123456", title: "title github 3");
    try addEntry(account: "test username 4", passwordString: "password", server: "github.com", uuid: "123457", title: "title github 4");
    try addEntry(account: "test username 1", passwordString: "password", server: "google.co.uk", uuid: "123458", title: "title google 1");
    try addEntry(account: "test username 2", passwordString: "password", server: "google.co.uk", uuid: "123459", title: "title google 2");
    try addEntry(account: "test username 3", passwordString: "password", server: "google.co.uk", uuid: "1234510", title: "title google 3");
    try addEntry(account: "test username 4", passwordString: "password", server: "google.co.uk", uuid: "1234511", title: "title google 4");
    try addEntry(account: "test username 5", passwordString: "password", server: "google.co.uk", uuid: "1234512", title: "title google 5");
    try addEntry(account: "test username 6", passwordString: "password", server: "google.co.uk", uuid: "1234513", title: "title google 6");
    try addEntry(account: "test username 7", passwordString: "password", server: "google.co.uk", uuid: "1234514", title: "title google 7");
    try addEntry(account: "test username 8", passwordString: "password", server: "google.co.uk", uuid: "1234515", title: "title google 8");
}


private func addEntry(account: String, passwordString: String, server: String, uuid: String, title: String) throws {
    let password = passwordString.data(using: String.Encoding.utf8)!
    let accessGroup = Bundle.main.infoDictionary!["KeeVaultSharedEntriesAccessGroup"] as! String
    
    let accessControl: SecAccessControl = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, [SecAccessControlCreateFlags.userPresence], nil)!

    
    let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                kSecAttrAccessGroup as String: accessGroup,
                                kSecAttrAccessControl as String: accessControl,
                                kSecAttrAccount as String: account,
                                kSecAttrServer as String: server,
                                kSecAttrDescription as String: uuid, // hack since custom attributes are not supported by Apple
                                kSecAttrLabel as String: title,
                                kSecValueData as String: password]
    
    //TODO:                                 kSecAttrAccount as String: account,    kSecAttrServer as String: server,
    // above are the only items considered as a test for uniqueness. however, when deleting the item below, we search by more attributes than just those primary keys so we don't find a match and thus don't delete the item.
    // next: work out whether keychain can actually support our needs with this serious limitation. if so, do a seperate query for the delete operation.
    
    SecItemDelete(query as CFDictionary)
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
    
    //TODO: Find all in keychain and compare timestamps for updates and delete any that are no longer in list of entries
}


enum KeychainError: Error {
    case noPassword
    case unexpectedPasswordData
    case unhandledError(status: OSStatus)
}
