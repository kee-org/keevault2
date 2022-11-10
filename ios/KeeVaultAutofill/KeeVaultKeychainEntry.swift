import Foundation

// UI representation of one or more KDBX Entry instances, esentially a subset of a KDBX entry
// but with added metadata for the current autofill match operation
struct KeeVaultAutofillEntry {
    let entryIndex: Int
    let server: String // the domain or hostname of the best matching URL in the entry for this autofill request
    let title: String
    let lowercaseUsername: String
    let lowercaseTitle: String
    let username: String
    let priority: Int // 0 = no match, 1> decreasing priority (limited only by number of search terms ios decides to supply)
}
