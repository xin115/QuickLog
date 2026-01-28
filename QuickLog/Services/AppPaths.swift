import Foundation

enum AppPaths {
    static var quickLogDocumentsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("QuickLog", isDirectory: true)
    }

    static var logsDir: URL {
        quickLogDocumentsDir.appendingPathComponent("logs", isDirectory: true)
    }

    static var notesDir: URL {
        quickLogDocumentsDir.appendingPathComponent("notes", isDirectory: true)
    }

    static var notesIndexURL: URL {
        notesDir.appendingPathComponent("notes.json", isDirectory: false)
    }

    static var appSupportDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("QuickLog", isDirectory: true)
    }

    static var draftURL: URL {
        appSupportDir.appendingPathComponent("draft.json", isDirectory: false)
    }

    static var entriesIndexURL: URL {
        appSupportDir.appendingPathComponent("entries.json", isDirectory: false)
    }

    static func ensureDirsExist() {
        let fm = FileManager.default
        for dir in [quickLogDocumentsDir, logsDir, notesDir, appSupportDir] {
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }
}
