import Foundation
import Logging
import Puppy

public struct MyPuppyLogHandler: LogHandler, Sendable {
    public var logLevel: Logger.Level = .info
    public var metadata: Logger.Metadata

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get {
            return metadata[key]
        }
        set(newValue) {
            metadata[key] = newValue
        }
    }

    private let label: String
    private let puppy: Puppy

    public init(label: String, puppy: Puppy, metadata: Logger.Metadata = [:]) {
        self.label = label
        self.puppy = puppy
        self.metadata = metadata
    }
    
    private func redact(_ metadata: Logger.Metadata) -> Logger.Metadata {
        let arr = metadata.map { (key, value: Logger.MetadataValue) in
            if (key.starts(with: "public:")) {
                return (key, value)
            }
            else {
            return (key, "REDACTED" as Logger.MetadataValue)
            }
        }
        return Dictionary(uniqueKeysWithValues: arr) as Logger.Metadata
    }

    public func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        #if DEBUG
        let merged = mergedMetadata(metadata)
        #else
        let merged = redact(mergedMetadata(metadata))
        #endif
        let metadata = !merged.isEmpty ? "\(merged)" : ""
        let swiftLogInfo = ["label": label, "source": source, "metadata": metadata]
        puppy.logMessage(level.toPuppy(), message: "\(message)", tag: "swiftlog", function: function, file: file, line: line, swiftLogInfo: swiftLogInfo)
    }

    private func mergedMetadata(_ metadata: Logger.Metadata?) -> Logger.Metadata {
        var mergedMetadata: Logger.Metadata
        if let metadata = metadata {
            mergedMetadata = self.metadata.merging(metadata, uniquingKeysWith: { _, new in new })
        } else {
            mergedMetadata = self.metadata
        }
        return mergedMetadata
    }
}

extension Logger.Level {
    func toPuppy() -> LogLevel {
        switch self {
        case .trace:
            return .trace
        case .debug:
            return .debug
        case .info:
            return .info
        case .notice:
            return .notice
        case .warning:
            return .warning
        case .error:
            return .error
        case .critical:
            return .critical
        }
    }
}

struct LogFormatter: LogFormattable {
    private let dateFormat = DateFormatter()

    init() {
        dateFormat.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
    }

    func formatMessage(_ level: LogLevel, message: String, tag: String, function: String,
                       file: String, line: UInt, swiftLogInfo: [String : String],
                       label: String, date: Date, threadID: UInt64) -> String {
        let date = dateFormatter(date, withFormatter: dateFormat)
        let fileName = fileName(file)
        let moduleName = moduleName(file)
        let metaData = swiftLogInfo["metadata"] ?? ""
        let source = swiftLogInfo["source"] ?? ""
        return "\(date) [\(level.short)] \(message) \(metaData) * \(source) \(threadID) \(moduleName)/\(fileName):\(line) \(function)"
    }
}

extension LogLevel {
    public var short: String {
        switch self {
        case .trace:
            return "T"
        case .verbose:
            return "V"
        case.debug:
            return "D"
        case .info:
            return "I"
        case .notice:
            return "N"
        case .warning:
            return "W"
        case .error:
            return "E"
        case .critical:
            return "C"
        }
    }
}
