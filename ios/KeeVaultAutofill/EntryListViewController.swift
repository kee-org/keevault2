//
//  EntryListViewController.swift
//  KeeVaultAutofill
//
//  Created by Chris Tomlinson on 21/09/2022.
//

import UIKit

class EntryListViewController: UITableViewController, UISearchBarDelegate {

    weak var selectionDelegate: EntrySelectionDelegate?
    var data: [PriorityCategory:[KeeVaultAutofillEntry]]!
    
    //let data //= ["Apples", "Oranges", "Pears", "Bannas", "Plums"]
    var filteredData: [KeeVaultAutofillEntry]!
    
    @IBOutlet weak var searchBar: UISearchBar!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBar.delegate = self
        filteredData = data[PriorityCategory.none]
        //TODO: all catergories

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredData.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = filteredData[indexPath.row].title
        return cell
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: Search Bar Config
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filteredData = []
        
        if searchText == "" {
            filteredData = data[PriorityCategory.none]
        } else {
            let xx = data[PriorityCategory.none] ?? []
            let searchTextLowered = searchText.lowercased()
            for entry in xx {
                let searchableTerm = entry.title?.lowercased() ?? ""
                //TODO: more searching
                if searchableTerm.contains(searchTextLowered) {
                    filteredData.append(entry)
                }
            }
        }
        
        self.tableView.reloadData()
    }
}
