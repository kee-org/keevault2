import Foundation
import CommonCrypto
import Logging

final class Header2: Eraseable {
    private static let signature1: UInt32 = 0x9AA2D903
    private static let signature2: UInt32 = 0xB54BFB67
    private static let fileVersion3: UInt32 = 0x00030001
    private static let fileVersion4: UInt32 = 0x00040000
    private static let fileVersion4_1: UInt32 = 0x00040001
    private static let majorVersionMask: UInt32 = 0xFFFF0000


    enum HeaderError: LocalizedError {
        case readingError
        case wrongSignature
        case unsupportedFileVersion(actualVersion: String)
        case unsupportedDataCipher(uuidHexString: String)
        case unsupportedStreamCipher(id: UInt32)
        case unsupportedKDF(uuid: UUID)
        case unknownCompressionAlgorithm
        case binaryUncompressionError(reason: String)
        case hashMismatch 
        case hmacMismatch 
        case corruptedField(fieldName: String)
        
        public var errorDescription: String? {
            switch self {
            case .readingError:
                return NSLocalizedString(
                    "[Database2/Header2/Error] Header reading error. DB file corrupt?",
                    bundle: Bundle.framework,
                    value: "Header reading error. DB file corrupt?",
                    comment: "Error message when reading database header")
            case .wrongSignature:
                return NSLocalizedString(
                    "[Database2/Header2/Error] Wrong file signature. Not a KeePass database?",
                    bundle: Bundle.framework,
                    value: "Wrong file signature. Not a KeePass database?",
                    comment: "Error message when opening a database")
            case .unsupportedFileVersion(let version):
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database2/Header2/Error] Unsupported database format version: %@.",
                        bundle: Bundle.framework,
                        value: "Unsupported database format version: %@.",
                        comment: "Error message when opening a database. [version: String]"),
                    version)
            case .unsupportedDataCipher(let uuidHexString):
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database2/Header2/Error] Unsupported data cipher: %@",
                        bundle: Bundle.framework,
                        value: "Unsupported data cipher: %@",
                        comment: "Error message. [uuidHexString: String]"),
                    uuidHexString.prefix(32).localizedUppercase)
            case .unsupportedStreamCipher(let id):
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database2/Header2/Error] Unsupported inner stream cipher (ID %d)",
                        bundle: Bundle.framework,
                        value: "Unsupported inner stream cipher (ID %d)",
                        comment: "Error message when opening a database. [id: UInt32]"),
                    id)
            case .unsupportedKDF(let uuid):
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database2/Header2/Error] Unsupported KDF: %@",
                        bundle: Bundle.framework,
                        value: "Unsupported KDF: %@",
                        comment: "Error message about Key Derivation Function. [uuidString: String]"),
                    uuid.uuidString)
            case .unknownCompressionAlgorithm:
                return NSLocalizedString(
                    "[Database2/Header2/Error] Unknown compression algorithm.",
                    bundle: Bundle.framework,
                    value: "Unknown compression algorithm.",
                    comment: "Error message when opening a database")
            case .binaryUncompressionError(let reason):
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database2/Header2/Error] Failed to uncompress attachment data: %@",
                        bundle: Bundle.framework,
                        value: "Failed to uncompress attachment data: %@",
                        comment: "Error message when saving a database. [reason: String]"),
                    reason)
            case .corruptedField(let fieldName):
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database2/Header2/Error] Header field %@ is corrupted.",
                        bundle: Bundle.framework,
                        value: "Header field %@ is corrupted.",
                        comment: "Error message, with the name of problematic field. [fieldName: String]"),
                    fieldName)
            case .hashMismatch:
                return NSLocalizedString(
                    "[Database2/Header2/Error] Header hash mismatch. DB file corrupt?",
                    bundle: Bundle.framework,
                    value: "Header hash mismatch. DB file corrupt?",
                    comment: "Error message")
            case .hmacMismatch:
                return NSLocalizedString(
                    "[Database2/Header2/Error] Header HMAC mismatch. DB file corrupt?",
                    bundle: Bundle.framework,
                    value: "Header HMAC mismatch. DB file corrupt?",
                    comment: "Error message. HMAC = https://en.wikipedia.org/wiki/HMAC")
            }
        }
    }

    enum FieldID: UInt8 {
        case end                 = 0
        case comment             = 1
        case cipherID            = 2
        case compressionFlags    = 3
        case masterSeed          = 4
        case transformSeed       = 5 
        case transformRounds     = 6 
        case encryptionIV        = 7
        case protectedStreamKey  = 8 
        case streamStartBytes    = 9 
        case innerRandomStreamID = 10 
        case kdfParameters       = 11 
        case publicCustomData    = 12 
        public var name: String {
            switch self {
            case .end:      return "End"
            case .comment:  return "Comment"
            case .cipherID: return "CipherID"
            case .compressionFlags: return "CompressionFlags"
            case .masterSeed:       return "MasterSeed"
            case .transformSeed:    return "TransformSeed"
            case .transformRounds:  return "TransformRounds"
            case .encryptionIV:     return "EncryptionIV"
            case .protectedStreamKey:  return "ProtectedStreamKey"
            case .streamStartBytes:    return "StreamStartBytes"
            case .innerRandomStreamID: return "RandomStreamID"
            case .kdfParameters:       return "KDFParameters"
            case .publicCustomData:    return "PublicCustomData"
            }
        }
    }

    enum InnerFieldID: UInt8 {
        case end                  = 0
        case innerRandomStreamID  = 1
        case innerRandomStreamKey = 2
        case binary               = 3
        public var name: String {
            switch self {
            case .end: return "Inner/End"
            case .innerRandomStreamID:  return "Inner/RandomStreamID"
            case .innerRandomStreamKey: return "Inner/RandomStreamKey"
            case .binary: return "Inner/Binary"
            }
        }
    }
    
    enum CompressionAlgorithm: UInt8 {
        case noCompression = 0
        case gzipCompression = 1
    }
    
    private unowned let database: Database2
    private var initialized: Bool
    private var data: ByteArray 
    
    private(set) var formatVersion: Database2.FormatVersion
    internal var size: Int { return data.count }
    private(set) var fields: [FieldID: ByteArray]
    private(set) var hash: ByteArray
    private(set) var dataCipher: DataCipher
    private(set) var kdf: KeyDerivationFunction
    private(set) var kdfParams: KDFParams
    private(set) var streamCipher: StreamCipher
    private(set) var publicCustomData: VarDict 
    
    var masterSeed: ByteArray { return fields[.masterSeed]! }
    var streamStartBytes: ByteArray? { return fields[.streamStartBytes] }
    
    var initialVector:  ByteArray { return fields[.encryptionIV]! }
    var isCompressed: Bool {
        guard let fieldData = fields[.compressionFlags],
              let compressionValue = UInt32(data: fieldData) else {
            assertionFailure()
            return false
        }
        return compressionValue != CompressionAlgorithm.noCompression.rawValue
    }
    
    var protectedStreamKey: ByteArray?
    var innerStreamAlgorithm: ProtectedStreamAlgorithm
    
    class func isSignatureMatches(data: ByteArray) -> Bool {
        let ins = data.asInputStream()
        ins.open()
        defer { ins.close() }
        guard let sign1: UInt32 = ins.readUInt32(),
            let sign2: UInt32 = ins.readUInt32() else {
                return false
        }
        return (sign1 == Header2.signature1) && (sign2 == Header2.signature2)
    }
    
    init(database: Database2) {
        Logger.mainLog.debug("DB header init")
        self.database = database
        initialized = false
        formatVersion = .v4
        data = ByteArray()
        fields = [:]
        dataCipher = AESDataCipher()
        hash = ByteArray()
        kdf = Argon2dKDF()
        kdfParams = kdf.defaultParams
        innerStreamAlgorithm = .Null
        streamCipher = UselessStreamCipher()
        publicCustomData = VarDict()
    }
    deinit {
        erase()
    }
    
    func erase() {
        Logger.mainLog.debug("DB header erase")
        initialized = false
        formatVersion = .v4
        data.erase()
        hash.erase()
        for (_, field) in fields { field.erase() }
        fields.removeAll()
        dataCipher = AESDataCipher()
        kdf = Argon2dKDF()
        kdfParams = kdf.defaultParams
        innerStreamAlgorithm = .Null
        streamCipher.erase()
        publicCustomData.erase()
    }
    
    func loadDefaultValuesV4() {
        formatVersion = .v4

        dataCipher = ChaCha20DataCipher()
        fields[.cipherID] = dataCipher.uuid.data
        
        kdf = Argon2dKDF()
        kdfParams = kdf.defaultParams
        let iterations: UInt64 = 100
        let memory: UInt64 = 1*1024*1024
        let parallelism: UInt32 = 2
        kdfParams.setValue(
            key: AbstractArgon2KDF.iterationsParam,
            value: VarDict.TypedValue(value: iterations))
        kdfParams.setValue(
            key: AbstractArgon2KDF.memoryParam,
            value: VarDict.TypedValue(value: memory))
        kdfParams.setValue(
            key: AbstractArgon2KDF.parallelismParam,
            value: VarDict.TypedValue(value: parallelism))
        fields[.kdfParameters] = kdfParams.data!
        
        let compressionFlags = UInt32(exactly: CompressionAlgorithm.gzipCompression.rawValue)!
        fields[.compressionFlags] = compressionFlags.data

        innerStreamAlgorithm = .ChaCha20

        fields[.publicCustomData] = ByteArray()
        
        
        initialized = true
    }
    
    private func verifyFileSignature(stream: ByteArray.InputStream, headerSize: inout Int) throws {
        guard let sign1: UInt32 = stream.readUInt32(),
              let sign2: UInt32 = stream.readUInt32()
        else {
            Logger.mainLog.error("Signature is too short")
            throw HeaderError.readingError
        }
        headerSize += sign1.byteWidth + sign2.byteWidth
        guard sign1 == Header2.signature1 else {
            Logger.mainLog.error("Wrong signature #1")
            throw HeaderError.wrongSignature
        }
        guard sign2 == Header2.signature2 else {
            Logger.mainLog.error("Wrong signature #2")
            throw HeaderError.wrongSignature
        }
    }
    
    private func readFormatVersion(stream: ByteArray.InputStream, headerSize: inout Int) throws {
        guard let fileVersion: UInt32 = stream.readUInt32() else {
            Logger.mainLog.error("Signature is too short")
            throw HeaderError.readingError
        }
        headerSize += fileVersion.byteWidth

        let maskedFileVersion = fileVersion & Header2.majorVersionMask
        if maskedFileVersion == (Header2.fileVersion4 & Header2.majorVersionMask) {
            formatVersion = .v4
            if fileVersion == Header2.fileVersion4_1 {
                formatVersion = .v4_1
            }
            Logger.mainLog.trace("Database format", metadata: ["public:version": "\(self.formatVersion)"])
            return
        }
        
        Logger.mainLog.error("Unsupported file version", metadata: ["public:version": "\(fileVersion.asHexString)"])
        throw HeaderError.unsupportedFileVersion(actualVersion: fileVersion.asHexString)
    }
    
    func read(data inputData: ByteArray) throws {
        if (initialized) {
            Logger.fatalError("Tried to read already initialized header")
        }
        
        Logger.mainLog.trace("Will read header")
        var headerSize = 0 
        let stream = inputData.asInputStream()
        stream.open()
        defer { stream.close() }
        
        try verifyFileSignature(stream: stream, headerSize: &headerSize) 
        try readFormatVersion(stream: stream, headerSize: &headerSize) 
        Logger.mainLog.trace("Header signatures OK")
        
        while (true) {
            guard let rawFieldID: UInt8 = stream.readUInt8() else { throw HeaderError.readingError }
            headerSize += rawFieldID.byteWidth
            
            let fieldSize: Int
                guard let fSize = stream.readUInt32() else { throw HeaderError.readingError }
                fieldSize = Int(fSize)
                headerSize += MemoryLayout.size(ofValue: fSize) + fieldSize
            
            guard let fieldID: FieldID = FieldID(rawValue: rawFieldID) else {
                Logger.mainLog.warning("Unknown field ID, skipping", metadata: ["fieldID": "\(rawFieldID)"])
                continue
            }
            
            guard let fieldValueData = stream.read(count: fieldSize) else {
                throw HeaderError.readingError
            }
            
            if fieldID == .end {
                self.initialized = true
                fields.updateValue(fieldValueData, forKey: fieldID)
                break 
            }

            switch fieldID {
            case .end:
                Logger.mainLog.trace("end field read OK", metadata: ["name": "\(fieldID.name)"])
                break 
            case .comment:
                Logger.mainLog.trace("comment read OK", metadata: ["name": "\(fieldID.name)"])
                break
            case .cipherID:
                guard let _cipherUUID = UUID(data: fieldValueData) else {
                    Logger.mainLog.error("Cipher UUID is misformatted")
                    throw HeaderError.corruptedField(fieldName: fieldID.name)
                }
                guard let _dataCipher = DataCipherFactory.instance.createFor(uuid: _cipherUUID) else {
                    Logger.mainLog.error("Unsupported cipher ID", metadata: ["public:value": "\(fieldValueData.asHexString)"])
                    throw HeaderError.unsupportedDataCipher(
                        uuidHexString: fieldValueData.asHexString)
                }
                self.dataCipher = _dataCipher
                Logger.mainLog.trace("cipherID read OK", metadata: ["name": "\(fieldID.name)", "cipher": "\(self.dataCipher.name)"])
            case .compressionFlags:
                guard let compressionFlags32 = UInt32(data: fieldValueData) else {
                    throw HeaderError.readingError
                }
                guard let compressionFlags8 = UInt8(exactly: compressionFlags32) else {
                    Logger.mainLog.error("Unknown compression algorithm", metadata: ["public:compressionFlags32": "\(compressionFlags32)"])
                    throw HeaderError.unknownCompressionAlgorithm
                }
                guard CompressionAlgorithm(rawValue: compressionFlags8) != nil else {
                    Logger.mainLog.error("Unknown compression algorithm", metadata: ["public:compressionFlags8": "\(compressionFlags8)"])
                    throw HeaderError.unknownCompressionAlgorithm
                }
                Logger.mainLog.trace("compressionFlags read OK", metadata: ["name": "\(fieldID.name)"])
            case .masterSeed:
                guard fieldSize == SHA256_SIZE else {
                    Logger.mainLog.error("Unexpected masterSeed size", metadata: ["name": "\(fieldID.name)", "bytes": "\(fieldSize)"])
                    throw HeaderError.corruptedField(fieldName: fieldID.name)
                }
                Logger.mainLog.trace("masterSeed read OK", metadata: ["name": "\(fieldID.name)"])
            
            case .encryptionIV:
                Logger.mainLog.trace("encryptionIV read OK", metadata: ["name": "\(fieldID.name)"])
                break
            
            case .kdfParameters: 
                guard formatVersion >= .v4 else {
                    Logger.mainLog.error("Found kdfParameters in non-V4 header. Database corrupted?", metadata: ["name": "\(fieldID.name)"])
                    throw HeaderError.corruptedField(fieldName: fieldID.name)
                }
                guard let kdfParams = KDFParams(data: fieldValueData) else {
                    Logger.mainLog.error("Cannot parse KDF params. Database corrupted?")
                    throw HeaderError.corruptedField(fieldName: fieldID.name)
                }
                self.kdfParams = kdfParams
                self.kdf = Argon2dKDF()
                Logger.mainLog.trace("kdfParameters read OK", metadata: ["name": "\(fieldID.name)"])
            case .publicCustomData:
                guard formatVersion >= .v4 else {
                    Logger.mainLog.error("Found publicCustomData in non-V4 header. Database corrupted?", metadata: ["name": "\(fieldID.name)"])
                    throw HeaderError.corruptedField(fieldName: fieldID.name)
                }
                guard let publicCustomData = VarDict(data: fieldValueData) else {
                    Logger.mainLog.error("Cannot parse public custom data. Database corrupted?")
                    throw HeaderError.corruptedField(fieldName: fieldID.name)
                }
                self.publicCustomData = publicCustomData
                Logger.mainLog.trace("publicCustomData read OK", metadata: ["name": "\(fieldID.name)"])
            default:
                throw HeaderError.corruptedField(fieldName: fieldID.name)
            }
            fields.updateValue(fieldValueData, forKey: fieldID)
        }
        
        self.data = inputData.prefix(headerSize)
        self.hash = self.data.sha256
        
        try verifyImportantFields()
        Logger.mainLog.trace("All important fields are in place")
        
    }
    
    private func verifyImportantFields() throws {
        Logger.mainLog.trace("Will check all important fields are present")
        var importantFields: [FieldID]
            importantFields =
                [.cipherID, .compressionFlags, .masterSeed, .encryptionIV, .kdfParameters]
        for fieldID in importantFields {
            guard let fieldData = fields[fieldID] else {
                Logger.mainLog.error("critical field is missing", metadata: ["public:name": "\(fieldID.name)"])
                throw HeaderError.corruptedField(fieldName: fieldID.name)
            }
            if fieldData.isEmpty {
                Logger.mainLog.error("critical field is present, but empty", metadata: ["public:name": "\(fieldID.name)"])
                throw HeaderError.corruptedField(fieldName: fieldID.name)
            }
        }
        Logger.mainLog.trace("All important fields are OK")
        
        guard initialVector.count == dataCipher.initialVectorSize else {
            Logger.mainLog.error("Initial vector size is inappropriate for the cipher", metadata: ["public:size": "\(self.initialVector.count)", "public:UUID": "\(self.dataCipher.uuid)"])
            throw HeaderError.corruptedField(fieldName: FieldID.encryptionIV.name)
        }
    }
    
    internal func initStreamCipher() {
        guard let protectedStreamKey = protectedStreamKey else {
            Logger.fatalError("initStreamCipher: Failed to assign protectedStreamKey")
        }
        self.streamCipher = StreamCipherFactory.create(
            algorithm: innerStreamAlgorithm,
            key: protectedStreamKey)
    }
    
    func getHMAC(key: ByteArray) -> ByteArray {
        assert(!self.data.isEmpty)
        assert(key.count == CC_SHA256_BLOCK_BYTES)
        
        let blockKey = CryptoManager.getHMACKey64(key: key, blockIndex: UInt64.max)
        return CryptoManager.hmacSHA256(data: data, key: blockKey)
    }
    
    
    
    func readInner(data: ByteArray) throws -> Int {
        let stream = data.asInputStream()
        stream.open()
        defer { stream.close() }
        
        Logger.mainLog.trace("Will read inner header")
        var size: Int = 0
        while true {
            guard let rawFieldID = stream.readUInt8() else {
                throw HeaderError.readingError
            }
            guard let fieldID = InnerFieldID(rawValue: rawFieldID) else {
                throw HeaderError.readingError
            }
            guard let fieldSize: Int32 = stream.readInt32() else {
                throw HeaderError.corruptedField(fieldName: fieldID.name)
            }
            guard fieldSize >= 0 else {
                throw HeaderError.readingError
            }
            guard let fieldData = stream.read(count: Int(fieldSize)) else {
                throw HeaderError.corruptedField(fieldName: fieldID.name)
            }
            size += MemoryLayout.size(ofValue: rawFieldID)
                + MemoryLayout.size(ofValue: fieldSize)
                + fieldData.count
            
            switch fieldID {
            case .innerRandomStreamID:
                guard let rawID = UInt32(data: fieldData) else {
                    throw HeaderError.corruptedField(fieldName: fieldID.name)
                }
                guard let protectedStreamAlgorithm = ProtectedStreamAlgorithm(rawValue: rawID) else {
                    Logger.mainLog.error("Unrecognized protected stream algorithm", metadata: ["public:rawID": "\(rawID)"])
                    throw HeaderError.unsupportedStreamCipher(id: rawID)
                }
                self.innerStreamAlgorithm = protectedStreamAlgorithm
                Logger.mainLog.trace("innerRandomStreamID read OK", metadata: ["public:name": "\(fieldID.name)", "public:innerStream": "\(self.innerStreamAlgorithm.name)"])
            case .innerRandomStreamKey:
                guard fieldData.count > 0 else {
                    throw HeaderError.corruptedField(fieldName: fieldID.name)
                }
                self.protectedStreamKey = fieldData.clone()
                Logger.mainLog.trace("innerRandomStreamKey read OK", metadata: ["name": "\(fieldID.name)"])
            case .binary:
                let isProtected = (fieldData[0] & 0x01 != 0)
                let newBinaryID = database.binaries.count
                let binary = Binary2(
                    id: newBinaryID,
                    data: fieldData.suffix(from: 1), 
                    isCompressed: false,
                    isProtected: isProtected) 
                database.binaries[newBinaryID] = binary
                Logger.mainLog.trace("binary read OK", metadata: ["public:name": "\(fieldID.name)", "bytes": "\(fieldData.count)"])
            case .end:
                initStreamCipher()
                Logger.mainLog.trace("Stream cipher init OK")
                Logger.mainLog.trace("Inner header read OK", metadata: ["bytes": "\(size)"])
                return size
            }
        }
    }
    
    func maybeUpdateFormatVersion() {
    }
    
    func write(to outStream: ByteArray.OutputStream) {
        Logger.mainLog.trace("Will write header")
        let headerStream = ByteArray.makeOutputStream()
        headerStream.open()
        defer { headerStream.close() }
        
        headerStream.write(value: Header2.signature1)
        headerStream.write(value: Header2.signature2)
        switch formatVersion {
        case .v4:
            headerStream.write(value: Header2.fileVersion4)
            writeV4(stream: headerStream)
            Logger.mainLog.trace("kdbx4 header written OK")
        case .v4_1:
            headerStream.write(value: Header2.fileVersion4_1)
            writeV4(stream: headerStream)
            Logger.mainLog.trace("kdbx4.1 header written OK")
        }
        
        let headerData = headerStream.data!
        self.data = headerData
        self.hash = headerData.sha256
        outStream.write(data: headerData)
    }
      
    private func writeV4(stream: ByteArray.OutputStream) {
        func writeField(to stream: ByteArray.OutputStream, fieldID: FieldID) {
            stream.write(value: UInt8(fieldID.rawValue))
            let fieldData = fields[fieldID] ?? ByteArray()
            stream.write(value: UInt32(fieldData.count))
            stream.write(data: fieldData)
        }
        fields[.cipherID] = self.dataCipher.uuid.data
        fields[.kdfParameters] = kdfParams.data

        writeField(to: stream, fieldID: .cipherID)
        writeField(to: stream, fieldID: .compressionFlags)
        writeField(to: stream, fieldID: .masterSeed)
        writeField(to: stream, fieldID: .kdfParameters)
        writeField(to: stream, fieldID: .encryptionIV)
        if !publicCustomData.isEmpty {
            fields[.publicCustomData] = publicCustomData.data
            writeField(to: stream, fieldID: .publicCustomData)
        }
        writeField(to: stream, fieldID: .end)
    }
    
    func writeInner(to stream: ByteArray.OutputStream) throws {
        assert(formatVersion >= .v4)
        guard let protectedStreamKey = protectedStreamKey else { Logger.fatalError("writeInner: failed to assign protectedStreamKey") }
        
        Logger.mainLog.trace("Writing kdbx4 inner header")
        stream.write(value: InnerFieldID.innerRandomStreamID.rawValue) 
        stream.write(value: UInt32(MemoryLayout.size(ofValue: innerStreamAlgorithm.rawValue))) 
        stream.write(value: innerStreamAlgorithm.rawValue) 
        
        stream.write(value: InnerFieldID.innerRandomStreamKey.rawValue) 
        stream.write(value: UInt32(protectedStreamKey.count)) 
            stream.write(data: protectedStreamKey)
            #if DEBUG
            print("  streamCipherKey: \(protectedStreamKey.asHexString)")
            #endif
        
        for binaryID in database.binaries.keys.sorted() {
            Logger.mainLog.trace("Writing a binary")
            let binary = database.binaries[binaryID]! 
            
            let data: ByteArray
            if binary.isCompressed {
                do {
                    data = try binary.data.gunzipped() 
                } catch {
                    Logger.mainLog.error("Failed to uncompress attachment data", metadata: ["public:message": "\(error.localizedDescription)"])
                    throw HeaderError.binaryUncompressionError(reason: error.localizedDescription)
                }
            } else {
                data = binary.data
            }
            stream.write(value: InnerFieldID.binary.rawValue) 
            stream.write(value: UInt32(1 + data.count)) 
            stream.write(value: UInt8(binary.flags))
            stream.write(data: data) 
            print("  binary: \(data.count + 1) bytes")
        }
        stream.write(value: InnerFieldID.end.rawValue) 
        stream.write(value: UInt32(0)) 
        Logger.mainLog.trace("Inner header written OK")
    }
    
    internal func randomizeSeeds() throws {
        Logger.mainLog.trace("Randomizing the seeds")
        fields[.masterSeed] = try CryptoManager.getRandomBytes(count: SHA256_SIZE)
        fields[.encryptionIV] = try CryptoManager.getRandomBytes(count: dataCipher.initialVectorSize)
        protectedStreamKey = try CryptoManager.getRandomBytes(count: 64)
        initStreamCipher()
    }
}
