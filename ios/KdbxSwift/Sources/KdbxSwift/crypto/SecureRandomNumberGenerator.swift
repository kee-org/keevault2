// import Foundation

// public struct SecureRandomNumberGenerator: RandomNumberGenerator {
//     public func next() -> UInt64 {
//         var random: UInt64 = 0
//         let status = SecRandomCopyBytes(kSecRandomDefault, MemoryLayout<UInt64>.size, &random)
//         guard status == errSecSuccess else {
//             Diag.warning("Failed to generate random bytes [status: \(status)]")
//             __failed_to_generate_random_bytes()
//             fatalError()
//         }
//         return random
//     }
    
//     private func __failed_to_generate_random_bytes() {
//         fatalError()
//     }
// }
