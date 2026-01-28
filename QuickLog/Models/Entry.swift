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
    let content: String

    // Backward compatible decoding (older entries may not have `content`).
    private enum CodingKeys: String, CodingKey { case id, createdAt, target, preview, content }

    init(id: UUID = UUID(), createdAt: Date = Date(), target: EntryTarget, preview: String, content: String) {
        self.id = id
        self.createdAt = createdAt
        self.target = target
        self.preview = preview
        self.content = content
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        target = try c.decode(EntryTarget.self, forKey: .target)
        preview = try c.decode(String.self, forKey: .preview)
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? preview
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(target, forKey: .target)
        try c.encode(preview, forKey: .preview)
        try c.encode(content, forKey: .content)
    }
}

struct EntriesIndex: Codable {
    var entries: [Entry] = []
}
