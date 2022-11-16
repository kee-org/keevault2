import Foundation
import AuthenticationServices

class NewEntryViewController: UIViewController {

    weak var addOrEditEntryDelegate: AddOrEditEntryDelegate?
   
    @IBAction func createEntry(_ sender: AnyObject?) {
        do {
            //TODO: read user input and create entry
            let passwordCredential = try getExampleEntry()
            addOrEditEntryDelegate?.create(credentials: passwordCredential)
        } catch _ {
        
        }
    }
    
    private func getExampleEntry() throws -> ASPasswordCredential {
        let credentials = ASPasswordCredential(user: "sample new username", password: "sample new password")
        return credentials;
    }
}
