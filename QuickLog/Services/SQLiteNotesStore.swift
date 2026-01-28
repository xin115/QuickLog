import Foundation
import SQLite3

final class SQLiteNotesStore: NotesStore {
    let db: SQLiteDatabase

    init(dbURL: URL) {
        do {
            self.db = try SQLiteDatabase(url: dbURL)
        } catch {
            fatalError("SQLiteNotesStore init failed: \(error)")
        }
        bootstrap()
    }

    private func bootstrap() {
        _ = db.exec("""
        CREATE TABLE IF NOT EXISTS notes (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          updatedAt REAL NOT NULL,
          format TEXT NOT NULL,
          content TEXT NOT NULL
        );
        """)
        _ = db.exec("CREATE INDEX IF NOT EXISTS idx_notes_updatedAt ON notes(updatedAt DESC);")
    }

    func fetchNotes() -> [Note] {
        let sql = "SELECT id, title, updatedAt, format FROM notes ORDER BY updatedAt DESC;"
        do {
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }

            var out: [Note] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let idC = sqlite3_column_text(stmt, 0),
                      let titleC = sqlite3_column_text(stmt, 1) else { continue }
                let id = UUID(uuidString: String(cString: idC)) ?? UUID()
                let title = String(cString: titleC)
                let updatedAt = Date(timeIntervalSinceReferenceDate: sqlite3_column_double(stmt, 2))
                let fmtRaw = String(cString: sqlite3_column_text(stmt, 3))
                let fmt = NoteFormat(rawValue: fmtRaw) ?? .markdown
                out.append(Note(id: id, title: title, updatedAt: updatedAt, format: fmt))
            }
            return out
        } catch {
            DebugLog.log("fetchNotes failed: \(error)")
            return []
        }
    }

    func createNote(title: String, format: NoteFormat) -> Note {
        let note = Note(title: title, updatedAt: Date(), format: format)
        let header = "# \(title)\n\n"
        upsert(note: note, content: header)
        return note
    }

    /// Insert or replace a note with explicit timestamps/content (used for migration and normal writes).
    func upsert(note: Note, content: String) {
        let sql = "INSERT OR REPLACE INTO notes(id, title, updatedAt, format, content) VALUES(?, ?, ?, ?, ?);"
        do {
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }

            sqlite3_bind_text(stmt, 1, note.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, note.title, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 3, note.updatedAt.timeIntervalSinceReferenceDate)
            sqlite3_bind_text(stmt, 4, note.format.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 5, content, -1, SQLITE_TRANSIENT)

            if sqlite3_step(stmt) != SQLITE_DONE {
                let msg = String(cString: sqlite3_errmsg(db.db))
                DebugLog.log("upsert failed: \(msg)")
            }
        } catch {
            DebugLog.log("upsert failed: \(error)")
        }
    }

    func renameNote(noteId: UUID, newTitle: String) {
        let sql = "UPDATE notes SET title=?, updatedAt=? WHERE id=?;"
        do {
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }

            sqlite3_bind_text(stmt, 1, newTitle, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 2, Date().timeIntervalSinceReferenceDate)
            sqlite3_bind_text(stmt, 3, noteId.uuidString, -1, SQLITE_TRANSIENT)

            _ = sqlite3_step(stmt)
        } catch {
            DebugLog.log("renameNote failed: \(error)")
        }
    }

    func deleteNote(noteId: UUID) {
        let sql = "DELETE FROM notes WHERE id=?;"
        do {
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }
            sqlite3_bind_text(stmt, 1, noteId.uuidString, -1, SQLITE_TRANSIENT)
            _ = sqlite3_step(stmt)
        } catch {
            DebugLog.log("deleteNote failed: \(error)")
        }
    }

    func loadContent(noteId: UUID) -> String {
        let sql = "SELECT content FROM notes WHERE id=? LIMIT 1;"
        do {
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }
            sqlite3_bind_text(stmt, 1, noteId.uuidString, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let c = sqlite3_column_text(stmt, 0) {
                    return String(cString: c)
                }
            }
            return ""
        } catch {
            DebugLog.log("loadContent failed: \(error)")
            return ""
        }
    }

    @discardableResult
    func saveContent(noteId: UUID, content: String) -> Bool {
        let now = Date().timeIntervalSinceReferenceDate
        let sql = "UPDATE notes SET content=?, updatedAt=? WHERE id=?;"
        do {
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }

            sqlite3_bind_text(stmt, 1, content, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 2, now)
            sqlite3_bind_text(stmt, 3, noteId.uuidString, -1, SQLITE_TRANSIENT)

            if sqlite3_step(stmt) != SQLITE_DONE {
                let msg = String(cString: sqlite3_errmsg(db.db))
                DebugLog.log("saveContent failed: \(msg)")
                return false
            }

            if DebugLog.enabled {
                let changed = sqlite3_changes(db.db)
                DebugLog.log("saveContent noteId=\(noteId) updatedAt=\(now) changes=\(changed)")
            }
            return true
        } catch {
            DebugLog.log("saveContent failed: \(error)")
            return false
        }
    }

    func append(noteId: UUID, entry: String) {
        guard !entry.isEmpty else { return }
        let now = Date().timeIntervalSinceReferenceDate
        // Single statement update to avoid race on read+write.
        let sql = "UPDATE notes SET content = content || ?, updatedAt=? WHERE id=?;"
        do {
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }

            sqlite3_bind_text(stmt, 1, entry, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 2, now)
            sqlite3_bind_text(stmt, 3, noteId.uuidString, -1, SQLITE_TRANSIENT)

            _ = sqlite3_step(stmt)
            if DebugLog.enabled {
                let changed = sqlite3_changes(db.db)
                DebugLog.log("append noteId=\(noteId) updatedAt=\(now) changes=\(changed)")
            }
        } catch {
            DebugLog.log("append failed: \(error)")
        }
    }
}
