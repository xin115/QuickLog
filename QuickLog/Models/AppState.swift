import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var clipboardHistory: [ClipboardItem] = []
    @Published var notes: [Note] = []
    @Published var selectedNoteId: UUID?
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
    }

    private func setupDraftAutosave() {
        draftAutosaveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.saveDraft()
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
        let entry = Entry(target: target, preview: preview)
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
