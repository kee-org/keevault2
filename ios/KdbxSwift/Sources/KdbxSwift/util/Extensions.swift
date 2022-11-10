import Foundation

extension StringProtocol {
    func base64ToBase64url() -> String {
        return self
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: ".")
    }
}

extension Bundle {
    internal static let framework = Bundle.main
}

// public extension Comparable {
    
//     func clamped(to limits: ClosedRange<Self>) -> Self {
//         return min(max(self, limits.lowerBound), limits.upperBound)
//     }
// }

// extension OperationQueue {
//     var isCurrent: Bool {
//         return OperationQueue.current == self
//     }
// }

// extension ProcessInfo {
    
//     public static var isRunningOnMac: Bool {
//         return isiPadAppOnMac || isCatalystApp
//     }
    
//     public static var isiPadAppOnMac: Bool {
//         guard #available(iOS 14, *) else {
//             return false
//         }
//         return ProcessInfo.processInfo.isiOSAppOnMac
//     }
    
//     public static var isCatalystApp: Bool {
//         guard #available(iOS 13, *) else {
//             return false
//         }
//         return ProcessInfo.processInfo.isMacCatalystApp && !isiPadAppOnMac
//     }
// }
