import Foundation
import SQLite3

// SwiftPM + SQLite3 does not always expose SQLITE_TRANSIENT.
let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Minimal SQLite wrapper (single connection, serialized by caller / MainActor in this app).
final class SQLiteDatabase {
    private(set) var db: OpaquePointer?
    let url: URL

    init(url: URL) throws {
        self.url = url
        try open()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    private func open() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.deletingLastPathComponent().path) {
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }

        // Open with FULLMUTEX for safety; this app is effectively single-threaded for DB access.
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        var handle: OpaquePointer?
        if sqlite3_open_v2(url.path, &handle, flags, nil) != SQLITE_OK {
            defer { if handle != nil { sqlite3_close(handle) } }
            let msg = String(cString: sqlite3_errmsg(handle))
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "sqlite open failed: \(msg)"])
        }
        db = handle

        // Pragmas (reasonable defaults for local app data)
        _ = exec("PRAGMA journal_mode=WAL;")
        _ = exec("PRAGMA foreign_keys=ON;")
    }

    @discardableResult
    func exec(_ sql: String) -> Bool {
        var err: UnsafeMutablePointer<Int8>?
        let rc = sqlite3_exec(db, sql, nil, nil, &err)
        if rc != SQLITE_OK {
            if let err {
                let msg = String(cString: err)
                sqlite3_free(err)
                DebugLog.log("SQLite exec failed: \(msg) | sql=\(sql)")
            }
            return false
        }
        return true
    }

    func prepare(_ sql: String) throws -> OpaquePointer? {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SQLite", code: 2, userInfo: [NSLocalizedDescriptionKey: "sqlite prepare failed: \(msg) | sql=\(sql)"])
        }
        return stmt
    }

    func step(_ stmt: OpaquePointer?) -> Int32 {
        sqlite3_step(stmt)
    }

    func finalize(_ stmt: OpaquePointer?) {
        sqlite3_finalize(stmt)
    }
}
