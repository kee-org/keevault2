import Foundation
import AuthenticationServices

class EditEntryViewController: UIViewController {
    
    weak var addOrEditEntryDelegate: AddOrEditEntryDelegate?
    var data: KeeVaultAutofillEntry!
    var category: PriorityCategory!
    
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    
    @IBAction func editEntry(_ sender: AnyObject?) {
        let username = usernameTextField.text ?? ""
        let password = passwordTextField.text ?? ""
        addOrEditEntryDelegate?.update(username: username, password: password, newUrl: category == .none, entryIndex: data.entryIndex)
    }
    //
    //    private func getExampleEntry() throws -> ASPasswordCredential {
    //        let credentials = ASPasswordCredential(user: data.username, password: "updated password")
    //        return credentials;
    //    }
}
