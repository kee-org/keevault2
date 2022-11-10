import Foundation

final class DataCipherFactory {
    public static let instance = DataCipherFactory()
    private let aes: AESDataCipher
    private let chacha20: ChaCha20DataCipher
    private init() {
        aes = AESDataCipher()
        chacha20 = ChaCha20DataCipher()
    }
    
    public func createFor(uuid: UUID) -> DataCipher? {
        switch uuid {
        case aes.uuid:
            Diag.info("Creating AES cipher")
            return AESDataCipher()
        case chacha20.uuid:
            Diag.info("Creating ChaCha20 cipher")
            return ChaCha20DataCipher()
        default:
            Diag.warning("Unrecognized cipher UUID")
            return nil
        }
    }
}
