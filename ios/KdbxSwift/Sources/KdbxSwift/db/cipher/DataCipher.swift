//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

protocol DataCipher: AnyObject {
    var uuid: UUID { get }
    var initialVectorSize: Int { get }
    var keySize: Int { get }
    var name: String { get }
    
    var progress: ProgressEx { get set }
    
    func initProgress() -> ProgressEx
    
    func encrypt(plainText: ByteArray, key: ByteArray, iv: ByteArray) throws -> ByteArray
    func decrypt(cipherText: ByteArray, key: ByteArray, iv: ByteArray) throws -> ByteArray
    
    func resizeKey(key: ByteArray) -> ByteArray
}

extension DataCipher {
    
    func initProgress() -> ProgressEx {
        progress = ProgressEx()
        return progress
    }
    
    func resizeKey(key: ByteArray) -> ByteArray {
        assert(key.count > 0)
        assert(keySize >= 0)
        
        if keySize == 0 {
            return ByteArray.empty()
        }
        
        let hash: ByteArray
        let hashSize: Int
        if keySize <= 32 {
            hash = key.sha256
            hashSize = SHA256_SIZE
        } else {
            hash = key.sha512
            hashSize = SHA512_SIZE
        }
        
        if hashSize == keySize {
            return hash
        }
            
        if keySize < hashSize {
            return hash.prefix(keySize)
        } else {
            fatalError("Not implemented")
        }
    }
}
