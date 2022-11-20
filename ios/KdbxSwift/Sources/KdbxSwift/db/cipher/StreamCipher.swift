import Foundation

protocol StreamCipher: Eraseable {
    func encrypt(data: ByteArray, progress: ProgressEx?) throws -> ByteArray
    func decrypt(data: ByteArray, progress: ProgressEx?) throws -> ByteArray
}
