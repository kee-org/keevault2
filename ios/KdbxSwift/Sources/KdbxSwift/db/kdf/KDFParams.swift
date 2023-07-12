import Foundation
import os.log

final class KDFParams: VarDict {
    public static let uuidParam = "$UUID"
    public var kdfUUID: UUID {
        let uuidBytes = getValue(key: KDFParams.uuidParam)?.asByteArray()
        return UUID(data: uuidBytes) ?? UUID.ZERO
    }
    
    override func erase() {
        super.erase()
    }
    
    override func read(data: ByteArray) -> Bool {
        Logger.mainLog.debug("Parsing KDF params")
        guard super.read(data: data) else { return false }
        
        guard let value = getValue(key: KDFParams.uuidParam) else {
            Logger.mainLog.warning("KDF UUID is missing")
            return false
        }
        guard let uuidData = value.asByteArray(),
            let _ = UUID(data: uuidData) else {
                Logger.mainLog.warning("KDF UUID is malformed")
                return false
        }
        return true
    }
}
