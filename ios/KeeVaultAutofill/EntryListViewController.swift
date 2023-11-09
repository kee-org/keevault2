import UIKit
import Logging

protocol MyCellDelegate {
    func didTapEdit(data: KeeVaultAutofillEntry, category: PriorityCategory)
}

class EntryCell: UITableViewCell {
    var delegate: MyCellDelegate?
    var data: KeeVaultAutofillEntry!
    var category: PriorityCategory!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBAction func editAction(_ sender: Any) {
        guard let delegate = self.delegate else {
            return;
        }
        delegate.didTapEdit(data: data, category: category)
    }
//
//    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
//            super.init(style: style, reuseIdentifier: reuseIdentifier)
//            accessoryView = UISwitch()
//    }
//
//    required init?(coder: NSCoder) {
//        super.init(coder: coder)
//    }
}

class EntryListViewController: UITableViewController, UISearchBarDelegate, MyCellDelegate {
    
    weak var selectionDelegate: RowSelectionDelegate?
    weak var addOrEditEntryDelegate: AddOrEditEntryDelegate?
    var data: [PriorityCategory:[KeeVaultAutofillEntry]]?
    var filteredData: [PriorityCategory:[KeeVaultAutofillEntry]]?
    @IBOutlet weak var searchBar: UISearchBar!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBar.delegate = self
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        Logger.appLog.debug("entry list view controller loaded")
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! EntryCell
        
        guard filteredData != nil else {
            cell.titleLabel?.text = "Loading..."
            return cell
        }
        let category = getCategoryForSection(section: indexPath.section)
        
        guard category != nil else {
            cell.titleLabel?.text = "No match!" // don't think this can happen if TableView behaves as expected
            return cell
        }
        
        let entry = filteredData![category!]![indexPath.row]
        
        var title = entry.title.isNotEmpty ? entry.title : entry.server
        if (title.isEmpty) {
            title = "Untitled entry"
        }
        cell.titleLabel?.text = title
        cell.usernameLabel?.text = entry.username
        cell.data = entry
        cell.delegate = self
        cell.category = category
      
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
        self.selectionDelegate?.selected(entryIndex: autofillEntry.entryIndex, newUrl: category == .none)
        
    }
    
    func didTapEdit(data: KeeVaultAutofillEntry, category: PriorityCategory) {
        Logger.appLog.debug("edit tapped")
        performSegue(withIdentifier: "editSegue", sender: [data, category])
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any? ) {
        if segue.identifier == "editSegue" {
            let vc: EditEntryViewController = segue.destination as! EditEntryViewController
            let data = sender as! [Any]
            vc.data = data[0] as? KeeVaultAutofillEntry
            vc.category = data[1] as? PriorityCategory
            vc.addOrEditEntryDelegate = addOrEditEntryDelegate
        }
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
                    // below is not very efficient. Unnecessary checks against empty strings and
                    // no short-circuiting when testing. Hopefully future swift will support a
                    // basic .any function with that efficiency improvement.
                    let searchableTerms = [entry.lowercaseTitle,
                                           entry.lowercaseUsername,
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
