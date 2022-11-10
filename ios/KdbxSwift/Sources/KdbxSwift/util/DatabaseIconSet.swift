public enum DatabaseIconSet: Int {
    public static let allValues = [keepassium, keepass, keepassxc]
    case keepassium
    case keepass
    case keepassxc
    
    public var title: String {
        switch self {
        case .keepassium:
            return "KeePassium" 
        case .keepass:
            return "KeePass" 
        case .keepassxc:
            return "KeePassXC" 
        }
    }
}
