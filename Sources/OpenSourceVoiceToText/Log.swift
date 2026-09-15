import Foundation

/// Diagnostic logging. Goes to the unified log (visible via
/// `log stream --predicate 'process == "OpenSourceVoiceToText"' --info`)
/// and to stderr when the binary is run from a terminal.
enum Log {
    static func info(_ message: String) {
        NSLog("[VTT] %@", message)
    }
}
