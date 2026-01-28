import Foundation

final class EntriesService {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted]
        AppPaths.ensureDirsExist()
    }

    func loadEntries() -> [Entry] {
        let url = AppPaths.entriesIndexURL
        guard let data = try? Data(contentsOf: url),
              let index = try? decoder.decode(EntriesIndex.self, from: data) else {
            return []
        }
        return index.entries.sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    func addEntry(_ entry: Entry, maxCount: Int = 300) {
        var entries = loadEntries()
        entries.insert(entry, at: 0)
        if entries.count > maxCount {
            entries = Array(entries.prefix(maxCount))
        }
        save(entries)
    }

    func updateEntry(id: UUID, content: String) {
        var entries = loadEntries()
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = String(trimmed.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true).first ?? "")

        let old = entries[i]
        entries[i] = Entry(id: old.id,
                          createdAt: old.createdAt,
                          updatedAt: Date(),
                          target: old.target,
                          preview: preview,
                          content: content)
        save(entries)
    }

    func deleteEntry(_ id: UUID) {
        var entries = loadEntries()
        entries.removeAll(where: { $0.id == id })
        save(entries)
    }

    private func save(_ entries: [Entry]) {
        let index = EntriesIndex(entries: entries)
        guard let data = try? encoder.encode(index) else { return }
        try? data.write(to: AppPaths.entriesIndexURL, options: [.atomic])
    }
}
