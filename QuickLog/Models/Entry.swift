import Foundation

enum EntryTarget: Codable, Equatable {
    case todaysLog
    case note(id: UUID, title: String)

    private enum Kind: String, Codable { case todaysLog, note }

    private enum CodingKeys: String, CodingKey { case kind, id, title }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .todaysLog:
            self = .todaysLog
        case .note:
            self = .note(id: try c.decode(UUID.self, forKey: .id), title: try c.decode(String.self, forKey: .title))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .todaysLog:
            try c.encode(Kind.todaysLog, forKey: .kind)
        case .note(let id, let title):
            try c.encode(Kind.note, forKey: .kind)
            try c.encode(id, forKey: .id)
            try c.encode(title, forKey: .title)
        }
    }

    var displayName: String {
        switch self {
        case .todaysLog: return "Today's Log"
        case .note(_, let title): return title
        }
    }
}

struct Entry: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let target: EntryTarget
    let preview: String

    init(id: UUID = UUID(), createdAt: Date = Date(), target: EntryTarget, preview: String) {
        self.id = id
        self.createdAt = createdAt
        self.target = target
        self.preview = preview
    }
}

struct EntriesIndex: Codable {
    var entries: [Entry] = []
}
