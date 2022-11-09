//
//  CredentialProviderViewController.swift
//  KeeVaultAutofill
//
//  Created by Chris Tomlinson on 30/08/2022.
//

import AuthenticationServices
import DomainParser
import Punycode
import Foundation
import LocalAuthentication
import KdbxSwift

class CredentialProviderViewController: ASCredentialProviderViewController {
    
    var embeddedNavigationController: UINavigationController {
        return children.first as! UINavigationController
    }
    
    var mainController: KeeVaultViewController {
        return embeddedNavigationController.viewControllers.first as! KeeVaultViewController
    }
    
    var sharedGroupName: String?
    var userId: String?
    var sharedDefaults: UserDefaults?
    var domainParser = try! DomainParser()
    
    override func viewDidLoad() {
        mainController.selectionDelegate = self
        mainController.domainParser = self.domainParser
        sharedGroupName = Bundle.main.infoDictionary!["KeeVaultSharedDefaultGroupName"] as? String
        sharedDefaults = UserDefaults(suiteName: sharedGroupName)
        mainController.sharedDefaults = sharedDefaults
        userId = getUserIdFromSharedSettings()
        //domainParser = try! DomainParser()
    }
    
    
    /*
     Prepare your UI to list available credentials for the user to choose from. The items in
     'serviceIdentifiers' describe the service the user is logging in to, so your extension can
     prioritize the most relevant credentials in the list.
     */
    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        // iOS supplies a punycode URL for requests from Safari. Spec says there can be more than one but I've never seen that happen and can't imagine any real scenario in which that would happen. App URLs are probably hostnames and/or domains and there is no documentation or example to say if it will be punycode or not so we just assume it is until real world experience suggests otherwise.
        
        guard let key = getKeyForUser(userId: userId) else {
            var message = "Your access key needs to be refreshed before you can AutoFill Kee Vault entries. Click OK and then sign in to the main Kee Vault app. You can then use AutoFill until your chosen key expiry time is next reached."
            mainController.initWithAuthError(message: message)
            return
        }
        
        var sis: [String] = []
        for si in serviceIdentifiers {
            if si.type == ASCredentialServiceIdentifier.IdentifierType.URL {
                // To keep everything fast for the user we don't match on full URLs, regexes, etc. like on the desktop. On Android we don't have the data needed to do this but it appears that at least in some iOS versions, we could offer this as a feature in future - for now we'll keep parity with Android.
                let url = URL(string: si.identifier)
                guard let host = url?.host else {
                    continue
                }
                //                let host = url!.host!
                sis.append(host)
                guard let unicodeHost = host.idnaDecoded else {
                    continue
                }
                guard let domain = domainParser.parse(host: unicodeHost)?.domain else {
                    continue
                }
                guard let punycodeDomain = domain.idnaEncoded else {
                    continue
                }
                sis.append(punycodeDomain)
            } else {
                sis.append(si.identifier)
            }
        }
        
        //let preTransformedKeyMaterial = ByteArray(bytes: "6907d5ab2ba3e8dc7d8d1542220260ad32c48c7ef731ac6fb24213e4f09be9ce".hexaBytes)
        let dbFileManager = DatabaseFileManager(status: Set<DatabaseFile.StatusFlag>(), preTransformedKeyMaterial: key, userId: userId, sharedGroupName: sharedGroupName!, sharedDefaults: sharedDefaults!)
        let dbFile = dbFileManager.loadFromFile()
        let db = dbFile.database
        var entries: [Entry] = []
        db.root?.collectAllEntries(to: &entries)
        mainController.searchDomains = sis
        mainController.entries = entries
        mainController.dbFileManager = dbFileManager
       // dbFileManager.saveToFile(db: db)
        
//        do {
//            let context = LAContext()
//            mainController.entries = try loadAllKeychainMetadata(context: context)
//            mainController.authenticatedContext = context
//        } catch {
//            // Will just initialise with no passwords displayed. Not sure what else useful
//            // we can do but will see what user feedback is if this ever happens
//        }
        //        mainController.entries = [
        //            KeeVaultKeychainEntry(uuid: "uuid1", server: "google.com", writtenByAutofill: false, title: "Example title 1", username: "account 1", password: "password 1" ),
        //            KeeVaultKeychainEntry(uuid: "uuid2", server: "app.google.com", writtenByAutofill: false, title: "Example title 2", username: "account 2", password: "password 2" ),
        //            KeeVaultKeychainEntry(uuid: "uuid3", server: "github.com", writtenByAutofill: false, title: "Example title 3", username: "account 3", password: "password 3" ),
        //        ]
        self.mainController.initAutofillEntries()
    }
    
    private func getUserIdFromSharedSettings() -> String? {
        return sharedDefaults?.string(forKey: "userId")
    }
    
    private func getKeyForUser(userId: String?) -> ByteArray? {
        guard userId != nil else { return nil }
        let name = Bundle.main.infoDictionary!["KeeVaultSharedBiometricStorageName"] as! String
        let accessGroup = Bundle.main.infoDictionary!["KeeVaultSharedDefaultAccessGroup"] as! String
        let iosKeychainServiceName = "flutter_biometric_storage"
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: iosKeychainServiceName,
                                    kSecAttrAccount as String: name,
                                    kSecAttrAccessGroup as String: accessGroup,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: true,
                                    kSecReturnData as String: true]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else { return nil}
        
        guard let existingItem = item as? [String : Any],
              let keyData = existingItem[kSecValueData as String] as? Data
        else {
            return nil
        }
        
        guard let allCredentials =
                try? JSONDecoder().decode(Dictionary<String,ExpiringCachedCredentials>.self, from: keyData) else {
            return nil
        }
        guard let credentials = allCredentials[userId!] else {
            return nil
        }
        
        if (credentials.expiry < Date.now.millisecondsSinceUnixEpoch) {
            return nil
        }
        return ByteArray(base64Encoded: credentials.kdbxKdfResultBase64)
        
    }
