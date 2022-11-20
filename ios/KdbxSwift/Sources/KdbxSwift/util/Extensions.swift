import Foundation

extension StringProtocol {
    func base64ToBase64url() -> String {
        return self
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: ".")
    }
}

extension String {
    public var isNotEmpty: Bool { return !isEmpty }
    
    mutating func erase() {
        self.removeAll()
    }
    
    var utf8data: ByteArray {
        return ByteArray(data: self.data(using: .utf8)!)
    }
    
    public func localizedContains<T: StringProtocol>(
        _ other: T,
        options: String.CompareOptions = [])
        -> Bool
    {
        let position = range(
            of: other,
            options: options,
            locale: Locale.current)
        return position != nil
    }
    
    public func containsDiacritics() -> Bool {
        let withoutDiacritics = self.folding(
            options: [.diacriticInsensitive],
            locale: Locale.current)
        let result = self.compare(withoutDiacritics, options: .literal, range: nil, locale: nil)
        return result != .orderedSame
    }
}

extension Bundle {
    internal static let framework = Bundle.main
}

public extension Bool {
    init?(optString value: String?) {
        guard let value = value else {
            return nil
        }
        
        switch value.lowercased() {
        case "true":
            self = true
        case "false":
            self = false
        default:
            return nil
        }
    }
    init(string: String) {
        if string.lowercased() == "true" {
            self = true
        } else {
            self = false
        }
    }
    init(string: String?) {
        self.init(string: string ?? "")
    }
}

public extension Date {
    static var now: Date { return Date() }
    
    private static let iso8601DateFormatter = { () -> ISO8601DateFormatter in
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    private static let iso8601DateFormatterWithFractionalSeconds = { () -> ISO8601DateFormatter in
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions =  [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let miniKeePassDateFormatter = { () -> DateFormatter in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss z"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static internal let secondsBetweenSwiftAndDotNetReferenceDates = Int64(63113904000)

    init?(iso8601string string: String?) {
        guard let string = string else { return nil }
        if let date = Date.iso8601DateFormatter.date(from: string) {
            self = date
        } else if let date = Date.iso8601DateFormatterWithFractionalSeconds.date(from: string) {
            self = date
        } else if let date = Date.miniKeePassDateFormatter.date(from: string) {
            self = date
        } else {
            return nil
        }
    }
    
    init?(base64Encoded string: String?) {
        guard let data = ByteArray(base64Encoded: string) else { return nil }
        guard let secondsSinceDotNetReferenceDate = Int64(data: data) else { return nil }
        let secondsSinceSwiftReferenceDate =
            secondsSinceDotNetReferenceDate - Date.secondsBetweenSwiftAndDotNetReferenceDates
        self = Date(timeIntervalSinceReferenceDate: Double(secondsSinceSwiftReferenceDate))
    }
    
    func iso8601String() -> String {
        return Date.iso8601DateFormatter.string(from: self)
    }
    
    func base64EncodedString() -> String {
        let secondsSinceSwiftReferenceDate = Int64(self.timeIntervalSinceReferenceDate)
        let secondsSinceDotNetReferenceDate =
            secondsSinceSwiftReferenceDate + Date.secondsBetweenSwiftAndDotNetReferenceDates
        return secondsSinceDotNetReferenceDate.data.base64EncodedString()
    }
    
    var iso8601WeekOfYear: Int {
        let isoCalendar = Calendar(identifier: .iso8601)
        let dateComponents = isoCalendar.dateComponents([.weekOfYear], from: self)
        return dateComponents.weekOfYear ?? 0
    }
}

extension UUID {
    public static let ZERO = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    public static let byteWidth = 16
    
    mutating func erase() {
        self = UUID.ZERO
    }
    
    internal var data: ByteArray {
        var bytes = Array<UInt8>(repeating: 0, count: UUID.byteWidth)
        guard let nsuuid = NSUUID(uuidString: self.uuidString) else {
            fatalError()
        }
        nsuuid.getBytes(&bytes)
        return ByteArray(bytes: bytes)
    }

    internal init?(data: ByteArray?) {
        guard let data = data else { return nil }
        guard data.count == UUID.byteWidth else { return nil }
        let nsuuid = data.withBytes {
            NSUUID(uuidBytes: $0)
        }
        self.init(uuidString: nsuuid.uuidString)
    }
    
    internal init?(base64Encoded base64: String?) {
        guard let data = ByteArray(base64Encoded: base64) else { return nil }
        let nsuuid = data.withBytes {
            NSUUID(uuidBytes: $0)
        }
        self.init(uuidString: nsuuid.uuidString)
    }
    
    internal func base64EncodedString() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        (self as NSUUID).getBytes(&bytes)
        return Data(bytes).base64EncodedString()
    }
}

extension Array where Element == Entry {
    mutating func remove(_ entry: Entry) {
        if let index = firstIndex(where: {$0 === entry}) {
            remove(at: index)
        }
    }
}

extension Array where Element == Group {
    mutating func remove(_ group: Group) {
        if let index = firstIndex(where: {$0 === group}) {
            remove(at: index)
        }
    }
}
