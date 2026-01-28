import Foundation

enum SettingsService {
    private static let key = "QuickLog.settings.v1"

    static func load() -> AppSettings? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }

    static func save(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
