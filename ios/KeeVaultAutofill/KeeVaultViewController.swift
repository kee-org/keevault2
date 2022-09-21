//
//  KeeVaultViewController.swift
//  KeeVaultAutofill
//
//  Created by Chris Tomlinson on 18/09/2022.
//

import Foundation
import AuthenticationServices

class KeeVaultViewController: UIViewController {

    weak var selectionDelegate: EntrySelectionDelegate?
    var entries: [KeeVaultKeychainEntry]?
    var searchDomains: [ASCredentialServiceIdentifier]?
    
    @IBAction func passwordSelected(_ sender: AnyObject?) {
        do {
            let entry = try getExampleEntry()
            let passwordCredential = ASPasswordCredential(user: entry.username, password: entry.password ?? "")
            self.selectionDelegate?.selected(credentials: passwordCredential)
        } catch _ {
        
        }
    }
    
    @IBAction func cancel(_ sender: AnyObject?) {
        self.selectionDelegate?.cancel()
    }
    
    func createEntry(_ sender: AnyObject?) {
        do {
            //TODO: read user input and create entry
            let entry = try getExampleEntry()
            let passwordCredential = ASPasswordCredential(user: entry.username, password: entry.password ?? "")
            selectionDelegate?.selected(credentials: passwordCredential)
        } catch _ {
        
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "newEntrySegue" {
            let destinationVC = segue.destination as! NewEntryViewController
            destinationVC.selectionDelegate = selectionDelegate
        } else if segue.identifier == "embeddedEntryListSegue" {
            let destinationVC = segue.destination as! EntryListViewController
            destinationVC.selectionDelegate = selectionDelegate
//            entries = [
//                KeeVaultKeychainEntry(uuid: "uuid1", server: "google.com", writtenByAutofill: false, title: "Example title 1", username: "account 1", password: "password 1" ),
//                KeeVaultKeychainEntry(uuid: "uuid2", server: "app.google.com", writtenByAutofill: false, title: "Example title 2", username: "account 2", password: "password 2" ),
//                KeeVaultKeychainEntry(uuid: "uuid3", server: "github.com", writtenByAutofill: false, title: "Example title 3", username: "account 3", password: "password 3" ),
//            ]
//            destinationVC.data =  [
//                KeeVaultAutofillEntry(entryIndex: 0, server: "google.com", title: "Example title 1", username: "account 1", priority: 2 ),
//                KeeVaultAutofillEntry(entryIndex: 1, server: "app.google.com", title: "Example title 2", username: "account 2", priority: 1 ),
//                KeeVaultAutofillEntry(entryIndex: 2, server: "github.com", title: "Example title 3", username: "account 3", priority: 0 ),
//            ]
            
            //TODO: will crash here if have guessed wrong about order in which ios calls all these various interaction points
            //TODO: yep. next: try fake data above and see if crash continues when not executing below operation
            destinationVC.data = getGroupedOrderedItems (searchDomains: searchDomains!)
        }
    }
    
    //TODO: get search domains from ios... in the above VC I guess
    private func getGroupedOrderedItems (searchDomains: [ASCredentialServiceIdentifier])
        -> [PriorityCategory: [KeeVaultAutofillEntry]] {
        var autofillEntries: [String: KeeVaultAutofillEntry] = [:]
        for index in entries!.indices {
            let entry = entries![index]
            var autofillEntry: KeeVaultAutofillEntry?
            if !(entry.uuid ?? "").isEmpty {
                autofillEntry = autofillEntries[entry.uuid!]
            }
            let currentPriority = autofillEntry?.priority ?? -1
            
            let priority = calculatePriority(entry: entry, searchDomains: searchDomains)
            if (priority > currentPriority) {
                // UUID for new entry is never used again
                autofillEntries[entry.uuid ?? UUID.init().uuidString] = KeeVaultAutofillEntry(entryIndex: index, server: entry.server, title: entry.title, username: entry.username, priority: priority )
            }
            
            // group by uuid and/or server, priority = max prioirty found from any of the grouped items, index = index of item with max priority
        }
        
        // Assuming sort order is preserved when items are extracted to their groups but if not will have to run the sort many times instead, after grouping
        let sortedEntries = autofillEntries.map({$0.value}).sorted { e1, e2 in
            guard e1.priority == e2.priority else {
                if (e1.priority == 0) { return false }
                if (e2.priority == 0) { return true }
                return e1.priority < e2.priority
            }

            //maybe later: lowercase operation caching
            return (e1.title ?? "").lowercased() < (e2.title ?? "").lowercased()
        }
        let grouped = Dictionary<PriorityCategory,[KeeVaultAutofillEntry]>(grouping: sortedEntries,
                                 by: {
            if $0.priority == 0 {return PriorityCategory.none}
            else if $0.priority == 1 {return PriorityCategory.exact}
            return PriorityCategory.close
            
        })
        return grouped
    }
    
    private func calculatePriority (entry: KeeVaultKeychainEntry, searchDomains: [ASCredentialServiceIdentifier]) -> Int {
        for index in searchDomains.indices {
            let searchDomain = searchDomains[index]
            if (searchDomain.identifier.lowercased() == entry.server.lowercased()) {
                return index + 1
            }
        }
        return 0
    }
    
    private func getExampleEntry() throws -> KeeVaultKeychainEntry {
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
              let account = existingItem[kSecAttrAccount as String] as? String,
              let uuid = existingItem["uuid"] as? String,
              let title = existingItem["title"] as? String
        else {
            throw KeychainError.unexpectedPasswordData
        }
        let entry = KeeVaultKeychainEntry(uuid: uuid, server: server, writtenByAutofill: false, title: title, username: account, password: password )
        return entry;
    }
}

protocol EntrySelectionDelegate: AnyObject {
    func selected(credentials: ASPasswordCredential)
    func cancel()
    //TODO: created(user: String, password: String, server: String)
}
