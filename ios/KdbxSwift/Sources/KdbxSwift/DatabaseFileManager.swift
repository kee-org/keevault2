//  Contains a few lines from KeePassium Password Manager (GPL3)

import Foundation

//public protocol DatabaseLoaderDelegate: AnyObject {
//    func databaseLoader(_ databaseLoader: DatabaseLoader, willLoadDatabase dbRef: URL)
//
//    func databaseLoader(
//        _ databaseLoader: DatabaseLoader,
//        didChangeProgress progress: ProgressEx,
//        for dbRef: URL)
//
//    func databaseLoader(
//        _ databaseLoader: DatabaseLoader,
//        didFailLoading dbRef: URL,
//        with error: DatabaseLoader.Error)
//
//    func databaseLoader(
//        _ databaseLoader: DatabaseLoader,
//        didLoadDatabase dbRef: URL,
//        databaseFile: DatabaseFile)
//}

public class DatabaseFileManager {
    public enum Error {
        case databaseUnreachable(_ reason: DatabaseUnreachableReason)
        case lowMemory
        case databaseError(reason: DatabaseError)
        case otherError(message: String)
    }
    
    public enum DatabaseUnreachableReason {
        case cannotFindDatabaseFile
        case cannotOpenDatabaseFile
    }
    
    private let kdbxAutofillURL: URL
    private let kdbxCurrentURL: URL
    private let tempBackup: URL
    private let preTransformedKeyMaterial: ByteArray
    public let status: DatabaseFile.Status
    
    private var isReadOnly: Bool {
        status.contains(.readOnly)
    }
    
    private var startTime: Date?
    
    public init(
        status: DatabaseFile.Status,
        preTransformedKeyMaterial: ByteArray,
        userId: String?,
        sharedGroupName: String,
        sharedDefaults: UserDefaults
    ) {
        self.preTransformedKeyMaterial = preTransformedKeyMaterial.clone()
        self.status = status
        
        let documentsDirectory = FileManager().containerURL(forSecurityApplicationGroupIdentifier: sharedGroupName)
        let userFolderName = userId == "localUserMagicString@v1" ? "local_user" : userId!
        kdbxAutofillURL = documentsDirectory!.appendingPathComponent(userFolderName + "/autofill.kdbx")
        kdbxCurrentURL = documentsDirectory!.appendingPathComponent(userFolderName + "/current.kdbx")
        tempBackup = documentsDirectory!.appendingPathComponent(userFolderName + "/backup.kdbx")
        //TODO: make a copy at autofill.kdbx for writing new URLs to (to start with)
        
    }
    
    private func initDatabase(signature data: ByteArray) -> Database? {
        if Database2.isSignatureMatches(data: data) {
            Diag.info("DB signature: KDBX")
            return Database2()
        } else {
            Diag.info("DB signature: no match")
            return nil
        }
    }
    
    public func loadFromFile(
        // fileName: String
    ) -> DatabaseFile {
        var fileData: ByteArray
        do {
            let autofillFileData = try ByteArray(contentsOf: kdbxAutofillURL, options: [.uncached, .mappedIfSafe])
            fileData = autofillFileData

//            let tempFileData = try ByteArray(contentsOf: tempBackup, options: [.uncached, .mappedIfSafe])
//            try tempFileData.write(to: kdbxCurrentURL, options: .atomic)
//            try tempFileData.write(to: kdbxAutofillURL, options: .atomic)
            try fileData.write(to: kdbxCurrentURL, options: .atomic)
            
//            fileData = try ByteArray(contentsOf: kdbxCurrentURL, options: [.uncached, .mappedIfSafe])
        } catch {
            Diag.info("Autofill file not found. Expected unless recent changes have been made via autofill and main app not opened yet.")
            do {
                    fileData = try ByteArray(contentsOf: kdbxCurrentURL, options: [.uncached, .mappedIfSafe])
                
            } catch {
                Diag.error("Failed to read current KDBX file [message: \(error.localizedDescription)]")
                fatalError("couldn't read KDBX file")
            }
        }
        
        guard let db = initDatabase(signature: fileData) else {
            let hexPrefix = fileData.prefix(8).asHexString
            fatalError("database init failed")
        }
        
        let dbFile = DatabaseFile(
            database: db,
            data: fileData,
            fileName: "<ignored filename>",
            status: status
        )        
        
        do {
            let db = dbFile.database
            try db.load(
                dbFileName: dbFile.fileName,
                dbFileData: dbFile.data,
                preTransformedKeyMaterial: preTransformedKeyMaterial)
            
        } catch {
            fatalError("Unprocessed exception while opening database. Probably hardware failure has corrupted the data on this device.")
        }
        return dbFile
    }
    
    public func saveToFile(db: Database) {
        do {
            let fileData = try db.save()
            try fileData.write(to: kdbxAutofillURL, options: .atomic)
        } catch {
                Diag.error("Failed to write autofill KDBX file [message: \(error.localizedDescription)]")
        }
    }
}
