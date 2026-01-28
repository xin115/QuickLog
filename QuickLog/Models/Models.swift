import Foundation

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
