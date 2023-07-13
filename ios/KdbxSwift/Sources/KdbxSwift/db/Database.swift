import Foundation
import os.log

public struct SearchQuery {
    public let includeSubgroups: Bool
    public let includeDeleted: Bool
    public let includeFieldNames: Bool
    public let includeProtectedValues: Bool
    public let compareOptions: String.CompareOptions
    
    public let text: String
    public let textWords: Array<Substring>
    
    public init(
        includeSubgroups: Bool,
        includeDeleted: Bool,
        includeFieldNames: Bool,
        includeProtectedValues: Bool,
        compareOptions: String.CompareOptions,
        text: String,
        textWords: Array<Substring>)
    {
        self.includeSubgroups = includeSubgroups
        self.includeDeleted = includeDeleted
        self.includeFieldNames = includeFieldNames
        self.includeProtectedValues = includeProtectedValues
        self.compareOptions = compareOptions
        self.text = text
        self.textWords = text.split(separator: " ")
    }
}

open class Database: Eraseable {    
    public internal(set) var root: Group?

    public internal(set) var progress = ProgressEx()

    internal var compositeKey = CompositeKey.empty
    
    public func initProgress() -> ProgressEx {
        progress = ProgressEx()
        return progress
    }
    
    public var keyHelper: KeyHelper {
        Logger.fatalError("Pure virtual method")
    }
    
    internal init() {
    }
    
    deinit {
        erase()
    }
    
    public func erase() {
        root?.erase()
        root = nil
        compositeKey.erase()
    }

    public class func isSignatureMatches(data: ByteArray) -> Bool {
        Logger.fatalError("Pure virtual method")
    }
    
    public func load(
        dbFileName: String,
        dbFileData: ByteArray,
        preTransformedKeyMaterial: ByteArray
    ) throws {
        Logger.fatalError("Pure virtual method")
    }
    
    public func save() throws -> ByteArray {
        Logger.fatalError("Pure virtual method")
    }
    
    public func changeCompositeKey(to newKey: CompositeKey) {
        Logger.fatalError("Pure virtual method")
    }
    
    public func getBackupGroup(createIfMissing: Bool) -> Group? {
        Logger.fatalError("Pure virtual method")
    }
    
    public func count(includeGroups: Bool = true, includeEntries: Bool = true) -> Int {
        var result = 0
        if let root = self.root {
            var groups = Array<Group>()
            var entries = Array<Entry>()
            root.collectAllChildren(groups: &groups, entries: &entries)
            result += includeGroups ? groups.count : 0
            result += includeEntries ? entries.count : 0
        }
        return result
    }
    
    public func search(query: SearchQuery, result: inout Array<Entry>) -> Int {
        result.removeAll()
        root?.filterEntries(query: query, result: &result)
        return result.count
    }
    
    public func delete(group: Group) {
        Logger.fatalError("Pure virtual method")
    }
    
    public func delete(entry: Entry) {
        Logger.fatalError("Pure virtual method")
    }

    public func makeAttachment(name: String, data: ByteArray) -> Attachment {
        Logger.fatalError("Pure virtual method")
    }
    
    internal func resolveReferences<T>(
        allEntries: T)
        where T: Collection, T.Element: Entry
    {
        Logger.mainLog.debug("Resolving references")
                
        allEntries.forEach { entry in
            entry.fields.forEach { field in
                field.unresolveReferences()
            }
        }
        
        allEntries.forEach { entry in
            entry.fields.forEach { field in
                field.resolveReferences(entries: allEntries)
            }
        }
        Logger.mainLog.debug("References resolved OK")
    }
}
