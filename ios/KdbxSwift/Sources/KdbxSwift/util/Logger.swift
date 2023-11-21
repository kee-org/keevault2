import Foundation
import Logging

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!

    public static var mainLog = Logger(label: "com.keevault.kdbxswift")
    public static var appLog = Logger(label: "com.keevault.keevault")
    
    public static func fatalError(_ message:String) -> Never {
        //TODO: stack trace, metadata, etc.?
        mainLog.critical("\(message)")
        Swift.fatalError(message)
    }
    
    public static func reloadConfig() {
        mainLog = Logger(label: "com.keevault.kdbxswift")
        appLog = Logger(label: "com.keevault.keevault")
        mainLog.info("Log configuration refreshed")
    }
}

