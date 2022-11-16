import Foundation
import AuthenticationServices

class EditEntryViewController: UIViewController {

    weak var addOrEditEntryDelegate: AddOrEditEntryDelegate?
    var data: KeeVaultAutofillEntry!
   
    @IBAction func editEntry(_ sender: AnyObject?) {
        do {
            //TODO: read user input and edit entry
            let passwordCredential = try getExampleEntry()
            addOrEditEntryDelegate?.update(credentials: passwordCredential, entryIndex: data.entryIndex)
        } catch _ {
        
        }
    }
    
    private func getExampleEntry() throws -> ASPasswordCredential {
        let credentials = ASPasswordCredential(user: data.username, password: "updated password")
        return credentials;
    }
}
