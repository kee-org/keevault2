//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public protocol DatabaseLoaderDelegate: AnyObject {
    func databaseLoader(_ databaseLoader: DatabaseLoader, willLoadDatabase dbRef: FileWrapper)
    
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didChangeProgress progress: ProgressEx,
        for dbRef: FileWrapper)

    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didFailLoading dbRef: FileWrapper,
        with error: DatabaseLoader.Error)
    
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didLoadDatabase dbRef: FileWrapper,
        databaseFile: DatabaseFile)
}


//TODO: modify and use before creating DatabaseLoader in main project
//private func buildCompositeKey(
//    password: String,
//    keyFileData: SecureBytes)
//) {
//    let passwordData = self.getPasswordData(password: password)
//    if passwordData.isEmpty && keyFileData.isEmpty && challengeHandler == nil {
//        Diag.error("Password and key file are both empty")
//        completionQueue.async {
//            completion(.failure(LString.Error.passwordAndKeyFileAreBothEmpty))
//        }
//    }
//
//    do {
//        let staticComponents = try self.combineComponents(
//            passwordData: passwordData,
//            keyFileData: keyFileData
//        )
//        let compositeKey = CompositeKey(
//            staticComponents: staticComponents,
//            challengeHandler: challengeHandler)
//        Diag.debug("New composite key created successfully")
//        completionQueue.async {
//            completion(.success(compositeKey))
//        }
//    } catch let error as KeyFileError {
//        Diag.error("Key file error [reason: \(error.localizedDescription)]")
//        completionQueue.async {
//            completion(.failure(error.localizedDescription))
//        }
//    } catch {
//        let message = "Caught unrecognized exception"
//        assertionFailure(message)
//        Diag.error(message)
//        completionQueue.async {
//            completion(.failure(message))
//        }
//    }
//}

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
        
    
    
    private let dbRef: FileWrapper
    private let compositeKey: CompositeKey
    public let status: DatabaseFile.Status
    
    private var isReadOnly: Bool {
        status.contains(.readOnly)
    }

    //private let warnings: DatabaseLoadingWarnings
    
    
    private var startTime: Date?
    
    public init(
        dbRef: FileWrapper,
        compositeKey: CompositeKey,
        status: DatabaseFile.Status
    ) {
        assert(compositeKey.state != .empty)
        self.dbRef = dbRef
        self.compositeKey = compositeKey.clone()
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
        fileName: String,
        fileURL: URL
    ) {
        let data: ByteArray = ByteArray.init()
        //TODO: read from file
        
        guard let db = initDatabase(signature: data) else {
            let hexPrefix = data.prefix(8).asHexString
            //Diag.error("Unrecognized database format [firstBytes: \(hexPrefix)]")
            //stopAndNotify(.unrecognizedFormat(hexSignature: hexPrefix))
            return
        }
        
        let dbFile = DatabaseFile(
            database: db,
            data: data,
            fileName: fileName,
            status: status
        )
//        guard compositeKey.state == .rawComponents else {
//
//            onCompositeKeyComponentsProcessed(dbFile: dbFile, compositeKey: compositeKey)
//            return
//        }
        
        guard let keyFileData = compositeKey.keyFileData else {
           // onKeyFileDataReady(dbFile: dbFile, keyFileData: SecureBytes.empty())
            return
        }
        
        let keyHelper = dbFile.database.keyHelper
        let passwordData = keyHelper.getPasswordData(password: compositeKey.password)
        if passwordData.isEmpty && keyFileData.isEmpty {
            Diag.error("Both password and key file are empty")
            return
        }
        
        compositeKey.setProcessedComponents(passwordData: passwordData, keyFileData: keyFileData)
        //TODO: make sure composite can be set using the actual master key rather than having to run it through argon2
        
        do {
            let db = dbFile.database
            try db.load(
                dbFileName: dbFile.fileName,
                dbFileData: dbFile.data,
                compositeKey: compositeKey)

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
