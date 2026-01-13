import Foundation

/// Simple logger with colored output and verbosity control
struct Logger {
    let verbose: Bool

    init(verbose: Bool = false) {
        self.verbose = verbose
    }

    /// Log an info message (always shown)
    func info(_ message: String) {
        print(message)
    }

    /// Log a success message with green color
    func success(_ message: String) {
        print("\u{001B}[32m\(message)\u{001B}[0m")
    }

    /// Log a warning message with yellow color
    func warning(_ message: String) {
        print("\u{001B}[33mWarning: \(message)\u{001B}[0m")
    }

    /// Log an error message with red color
    func error(_ message: String) {
        print("\u{001B}[31mError: \(message)\u{001B}[0m")
    }

    /// Log a verbose message (only shown when verbose is enabled)
    func verbose(_ message: String) {
        if verbose {
            print("\u{001B}[90m[verbose] \(message)\u{001B}[0m")
        }
    }
}
