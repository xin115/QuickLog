import Foundation
import AppKit

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let content: ClipboardContent
    let timestamp: Date
    var isPinned: Bool

    init(id: UUID = UUID(), content: ClipboardContent, timestamp: Date = Date(), isPinned: Bool = false) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.isPinned = isPinned
    }

    static func text(_ string: String) -> ClipboardItem {
        ClipboardItem(content: .text(string))
    }

    static func image(_ data: Data) -> ClipboardItem {
        ClipboardItem(content: .image(data))
    }

    var preview: String {
        switch content {
        case .text(let s):
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 100 {
                return String(trimmed.prefix(100)) + "..."
            }
            return trimmed
        case .image:
            return "(image)"
        }
    }

    var nsImage: NSImage? {
        content.nsImage
    }

    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
