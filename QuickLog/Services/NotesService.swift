import Foundation

final class NotesService {
    private let store: NotesStore

    init() {
        AppPaths.ensureDirsExist()

        let dbURL = AppPaths.appSupportDir.appendingPathComponent("notes.sqlite", isDirectory: false)
        let sqliteStore = SQLiteNotesStore(dbURL: dbURL)
        self.store = sqliteStore

        migrateFromLegacyFilesIfNeeded(into: sqliteStore)
    }

    func loadNotes() -> [Note] {
        store.fetchNotes()
    }

    func createNote(title: String) -> Note {
        store.createNote(title: title, format: .markdown)
    }

    func renameNote(noteId: UUID, newTitle: String) {
        store.renameNote(noteId: noteId, newTitle: newTitle)
    }

    func deleteNote(noteId: UUID) {
        store.deleteNote(noteId: noteId)
    }

    func appendToNote(noteId: UUID, content: String) {
        let entry = formatEntry(content)
        store.append(noteId: noteId, entry: entry)
    }

    func appendToTodaysLog(content: String) {
        let fm = FileManager.default
        AppPaths.ensureDirsExist()

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let filename = df.string(from: Date()) + ".md"

        let url = AppPaths.logsDir.appendingPathComponent(filename)
        if !fm.fileExists(atPath: url.path) {
            let header = "# " + df.string(from: Date()) + "\n\n"
            try? header.data(using: .utf8)?.write(to: url, options: [.atomic])
        }

        let entry = formatEntry(content)
        append(entry, to: url)
    }

    func loadNoteContent(noteId: UUID) -> String {
        store.loadContent(noteId: noteId)
    }

    @discardableResult
    func saveNoteContent(noteId: UUID, content: String) -> URL? {
        let ok = store.saveContent(noteId: noteId, content: content)
        return ok ? AppPaths.appSupportDir.appendingPathComponent("notes.sqlite") : nil
    }

    // MARK: - Legacy Migration (notes.json + per-note files)

    private func migrateFromLegacyFilesIfNeeded(into sqliteStore: SQLiteNotesStore) {
        // If there are already notes in the DB, don't migrate.
        if !sqliteStore.fetchNotes().isEmpty { return }

        let legacyIndexURL = AppPaths.notesIndexURL
        guard let data = try? Data(contentsOf: legacyIndexURL),
              let index = try? JSONDecoder().decode(NotesIndex.self, from: data),
              !index.notes.isEmpty else {
            return
        }

        DebugLog.log("Migrating legacy notes from \(legacyIndexURL.path) -> SQLite")

        for note in index.notes {
            let content = loadLegacyNoteFile(noteId: note.id, format: note.format)
            // Insert with original timestamps.
            insertMigrated(note: note, content: content, into: sqliteStore)
        }
    }

    private func loadLegacyNoteFile(noteId: UUID, format: NoteFormat) -> String {
        let ext = (format == .richText) ? "rtf" : "md"
        let url = AppPaths.notesDir.appendingPathComponent(noteId.uuidString + "." + ext)
        guard let data = try? Data(contentsOf: url) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    private func insertMigrated(note: Note, content: String, into sqliteStore: SQLiteNotesStore) {
        sqliteStore.upsert(note: note, content: content)
    }

    // MARK: - Helpers

    private func formatEntry(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"
        let time = tf.string(from: Date())

        return "\n---\n" + "**" + time + "**\n\n" + trimmed + "\n"
    }

    private func append(_ string: String, to url: URL) {
        guard !string.isEmpty else { return }
        if let data = string.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url, options: [.atomic])
            }
        }
    }
}
