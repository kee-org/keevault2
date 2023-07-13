import Foundation
import os.log

protocol Database2XMLTimeFormatter {
    func dateToXMLString(_ date: Date) -> String
}
protocol Database2XMLTimeParser {
    func xmlStringToDate(_ string: String?) -> Date?
}

public class Database2: Database {
    public enum FormatVersion: Comparable, CustomStringConvertible {
        case v4
        case v4_1
        
        public var description: String {
            switch self {
            case .v4:
                return "v4"
            case .v4_1:
                return "v4.1"
            }
        }
    }
    
    public enum FormatError: LocalizedError {
        case prematureDataEnd
        case negativeBlockSize(blockIndex: Int)
        case parsingError(reason: String)
        case blockIDMismatch
        case blockHashMismatch(blockIndex: Int) 
        case blockHMACMismatch(blockIndex: Int) 
        case compressionError(reason: String)
        public var errorDescription: String? {
            switch self {
            case .prematureDataEnd:
                return NSLocalizedString(
                    "[Database2/FormatError] Unexpected end of file. Corrupted file?",
                    bundle: Bundle.framework,
                    value: "Unexpected end of file. Corrupted file?",
                    comment: "Error message")
            case .negativeBlockSize(let blockIndex):
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database2/FormatError] Corrupted database file (block %d has negative size)",
                        bundle: Bundle.framework,
                        value: "Corrupted database file (block %d has negative size)",
                        comment: "Error message [blockIndex: Int]"),
                    blockIndex)
            case .parsingError(let reason):
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database2/FormatError] Cannot parse database. %@",
                        bundle: Bundle.framework,
                        value: "Cannot parse database. %@",
                        comment: "Error message. Parsing refers to the analysis/understanding of file content. [reason: String]"),
                    reason)
            case .blockIDMismatch:
                return NSLocalizedString(
                    "[Database2/FormatError] Unexpected block ID.",
                    bundle: Bundle.framework,
                    value: "Unexpected block ID.",
                    comment: "Error message: wrong ID of a data block")
            case .blockHashMismatch(let blockIndex):
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database2/FormatError] Corrupted database file (hash mismatch in block %d)",
                        bundle: Bundle.framework,
                        value: "Corrupted database file (hash mismatch in block %d)",
                        comment: "Error message: hash(checksum) of a data block is wrong. [blockIndex: Int]"),
                    blockIndex)
            case .blockHMACMismatch(let blockIndex):
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database2/FormatError] Corrupted database file (HMAC mismatch in block %d)",
                        bundle: Bundle.framework,
                        value: "Corrupted database file (HMAC mismatch in block %d)",
                        comment: "Error message: HMAC value (kind of checksum) of a data block is wrong. [blockIndex: Int]"),
                    blockIndex)
            case .compressionError(let reason):
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database2/FormatError] Gzip error: %@",
                        bundle: Bundle.framework,
                        value: "Gzip error: %@",
                        comment: "Error message about Gzip compression algorithm. [reason: String]"),
                    reason)
            }
        }
    }
    
    private(set) var header: Header2!
    private(set) var meta: Meta2!
    public var binaries: [Binary2.ID: Binary2] = [:]
    public var customIcons: [CustomIcon2] { return meta.customIcons }
    public var defaultUserName: String { return meta.defaultUserName }
    private var cipherKey = ByteArray.empty()
    private var hmacKey = ByteArray.empty()
    private var deletedObjects: ContiguousArray<DeletedObject2> = []
    
    override public var keyHelper: KeyHelper { return _keyHelper }
    private let _keyHelper = KeyHelper2()
    
    override public init() {
        Logger.mainLog.debug("Database2 init")
        super.init()
        header = Header2(database: self)
        meta = Meta2(database: self)
    }
    
    deinit {
        erase()
    }
    
    override public func erase() {
        header.erase()
        meta.erase()
        binaries.removeAll()
        cipherKey.erase()
        hmacKey.erase()
        deletedObjects.removeAll()
        super.erase()
        Logger.mainLog.debug("DB memory cleaned up")
    }
    
    internal static func makeNewV4() -> Database2 {
        let db = Database2()
        db.header.loadDefaultValuesV4()
        db.meta.loadDefaultValuesV4()
        
        let rootGroup = Group2(database: db)
        rootGroup.uuid = UUID()
        rootGroup.name = "/"
        rootGroup.isAutoTypeEnabled = true
        rootGroup.isSearchingEnabled = true
        rootGroup.canExpire = false
        rootGroup.isExpanded = true
        db.root = rootGroup
        return db
    }
    
    override public class func isSignatureMatches(data: ByteArray) -> Bool {
        return Header2.isSignatureMatches(data: data)
    }
    
    internal func addDeletedObject(uuid: UUID) {
        let deletedObject = DeletedObject2(database: self, uuid: uuid)
        deletedObjects.append(deletedObject)
    }
    
    override public func load(
        dbFileName: String,
        dbFileData: ByteArray,
        preTransformedKeyMaterial: ByteArray
    ) throws {
        Logger.mainLog.info("Loading KDBX database")
        do {
            try header.read(data: dbFileData) 
            Logger.mainLog.debug("Header read OK [format: \(self.header.formatVersion, privacy: .public)]")
            importMasterKey(preTransformedKeyMaterial: preTransformedKeyMaterial, cipher: header.dataCipher)
            var decryptedData: ByteArray
            let dbWithoutHeader: ByteArray = dbFileData.suffix(from: header.size)
            
            decryptedData = try decryptBlocksV4(
                data: dbWithoutHeader,
                cipher: header.dataCipher)
            Logger.mainLog.debug("Block decryption OK")
            
            if header.isCompressed {
                Logger.mainLog.debug("Inflating Gzip data")
                decryptedData = try decryptedData.gunzipped() 
            } else {
                Logger.mainLog.debug("Data not compressed")
            }
            
            var xmlData: ByteArray
            switch header.formatVersion {
            case .v4, .v4_1:
                let innerHeaderSize = try header.readInner(data: decryptedData) 
                xmlData = decryptedData.suffix(from: innerHeaderSize)
                Logger.mainLog.debug("Inner header read OK")
            }
            
            try load(xmlData: xmlData, timeParser: self)
            
            if let backupGroup = getBackupGroup(createIfMissing: false) {
                backupGroup.deepSetDeleted(true)
            }
            
            assert(root != nil)
            var allCurrentEntries = [Entry]()
            root?.collectAllEntries(to: &allCurrentEntries) 
            
            var allEntriesPlusHistory = [Entry]()
            allEntriesPlusHistory.reserveCapacity(allCurrentEntries.count * 4) 
            allCurrentEntries.forEach { entry in
                allEntriesPlusHistory.append(entry)
                guard let entry2 = entry as? Entry2 else { assertionFailure(); return }
                allEntriesPlusHistory.append(contentsOf: entry2.history)
            }
            
            resolveReferences(
                allEntries: allEntriesPlusHistory
            )
            
            Logger.mainLog.debug("Content loaded OK")
        } catch is Header2.HeaderError {
            throw DatabaseError.loadError(
                reason: "load error"
            )
        } catch is CryptoError {
            throw DatabaseError.loadError(reason: "crypto error")
        } catch is KeyFileError {
            throw DatabaseError.loadError(reason: "keyfile error")
        } catch is FormatError {
            throw DatabaseError.loadError(
                reason: "format error")
        } catch is GzipError {
            throw DatabaseError.loadError(reason: "gzip error")
        }
        
        self.compositeKey = compositeKey
    }
    
    func decryptBlocksV4(data: ByteArray, cipher: DataCipher) throws -> ByteArray {
        Logger.mainLog.debug("Decrypting V4 blocks")
        let inStream = data.asInputStream()
        inStream.open()
        defer { inStream.close() }
        
        guard let storedHash = inStream.read(count: SHA256_SIZE) else {
            throw FormatError.prematureDataEnd
        }
        guard header.hash == storedHash else {
            Logger.mainLog.error("Header hash mismatch. Database corrupted?")
            throw Header2.HeaderError.hashMismatch
        }
        
        let headerHMAC = header.getHMAC(key: self.hmacKey)
        guard let storedHMAC = inStream.read(count: SHA256_SIZE) else {
            throw FormatError.prematureDataEnd
        }
        guard headerHMAC == storedHMAC else {
            Logger.mainLog.error("Header HMAC mismatch. Invalid master key?")
            throw DatabaseError.invalidKey
        }
        
        Logger.mainLog.trace("Reading blocks")
        let blockBytesCount = data.count - storedHash.count - storedHMAC.count
        let allBlocksData = ByteArray(capacity: blockBytesCount)
        
        var blockIndex: UInt64 = 0
        while true {
            guard let storedBlockHMAC = inStream.read(count: SHA256_SIZE) else {
                throw FormatError.prematureDataEnd
            }
#if DEBUG
            print("Stored block HMAC: \(storedBlockHMAC.asHexString)")
#endif
            guard let blockSize = inStream.readInt32() else {
                throw FormatError.prematureDataEnd
            }
            guard blockSize >= 0 else {
                throw FormatError.negativeBlockSize(blockIndex: Int(blockIndex))
            }
            
            guard let blockData = inStream.read(count: Int(blockSize)) else {
                throw FormatError.prematureDataEnd
            }
            let blockKey = CryptoManager.getHMACKey64(key: hmacKey, blockIndex: blockIndex)
            let dataForHMAC = ByteArray.concat(blockIndex.data, blockSize.data, blockData)
            let blockHMAC = CryptoManager.hmacSHA256(data: dataForHMAC, key: blockKey)
            guard blockHMAC == storedBlockHMAC else {
                Logger.mainLog.error("Block HMAC mismatch")
                throw FormatError.blockHMACMismatch(blockIndex: Int(blockIndex))
            }
            
            if blockSize == 0 { break }
            
            allBlocksData.append(blockData)
            blockIndex += 1
        }
        
        Logger.mainLog.trace("Will decrypt \(allBlocksData.count) bytes")
        
#if DEBUG
        print("hmacKey plain: \(hmacKey.asHexString)")
        print("hmacKey enc: \(hmacKey.description)")
        
        print("cipherKey plain: \(cipherKey.asHexString)")
        print("cipherKey enc: \(cipherKey.description)")
#endif
        
        let decryptedData = try cipher.decrypt(
            cipherText: allBlocksData,
            key: cipherKey,
            iv: header.initialVector
        ) 
        Logger.mainLog.trace("Decrypted \(decryptedData.count) bytes")
        
        return decryptedData
    }
    
    
    func load(
        xmlData: ByteArray,
        timeParser: Database2XMLTimeParser
    ) throws {
        var parsingOptions = AEXMLOptions()
        parsingOptions.documentHeader.standalone = "yes"
        parsingOptions.parserSettings.shouldTrimWhitespace = false
        do {
            Logger.mainLog.debug("Parsing XML")
            let xmlDoc = try AEXMLDocument(xml: xmlData.asData, options: parsingOptions)
            if let xmlError = xmlDoc.error {
                Logger.mainLog.error("Cannot parse XML: \(xmlError.localizedDescription)")
                throw Xml2.ParsingError.xmlError(details: xmlError.localizedDescription)
            }
            guard xmlDoc.root.name == Xml2.keePassFile else {
                Logger.mainLog.error("Not a KeePass XML document [xmlRoot: \(xmlDoc.root.name)]")
                throw Xml2.ParsingError.notKeePassDocument
            }
            
            let rootGroup = Group2(database: self)
            rootGroup.parent = nil
            
            for tag in xmlDoc.root.children {
                switch tag.name {
                case Xml2.meta:
                    try meta.load(
                        xml: tag,
                        formatVersion: header.formatVersion,
                        streamCipher: header.streamCipher,
                        timeParser: self
                    ) 
                    
                    if meta.headerHash != nil && (header.hash != meta.headerHash!) {
                        Logger.mainLog.error("kdbx3 meta meta hash mismatch")
                        throw Header2.HeaderError.hashMismatch
                    }
                    Logger.mainLog.trace("Meta loaded OK")
                case Xml2.root:
                    try loadRoot(
                        xml: tag,
                        root: rootGroup,
                        timeParser: timeParser
                    ) 
                    Logger.mainLog.trace("XML root loaded OK")
                default:
                    throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "KeePassFile/*")
                }
            }
            
            self.root = rootGroup
            Logger.mainLog.debug("XML content loaded OK")
        } catch let error as Header2.HeaderError {
            Logger.mainLog.error("Header error [reason: \(error.localizedDescription)]")
            throw FormatError.parsingError(reason: error.localizedDescription)
        } catch let error as Xml2.ParsingError {
            Logger.mainLog.error("XML parsing error [reason: \(error.localizedDescription)]")
            throw FormatError.parsingError(reason: error.localizedDescription)
        } catch let error as AEXMLError {
            Logger.mainLog.error("Raw XML parsing error [reason: \(error.localizedDescription)]")
            throw FormatError.parsingError(reason: error.localizedDescription)
        }
    }
    
    internal func loadRoot(
        xml: AEXMLElement,
        root: Group2,
        timeParser: Database2XMLTimeParser
    ) throws {
        assert(xml.name == Xml2.root)
        Logger.mainLog.debug("Loading XML root")
        for tag in xml.children {
            switch tag.name {
            case Xml2.group:
                try root.load(
                    xml: tag,
                    formatVersion: header.formatVersion,
                    streamCipher: header.streamCipher,
                    timeParser: timeParser
                ) 
            case Xml2.deletedObjects:
                try loadDeletedObjects(xml: tag, timeParser: timeParser)
            default:
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "Root/*")
            }
        }
    }
    
    private func loadDeletedObjects(
        xml: AEXMLElement,
        timeParser: Database2XMLTimeParser
    ) throws {
        assert(xml.name == Xml2.deletedObjects)
        for tag in xml.children {
            switch tag.name {
            case Xml2.deletedObject:
                let deletedObject = DeletedObject2(database: self)
                try deletedObject.load(xml: tag, timeParser: timeParser)
                deletedObjects.append(deletedObject)
            default:
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "DeletedObjects/*")
            }
        }
    }
    
    func importMasterKey(preTransformedKeyMaterial: ByteArray, cipher: DataCipher) {
        
        // Have to do this or change CompositeKey class to support importing directly
        compositeKey = CompositeKey(staticComponents: preTransformedKeyMaterial)
        
        let secureMasterSeed = header.masterSeed.clone()
        let joinedKey = ByteArray.concat(secureMasterSeed, preTransformedKeyMaterial)
        self.cipherKey = cipher.resizeKey(key: joinedKey)

        var oneBytes = [UInt8]()
        oneBytes.append(1)
        let one = ByteArray(bytes: oneBytes)
        // SOMEHOW, when Swift evaluates this array literal assignment for the 2nd time, it decides to use 0 instead of 1 for
        // the value it initialises with. Thus, it is critical that the hacky workaround above remain in place and no
        // seemingly innocuous change like below is allowed to be made, at least until a version of Swift >5.7
        // resolves the bug or some deeper workaround in the ByteArray initialiser is made possible.
        // Theory: [1] is syntactic sugar for a let declaration of a new array and thus the optimiser determines that
        // it can never be mutated. Therefore when we actually do mutate it as part of the empty() memory sanitation
        // step at the end of the first run through the autofill extension, we end up modifying something that the
        // compiler has reasonably determined will never change and thus can be re-used safely in future. Creating
        // oneBytes as a var ensures this optimisation is not performed.
        //let one = ByteArray(bytes: [1])
        
        self.hmacKey = ByteArray.concat(joinedKey, one).sha512
        compositeKey.setFinalKeys(hmacKey, cipherKey)
    }
    
    func rederiveMasterKey(key: CompositeKey, cipher: DataCipher) {
        let secureMasterSeed = header.masterSeed.clone()
        let joinedKey = ByteArray.concat(secureMasterSeed, key.combinedStaticComponents!)
        self.cipherKey = cipher.resizeKey(key: joinedKey)
        
        var oneBytes = [UInt8]()
        oneBytes.append(1)
        let one = ByteArray(bytes: oneBytes)
        // See importMasterKey before changing this function
        //let one = ByteArray(bytes: [1])
        
        self.hmacKey = ByteArray.concat(joinedKey, one).sha512
        compositeKey.setFinalKeys(hmacKey, cipherKey)
    }
    
    override public func changeCompositeKey(to newKey: CompositeKey) {
        compositeKey = newKey.clone()
        meta.masterKeyChangedTime = Date.now
        meta.masterKeyChangeForceOnce = false
    }
    
    override public func getBackupGroup(createIfMissing: Bool) -> Group? {
        assert(root != nil)
        if !meta.isRecycleBinEnabled {
            Logger.mainLog.trace("RecycleBin disabled in Meta")
            return nil
        }
        
        guard let root = root else {
            Logger.mainLog.warning("Tried to get RecycleBin group without the root one")
            assertionFailure()
            return nil
        }
        
        if meta.recycleBinGroupUUID != UUID.ZERO {
            if let backupGroup = root.findGroup(byUUID: meta.recycleBinGroupUUID) {
                Logger.mainLog.trace("RecycleBin group found")
                return backupGroup
            }
        }
        
        if createIfMissing {
            let backupGroup = meta.createRecycleBinGroup()
            root.add(group: backupGroup)
            backupGroup.isDeleted = true
            backupGroup.isSearchingEnabled = false
            backupGroup.isAutoTypeEnabled = false
            Logger.mainLog.trace("RecycleBin group created")
            return backupGroup
        }
        Logger.mainLog.trace("RecycleBin group not found nor created.")
        return nil
    }
    
    private func updateBinaries(root: Group2) {
        Logger.mainLog.trace("Updating all binaries")
        var allEntries = [Entry2]() as [Entry]
        root.collectAllEntries(to: &allEntries)
        
        var oldBinaryPoolInverse = [ByteArray : Binary2]()
        binaries.values.forEach { oldBinaryPoolInverse[$0.data] = $0 }
        
        var newBinaryPoolInverse = [ByteArray: Binary2]()
        for entry in allEntries {
            updateBinaries(
                entry: entry as! Entry2,
                oldPoolInverse: oldBinaryPoolInverse,
                newPoolInverse: &newBinaryPoolInverse)
        }
        binaries.removeAll()
        newBinaryPoolInverse.values.forEach { binaries[$0.id] = $0 }
    }
    
    private func updateBinaries(
        entry: Entry2,
        oldPoolInverse: [ByteArray: Binary2],
        newPoolInverse: inout [ByteArray: Binary2])
    {
        for histEntry in entry.history {
            updateBinaries(
                entry: histEntry,
                oldPoolInverse: oldPoolInverse,
                newPoolInverse: &newPoolInverse
            )
        }
        
        for att in entry.attachments {
            let att2 = att as! Attachment2
            if let binaryInNewPool = newPoolInverse[att2.data],
               binaryInNewPool.isCompressed == att2.isCompressed
            {
                att2.id = binaryInNewPool.id
                continue
            }
            
            let newID = newPoolInverse.count
            let newBinary: Binary2
            if let binaryInOldPool = oldPoolInverse[att2.data],
               binaryInOldPool.isCompressed == att2.isCompressed
            {
                newBinary = Binary2(
                    id: newID,
                    data: binaryInOldPool.data,
                    isCompressed: binaryInOldPool.isCompressed,
                    isProtected: binaryInOldPool.isProtected
                )
            } else {
                
                newBinary = Binary2(
                    id: newID,
                    data: att2.data,
                    isCompressed: att2.isCompressed,
                    isProtected: !att2.isCompressed
                )
            }
            newPoolInverse[newBinary.data] = newBinary
            att2.id = newID
        }
    }
    
    override public func save() throws -> ByteArray {
        Logger.mainLog.info("Saving KDBX database")
        assert(root != nil, "Load or create a DB before saving.")
        
        header.maybeUpdateFormatVersion()
        let formatVersion = header.formatVersion
        Logger.mainLog.debug("Format version: \(formatVersion)")
        do {
            try header.randomizeSeeds() 
            Logger.mainLog.debug("Seeds randomized OK")
            rederiveMasterKey(
                key: compositeKey,
                cipher: header.dataCipher)
            Logger.mainLog.debug("Key derivation OK")
        } catch let error as CryptoError {
            throw DatabaseError.saveError(reason: error.localizedDescription)
        } catch is KeyFileError {
            throw DatabaseError.saveError(reason: "keyfile")
        }
        
        updateBinaries(root: root! as! Group2)
        Logger.mainLog.trace("Binaries updated OK")
        
        let outStream = ByteArray.makeOutputStream()
        outStream.open()
        defer { outStream.close() }
        
        header.write(to: outStream) 
        
        meta.headerHash = header.hash
        let xmlString = try self.toXml(timeFormatter: self).xml 
        let xmlData = ByteArray(utf8String: xmlString)
        Logger.mainLog.debug("XML generation OK")
        
        try encryptBlocksV4(to: outStream, xmlData: xmlData)
        Logger.mainLog.debug("Content encryption OK")
        
        var allEntries = [Entry]()
        root?.collectAllEntries(to: &allEntries)
        resolveReferences(
            allEntries: allEntries
        )
        
        return outStream.data!
    }
    
    internal func encryptBlocksV4(to outStream: ByteArray.OutputStream, xmlData: ByteArray) throws {
        Logger.mainLog.debug("Encrypting kdbx4 blocks")
        outStream.write(data: header.hash)
        outStream.write(data: header.getHMAC(key: hmacKey))
        
        let contentStream = ByteArray.makeOutputStream()
        contentStream.open()
        defer { contentStream.close() }
        
        do {
            try header.writeInner(to: contentStream) 
            Logger.mainLog.trace("Header written OK")
            contentStream.write(data: xmlData)
            guard let contentData = contentStream.data else { Logger.fatalError("Failed to get data from contentStream") }
            
            var dataToEncrypt = contentData
            if header.isCompressed {
                dataToEncrypt = try contentData.gzipped()
                Logger.mainLog.trace("Gzip compression OK")
            } else {
                Logger.mainLog.trace("No compression required")
            }
            
            Logger.mainLog.trace("Encrypting \(dataToEncrypt.count) bytes")
            let encData = try header.dataCipher.encrypt(
                plainText: dataToEncrypt,
                key: cipherKey,
                iv: header.initialVector.clone())
            Logger.mainLog.trace("Encrypted \(encData.count) bytes")
            
            try writeAsBlocksV4(to: outStream, data: encData) 
            Logger.mainLog.trace("Blocks written OK")
        } catch let error as Header2.HeaderError {
            Logger.mainLog.error("Header error [message: \(error.localizedDescription)]")
            throw DatabaseError.saveError(reason: error.localizedDescription)
        } catch let error as GzipError {
            Logger.mainLog.error("Gzip error [kind: \(String(describing: error.kind)), message: \(error.message)]")
            let errMsg = String.localizedStringWithFormat(
                NSLocalizedString(
                    "[Database2/Saving/Error] Data compression error: %@",
                    bundle: Bundle.framework,
                    value: "Data compression error: %@",
                    comment: "Error message while saving a database. [errorDescription: String]"),
                error.localizedDescription)
            throw DatabaseError.saveError(reason: errMsg)
        } catch let error as CryptoError {
            Logger.mainLog.error("Crypto error [reason: \(error.localizedDescription)]")
            let errMsg = String.localizedStringWithFormat(
                NSLocalizedString(
                    "[Database2/Saving/Error] Encryption error: %@",
                    bundle: Bundle.framework,
                    value: "Encryption error: %@",
                    comment: "Error message while saving a database. [errorDescription: String]"),
                error.localizedDescription)
            throw DatabaseError.saveError(reason: errMsg)
        }
    }
    
    internal func writeAsBlocksV4(to blockStream: ByteArray.OutputStream, data: ByteArray) throws {
        Logger.mainLog.debug("Writing kdbx4 blocks")
        let defaultBlockSize  = 1024 * 1024 
        var blockStart: Int = 0
        var blockIndex: UInt64 = 0
        
        Logger.mainLog.trace("\(data.count) bytes to write")
        while blockStart != data.count {
            let blockSize = min(defaultBlockSize, data.count - blockStart)
            let blockData = data[blockStart..<blockStart+blockSize]
            
            let blockKey = CryptoManager.getHMACKey64(key: hmacKey, blockIndex: blockIndex)
            let dataForHMAC = ByteArray.concat(blockIndex.data, Int32(blockSize).data, blockData)
            let blockHMAC = CryptoManager.hmacSHA256(data: dataForHMAC, key: blockKey)
            blockStream.write(data: blockHMAC)
            blockStream.write(value: Int32(blockSize))
            blockStream.write(data: blockData)
            blockStart += blockSize
            blockIndex += 1
        }
        let endBlockSize: Int32 = 0
        let endBlockKey = CryptoManager.getHMACKey64(key: hmacKey, blockIndex: blockIndex)
        let endBlockHMAC = CryptoManager.hmacSHA256(
            data: ByteArray.concat(blockIndex.data, endBlockSize.data),
            key: endBlockKey)
        blockStream.write(data: endBlockHMAC)
        blockStream.write(value: endBlockSize)
    }
    
    func toXml(timeFormatter: Database2XMLTimeFormatter) throws -> AEXMLDocument {
        Logger.mainLog.debug("Will generate XML")
        var options = AEXMLOptions()
        options.documentHeader.encoding = "utf-8"
        options.documentHeader.standalone = "yes"
        options.documentHeader.version = 1.0
        
        let xmlMain = AEXMLElement(name: Xml2.keePassFile)
        let xmlDoc = AEXMLDocument(root: xmlMain, options: options)
        xmlMain.addChild(
            try meta.toXml(
                streamCipher: header.streamCipher,
                formatVersion: header.formatVersion,
                timeFormatter: timeFormatter
            )
        ) 
        Logger.mainLog.trace("XML generation: Meta OK")
        
        let xmlRoot = xmlMain.addChild(name: Xml2.root)
        let root2 = root! as! Group2
        let rootXML = try root2.toXml(
            formatVersion: header.formatVersion,
            streamCipher: header.streamCipher,
            timeFormatter: timeFormatter
        ) 
        xmlRoot.addChild(rootXML)
        Logger.mainLog.trace("XML generation: Root group OK")
        
        let xmlDeletedObjects = xmlRoot.addChild(name: Xml2.deletedObjects)
        for deletedObject in deletedObjects {
            xmlDeletedObjects.addChild(deletedObject.toXml(timeFormatter: timeFormatter))
        }
        return xmlDoc
    }
    
    func setAllTimestamps(to time: Date) {
        meta.setAllTimestamps(to: time)
        
        guard let root = root else { return }
        var groups: [Group] = [root]
        var entries: [Entry] = []
        root.collectAllChildren(groups: &groups, entries: &entries)
        for group in groups {
            group.creationTime = time
            group.lastAccessTime = time
            group.lastModificationTime = time
        }
        for entry in entries {
            entry.creationTime = time
            entry.lastModificationTime = time
            entry.lastAccessTime = time
        }
    }
    
    override public func delete(group: Group) {
        guard let group = group as? Group2 else { Logger.fatalError("Cannot delete group: not a Group") }
        guard let parentGroup = group.parent else {
            Logger.mainLog.warning("Cannot delete group: no parent group")
            return
        }
        
        var subGroups = [Group]()
        var subEntries = [Entry]()
        group.collectAllChildren(groups: &subGroups, entries: &subEntries)
        
        let moveOnly = !group.isDeleted && meta.isRecycleBinEnabled
        if moveOnly, let backupGroup = getBackupGroup(createIfMissing: meta.isRecycleBinEnabled) {
            Logger.mainLog.debug("Moving group to RecycleBin")
            group.move(to: backupGroup) 
            group.touch(.accessed, updateParents: false)
            
            group.isDeleted = true
            subGroups.forEach { $0.isDeleted = true }
            subEntries.forEach { $0.isDeleted = true }
        } else {
            Logger.mainLog.debug("Removing the group permanently.")
            if group === getBackupGroup(createIfMissing: false) {
                meta?.resetRecycleBinGroupUUID()
            }
            addDeletedObject(uuid: group.uuid)
            subGroups.forEach { addDeletedObject(uuid: $0.uuid) }
            subEntries.forEach { addDeletedObject(uuid: $0.uuid) }
            parentGroup.remove(group: group)
        }
        Logger.mainLog.debug("Delete group OK")
    }
    
    override public func delete(entry: Entry) {
        guard let parentGroup = entry.parent else {
            Logger.mainLog.warning("Cannot delete entry: no parent group")
            return
        }
        
        if entry.isDeleted {
            Logger.mainLog.debug("Already in Backup, removing permanently")
            addDeletedObject(uuid: entry.uuid)
            parentGroup.remove(entry: entry)
            return
        }
        
        if meta.isRecycleBinEnabled,
           let backupGroup = getBackupGroup(createIfMissing: meta.isRecycleBinEnabled)
        {
            entry.move(to: backupGroup) 
            entry.touch(.accessed)
        } else {
            Logger.mainLog.debug("Backup disabled, removing permanently.")
            addDeletedObject(uuid: entry.uuid)
            parentGroup.remove(entry: entry)
        }
        Logger.mainLog.debug("Delete entry OK")
    }
    
    override public func makeAttachment(name: String, data: ByteArray) -> Attachment {
        let attemptCompression = header.isCompressed
        
        if attemptCompression {
            do {
                let compressedData = try data.gzipped()
                return Attachment2(name: name, isCompressed: true, data: compressedData)
            } catch {
                Logger.mainLog.warning("Failed to compress attachment data [message: \(error.localizedDescription)]")
            }
        }
        
        return Attachment2(name: name, isCompressed: false, data: data)
    }
    
    @discardableResult
    public func addCustomIcon(pngData: ByteArray) -> CustomIcon2 {
        if let existingIcon = findCustomIcon(pngDataSha256: pngData.sha256) {
            return existingIcon
        }
        
        let newCustomIcon = CustomIcon2(uuid: UUID(), data: pngData)
        meta.addCustomIcon(newCustomIcon)
        Logger.mainLog.debug("Custom icon added OK")
        return newCustomIcon
    }
    
    public func findCustomIcon(pngDataSha256: ByteArray) -> CustomIcon2? {
        return customIcons.first(where: { $0.data.sha256 == pngDataSha256 })
    }
    
    public func getCustomIcon(with uuid: UUID) -> CustomIcon2? {
        return customIcons.first(where: { $0.uuid == uuid })
    }
    
    @discardableResult
    public func deleteCustomIcon(uuid: UUID) -> Bool {
        guard customIcons.contains(where: { $0.uuid == uuid }) else {
            Logger.mainLog.warning("Tried to delete non-existent custom icon")
            return false
        }
        meta.deleteCustomIcon(uuid: uuid)
        deletedObjects.append(DeletedObject2(database: self, uuid: uuid))
        removeUnusedCustomIconRefs()
        Logger.mainLog.debug("Custom icon deleted OK")
        return true
    }
    
    private func removeUnusedCustomIconRefs() {
        let knownIconUUIDs = Set<UUID>(customIcons.map { $0.uuid })
        root?.applyToAllChildren(
            groupHandler: { group in
                (group as! Group2).enforceCustomIconUUID(isValid: knownIconUUIDs)
            },
            entryHandler: { entry in
                (entry as! Entry2).enforceCustomIconUUID(isValid: knownIconUUIDs)
            }
        )
    }
}

