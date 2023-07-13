import Foundation
import os.log

final class KeyHelper2: KeyHelper {
    
    override init() {
        super.init()
    }
    
    override func getPasswordData(password: String) -> ByteArray {
        return password.utf8data.clone()
    }
    
    override func combineComponents(
        passwordData: ByteArray,
        keyFileData: ByteArray
    ) throws -> ByteArray {
        let hasPassword = !passwordData.isEmpty
        let hasKeyFile = !keyFileData.isEmpty
        
        var preKey = ByteArray.empty()
        if hasPassword {
            Logger.mainLog.info("Using password")
            preKey = ByteArray.concat(preKey, passwordData.sha256)
        }
        if hasKeyFile {
            Logger.mainLog.info("Using key file")
            preKey = ByteArray.concat(
                preKey,
                try processKeyFile(keyFileData: keyFileData) 
            )
        }
        if preKey.isEmpty {
            Logger.mainLog.warning("All key components are empty after being checked.")
        }
        return preKey 
    }
    
    override func getKey(fromCombinedComponents combinedComponents: ByteArray) -> ByteArray {
        return combinedComponents.sha256
    }
}
