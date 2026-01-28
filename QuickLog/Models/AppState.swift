import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var clipboardHistory: [ClipboardItem] = []

    // Editor
    @Published var editorContext: EditorContext = .draft
    @Published var draftContent: String = ""
    @Published var editorMode: EditorMode = .markdown
    @Published var showMarkdownPreview: Bool = false
    @Published var settings: AppSettings = AppSettings()
    @Published var todaysLogUpdatedAt: Date? = nil

    @Published var entries: [Entry] = []

    // Pending (unsaved) draft preview shown in History when editing a fresh Draft.
    @Published var pendingEntry: Entry?

    // Debug/status
    @Published var lastSaveStatus: String = ""

    let clipboardWatcher: ClipboardWatcher
    private let draftService: DraftService
    private let entriesService: EntriesService
    private var draftAutosaveTimer: Timer?
    private var lastAutosaveContent: String = ""

    // Track whether the current draft session has started producing a pending history row.
    private var draftSessionId: UUID = UUID()
    private var pendingCreatedAt: Date? = nil

    init() {
        self.clipboardWatcher = ClipboardWatcher()
        self.draftService = DraftService()
        self.entriesService = EntriesService()

        AppPaths.ensureDirsExist()
        loadSettings()
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

        // Normalize any legacy/bad values.
        if settings.clipboardHistorySize < 10 { settings.clipboardHistorySize = 10 }
        if settings.clipboardHistorySize > 200 { settings.clipboardHistorySize = 200 }

        editorMode = settings.defaultEditorMode
        showMarkdownPreview = settings.markdownPreviewDefault

        // Persist normalized settings so behavior is stable.
        SettingsService.save(settings)
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

    func loadEntries() {
        entries = entriesService.loadEntries()
    }

    func loadDraft() {
        if let draft = draftService.loadDraft() {
            draftContent = draft.content
            editorMode = draft.editorMode
        }
        refreshPendingEntry()
    }

    func saveDraft() {
        let draft = Draft(content: draftContent, editorMode: editorMode, lastModified: Date())
        draftService.saveDraft(draft)
        refreshPendingEntry()
    }

    func newDraft() {
        autosaveIfNeeded()
        editorContext = .draft
        draftContent = ""
        lastAutosaveContent = ""

        draftSessionId = UUID()
        pendingCreatedAt = nil
        pendingEntry = nil

        saveDraft()
    }

    /// Commit current Draft/TodaysLog text as a new saved entry (and append to Today's Log), then open a fresh Draft.
    func commitDraftAndNew() {
        autosaveIfNeeded()

        switch editorContext {
        case .draft, .todaysLog:
            let trimmed = draftContent.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            appendToTodaysLog()
            draftContent = ""
            lastAutosaveContent = ""
            pendingEntry = nil
            pendingCreatedAt = nil
            saveDraft()

            // Next draft session.
            draftSessionId = UUID()

        case .entry:
            newDraft()
        }
    }

    func openTodaysLogForEditing() {
        autosaveIfNeeded()
        editorContext = .todaysLog
        refreshPendingEntry()
    }

    func forceAutosaveNow() {
        autosaveIfNeeded()
    }

    private func autosaveIfNeeded() {
        guard draftContent != lastAutosaveContent else { return }
        lastAutosaveContent = draftContent

        switch editorContext {
        case .draft:
            saveDraft()
        case .todaysLog:
            saveDraft()
        case .entry(let id):
            entriesService.updateEntry(id: id, content: draftContent)
            lastSaveStatus = "Saved history @ \(Date())"
            loadEntries()
        }

        refreshPendingEntry()
    }

    private func addClipboardItem(_ item: ClipboardItem) {
        // Keep a true history. (Do not de-dupe by content; repeated copies should still show up.)
        clipboardHistory.insert(item, at: 0)

        if clipboardHistory.count > settings.clipboardHistorySize {
            clipboardHistory = Array(clipboardHistory.prefix(settings.clipboardHistorySize))
        }

        if DebugLog.enabled {
            DebugLog.log("clipboard add count=\(clipboardHistory.count)/\(settings.clipboardHistorySize) preview=\(item.preview)")
        }
    }

    var saveTargetName: String {
        "Today's Log"
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
        appendToTodaysLog()
    }

    private func appendToTodaysLog() {
        NotesLegacy.appendToTodaysLog(content: draftContent)
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

    func deleteEntry(_ id: UUID) {
        entriesService.deleteEntry(id)
        loadEntries()
    }

    func openEntryForEditing(_ id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        autosaveIfNeeded()
        editorContext = .entry(id: id)
        pendingEntry = nil
        pendingCreatedAt = nil
        draftContent = entry.content
        lastAutosaveContent = draftContent
    }

    func insertIntoEditor(_ text: String) {
        draftContent += text
        refreshPendingEntry()
    }

    private func refreshPendingEntry() {
        // Only show pending item when editing a fresh Draft.
        guard editorContext == .draft else {
            pendingEntry = nil
            pendingCreatedAt = nil
            return
        }

        let trimmed = draftContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            pendingEntry = nil
            pendingCreatedAt = nil
            return
        }

        // First time we become non-empty in this draft session, pin a createdAt.
        if pendingCreatedAt == nil {
            pendingCreatedAt = Date()
        }

        let preview = String(trimmed.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true).first ?? "")
        pendingEntry = Entry(id: draftSessionId,
                             createdAt: pendingCreatedAt ?? Date(),
                             updatedAt: Date(),
                             target: .todaysLog,
                             preview: preview,
                             content: trimmed)
    }
}

/// Minimal leftover for Today's Log file append (we keep logs as md files).
enum NotesLegacy {
    static func appendToTodaysLog(content: String) {
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

    private static func formatEntry(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"
        let time = tf.string(from: Date())

        return "\n---\n" + "**" + time + "**\n\n" + trimmed + "\n"
    }

    private static func append(_ string: String, to url: URL) {
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

enum EditorMode: String, Codable, CaseIterable {
    case markdown = "Markdown"
    case richText = "Rich Text"
}
