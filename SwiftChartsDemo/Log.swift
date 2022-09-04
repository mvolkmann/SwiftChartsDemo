import os

struct Log {
    let logger = Logger()

    func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let message = buildMessage("debug", message, file, function, line)
        log(message: message, type: .debug)
    }

    func error(
        _ err: Error,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let message = err.localizedDescription
        error(message, file: file, function: function, line: line)
    }

    func error(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let message = buildMessage("error", message, file, function, line)
        log(message: message, type: .error)
    }

    func fault(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let message = buildMessage("fault", message, file, function, line)
        log(message: message, type: .fault)
    }

    func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let message = buildMessage("info", message, file, function, line)
        log(message: message, type: .info)
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

    /*
     This sets "privacy" to "public" to prevent values
     in string interpolations from being redacted.
     From https://developer.apple.com/documentation/os/logger
     "When you include an interpolated string or custom object in your message,
     the system redacts the value of that string or object by default.
     This behavior prevents the system from leaking potentially user-sensitive
     information in the log files, such as the user’s account information.
     If the data doesn’t contain sensitive information, change the
     privacy option of that value when logging the information."
     */
    private func log(message: String, type: OSLogType) {
        switch type {
        case .debug:
            // The argument in each of the logger calls below
            // MUST be a string interpolation!
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

let log = Log()

// This simplifies print statements that use string interpolation
// to print values with types like Bool.
func sd(_ css: CustomStringConvertible) -> String {
    String(describing: css)
}
