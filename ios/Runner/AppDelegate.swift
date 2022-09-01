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
    let account = "test username"
    let password = "password123".data(using: String.Encoding.utf8)!
    let server = "www.github.com"
    let accessGroup = Bundle.main.infoDictionary!["KeeVaultSharedEntriesAccessGroup"] as! String

var error: NSError?
let access = SecAccessControlCreateWithFlags(NULL,  // Use the default allocator.
kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                             kSecAccessControlUserPresence,
                                             &error);

    let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                kSecAttrAccessGroup as String: accessGroup,
                                kSecAttrAccessControl as String: access,
                                kSecAttrAccount as String: account,
                                kSecAttrServer as String: server,
                                kSecValueData as String: password]

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
