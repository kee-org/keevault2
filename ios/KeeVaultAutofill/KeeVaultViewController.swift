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
            autofillEntries[entry.uuid.uuidString] = KeeVaultAutofillEntry(entryIndex: index, server: server, title: entry.rawTitle, lowercaseUsername: entry.rawUserName.lowercased(), lowercaseTitle: entry.rawTitle.lowercased(), username: entry.rawUserName,  priority: priority)
        }
        
        // Assuming sort order is preserved when items are extracted to their groups
        // but if not, will have to run the sort a few times instead, after grouping
        let sortedEntries = autofillEntries.map({$0.value}).sorted { e1, e2 in
            guard e1.priority == e2.priority else {
                if (e1.priority == 0) { return false }
                if (e2.priority == 0) { return true }
                return e1.priority < e2.priority
            }
            
            return e1.lowercaseTitle < e2.lowercaseTitle
        }
        let grouped = Dictionary<PriorityCategory,[KeeVaultAutofillEntry]>(grouping: sortedEntries,
                                                                           by: {
            if $0.priority == 0 || $0.priority == 1000 {return PriorityCategory.none}
            else if $0.priority == 1 {return PriorityCategory.exact}
            return PriorityCategory.close
        })
        return grouped
    }
    
    func urlFromString(_ value: String) -> URL? {
        var normalisedValue = value
        if (!value.contains("://")) {
            normalisedValue = "https://" + value
        }
        
        guard let url = URL(string: normalisedValue) else {
            return nil
        }
        if (url.scheme != "https" && url.scheme != "http") {
            return nil
        }
        return url
    }
    
    private func calculatePriority (entry: Entry, searchDomains: [String]) -> (Int, String) {
        var URLs = [urlFromString(entry.rawURL)].compactMap() { $0 }
        if let entryJson = entry.getField("KPRPC JSON") {
            let kprpcsubset = try? JSONDecoder().decode(KPRPCSubset.self, from: Data(entryJson.value.utf8))
            let altUrls = kprpcsubset?.altURLs
            altUrls?.forEach() {
                if let url = urlFromString($0) {
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
    
    private func addUrlToEntry(entry: Entry, url: String) throws {
        guard let db = entry.database else {
            fatalError("Invalid entry found while saving new URL")
        }
        if (entry.rawURL.isEmpty) {
            entry.rawURL = url
        } else {
            let entryJson = entry.getField("KPRPC JSON")?.value ?? "{\"version\":1,\"priority\":0,\"hide\":false,\"hTTPRealm\":\"\",\"formFieldList\":[],\"alwaysAutoFill\":false,\"alwaysAutoSubmit\":false,\"neverAutoFill\":false,\"neverAutoSubmit\":false,\"blockDomainOnlyMatch\":false,\"blockHostnameOnlyMatch\":false,\"altURLs\":[],\"regExURLs\":[],\"blockedURLs\":[],\"regExBlockedURLs\":[]}"
            let range = entryJson.range(of: #""altURLs"\:\[([^\]]*)\]"#, options: .regularExpression)
            var newJson = entryJson.replacingOccurrences(of: "[]", with: "[\"\(url)\"]", options: .init(), range: range)
            if (newJson.count == entryJson.count) {
                newJson = entryJson.replacingOccurrences(of: "]", with: ",\"\(url)\"]", options: .init(), range: range)
            }
            entry.setField(name: "KPRPC JSON", value: newJson, isProtected: true)
        }
        entry.setModified()
        dbFileManager.saveToFile(db: db)
        
        // Eventually we may have a background service manage all the merging and potential
        // remote file access, in which case we need to use UserDefaults observers to track
        // when a merge from autofill is required (e.g.
        // https://stackoverflow.com/questions/60104060/ios-notify-today-extension-for-core-data-changes-in-the-main-app)
        //    sharedDefaults!["LastChangeAutofillTimestamp"] = Date()
    }
}

extension KeeVaultViewController: RowSelectionDelegate {
    func selected(entryIndex: Int, newUrl: Bool) {
        do {
            let entry = entries![entryIndex]
            let passwordCredential = ASPasswordCredential(user: entry.rawUserName, password: entry.rawPassword )
            if (newUrl) {
                if let url = urlFromString((self.searchDomains?[0])!) {
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

struct KPRPCSubset: Codable {
    let altURLs: [String]
    
    enum CodingKeys: String, CodingKey {
        case altURLs
    }
}
