import Foundation

enum DebugLog {
    static var enabled: Bool {
        ProcessInfo.processInfo.environment["QUICKLOG_DEBUG"] == "1"
    }

    static func log(_ msg: String) {
        guard enabled else { return }
        print("[QuickLog] \(msg)")
    }
}
