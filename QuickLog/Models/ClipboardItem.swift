import Foundation

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date
    var isPinned: Bool

    init(id: UUID = UUID(), content: String, timestamp: Date = Date(), isPinned: Bool = false) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.isPinned = isPinned
    }

    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 100 {
            return String(trimmed.prefix(100)) + "..."
        }
        return trimmed
    }

    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
