import Foundation

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var updatedAt: Date
    var format: NoteFormat

    init(id: UUID = UUID(), title: String, updatedAt: Date = Date(), format: NoteFormat = .markdown) {
        self.id = id
        self.title = title
        self.updatedAt = updatedAt
        self.format = format
    }
}

enum NoteFormat: String, Codable, CaseIterable {
    case markdown
    case richText
}

struct NotesIndex: Codable {
    var notes: [Note] = []
}

struct Draft: Codable {
    var content: String
    var editorMode: EditorMode
    var lastModified: Date
}

struct AppSettings: Codable, Equatable {
    var panelHeightRatio: Double = 0.33
    var panelWidth: Double = 1000
    var clipboardHistorySize: Int = 50
    var defaultEditorMode: EditorMode = .markdown
    var markdownPreviewDefault: Bool = false

    // Unclutter-like layout (persisted)
    var leftPanelWidth: Double = 260
    var centerPanelWidth: Double = 560
    var rightPanelWidth: Double = 260
}
