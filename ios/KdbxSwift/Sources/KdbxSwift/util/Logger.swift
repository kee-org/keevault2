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
