public class DatabaseFile {
    
    public enum ConflictResolutionStrategy {
        case cancelSaving
        case overwriteRemote
        case saveAs
        case merge
    }
    
    public enum StatusFlag {
        case readOnly
        case localFallback
    }
    public typealias Status = Set<StatusFlag>
    
    public let database: Database
       
    public private(set) var data: ByteArray
    
    public private(set) var storedDataSHA512: ByteArray
    
    public var fileName: String
    
    public private(set) var status: Status
    
    init(
        database: Database,
        data: ByteArray = ByteArray(),
        fileName: String,
        status: Status
    ) {
        self.database = database
        self.data = data
        self.storedDataSHA512 = data.sha512
        self.fileName = fileName
        self.status = status
    }
    
    public func setData(_ data: ByteArray, updateHash: Bool) {
        self.data = data.clone()
        if updateHash {
            storedDataSHA512 = data.sha512
        }
    }
}
