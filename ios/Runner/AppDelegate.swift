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
//                guard let args = call.arguments as? Dictionary<String, Any> else {
//                    result(FlutterError.init(code: "bad args", message: nil, details: nil))
//                    break
//                  }
//                guard let kvEntries = args["entries"] as? [String] else {
//                    result(FlutterError.init(code: "missing entries argument", message: nil, details: nil))
//                    break
//                } //TODO:f: needs to be a JSON String instead?
//
//                let entries = kvEntries.compactMap {
//                    try? JSONDecoder().decode(KeeVaultEntryIos.self, from: Data($0.utf8))
//                }
//                do {
//                    try addEntries(entries: entries)
//                } catch _ {
//
//                }
                result(true)
            case "getAppGroupDirectory":
                let groupName = Bundle.main.infoDictionary!["KeeVaultSharedDefaultGroupName"] as! String
                let groupURL:URL! = FileManager().containerURL(forSecurityApplicationGroupIdentifier: groupName)
                result(groupURL.path)
            case "setUserId":
                guard let args = call.arguments as? Dictionary<String, Any> else {
                    result(FlutterError.init(code: "bad args", message: nil, details: nil))
                    break
                  }
                guard let userId = args["userId"] as? String else {
                    result(FlutterError.init(code: "missing userId argument", message: nil, details: nil))
                    break
                }
                let groupName = Bundle.main.infoDictionary!["KeeVaultSharedDefaultGroupName"] as! String
                guard let defaults = UserDefaults(suiteName: groupName) else {
                    result(FlutterError.init(code: "missing shared user defaults group", message: nil, details: nil))
                    break
                }
                defaults.set(userId, forKey: "userId")
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        })
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
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
