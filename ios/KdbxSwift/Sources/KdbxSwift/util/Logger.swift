import Foundation
import os.log

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!

    public static let mainLog = Logger(subsystem: subsystem, category: "main")
    
    public static func fatalError(_ message:String) -> Never {
        mainLog.fault("\(message)")
        Swift.fatalError(message)
    }
}

//
//public class Diag {
//    public enum Level: Int {
//        case verbose = 0
//        case debug = 1
//        case info = 2
//        case warning = 3
//        case error = 4
//        public var asString: String {
//            switch self {
//            case .verbose:
//                return "(V)"
//            case .debug:
//                return "(D)"
//            case .info:
//                return "(I)"
//            case .warning:
//                return "(W)"
//            case .error:
//                return "(E)"
//            }
//        }
//    }
//
//    public struct Item {
//        public var timestamp: TimeInterval
//        public var level: Level
//        public var message: String
//        public var file: String
//        public var function: String
//        public var line: Int
//        public func toString() -> String {
//            return "\(String(format: "%.3f", timestamp)) \(level.asString) \t\(file):\(line) \t\(function) \t\(message)"
//        }
//    }
//
//    private static let level = Level.debug
//    private static let instance = Diag()
//    private let queue = DispatchQueue(label: "com.keevault.unused.diagnostics.stub")
//    private var items = [Item]()
//    private var startTime: TimeInterval = Date.timeIntervalSinceReferenceDate
//
//    public class func verbose(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
//        guard Logger.mainLog.level.rawValue <= Level.verbose.rawValue else { return }
//        let item = Item(
//            timestamp: Date.timeIntervalSinceReferenceDate - instance.startTime,
//            level: .verbose,
//            message: message,
//            file: prettifyFileName(file),
//            function: prettifyFunctionName(function),
//            line: line)
//        instance.add(item: item)
//    }
//    public class func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
//        guard Logger.mainLog.level.rawValue <= Level.debug.rawValue else { return }
//        let item = Item(
//            timestamp: Date.timeIntervalSinceReferenceDate - instance.startTime,
//            level: .debug,
//            message: message,
//            file: prettifyFileName(file),
//            function: prettifyFunctionName(function),
//            line: line)
//        instance.add(item: item)
//    }
//    public class func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
//        guard Logger.mainLog.level.rawValue <= Level.info.rawValue else { return }
//        let item = Item(
//            timestamp: Date.timeIntervalSinceReferenceDate - instance.startTime,
//            level: .info,
//            message: message,
//            file: prettifyFileName(file),
//            function: prettifyFunctionName(function),
//            line: line)
//        instance.add(item: item)
//    }
//    public class func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
//        guard Logger.mainLog.level.rawValue <= Level.warning.rawValue else { return }
//        let item = Item(
//            timestamp: Date.timeIntervalSinceReferenceDate - instance.startTime,
//            level: .warning,
//            message: message,
//            file: prettifyFileName(file),
//            function: prettifyFunctionName(function),
//            line: line)
//        instance.add(item: item)
//    }
//    public class func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
//        guard Logger.mainLog.level.rawValue <= Level.error.rawValue else { return }
//        let item = Item(
//            timestamp: Date.timeIntervalSinceReferenceDate - instance.startTime,
//            level: .error,
//            message: message,
//            file: prettifyFileName(file),
//            function: prettifyFunctionName(function),
//            line: line)
//        instance.add(item: item)
//    }
//
//    public class func clear() {
//        instance.startTime = Date.timeIntervalSinceReferenceDate
//        instance.items.removeAll(keepingCapacity: false)
//    }
//
//    private func add(item: Item) {
//        queue.async {
//            print(item.toString())
//            self.items.append(item)
//        }
//    }
//
//    private static func prettifyFileName(_ fName: String) -> String {
//        let url = URL(fileURLWithPath: fName, isDirectory: false)
//        return url.lastPathComponent
//    }
//
//    private static func prettifyFunctionName(_ fName: String) -> String {
//        if fName.contains("(") {
//           return fName
//        } else {
//            return fName + "()"
//        }
//    }
//
//    public static func itemsSnapshot() -> Array<Item> {
//        return Array(instance.items)
//    }
//
//    public static func toString() -> String {
//        return instance._toString()
//    }
//
//    private func _toString() -> String {
//        var lines = [String]()
//        queue.sync {
//            for item in self.items {
//                lines.append(item.toString())
//            }
//        }
//        return lines.joined(separator: "\n")
//    }
//
//    public static func isDeepDebugMode() -> Bool {
//        return false
//    }
//
//}
