//
//  CredentialProviderViewController.swift
//  KeeVaultAutofill
//
//  Created by Chris Tomlinson on 30/08/2022.
//

import AuthenticationServices

class CredentialProviderViewController: ASCredentialProviderViewController {
    
    var embeddedNavigationController: UINavigationController {
        return children.first as! UINavigationController
    }

    var mainController: KeeVaultViewController {
        return embeddedNavigationController.viewControllers.first as! KeeVaultViewController
    }
    
    override func viewDidLoad() {
        mainController.selectionDelegate = self
    }
    
    
    /*
     Prepare your UI to list available credentials for the user to choose from. The items in
     'serviceIdentifiers' describe the service the user is logging in to, so your extension can
     prioritize the most relevant credentials in the list.
    */
    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        var sis: [String] = []
        for si in serviceIdentifiers {
            if si.type == ASCredentialServiceIdentifier.IdentifierType.URL {
                //TODO: run a PSL operation on the URL
                let url = URL(string: si.identifier)
                guard url?.host != nil else {
                    continue
                }
                sis.append(url!.host!)
            } else {
                sis.append(si.identifier)
            }
        }
        mainController.searchDomains = sis
        do {
            mainController.entries = try loadAllKeychainMetadata()
        } catch {
            // Will just initialise with no passwords displayed. Not sure what else useful
            // we can do but will see what user feedback is if this ever happens
        }
//        mainController.entries = [
//            KeeVaultKeychainEntry(uuid: "uuid1", server: "google.com", writtenByAutofill: false, title: "Example title 1", username: "account 1", password: "password 1" ),
//            KeeVaultKeychainEntry(uuid: "uuid2", server: "app.google.com", writtenByAutofill: false, title: "Example title 2", username: "account 2", password: "password 2" ),
//            KeeVaultKeychainEntry(uuid: "uuid3", server: "github.com", writtenByAutofill: false, title: "Example title 3", username: "account 3", password: "password 3" ),
//        ]
        self.mainController.initAutofillEntries()
    }
    
    //TODO: custom context so user only gets asks once during this autofill procedure... or maybe those referneces it supplies could be used instead?
    private func loadAllKeychainMetadata() throws -> [KeeVaultKeychainEntry] {
        var entries: [KeeVaultKeychainEntry] = []
        let accessGroup = Bundle.main.infoDictionary!["KeeVaultSharedEntriesAccessGroup"] as! String
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrAccessGroup as String: accessGroup,
                                    kSecMatchLimit as String: kSecMatchLimitAll,
                                    kSecReturnAttributes as String: true]
        
        var items_ref: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items_ref)
        guard status != errSecItemNotFound else { throw KeychainError.noPassword }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
        guard let items = items_ref as? Array<Dictionary<String, Any>>
                
        else {
            throw KeychainError.unexpectedPasswordData
        }
        for item in items {
            let existingItem = item
            guard let server = existingItem[kSecAttrServer as String] as? String else {
                continue
            }
            let uuid = existingItem[kSecAttrAccount as String] as? String
            
            let account = existingItem[kSecAttrDescription as String] as? String ?? ""
            let title = existingItem[kSecAttrLabel as String] as? String
            let entry = KeeVaultKeychainEntry(uuid: uuid, server: server, writtenByAutofill: false, title: title, username: account, password: nil)
            entries.append(entry)
        }
        return entries;
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
