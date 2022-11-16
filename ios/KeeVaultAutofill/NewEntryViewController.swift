import Foundation
import AuthenticationServices

class NewEntryViewController: UIViewController {

    weak var addOrEditEntryDelegate: AddOrEditEntryDelegate?
   
    @IBAction func createEntry(_ sender: AnyObject?) {
        //TODO: read user input and create entry
        addOrEditEntryDelegate?.create(username: "sample new username", password: "sample new password")
    }
    
}
