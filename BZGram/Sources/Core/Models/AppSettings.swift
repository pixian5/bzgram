import Foundation

/// Application-wide persistent settings.
public struct AppSettings: Codable, Equatable {
    /// Global translation configuration applied to every conversation unless overridden.
    public var globalTranslation: TranslationSettings
    /// The UUID of the account currently in use.
    public var activeAccountID: UUID?

    public init(
        globalTranslation: TranslationSettings = .disabled,
        activeAccountID: UUID? = nil
    ) {
        self.globalTranslation = globalTranslation
        self.activeAccountID = activeAccountID
    }
}
