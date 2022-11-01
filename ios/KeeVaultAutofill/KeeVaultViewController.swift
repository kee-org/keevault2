//
//  KeeVaultViewController.swift
//  KeeVaultAutofill
//
//  Created by Chris Tomlinson on 18/09/2022.
//

import Foundation
import AuthenticationServices
import LocalAuthentication
import KdbxSwift
import DomainParser

class KeeVaultViewController: UIViewController {
    
    weak var selectionDelegate: EntrySelectionDelegate?
    var domainParser: DomainParser!
    var entries: [Entry]?
    var authenticatedContext: LAContext?
    var searchDomains: [String]?
    weak var entryListVC: EntryListViewController? //TODO: OK to be weak?
    var spinner = SpinnerViewController()
    
    override func loadView() {
        super.loadView()
        addSpinnerView()
    }
    
    private func addSpinnerView() {
        addChild(spinner)
        spinner.view.frame = view.frame
        view.addSubview(spinner.view)
        spinner.didMove(toParent: self)
    }
    
    @IBAction func cancel(_ sender: AnyObject?) {
        self.selectionDelegate?.cancel()
    }
    
    func createEntry(_ sender: AnyObject?) {
//        do {
//            //TODO: read user input and create entry
//            let entry = try getExampleEntry()
//            let passwordCredential = ASPasswordCredential(user: entry.username, password: entry.password ?? "")
//            selectionDelegate?.selected(credentials: passwordCredential)
//        } catch _ {
//
//        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "newEntrySegue" {
            let destinationVC = segue.destination as! NewEntryViewController
            destinationVC.selectionDelegate = selectionDelegate
        } else if segue.identifier == "embeddedEntryListSegue" {
            let destinationVC = segue.destination as! EntryListViewController
            destinationVC.selectionDelegate = self
            entryListVC = destinationVC
        }
    }
    
    func initAutofillEntries () {
        //        let entries =  [
        //            PriorityCategory.close: [KeeVaultAutofillEntry(entryIndex: 0, server: "google.com", title: "Example title 1", username: "account 1", priority: 2 )],
        //            PriorityCategory.exact: [KeeVaultAutofillEntry(entryIndex: 1, server: "app.google.com", title: "Example title 2", username: "account 2", priority: 1 )],
        //            PriorityCategory.none: [KeeVaultAutofillEntry(entryIndex: 2, server: "github.com", title: "Example title 3", username: "account 3", priority: 0 )],
        //        ]
        let entries = getGroupedOrderedItems (searchDomains: searchDomains!)
        entryListVC?.initAutofillEntries(entries: entries)
        
        spinner.willMove(toParent: nil)
        spinner.view.removeFromSuperview()
        spinner.removeFromParent()
    }
    
    private func getGroupedOrderedItems (searchDomains: [String])
    -> [PriorityCategory: [KeeVaultAutofillEntry]] {
        var autofillEntries: [String: KeeVaultAutofillEntry] = [:]
        for index in entries!.indices {
            let entry = entries![index]
            
            let (priority, server) = calculatePriority(entry: entry, searchDomains: searchDomains)
            if (priority == -1)
            {
                // invalid or hidden entry
                continue
            }
            autofillEntries[entry.uuid.uuidString] = KeeVaultAutofillEntry(entryIndex: index, server: server, title: entry.rawTitle, username: entry.rawUserName, priority: priority )
            
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
    
    private func calculatePriority (entry: Entry, searchDomains: [String]) -> (Int, String) {
        var URLs = [URL(string: entry.rawURL)].compactMap() { $0 }
        if let entryJson = entry.getField("KPRPC JSON") {
            let kprpcsubset = try? JSONDecoder().decode(KPRPCSubset.self, from: Data(entryJson.value.utf8))
            let altUrls = kprpcsubset?.altURLs
            altUrls?.forEach() {
                if let url = URL(string: $0) {
                    URLs.append(url)
                }
            }
        }
        if (URLs.count < 1) {
            return (1000, "")
        }
        var domains: [String] = []
        var hostnames: [String] = []
        for url in URLs {
            guard let host = url.host else {
                continue
            }
            hostnames.append(host)
            guard let unicodeHost = host.idnaDecoded else {
                continue
            }
            guard let domain = domainParser.parse(host: unicodeHost)?.domain else {
                continue
            }
            guard let punycodeDomain = domain.idnaEncoded else {
                continue
            }
            domains.append(punycodeDomain)
        }
        
        for index in searchDomains.indices {
            let searchDomain = searchDomains[index]
            if (hostnames.contains(searchDomain.lowercased()) || domains.contains(searchDomain.lowercased())) {
                return (index + 1, searchDomain)
            }
        }
        return (0, hostnames[0])
    }
    
//
//    private func getEntry(uuid: String, context: LAContext) throws -> KeeVaultKeychainEntry {
//        let accessGroup = Bundle.main.infoDictionary!["KeeVaultSharedDefaultAccessGroup"] as! String
//        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
//                                    kSecAttrAccessGroup as String: accessGroup,
//                                    kSecAttrAccount as String: uuid,
//                                    kSecMatchLimit as String: kSecMatchLimitOne,
//                                    kSecReturnAttributes as String: true,
//                                    kSecReturnData as String: true,
//                                    kSecUseAuthenticationContext as String: context]
//
//        var item: CFTypeRef?
//        let status = SecItemCopyMatching(query as CFDictionary, &item)
//        guard status != errSecItemNotFound else { throw KeychainError.noPassword }
//        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
//
//        guard let existingItem = item as? [String : Any],
//              let passwordData = existingItem[kSecValueData as String] as? Data,
//              let password = String(data: passwordData, encoding: String.Encoding.utf8),
//              let uuid = existingItem[kSecAttrAccount as String] as? String,
//              let server = existingItem[kSecAttrServer as String] as? String,
//              let account = existingItem[kSecAttrDescription as String] as? String
//        else {
//            throw KeychainError.unexpectedPasswordData
//        }
//        let entry = KeeVaultKeychainEntry(uuid: uuid, server: server, writtenByAutofill: false, title: title, username: account, password: password )
//        return entry;
//    }
//
//    private func getExampleEntry() throws -> KeeVaultKeychainEntry {
//        let server = "www.github.com"
//        let accessGroup = Bundle.main.infoDictionary!["KeeVaultSharedDefaultAccessGroup"] as! String
//        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
//                                    kSecAttrAccessGroup as String: accessGroup,
//                                    kSecAttrServer as String: server,
//                                    kSecMatchLimit as String: kSecMatchLimitOne,
//                                    kSecReturnAttributes as String: true,
//                                    kSecReturnData as String: true]
//
//        var item: CFTypeRef?
//        let status = SecItemCopyMatching(query as CFDictionary, &item)
//        guard status != errSecItemNotFound else { throw KeychainError.noPassword }
//        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
//
//        guard let existingItem = item as? [String : Any],
//              let passwordData = existingItem[kSecValueData as String] as? Data,
//              let password = String(data: passwordData, encoding: String.Encoding.utf8),
//              let account = existingItem[kSecAttrAccount as String] as? String,
//              let uuid = existingItem["uuid"] as? String,
//              let title = existingItem["title"] as? String
//        else {
//            throw KeychainError.unexpectedPasswordData
//        }
//        let entry = KeeVaultKeychainEntry(uuid: uuid, server: server, writtenByAutofill: false, title: title, username: account, password: password )
//        return entry;
//    }
//
    //TODO: ...
    private func addUrlToEntry(account: String, passwordString: String, server: String, uuid: String, title: String) throws {
        let password = passwordString.data(using: String.Encoding.utf8)!
        let accessGroup = Bundle.main.infoDictionary!["KeeVaultSharedDefaultAccessGroup"] as! String
        
        let accessControl: SecAccessControl = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, [SecAccessControlCreateFlags.userPresence], nil)!
        
        
        let baseQuery: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                        kSecAttrAccessGroup as String: accessGroup,
                                        kSecAttrAccessControl as String: accessControl,
                                        kSecAttrAccount as String: uuid,
                                        kSecAttrServer as String: server]
        
        let addQuery: [String: Any] = baseQuery + [
            kSecAttrDescription as String: account, // hack since custom attributes are not supported by Apple and we have to use Account for the uuid due to limitations of keychain primary keys
            kSecAttrLabel as String: title,
            kSecValueData as String: password]
        
        SecItemDelete(baseQuery as CFDictionary)
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
        
    }
    
    //
    //    @IBAction func agreeToTerms() {
    //       // Create the action buttons for the alert.
    //       let defaultAction = UIAlertAction(title: "Agree",
    //                            style: .default) { (action) in
    //        // Respond to user selection of the action.
    //       }
    //       let cancelAction = UIAlertAction(title: "Disagree",
    //                            style: .cancel) { (action) in
    //        // Respond to user selection of the action.
    //       }
    //
    //       // Create and configure the alert controller.
    //       let alert = UIAlertController(title: "Terms and Conditions",
    //             message: "Click Agree to accept the terms and conditions.",
    //             preferredStyle: .alert)
    //       alert.addAction(defaultAction)
    //       alert.addAction(cancelAction)
    //
    //       self.present(alert, animated: true) {
    //          // The alert was presented
    //       }
    //    }
    
}

extension KeeVaultViewController: RowSelectionDelegate {
    func selected(entryIndex: Int, newUrl: String?) {
        do {
            let e = entries![entryIndex]
            let entry = e //try getEntry(uuid: e.uuid!, context: authenticatedContext!)
            let passwordCredential = ASPasswordCredential(user: entry.rawUserName, password: entry.rawPassword ?? "")
            if (newUrl != nil) {
                //addUrlToEntry...
            }
            self.selectionDelegate?.selected(credentials: passwordCredential)
        } catch _ {
            
        }
    }
}

protocol EntrySelectionDelegate: AnyObject {
    func selected(credentials: ASPasswordCredential)
    func cancel()
    //TODO: created(user: String, password: String, server: String)
    //TODO: edited(user: String, password: String, uuid: String)
}

protocol RowSelectionDelegate: AnyObject {
    func selected(entryIndex: Int, newUrl: String?)
}

func +<Key, Value> (lhs: [Key: Value], rhs: [Key: Value]) -> [Key: Value] {
    var result = lhs
    rhs.forEach{ result[$0] = $1 }
    return result
}


struct KPRPCSubset: Codable {
    let altURLs: [String]
    
    enum CodingKeys: String, CodingKey {
            case altURLs
        }
}
