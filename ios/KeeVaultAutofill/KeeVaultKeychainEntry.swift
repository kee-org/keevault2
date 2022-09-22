//
//  KeeVaultKeychainEntry.swift
//  KeeVaultAutofill
//
//  Created by Chris Tomlinson on 21/09/2022.
//

import Foundation

struct KeeVaultKeychainEntry {
    let uuid: String?
    let server: String
    let writtenByAutofill: Bool
    let title: String?
    let username: String
    let password: String? // keychain value (encrypted behind presense check in secure chip)
}

// UI representation of one or more KeeVaultKeychainEntry instances, esentially a subset of a KDBX entry but with added metadata for the current autofill match operation
struct KeeVaultAutofillEntry {
    let entryIndex: Int // uuid could be empty if this is an entry we've recently added via autofill
    let server: String
    let title: String?
    let username: String
    let priority: Int // 0 = no match, 1> decreasing priority (limited only by number of search terms ios decides to supply)
}

public enum PriorityCategory: String {
    case exact = "exact"
    case close = "close"
    case none = "none"
}
