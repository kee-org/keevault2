import Foundation

public enum KeyFileError: Error {
    case unsupportedFormat
    case keyFileCorrupted
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return NSLocalizedString(
                "[KeyFileError/UnsupportedFormat/title]",
                bundle: Bundle.framework,
                value: "Unsupported key file format",
                comment: "Error message: unsupported/unknown format of a key file")
        case .keyFileCorrupted:
            return NSLocalizedString(
                "[KeyFileError/Corrupted/title]",
                bundle: Bundle.framework,
                value: "Key file is corrupted",
                comment: "Error message when the key file is misformatted or damaged")
        }
    }
}
