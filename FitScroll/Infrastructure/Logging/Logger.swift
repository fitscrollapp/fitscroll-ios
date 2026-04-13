import Foundation
import os

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

enum Logger {
    private static let osLog = os.Logger(subsystem: "com.fitscroll", category: "general")

    static func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(level.rawValue)] [\(fileName):\(line)] \(function) - \(message)"

        switch level {
        case .debug:
            osLog.debug("\(logMessage)")
        case .info:
            osLog.info("\(logMessage)")
        case .warning:
            osLog.warning("\(logMessage)")
        case .error:
            osLog.error("\(logMessage)")
        }

        #if DEBUG
        print(logMessage)
        #endif
    }
}
