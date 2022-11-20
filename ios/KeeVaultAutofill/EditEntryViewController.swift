import Foundation
import AuthenticationServices

class EditEntryViewController: UIViewController, UITextFieldDelegate {
    
    weak var addOrEditEntryDelegate: AddOrEditEntryDelegate?
    var data: KeeVaultAutofillEntry!
    var category: PriorityCategory!
    
    @IBOutlet var titleTextField: UITextField!
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    
    @IBAction func editEntry(_ sender: AnyObject?) {
        let title = titleTextField.text ?? ""
        let username = usernameTextField.text ?? ""
        let password = passwordTextField.text ?? ""
        addOrEditEntryDelegate?.update(title: title, username: username, password: password, newUrl: category == PriorityCategory.none, entryIndex: data.entryIndex)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        usernameTextField.enablesReturnKeyAutomatically = false
        usernameTextField.text = data.username
        titleTextField.text = data.title
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case titleTextField:
            usernameTextField.becomeFirstResponder()
        case usernameTextField:
            passwordTextField.becomeFirstResponder()
        default:
            passwordTextField.resignFirstResponder()
        }
        return true
    }

}
