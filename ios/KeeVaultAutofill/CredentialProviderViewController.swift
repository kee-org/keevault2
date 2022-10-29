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
    
    override func viewDidLoad() {
        mainController.selectionDelegate = self
    }
    
    
    /*
     Prepare your UI to list available credentials for the user to choose from. The items in
     'serviceIdentifiers' describe the service the user is logging in to, so your extension can
     prioritize the most relevant credentials in the list.
     */
    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        // iOS supplies a punycode URL for requests from Safari. Spec says there can be more than one but I've never seen that happen and can't imagine any real scenario in which that would happen. App URLs are probably hostnames and/or domains and there is no documentation or example to say if it will be punycode or not so we just assume it is until real world experience suggests otherwise.
        let domainParser = try! DomainParser()
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
        
        //TODO: maybe move the kdbx load and PSL stuff so they can load in parrallel
        //TODO: load kdbx key from keychain
        //TODO: abort trying to create new DB with this library - too hard. Instead, load from existing file and create a composite key from file's password argon result bytes (inspected in dart debugger)
        //TODO: need to write the file to somewhere I can find it first... unless the recent app group stuff for keychain has magically made this happen already.
//let    completionQueue: DispatchQueue = .main

        let documentsDirectory = FileManager().containerURL(forSecurityApplicationGroupIdentifier: "group.com.keevault.keevault.dev")
                guard let kdbxURL = documentsDirectory?.appendingPathComponent("local_user/current.kdbx") else { return }
            //TODO: shared config to set fiel url path (user directory)
        
        let preTransformedKeyMaterial = ByteArray(bytes: [])
        let dbLoader = DatabaseLoader(dbRef: kdbxURL, status: Set<DatabaseFile.StatusFlag>(), preTransformedKeyMaterial: preTransformedKeyMaterial)
        let dbFile = dbLoader.loadFromFile()
        let db = dbFile.database
        let root = db.root
        mainController.searchDomains = sis
        do {
            let context = LAContext()
            mainController.entries = try loadAllKeychainMetadata(context: context)
            mainController.authenticatedContext = context
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
    
    private func loadAllKeychainMetadata(context: LAContext) throws -> [KeeVaultKeychainEntry] {
        var entries: [KeeVaultKeychainEntry] = []
        let accessGroup = Bundle.main.infoDictionary!["KeeVaultSharedEntriesAccessGroup"] as! String
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrAccessGroup as String: accessGroup,
                                    kSecMatchLimit as String: kSecMatchLimitAll,
                                    kSecReturnAttributes as String: true,
                                    kSecUseAuthenticationContext as String: context]
        
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
