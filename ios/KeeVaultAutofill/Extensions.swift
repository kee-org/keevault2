//
//  Extensions.swift
//  KeeVaultAutofill
//
//  Created by Chris Tomlinson on 10/11/2022.
//

import Foundation
import AuthenticationServices

extension StringProtocol {
    var hexaData: Data { .init(hexa) }
    var hexaBytes: [UInt8] { .init(hexa) }
    private var hexa: UnfoldSequence<UInt8, Index> {
        sequence(state: startIndex) { startIndex in
            guard startIndex < self.endIndex else { return nil }
            let endIndex = self.index(startIndex, offsetBy: 2, limitedBy: self.endIndex) ?? self.endIndex
            defer { startIndex = endIndex }
            return UInt8(self[startIndex..<endIndex], radix: 16)
        }
    }
}

extension CredentialProviderViewController: EntrySelectionDelegate {
    func selected(credentials: ASPasswordCredential) {
        self.extensionContext.completeRequest(withSelectedCredential: credentials, completionHandler: nil)
    }
    func cancel() {
        self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userCanceled.rawValue))
    }
}

extension Date {
    var millisecondsSinceUnixEpoch:Int64 {
        Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
}
