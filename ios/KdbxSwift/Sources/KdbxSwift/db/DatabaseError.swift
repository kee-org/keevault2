public enum DatabaseError: Error {
    case loadError(reason: String)
    case invalidKey
    case saveError(reason: String)
}
