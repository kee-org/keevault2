import Foundation
import AuthenticationServices

class NewEntryViewController: UIViewController, UITextFieldDelegate {

    weak var addOrEditEntryDelegate: AddOrEditEntryDelegate?
    var defaultTitle: String?
    
    @IBOutlet var titleTextField: UITextField!
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var saveButton: UIButton!
    
    @IBAction func createEntry(_ sender: AnyObject?) {
        addOrEditEntryDelegate?.create(title: titleTextField.text ?? "", username: usernameTextField.text ?? "", password: passwordTextField.text ?? "")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        saveButton.isEnabled = false
        titleTextField.text = defaultTitle

        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: nil)
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
    
    @objc private func textDidChange(_ notification: Notification) {
        saveButton.isEnabled = usernameTextField.hasText || passwordTextField.hasText
    }
}
