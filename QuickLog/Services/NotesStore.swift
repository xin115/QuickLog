import Foundation

protocol NotesStore {
    func fetchNotes() -> [Note]

    func createNote(title: String, format: NoteFormat) -> Note
    func renameNote(noteId: UUID, newTitle: String)
    func deleteNote(noteId: UUID)

    func loadContent(noteId: UUID) -> String

    /// Returns true on success.
    @discardableResult
    func saveContent(noteId: UUID, content: String) -> Bool

    func append(noteId: UUID, entry: String)
}