extension Database2: Database2XMLTimeParser {
    func xmlStringToDate(_ string: String?) -> Date? {
        let trimmedString = string?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let formatAppropriateDate = Date(base64Encoded: trimmedString) {
            return formatAppropriateDate
        }
        if let altFormatDate = Date(iso8601string: trimmedString) {
            Logger.mainLog.warning("Found ISO8601-formatted timestamp in \(self.header.formatVersion) DB.")
            return altFormatDate
        }
        return nil
    }
}

extension Database2: Database2XMLTimeFormatter {
    func dateToXMLString(_ date: Date) -> String {
        return date.base64EncodedString()
    }
}

private extension Group2 {
    func enforceCustomIconUUID(isValid validValues: Set<UUID>) {
        guard customIconUUID != UUID.ZERO else { return }
        if !validValues.contains(self.customIconUUID) {
            customIconUUID = UUID.ZERO
        }
    }
}

private extension Entry2 {
    func enforceCustomIconUUID(isValid validValues: Set<UUID>) {
        guard customIconUUID != UUID.ZERO else { return }
        if !validValues.contains(customIconUUID) {
            customIconUUID = UUID.ZERO
        }
        history.forEach { historyEntry in
            historyEntry.enforceCustomIconUUID(isValid: validValues)
        }
    }
}
