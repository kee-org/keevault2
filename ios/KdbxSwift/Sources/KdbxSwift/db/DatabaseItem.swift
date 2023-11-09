import Logging

open class DatabaseItem {
    public enum TouchMode {
        case accessed
        case modified
    }
    
    public weak var parent: Group?
    
    public func isAncestor(of item: DatabaseItem) -> Bool {
        var parent = item.parent
        while parent != nil {
            if self === parent {
                return true
            }
            parent = parent?.parent
        }
        return false
    }
    
    public func touch(_ mode: TouchMode, updateParents: Bool = true) {
        Logger.fatalError("Pure abstract method")
    }
}
