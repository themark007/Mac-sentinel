import Foundation

enum PreferencesStore {
    private static let alertSettingsKey = "MacSentinel.AlertSettings.v1"

    static func loadAlertSettings() -> AlertSettings {
        guard let data = UserDefaults.standard.data(forKey: alertSettingsKey),
              let settings = try? JSONDecoder().decode(AlertSettings.self, from: data) else {
            return .defaults
        }
        return settings
    }

    static func saveAlertSettings(_ settings: AlertSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: alertSettingsKey)
    }
}
