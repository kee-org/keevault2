//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

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
            //Diag.error("Unrecognized database format [firstBytes: \(hexPrefix)]")
            //stopAndNotify(.unrecognizedFormat(hexSignature: hexPrefix))
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
    
}