//
//    private func loadAllEntryRows(db: Database) -> [KeeVaultKeychainEntry] {
//        var entryRows: [KeeVaultKeychainEntry] = []
//        var entries: [Entry] = []
//        //let root = db.root
//        db.root?.collectAllEntries(to: &entries)
//        for entry in entries {
//            entry.
//        }
//
////
////        for item in items {
////            let existingItem = item
////            guard let server = existingItem[kSecAttrServer as String] as? String else {
////                continue
////            }
////            let uuid = existingItem[kSecAttrAccount as String] as? String
////
////            let account = existingItem[kSecAttrDescription as String] as? String ?? ""
////            let title = existingItem[kSecAttrLabel as String] as? String
////            let entry = KeeVaultKeychainEntry(uuid: uuid, server: server, writtenByAutofill: false, title: title, username: account, password: nil)
////            entries.append(entry)
////        }
//        return entries;
//    }
//
    /*
     Implement this method if your extension supports showing credentials in the QuickType bar.
     When the user selects a credential from your app, this method will be called with the
     ASPasswordCredentialIdentity your app has previously saved to the ASCredentialIdentityStore.
     Provide the password by completing the extension request with the associated ASPasswordCredential.
     If using the credential would require showing custom UI for authenticating the user, cancel
     the request with error code ASExtensionError.userInteractionRequired.
     
     override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
     let databaseIsUnlocked = true
     if (databaseIsUnlocked) {
     let passwordCredential = ASPasswordCredential(user: "j_appleseed", password: "apple1234")
     self.extensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
     } else {
     self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code:ASExtensionError.userInteractionRequired.rawValue))
     }
     }
     */
    
    /*
     Implement this method if provideCredentialWithoutUserInteraction(for:) can fail with
     ASExtensionError.userInteractionRequired. In this case, the system may present your extension's
     UI and call this method. Show appropriate UI for authenticating the user then provide the password
     by completing the extension request with the associated ASPasswordCredential.
     
     override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
     }
     */
}

extension CredentialProviderViewController: EntrySelectionDelegate {
    func selected(credentials: ASPasswordCredential) {
        self.extensionContext.completeRequest(withSelectedCredential: credentials, completionHandler: nil)
    }
    func cancel() {
        self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userCanceled.rawValue))
    }
}

enum KeychainError: Error {
    case noPassword
    case unexpectedPasswordData
    case unhandledError(status: OSStatus)
}

extension StringProtocol {
    var hexaData: Data { .init(hexa) }
    var hexaBytes: [UInt8] { .init(hexa) }
    private var hexa: UnfoldSequence<UInt8, Index> {
        sequence(state: startIndex) { startIndex in
            guard startIndex < self.endIndex else { return nil }
            let endIndex = self.index(startIndex, offsetBy: 2, limitedBy: self.endIndex) ?? self.endIndex
            defer { startIndex = endIndex }
            return UInt8(self[startIndex..<endIndex], radix: 16)
        }
    }
}

struct ExpiringCachedCredentials: Decodable {
    let kdbxBase64Hash: String;
    let userPassKey: String;
    let kdbxKdfResultBase64: String;
    let kdbxKdfCacheKey: String;
    let expiry: Int;
}

extension Date {
    var millisecondsSinceUnixEpoch:Int64 {
        Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
}
