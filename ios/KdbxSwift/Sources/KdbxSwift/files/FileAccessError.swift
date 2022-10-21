//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public enum FileAccessError: LocalizedError {
    case timeout(fileProvider: FileProvider?)
    
    case noInfoAvailable
    
    case internalError
    
    case fileProviderDoesNotRespond(fileProvider: FileProvider?)
    
    case fileProviderNotFound(fileProvider: FileProvider?)
    
    case targetFileIsReadOnly(fileProvider: FileProvider)
    
    case networkAccessDenied

    case serverSideError(message: String)
    
    case networkError(message: String)
    
    case systemError(_ originalError: Error?)
    
    public var isTimeout: Bool {
        switch self {
        case .timeout(_):
            return true
        default:
            return false
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .timeout(let fileProvider):
            if let fileProvider = fileProvider {
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[FileAccessError/Timeout/knownFileProvider]",
                        bundle: Bundle.framework,
                        value: "%@ does not respond.",
                        comment: "Error message: file provider does not respond to requests (quickly enough). For example: `Google Drive does not respond`"),
                    fileProvider.localizedName
                )
            } else {
                return NSLocalizedString(
                    "[FileAccessError/Timeout/genericFileProvider]",
                    bundle: Bundle.framework,
                    value: "Storage provider does not respond.",
                    comment: "Error message: storage provider app (e.g. Google Drive) does not respond to requests (quickly enough).")
            }
        case .noInfoAvailable:
            assertionFailure("Should not be shown to the user")
            return "noInfoAvailable" 
        case .internalError:
            return NSLocalizedString(
                "[FileAccessError/internalError]",
                bundle: Bundle.framework,
                value: "Internal KeePassium error, please tell us about it.",
                comment: "Error message shown when there's internal inconsistency in KeePassium.")
        case .fileProviderDoesNotRespond(let fileProvider):
            if let fileProvider = fileProvider {
                return String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[FileAccessError/NoResponse/knownFileProvider]",
                        bundle: Bundle.framework,
                        value: "%@ does not respond.",
                        comment: "Error message: file provider does not respond to requests. For example: `Google Drive does not respond.`"),
                    fileProvider.localizedName
                )
            } else {
                return NSLocalizedString(
                    "[FileAccessError/NoResponse/genericFileProvider]",
                    bundle: Bundle.framework,
                    value: "Storage provider does not respond.",
                    comment: "Error message: storage provider app (e.g. Google Drive) does not respond to requests.")
            }
        case .fileProviderNotFound(let fileProvider):
            if let fileProvider = fileProvider {
                switch fileProvider {
                case .smbShare:
                    return NSLocalizedString(
                            "[FileAccessError/FileProvider/NotFound/smbShare]",
                            bundle: Bundle.framework,
                            value: "Network storage is disconnected.",
                            comment: "Error message: the required network drive is not connected.")
                case .usbDrive:
                    return NSLocalizedString(
                            "[FileAccessError/FileProvider/NotFound/usbDrive]",
                            bundle: Bundle.framework,
                            value: "USB drive is disconnected.",
                            comment: "Error message: there is no USB drive connected to the device.")
                default:
                    return String.localizedStringWithFormat(
                        NSLocalizedString(
                            "[FileAccessError/FileProvider/NotFound/other]",
                            bundle: Bundle.framework,
                            value: "%@ is not available. Please check whether it is installed and logged in to your account.",
                            comment: "Error message: storage provider app was logged out or uninstalled [fileProviderName: String]."),
                        fileProvider.localizedName
                    )
                }
            } else {
                return NSLocalizedString(
                    "[FileAccessError/FileProvider/NotFound/generic]",
                    bundle: Bundle.framework,
                    value: "Storage provider is not available. Please check whether it is installed and logged in to your account.",
                    comment: "Error message: storage provider app was logged out or uninstalled.")
            }
        case .targetFileIsReadOnly(let fileProvider):
            return String.localizedStringWithFormat(
                NSLocalizedString(
                    "[FileAccessError/NoWritePermission/title]",
                    bundle: Bundle.framework,
                    value: "Cannot save file (%@)",
                    comment: "Error message: file provider does not support write operations. For example: `Cannot save file (OneDrive)`"),
                fileProvider.localizedName
            )
        case .networkAccessDenied:
            return NSLocalizedString(
                "[FileAccessError/NetworkAccessDenied/generic]",
                bundle: Bundle.framework,
                value: "Network access is blocked by the settings.",
                comment: "Error message: network access is forbidden by system or app settings.")
        case .serverSideError(let message):
            return message
        case .networkError(let message):
            return message
        case .systemError(let originalError):
            return originalError?.localizedDescription
        }
    }
    
    public var failureReason: String? {
        return nil
    }
    
    public var recoverySuggestion: String? {
        return nil
    }
    
    public static func make(from originalError: Error, fileProvider: FileProvider?) -> FileAccessError {
        let nsError = originalError as NSError
        Diag.error("""
            Failed to access the file \
            [fileProvider: \(fileProvider?.id ?? "nil"), systemError: \(nsError.debugDescription)]
            """)
        switch (nsError.domain, nsError.code) {
        case (NSCocoaErrorDomain, CocoaError.Code.xpcConnectionReplyInvalid.rawValue): 
            return .fileProviderDoesNotRespond(fileProvider: fileProvider)
            
        case (NSCocoaErrorDomain, CocoaError.Code.xpcConnectionInterrupted.rawValue), 
             (NSCocoaErrorDomain, CocoaError.Code.xpcConnectionInvalid.rawValue): 
            return .fileProviderDoesNotRespond(fileProvider: fileProvider)

        case (NSCocoaErrorDomain, CocoaError.Code.fileWriteNoPermission.rawValue): 
            if let fileProvider = fileProvider {
                return .targetFileIsReadOnly(fileProvider: fileProvider)
            } else {
                return .systemError(originalError)
            }

        case ("NSFileProviderInternalErrorDomain", 0), 
             ("NSFileProviderErrorDomain", -2001): 
            return .fileProviderNotFound(fileProvider: fileProvider)
            
        default:
            return .systemError(originalError)
        }
    }
    
    public var underlyingError: Error? {
        switch self {
        case .systemError(let originalError):
            return originalError
        default:
            return nil
        }
    }
}

extension LString.Error {
    fileprivate static let oneDriveIsReadOnlyDescription = NSLocalizedString(
        "[FileAccessError/OneDriveReadOnly/reason]",
        bundle: Bundle.framework,
        value: "Microsoft has recently switched OneDrive integration with iOS to read-only mode. Temporarily, they say.",
        comment: "Explanation of a file writing error"
    )
    fileprivate static let oneDriveIsReadOnlyRecoverySuggestion = NSLocalizedString(
        "[FileAccessError/OneDriveReadOnly/recoverySuggestion]",
        bundle: Bundle.framework,
        value: "Use the Export option to save file to another location.",
        comment: "Suggestion for error recovery"
    )
}
