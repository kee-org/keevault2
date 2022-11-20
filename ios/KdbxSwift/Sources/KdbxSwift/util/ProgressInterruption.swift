import Foundation

public enum ProgressInterruption: LocalizedError {
    case cancelled(reason: ProgressEx.CancellationReason)
    
    public var errorDescription: String? {
        switch self {
        case .cancelled(let reason):
            return reason.localizedDescription
        }
    }
}
