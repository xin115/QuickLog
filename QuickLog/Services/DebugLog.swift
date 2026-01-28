import Foundation

enum DebugLog {
    static var enabled: Bool {
        ProcessInfo.processInfo.environment["QUICKLOG_DEBUG"] == "1"
    }

    private static var logFileURL: URL {
        AppPaths.appSupportDir.appendingPathComponent("debug.log", isDirectory: false)
    }

    static func log(_ msg: String) {
        guard enabled else { return }
        let line = "[QuickLog] \(iso8601()) \(msg)\n"
        // Console
        print(line, terminator: "")
        fflush(stdout)

        // File (best-effort)
        do {
            AppPaths.ensureDirsExist()
            let data = Data(line.utf8)
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                let handle = try FileHandle(forWritingTo: logFileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: logFileURL, options: [.atomic])
            }
        } catch {
            // If logging fails, don't crash the app.
        }
    }

    private static func iso8601() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: Date())
    }
}
