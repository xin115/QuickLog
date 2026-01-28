import Foundation

enum EditorContext: Equatable {
    case draft
    case todaysLog
    case entry(id: UUID)

    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .todaysLog: return "Today's Log"
        case .entry: return "History"
        }
    }
}
