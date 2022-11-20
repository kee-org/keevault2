import Foundation

public class CompositeKey: Codable {
    public enum State: Int, Comparable, Codable {
        case empty               = 0 
        case rawComponents       = 1 
        case processedComponents = 2 
        case combinedComponents  = 3 
        case final = 4
        
        public static func < (lhs: CompositeKey.State, rhs: CompositeKey.State) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    static let empty = CompositeKey()

    internal private(set) var state: State
    
    internal private(set) var password: String = ""
    internal private(set) var keyFileRef: URL?
    
    internal private(set) var passwordData: ByteArray?
    internal private(set) var keyFileData: ByteArray?
    
    internal private(set) var combinedStaticComponents: ByteArray?
    
    internal private(set) var finalKey: ByteArray?
    internal private(set) var cipherKey: ByteArray?
    
    
    public init() {
        self.password = ""
        self.keyFileRef = nil
        state = .empty
    }
    
    public init(password: String, keyFileRef: URL?) {
        self.password = password
        self.keyFileRef = keyFileRef
        state = .rawComponents
    }
    
    init(staticComponents: ByteArray) {
        self.password = ""
        self.keyFileRef = nil
        self.passwordData = nil
        self.keyFileData = nil
        self.combinedStaticComponents = staticComponents
        state = .combinedComponents
    }
    
    deinit {
        erase()
    }
    
    func erase() {
        keyFileRef = nil
        passwordData = nil
        keyFileData = nil
        combinedStaticComponents = nil
        
        state = .empty
    }

    
    private enum CodingKeys: String, CodingKey {
        case state
        case passwordData
        case keyFileData
        case combinedStaticComponents = "staticComponents"
        case cipherKey
        case finalKey
    }
    
    
    public func clone() -> CompositeKey {
        let clone = CompositeKey(
            password: self.password,
            keyFileRef: self.keyFileRef)
        clone.passwordData = self.passwordData?.clone()
        clone.keyFileData = self.keyFileData?.clone()
        clone.combinedStaticComponents = self.combinedStaticComponents?.clone()
        clone.cipherKey = self.cipherKey?.clone()
        clone.finalKey = self.finalKey?.clone()
        clone.state = self.state
        return clone
    }
    
    func setProcessedComponents(passwordData: ByteArray, keyFileData: ByteArray) {
        assert(state == .rawComponents)
        self.passwordData = passwordData.clone()
        self.keyFileData = keyFileData.clone()
        state = .processedComponents
        
        self.password.erase()
        self.keyFileRef = nil
        self.cipherKey?.erase()
        self.cipherKey = nil
        self.finalKey?.erase()
        self.finalKey = nil
    }
    
    func setCombinedStaticComponents(_ staticComponents: ByteArray) {
        assert(state <= .combinedComponents)
        self.combinedStaticComponents = staticComponents.clone()
        state = .combinedComponents
        
        self.password.erase()
        self.keyFileRef = nil
        self.passwordData?.erase()
        self.passwordData = nil
        self.keyFileData?.erase()
        self.keyFileData = nil
        
        self.cipherKey?.erase()
        self.cipherKey = nil
        self.finalKey?.erase()
        self.finalKey = nil
    }
    
    func setFinalKeys(_ finalKey: ByteArray, _ cipherKey: ByteArray?) {
        assert(state >= .combinedComponents)
        self.cipherKey = cipherKey?.clone()
        self.finalKey = finalKey.clone()
        state = .final
    }
    
    public func eraseFinalKeys() {
        guard state >= .final else { return }
        state = .combinedComponents
        cipherKey?.erase()
        cipherKey = nil
        finalKey?.erase()
        finalKey = nil
    }
    
}
