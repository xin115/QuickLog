import Foundation

final class NotesService {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted]
        AppPaths.ensureDirsExist()
    }

    func loadNotes() -> [Note] {
        let url = AppPaths.notesIndexURL
        guard let data = try? Data(contentsOf: url),
              let index = try? decoder.decode(NotesIndex.self, from: data) else {
            return []
        }
        return index.notes.sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    func createNote(title: String) -> Note {
        var notes = loadNotes()
        let note = Note(title: title, updatedAt: Date(), format: .markdown)
        notes.insert(note, at: 0)
        saveIndex(notes)
        ensureNoteFileExists(note)
        return note
    }

    func renameNote(noteId: UUID, newTitle: String) {
        var notes = loadNotes()
        guard let i = notes.firstIndex(where: { $0.id == noteId }) else { return }
        notes[i].title = newTitle
        notes[i].updatedAt = Date()
        saveIndex(notes)
    }

    func deleteNote(noteId: UUID) {
        var notes = loadNotes()
        notes.removeAll(where: { $0.id == noteId })
        saveIndex(notes)

        let url = noteURL(noteId: noteId, format: .markdown)
        try? FileManager.default.removeItem(at: url)
    }

    func appendToNote(noteId: UUID, content: String) {
        var notes = loadNotes()
        guard let i = notes.firstIndex(where: { $0.id == noteId }) else { return }

        let note = notes[i]
        let url = noteURL(noteId: noteId, format: note.format)
        ensureNoteFileExists(note)

        let entry = formatEntry(content)
        append(entry, to: url)

        notes[i].updatedAt = Date()
        saveIndex(notes)
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
        // Use the note's recorded format when possible.
        let notes = loadNotes()
        let format = notes.first(where: { $0.id == noteId })?.format ?? .markdown
        let url = noteURL(noteId: noteId, format: format)
        guard let data = try? Data(contentsOf: url) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    @discardableResult
    func saveNoteContent(noteId: UUID, content: String) -> URL? {
        var notes = loadNotes()
        guard let i = notes.firstIndex(where: { $0.id == noteId }) else {
            DebugLog.log("saveNoteContent: noteId not found: \(noteId)")
            return nil
        }
        let note = notes[i]
        let url = noteURL(noteId: noteId, format: note.format)
        ensureNoteFileExists(note)

        do {
            try content.data(using: .utf8)?.write(to: url, options: [.atomic])
            DebugLog.log("saveNoteContent wrote \(content.utf8.count) bytes -> \(url.path)")
        } catch {
            DebugLog.log("saveNoteContent write failed -> \(url.path): \(error)")
            return nil
        }

        notes[i].updatedAt = Date()
        saveIndex(notes)
        return url
    }

    // MARK: - Helpers

    private func saveIndex(_ notes: [Note]) {
        // Keep the on-disk index sorted by last-updated so other consumers (and humans)
        // see the same ordering as the UI.
        let sorted = notes.sorted(by: { $0.updatedAt > $1.updatedAt })
        let index = NotesIndex(notes: sorted)
        guard let data = try? encoder.encode(index) else { return }
        try? data.write(to: AppPaths.notesIndexURL, options: [.atomic])
    }

    private func noteURL(noteId: UUID, format: NoteFormat) -> URL {
        let ext = (format == .richText) ? "rtf" : "md"
        return AppPaths.notesDir.appendingPathComponent(noteId.uuidString + "." + ext)
    }

    private func ensureNoteFileExists(_ note: Note) {
        let fm = FileManager.default
        let url = noteURL(noteId: note.id, format: note.format)
        if fm.fileExists(atPath: url.path) { return }
        let header = "# " + note.title + "\n\n"
        try? header.data(using: .utf8)?.write(to: url, options: [.atomic])
    }

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
