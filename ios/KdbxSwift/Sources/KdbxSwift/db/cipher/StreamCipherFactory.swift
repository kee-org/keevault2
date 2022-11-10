import Foundation

internal enum ProtectedStreamAlgorithm: UInt32 {
    case Null      = 0
    case ChaCha20  = 3
    var name: String {
        switch self {
        case .Null: return "NULL"
        case .ChaCha20: return "ChaCha20"
        }
    }
}

final internal class UselessStreamCipher: StreamCipher {
    func encrypt(data: ByteArray, progress: ProgressEx?) throws -> ByteArray {
        return data
    }
    func decrypt(data: ByteArray, progress: ProgressEx?) throws -> ByteArray {
        return data
    }
    func erase() {
    }
}

final class StreamCipherFactory {
    static func create(algorithm: ProtectedStreamAlgorithm, key: ByteArray) -> StreamCipher {
        switch algorithm {
        case .Null:
            Diag.verbose("Creating Null stream cipher")
            return UselessStreamCipher()
        case .ChaCha20:
            Diag.verbose("Creating ChaCha20 stream cipher")
            let sha512 = key.sha512
            let chacha20 = sha512.withThrowableBytes { (sha512bytes) -> ChaCha20 in
                let chachaKey = ByteArray(bytes: sha512bytes.prefix(32))
                let iv = ByteArray(bytes: sha512bytes[32..<(32+12)])
                return ChaCha20(key: chachaKey, iv: iv)
            }
            return chacha20
        }
    }
}

