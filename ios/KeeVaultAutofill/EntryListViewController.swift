//
//  EntryListViewController.swift
//  KeeVaultAutofill
//
//  Created by Chris Tomlinson on 21/09/2022.
//

import UIKit
//import LocalAuthentication
//import AuthenticationServices

class EntryListViewController: UITableViewController, UISearchBarDelegate {

    weak var selectionDelegate: RowSelectionDelegate?
    var data: [PriorityCategory:[KeeVaultAutofillEntry]]?
    var filteredData: [PriorityCategory:[KeeVaultAutofillEntry]]?
//    var authenticatedContext: LAContext?
    @IBOutlet weak var searchBar: UISearchBar!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBar.delegate = self

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return filteredData?.filter({ $0.value.count > 0 }).count ?? 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard filteredData != nil else {
            return 0
        }
        let category = getCategoryForSection(section: section)
        
        guard category != nil else {
            return 0
        }
        return filteredData![category!]?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        guard filteredData != nil else {
            cell.textLabel?.text = "Loading..."
            return cell
        }
        let category = getCategoryForSection(section: indexPath.section)
        
        guard category != nil else {
            cell.textLabel?.text = "No match!" // don't think this can happen if TableView behaves as expected
            return cell
        }
        
        cell.textLabel?.text = filteredData![category!]![indexPath.row].title
        return cell
    }
    
    func getCategoryForSection (section: Int) -> PriorityCategory? {
        let hasExact = filteredData?.contains(where: { $0.key == PriorityCategory.exact && $0.value.count > 0 }) ?? false
        let hasClose = filteredData?.contains(where: { $0.key == PriorityCategory.close && $0.value.count > 0 }) ?? false
        let hasOther = filteredData?.contains(where: { $0.key == PriorityCategory.none && $0.value.count > 0 }) ?? false
        
        if (!hasExact && !hasClose && !hasOther) {
            // No matches
            return nil
        }
        
        if (section == 0) {
            if (hasExact) {
                return PriorityCategory.exact
            } else if (hasClose) {
                return PriorityCategory.close
            } else if (hasOther) {
                return PriorityCategory.none
            }
        }
        if (section == 1) {
            if (hasExact && hasClose) {
                return PriorityCategory.close
            } else if (hasOther) {
                return PriorityCategory.none
            }
        }
        
        return PriorityCategory.none
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let category = getCategoryForSection(section: section);
        
        guard category != nil else {
            return nil
        }
        
        if (category == PriorityCategory.exact) {
            return "Best matches"
        } else if (category == PriorityCategory.close) {
            return "Close matches"
        } else {
            return "Unmatched entries"
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        guard let category = getCategoryForSection(section: indexPath.section) else {
            return
        }
        guard let autofillEntry = filteredData![category]?[row] else {
            return
        }
        self.selectionDelegate?.selected(entryIndex: autofillEntry.entryIndex, newUrl: "TODO")

    }
    
    func initAutofillEntries (entries: [PriorityCategory:[KeeVaultAutofillEntry]]!) {
        data = entries
        filteredData = data
        self.tableView.reloadData()
    }

    // MARK: Search Bar Config
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filteredData = [:]
        
        guard data != nil else {
            return
        }
        
        if searchText == "" {
            filteredData = data
        } else {
            let searchTextLowered = searchText.lowercased()
            for categoryData in data! {
                for entry in categoryData.value {
                    // below is not very efficient. Unnecessary checks against empty strings and no short-circuiting when testing. Hopefully future swift will support a basic .any function with that efficiency improvement.
                    let searchableTerms = [entry.title?.lowercased() ?? "",
                                           entry.username.lowercased(),
                                           entry.server.lowercased()
                                           ]
                    if searchableTerms.filter({$0.contains(searchTextLowered)}).count > 0 {
                        if !filteredData!.contains(where : {$0.key == categoryData.key}) {
                            filteredData![categoryData.key] = []
                        }
                        filteredData![categoryData.key]!.append(entry)
                    }
                }
            }
        }
        
        self.tableView.reloadData()
    }
    
}
