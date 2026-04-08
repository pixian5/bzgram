import Foundation
#if canImport(Combine)
import Combine
#endif

/// Persists and loads `AppSettings` to/from `UserDefaults`.
public final class SettingsStore {

    public var settings: AppSettings {
        didSet { save() }
    }

    private let key = "bzgram.appSettings"
    private let store: UserDefaults

    public init(store: UserDefaults = .standard) {
        self.store = store
        if let data = store.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = AppSettings()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        store.set(data, forKey: key)
    }
}

#if canImport(Combine)
// Retroactively add ObservableObject so SwiftUI views can observe settings changes.
extension SettingsStore: ObservableObject {}
#endif
