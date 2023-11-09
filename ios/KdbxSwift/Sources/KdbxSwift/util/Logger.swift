import Foundation
import Logging

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!

    public static var mainLog = Logging.Logger(label: "com.keevault.kdbxswift")    
    public static var appLog = Logging.Logger(label: "com.keevault.keevault")
    
    public static func fatalError(_ message:String) -> Never {
        //TODO: stack trace, metadata, etc.?
        mainLog.critical("\(message)")
        Swift.fatalError(message)
    }
    
    public static func reloadConfig() {
        mainLog = Logging.Logger(label: "com.keevault.kdbxswift")
        appLog = Logging.Logger(label: "com.keevault.keevault")
        mainLog.info("Log configuration refreshed")
    }
}

