//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public let SHA256_SIZE = Int(CC_SHA256_DIGEST_LENGTH)
public let SHA512_SIZE = Int(CC_SHA512_DIGEST_LENGTH)
public let SHA1_SIZE = Int(CC_SHA1_DIGEST_LENGTH)

public final class CryptoManager {

    public static func sha256(of buffer: [UInt8]) -> [UInt8] {
        var hash = [UInt8](repeating: 0, count: SHA256_SIZE)
        CC_SHA256(buffer, CC_LONG(buffer.count), &hash)
        return hash
    }
    
    public static func sha512(of buffer: [UInt8]) -> [UInt8] {
        var hash = [UInt8](repeating: 0,  count: Int(CC_SHA512_DIGEST_LENGTH))
        CC_SHA512(buffer, CC_LONG(buffer.count), &hash)
        return hash
    }
    
    public static func getRandomBytes(count: Int) throws -> ByteArray {
        let output = ByteArray(count: count)
        let status = output.withMutableBytes { (outBytes: inout [UInt8]) in
            return SecRandomCopyBytes(kSecRandomDefault, outBytes.count, &outBytes)
        }
        if status != errSecSuccess {
            Diag.warning("Failed to generate random bytes [count: \(count), status: \(status)]")
            throw CryptoError.rngError(code: Int(status))
        }
        return output
    }
    
    public static func getRandomSecureBytes(count: Int) throws -> SecureBytes {
        let plainTextBytes = try getRandomBytes(count: count)
        defer {
            plainTextBytes.erase()
        }
        let result = SecureBytes.from(plainTextBytes)
        return result
    }
    
    public static func getHMACKey64(key: SecureBytes, blockIndex: UInt64) -> ByteArray {
        let result = key.withDecryptedByteArray { (keyBytes) -> ByteArray in
            assert(keyBytes.count == 64)
            let merged = ByteArray.concat(blockIndex.data, keyBytes)
            return merged.sha512
        }
        return result
    }
    
    public static func hmacSHA1(data: ByteArray, key: ByteArray) -> ByteArray {
        let out = ByteArray(count: Int(CC_SHA1_DIGEST_LENGTH))
        hmacSHA(algorithm: CCHmacAlgorithm(kCCHmacAlgSHA1), data: data, key: key, out: out)
        return out
    }
    
    public static func hmacSHA256(data: ByteArray, key: ByteArray) -> ByteArray {
        assert(key.count == CC_SHA256_BLOCK_BYTES)
        let out = ByteArray(count: Int(CC_SHA256_DIGEST_LENGTH))
        hmacSHA(algorithm: CCHmacAlgorithm(kCCHmacAlgSHA256), data: data, key: key, out: out)
        return out
    }
    
    public static func hmacSHA512(data: ByteArray, key: ByteArray) -> ByteArray {
        assert(key.count == CC_SHA512_BLOCK_BYTES)
        let out = ByteArray(count: Int(CC_SHA512_DIGEST_LENGTH))
        hmacSHA(algorithm: CCHmacAlgorithm(kCCHmacAlgSHA512), data: data, key: key, out: out)
        return out
    }
    
    private static func hmacSHA(
        algorithm: CCHmacAlgorithm,
        data: ByteArray,
        key: ByteArray,
        out: ByteArray)
    {
        data.withBytes{ dataBytes in
            key.withBytes{ keyBytes in
                out.withMutableBytes { (outBytes: inout [UInt8]) in
                    CCHmac(
                        algorithm,
                        keyBytes, keyBytes.count,
                        dataBytes, dataBytes.count,
                        &outBytes
                    )
                }
            }
        }
    }
    
    public static func addPadding(data: ByteArray, blockSize: Int) {
        var padLength = 16 - data.count % blockSize
        if (padLength == 0) {
            padLength = blockSize
        }
        let padding = Array<UInt8>(repeating: UInt8(padLength), count: padLength)
        data.append(bytes: padding)
    }
    
    public static func removePadding(data: ByteArray) throws {
        guard data.count > 0 else {
            throw CryptoError.paddingError(code: 10)
        }
        
        let padLength = Int(data[data.count - 1])
        guard (data.count - padLength) >= 0 else {
            throw CryptoError.paddingError(code: 20)
        }
        guard padLength > 0 else {
            throw CryptoError.paddingError(code: 30)
        }

        for i in (data.count - padLength)..<data.count {
            if data[i] != padLength {
                throw CryptoError.paddingError(code: 40)
            }
        }
        data.trim(toCount: data.count - padLength)
    }
}
