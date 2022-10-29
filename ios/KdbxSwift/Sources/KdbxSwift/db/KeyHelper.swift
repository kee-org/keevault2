//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class KeyHelper {
    public static let compositeKeyLength = 32
    internal let keyFileKeyLength = 32
    
    public func combineComponents(
        passwordData: ByteArray,
        keyFileData: ByteArray
    ) throws -> ByteArray {
        fatalError("Pure virtual method")
    }
    
    public func getKey(fromCombinedComponents combinedComponents: ByteArray) -> ByteArray {
        fatalError("Pure virtual method")
    }
    
    public func getPasswordData(password: String) -> ByteArray {
        fatalError("Pure virtual method")
    }
    
    public func processKeyFile(keyFileData: ByteArray) throws -> ByteArray {
        assert(!keyFileData.isEmpty, "keyFileData cannot be empty here")
        
        let keyFileDataSize = keyFileData.count
        if keyFileDataSize == keyFileKeyLength {
            Diag.debug("Key file format is: binary")
            return keyFileData
//        } else if keyFileDataSize == 2 * keyFileKeyLength {
//
//            if let key = keyFileData.interpretedAsASCIIHexString() {
//                Diag.debug("Key file format is: base64")
//                return key
//            }
        }
        
        if let key = try processXmlKeyFile(keyFileData: keyFileData) {
            Diag.debug("Key file format is: XML")
            return key
        }
        
        Diag.debug("Key file format is: other")
        return keyFileData.sha256
    }
    
    public func processXmlKeyFile(keyFileData: ByteArray) throws -> ByteArray? {
        return nil
    }
}


