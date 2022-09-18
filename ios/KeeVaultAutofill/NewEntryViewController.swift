//
//  NewEntryViewController.swift
//  KeeVaultAutofill
//
//  Created by Chris Tomlinson on 18/09/2022.
//

import Foundation
import AuthenticationServices

class NewEntryViewController: UIViewController {

    weak var selectionDelegate: EntrySelectionDelegate?
   
    /*
    func passwordSelected(_ sender: AnyObject?) {
        do {
            let passwordCredential = try getExampleEntry()
            self.selectionDelegate?.selected(credentials: passwordCredential)
        } catch _ {
        
        }
    }
    
    @IBAction func cancel(_ sender: AnyObject?) {
        self.selectionDelegate?.cancel()
    }
    */
    
    @IBAction func createEntry(_ sender: AnyObject?) {
        do {
            //TODO: read user input and create entry
            let passwordCredential = try getExampleEntry()
            selectionDelegate?.selected(credentials: passwordCredential)
        } catch _ {
        
        }
    }
    
    private func getExampleEntry() throws -> ASPasswordCredential {
        let server = "www.github.com"
        let accessGroup = Bundle.main.infoDictionary!["KeeVaultSharedEntriesAccessGroup"] as! String
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrAccessGroup as String: accessGroup,
                                    kSecAttrServer as String: server,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: true,
                                    kSecReturnData as String: true]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { throw KeychainError.noPassword }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
        
        guard let existingItem = item as? [String : Any],
              let passwordData = existingItem[kSecValueData as String] as? Data,
              let password = String(data: passwordData, encoding: String.Encoding.utf8),
              let account = existingItem[kSecAttrAccount as String] as? String
        else {
            throw KeychainError.unexpectedPasswordData
        }
        let credentials = ASPasswordCredential(user: account, password: password)
        return credentials;
    }
}
