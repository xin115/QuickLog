import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var clipboardHistory: [ClipboardItem] = []
    @Published var notes: [Note] = []
    @Published var selectedNoteId: UUID?

    // Editor
    @Published var editorContext: EditorContext = .draft
    @Published var draftContent: String = ""
    @Published var editorMode: EditorMode = .markdown
    @Published var showMarkdownPreview: Bool = false
    @Published var settings: AppSettings = AppSettings()
    @Published var todaysLogUpdatedAt: Date? = nil

    @Published var entries: [Entry] = []

    let clipboardWatcher: ClipboardWatcher
    private let notesService: NotesService
    private let draftService: DraftService
    private let entriesService: EntriesService
    private var draftAutosaveTimer: Timer?
    private var lastAutosaveContent: String = ""

    init() {
        self.clipboardWatcher = ClipboardWatcher()
        self.notesService = NotesService()
        self.draftService = DraftService()
        self.entriesService = EntriesService()

        AppPaths.ensureDirsExist()
        loadSettings()
        loadNotes()
        loadEntries()

        clipboardWatcher.onClipboardChange = { [weak self] item in
            self?.addClipboardItem(item)
        }

        setupDraftAutosave()

        // Start in draft mode.
        editorContext = .draft
    }

    private func setupDraftAutosave() {
        draftAutosaveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.autosaveIfNeeded()
            }
        }
    }

    private func loadSettings() {
        if let loadedSettings = SettingsService.load() {
            settings = loadedSettings
        }
        editorMode = settings.defaultEditorMode
        showMarkdownPreview = settings.markdownPreviewDefault
    }

    func saveSettings() {
        SettingsService.save(settings)
    }

    func updatePanelWidths(left: CGFloat, center: CGFloat, right: CGFloat) {
        settings.leftPanelWidth = Double(left)
        settings.centerPanelWidth = Double(center)
        settings.rightPanelWidth = Double(right)
        saveSettings()
    }

    func loadNotes() {
        notes = notesService.loadNotes()
    }

    func loadEntries() {
        entries = entriesService.loadEntries()
    }

    func loadDraft() {
        if let draft = draftService.loadDraft() {
            draftContent = draft.content
            editorMode = draft.editorMode
        }
    }

    func saveDraft() {
        let draft = Draft(content: draftContent, editorMode: editorMode, lastModified: Date())
        draftService.saveDraft(draft)
    }

    func newDraft() {
        // Leave any note editing context to avoid overwriting a note with blank content.
        editorContext = .draft
        selectedNoteId = nil
        draftContent = ""
        lastAutosaveContent = ""
        saveDraft()
    }

    /// If the current editor is a plain Draft and it contains text,
    /// "commit" it as a new saved entry (and append to Today's Log), then open a fresh Draft.
    func commitDraftAndNew() {
        switch editorContext {
        case .draft, .todaysLog:
            let trimmed = draftContent.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            // Persist the text as an entry + append to today's log (default capture behavior).
            appendToTodaysLog()
            // Clear for the next capture.
            draftContent = ""
            lastAutosaveContent = ""
            saveDraft()

        case .note:
            // Note editing is already autosaved; just start a new scratch draft.
            newDraft()
        }
    }

    func openTodaysLogForEditing() {
        editorContext = .todaysLog
        selectedNoteId = nil
        // For now: editing Today's Log uses the persisted draft as the scratchpad,
        // and writing happens via append model elsewhere.
    }

    func openNoteForEditing(noteId: UUID) {
        editorContext = .note(id: noteId)
        selectedNoteId = noteId
        draftContent = notesService.loadNoteContent(noteId: noteId)
        lastAutosaveContent = draftContent
    }

    private func autosaveIfNeeded() {
        guard draftContent != lastAutosaveContent else { return }
        lastAutosaveContent = draftContent

        switch editorContext {
        case .draft:
            saveDraft()
        case .todaysLog:
            // Keep draft autosave only (no continuous appends).
            saveDraft()
        case .note(let id):
            notesService.saveNoteContent(noteId: id, content: draftContent)
            loadNotes()
        }
    }

    private func addClipboardItem(_ item: ClipboardItem) {
        if let existingIndex = clipboardHistory.firstIndex(where: { $0.content == item.content }) {
            clipboardHistory.remove(at: existingIndex)
        }

        clipboardHistory.insert(item, at: 0)

        if clipboardHistory.count > settings.clipboardHistorySize {
            clipboardHistory = Array(clipboardHistory.prefix(settings.clipboardHistorySize))
        }
    }

    var saveTargetName: String {
        if let noteId = selectedNoteId,
           let note = notes.first(where: { $0.id == noteId }) {
            return note.title
        }
        return "Today's Log"
    }

    func saveAndNext() {
        saveToTarget()
        draftContent = ""
        saveDraft()
    }

    func saveOnly() {
        saveToTarget()
        saveDraft()
    }

    private func saveToTarget() {
        guard !draftContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if let noteId = selectedNoteId {
            appendToNote(noteId: noteId)
        } else {
            appendToTodaysLog()
        }
    }

    private func appendToNote(noteId: UUID) {
        notesService.appendToNote(noteId: noteId, content: draftContent)
        loadNotes()

        let title = notes.first(where: { $0.id == noteId })?.title ?? "Note"
        addEntry(target: .note(id: noteId, title: title), content: draftContent)
    }

    private func appendToTodaysLog() {
        notesService.appendToTodaysLog(content: draftContent)
        todaysLogUpdatedAt = Date()

        addEntry(target: .todaysLog, content: draftContent)
    }

    private func addEntry(target: EntryTarget, content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let preview = String(trimmed.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true).first ?? "")
        let entry = Entry(target: target, preview: preview, content: trimmed)
        entriesService.addEntry(entry)
        loadEntries()
    }

    func createNote(title: String) {
        let note = notesService.createNote(title: title)
        notes.insert(note, at: 0)
    }

    func renameNote(noteId: UUID, newTitle: String) {
        notesService.renameNote(noteId: noteId, newTitle: newTitle)
        loadNotes()
    }

    func deleteNote(noteId: UUID) {
        notesService.deleteNote(noteId: noteId)
        if selectedNoteId == noteId {
            selectedNoteId = nil
        }
        loadNotes()
    }

    func deleteEntry(_ id: UUID) {
        entriesService.deleteEntry(id)
        loadEntries()
    }

    func openEntryForEditing(_ id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        editorContext = .draft
        selectedNoteId = nil
        draftContent = entry.content
        lastAutosaveContent = draftContent
        saveDraft()
    }

    func selectNote(_ noteId: UUID?) {
        selectedNoteId = noteId
    }

    func insertIntoEditor(_ text: String) {
        draftContent += text
    }
}

enum EditorMode: String, Codable, CaseIterable {
    case markdown = "Markdown"
    case richText = "Rich Text"
}
