import Foundation
import os

struct Log {
    static let shared = Log()

    let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Log.self)
    )

    func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let message = buildMessage("debug", message, file, function, line)
        logWithType(message: message, type: .debug)
    }

    func error(
        _ error: Error,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let message = buildMessage("error", error.localizedDescription, file, function, line)
        logWithType(message: message, type: .error)
    }

    func fault(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let message = buildMessage("fault", message, file, function, line)
        logWithType(message: message, type: .fault)
    }

    func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let message = buildMessage("info", message, file, function, line)
        logWithType(message: message, type: .info)
    }

    private func buildMessage(
        _ kind: String,
        _ message: String,
        _ file: String,
        _ function: String,
        _ line: Int
    ) -> String {
        let fileName = file.components(separatedBy: "/").last ?? "unknown"
        return """
            \(fileName) \(function) line \(line)
            \(kind): \(message)
            """
    }

    private func logWithType(message: String, type: OSLogType) {
        switch type {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        case .fault:
            logger.fault("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        default:
            logger.log("\(message, privacy: .public)")
        }
    }
}

// This simplifies print statements that use string interpolation
// to print values with types like Bool.
func sd(_ css: CustomStringConvertible) -> String {
    String(describing: css)
}
