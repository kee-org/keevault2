//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public protocol DatabaseLoaderDelegate: AnyObject {
    func databaseLoader(_ databaseLoader: DatabaseLoader, willLoadDatabase dbRef: URL)
    
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didChangeProgress progress: ProgressEx,
        for dbRef: URL)
    
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didFailLoading dbRef: URL,
        with error: DatabaseLoader.Error)
    
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didLoadDatabase dbRef: URL,
        databaseFile: DatabaseFile)
}

public class DatabaseLoader {
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
    
    private let dbRef: URL
    private let preTransformedKeyMaterial: ByteArray
    public let status: DatabaseFile.Status
    
    private var isReadOnly: Bool {
        status.contains(.readOnly)
    }
    
    //private let warnings: DatabaseLoadingWarnings
    
    
    private var startTime: Date?
    
    public init(
        dbRef: URL,
        //     compositeKey: CompositeKey,
        status: DatabaseFile.Status,
        preTransformedKeyMaterial: ByteArray
    ) {
        self.dbRef = dbRef
        self.preTransformedKeyMaterial = preTransformedKeyMaterial.clone()
        self.status = status
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
            fileData = try ByteArray(contentsOf: dbRef, options: [.uncached, .mappedIfSafe])
        } catch {
            Diag.error("Failed to read file [message: \(error.localizedDescription)]")
            fatalError("couldn't read KDBX file")
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
            fileName: dbRef.lastPathComponent ?? "<missing filename>",
            status: status
        )
        
        
        do {
            let db = dbFile.database
            try db.load(
                dbFileName: dbFile.fileName,
                dbFileData: dbFile.data,
                preTransformedKeyMaterial: preTransformedKeyMaterial)
            
        } catch let error as DatabaseError {
            //            switch error {
            //            case .loadError:
            ////                Diag.error("""
            ////                        Database load error. [
            ////                            isCancelled: \(progress.isCancelled),
            ////                            message: \(error.localizedDescription),
            ////                            reason: \(String(describing: error.failureReason))]
            ////                    """)
            ////                stopAndNotify(.databaseError(reason: error))
            //            case .invalidKey:
            //                //Diag.error("Invalid master key. [message: \(error.localizedDescription)]")
            //                //stopAndNotify(.invalidKey(message: error.localizedDescription))
            //            case .saveError:
            //                //Diag.error("saveError while loading?!")
            //                //fatalError("Database saving error while loading?!")
            //            }
        } catch {
            assertionFailure("Unprocessed exception")
        }
        return dbFile
    }
    //
    //    private func performAfterLoadTasks(_ dbFile: DatabaseFile) {
    //            let quickTypeDatabaseCount = dbSettingsManager.getQuickTypeDatabaseCount()
    //            let isReplaceExisting = quickTypeDatabaseCount == 1
    //            Diag.debug("Updating QuickType AutoFill records [replacing: \(isReplaceExisting)]")
    //            QuickTypeAutoFillStorage.saveIdentities(
    //                from: dbFile,
    //                replaceExisting: isReplaceExisting
    //            )
    //    }
    
    
}
