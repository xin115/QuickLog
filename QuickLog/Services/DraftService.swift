import Foundation

final class DraftService {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted]
        AppPaths.ensureDirsExist()
    }

    func loadDraft() -> Draft? {
        let url = AppPaths.draftURL
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(Draft.self, from: data)
    }

    func saveDraft(_ draft: Draft) {
        let url = AppPaths.draftURL
        guard let data = try? encoder.encode(draft) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}
