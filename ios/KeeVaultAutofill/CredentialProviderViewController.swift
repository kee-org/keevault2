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
    var key: ByteArray?
    var keyStatus: OSStatus?
    let iOSBugWorkaroundAuthenticationDelay = 0.25
    
    override func present(_ viewControllerToPresent: UIViewController,
                            animated flag: Bool,
                            completion: (() -> Void)? = nil) {
        viewControllerToPresent.modalPresentationStyle = .fullScreen
        super.present(viewControllerToPresent, animated: flag, completion: completion)
      }

    override func viewDidLoad() {
        mainController.selectionDelegate = self
        mainController.domainParser = self.domainParser
        sharedGroupName = Bundle.main.infoDictionary!["KeeVaultSharedDefaultGroupName"] as? String
        sharedDefaults = UserDefaults(suiteName: sharedGroupName)
        mainController.sharedDefaults = sharedDefaults
        userId = getUserIdFromSharedSettings()
    }
    
    /*
     Prepare your UI to list available credentials for the user to choose from. The items in
     'serviceIdentifiers' describe the service the user is logging in to, so your extension can
     prioritize the most relevant credentials in the list.
     */
    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        // iOS supplies a punycode URL for requests from Safari. Spec says there can be more than
        // one but I've never seen that happen and can't imagine any real scenario in which that
        // would happen. App URLs are probably hostnames and/or domains and there is no
        // documentation or example to say if it will be punycode or not so we just assume it
        // is until real world experience suggests otherwise.
        // Not all apps have a serviceIdentifier!
        
        DispatchQueue.main.asyncAfter(deadline: .now() + iOSBugWorkaroundAuthenticationDelay) { [self] in
            
            (key, keyStatus) = getKeyForUser(userId: userId)
            if key == nil {
                var message = "Your access key needs to be refreshed before you can AutoFill Kee Vault entries. Click OK and then sign in to the main Kee Vault app. You can then use AutoFill until your chosen expiry time is next reached."
                message += keyStatus != nil ? " Technical error code: \(String(describing: keyStatus))" : ""
                mainController.initWithAuthError(message: message)
                return
            }
            
            var seachDomains: [String] = []
            for si in serviceIdentifiers {
                if si.type == ASCredentialServiceIdentifier.IdentifierType.URL {
                    // To keep everything fast for the user we don't match on full URLs, regexes, etc. like
                    // on the desktop. On Android we don't have the data needed to do this but it appears
                    // that at least in some iOS versions and for Safari only, we could offer this as a
                    // feature in future - for now we'll keep parity with Android.
                    let url = URL(string: si.identifier)
                    guard let host = url?.host else {
                        continue
                    }
                    seachDomains.append(host)
                    guard let unicodeHost = host.idnaDecoded else {
                        continue
                    }
                    guard let domain = domainParser.parse(host: unicodeHost)?.domain else {
                        continue
                    }
                    guard let punycodeDomain = domain.idnaEncoded else {
                        continue
                    }
                    seachDomains.append(punycodeDomain)
                } else {
                    seachDomains.append(si.identifier)
                }
            }
            
            let dbFileManager = DatabaseFileManager(status: Set<DatabaseFile.StatusFlag>(), preTransformedKeyMaterial: key!, userId: userId!, sharedGroupName: sharedGroupName!, sharedDefaults: sharedDefaults!)
            let dbFile = dbFileManager.loadFromFile()
            let db = dbFile.database
            var entries: [Entry] = []
            db.root?.collectAllEntries(to: &entries)
            mainController.searchDomains = seachDomains
            mainController.entries = entries
            mainController.dbFileManager = dbFileManager
            self.mainController.initAutofillEntries()
        }
    }
    
    private func getUserIdFromSharedSettings() -> String? {
        return sharedDefaults?.string(forKey: "userId")
    }
    
    private func getKeyForUser(userId: String?) -> (ByteArray?, OSStatus?) {
        guard userId != nil else { return (nil,nil) }
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
        guard status != errSecItemNotFound else { return (nil,status) }
        guard status == errSecSuccess else { return (nil,status)}
        
        guard let existingItem = item as? [String : Any],
              let keyData = existingItem[kSecValueData as String] as? Data
        else {
            return (nil,nil)
        }
        
        guard let allCredentials =
                try? JSONDecoder().decode(Dictionary<String,ExpiringCachedCredentials>.self, from: keyData) else {
            return (nil,nil)
        }
        guard let credentials = allCredentials[userId!] else {
            return (nil,nil)
        }
        
        if (credentials.expiry < Date.now.millisecondsSinceUnixEpoch) {
            return (nil,nil)
        }
        return (ByteArray(base64Encoded: credentials.kdbxKdfResultBase64),nil)
        
    }
    
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
