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
        //TODO: unclear when this gets called. is the UI view already loaded or what?
        mainController.searchDomains = serviceIdentifiers
        mainController.entries = [
            KeeVaultKeychainEntry(uuid: "uuid1", server: "google.com", writtenByAutofill: false, title: "Example title 1", username: "account 1", password: "password 1" ),
            KeeVaultKeychainEntry(uuid: "uuid2", server: "app.google.com", writtenByAutofill: false, title: "Example title 2", username: "account 2", password: "password 2" ),
            KeeVaultKeychainEntry(uuid: "uuid3", server: "github.com", writtenByAutofill: false, title: "Example title 3", username: "account 3", password: "password 3" ),
        ]
        
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
