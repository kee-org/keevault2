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
    var dbFileManager: DatabaseFileManager!
    var sharedDefaults: UserDefaults?
    var entries: [Entry]?
    var authenticatedContext: LAContext?
    var searchDomains: [String]?
    weak var entryListVC: EntryListViewController?
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
        let entries = getGroupedOrderedItems (searchDomains: searchDomains!)
        entryListVC?.initAutofillEntries(entries: entries)
        spinner.willMove(toParent: nil)
        spinner.view.removeFromSuperview()
        spinner.removeFromParent()
    }
    
    func initWithAuthError (message: String) {
        
        spinner.willMove(toParent: nil)
        spinner.view.removeFromSuperview()
        spinner.removeFromParent()
        // Create the action buttons for the alert.
        let defaultAction = UIAlertAction(title: "OK",
                                          style: .default) { (action) in
            // Respond to user selection of the action.
            self.cancel(nil)
        }
        let alert = UIAlertController(title: "Full Kee Vault authorisation required",
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(defaultAction)
        
        self.present(alert, animated: true) {
            // The alert was presented
        }
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
            if $0.priority == 0 || $0.priority == 1000 {return PriorityCategory.none}
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
                if let url = URL(string: $0)?.setSchemeIfNotPresent("https") {
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
        guard let firstHostname = hostnames.first else {
            return (1000, "")
        }
        return (0, firstHostname)
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
    
    private func addUrlToEntry(entry: Entry, url: String) throws {
        guard let db = entry.database else {
            fatalError("Invalid entry found while saving new URL")
        }
        if (entry.rawURL.isEmpty) {
            entry.rawURL = url
        } else {
            let entryJson = entry.getField("KPRPC JSON")?.value ?? "{\"version\":1,\"priority\":0,\"hide\":false,\"hTTPRealm\":\"\",\"formFieldList\":[],\"alwaysAutoFill\":false,\"alwaysAutoSubmit\":false,\"neverAutoFill\":false,\"neverAutoSubmit\":false,\"blockDomainOnlyMatch\":false,\"blockHostnameOnlyMatch\":false,\"altURLs\":[],\"regExURLs\":[],\"blockedURLs\":[],\"regExBlockedURLs\":[]}"
            let range = entryJson.range(of: #""altURLs"\:\[([^\]]*)\]"#)
            var newJson = entryJson.replacingOccurrences(of: "[]", with: "[\"\(url)\"]", options: .init(), range: range)
            if (newJson.count == entryJson.count) {
                newJson = entryJson.replacingOccurrences(of: "]", with: ",\"\(url)\"]", options: .init(), range: range)
                entry.setField(name: "KPRPC JSON", value: newJson)
            }
        }
        entry.setModified()
        dbFileManager.saveToFile(db: db)
        
        // Eventually we may have a background service manage all the merging and potential
        // remote file access, in which case we need to use UserDefaults observers to track
        // when a merge from autofill is required (e.g.
        // https://stackoverflow.com/questions/60104060/ios-notify-today-extension-for-core-data-changes-in-the-main-app)
        //    sharedDefaults!["LastChangeAutofillTimestamp"] = Date()
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
    func selected(entryIndex: Int, newUrl: Bool) {
        do {
            let entry = entries![entryIndex]
            let passwordCredential = ASPasswordCredential(user: entry.rawUserName, password: entry.rawPassword )
            if (newUrl) {
                if let url = URL(string: (self.searchDomains?[0])!)?.setSchemeIfNotPresent("https") {
                    try addUrlToEntry(entry: entry, url: url.absoluteString)
                }
            }
            self.selectionDelegate?.selected(credentials: passwordCredential)
        } catch _ {
            
        }
    }
}

protocol EntrySelectionDelegate: AnyObject {
    func selected(credentials: ASPasswordCredential)
    func cancel()
}

protocol RowSelectionDelegate: AnyObject {
    func selected(entryIndex: Int, newUrl: Bool)
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

extension URL {
    //TODO: Needs much more work. ios is a bit shit at understanding partial URLs so our hostnames don't appear to be processed as such and therefore even adding a scheme is not enough for it to produce a valid URL. E.g. "https:blah.com" is the best we can do so far.
    func setSchemeIfNotPresent(_ value: String) -> URL {
        let components = NSURLComponents.init(url: self, resolvingAgainstBaseURL: true)
        components?.scheme = value
        return (components?.url!)!
    }
}
