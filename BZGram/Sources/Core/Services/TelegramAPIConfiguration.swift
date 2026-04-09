import Foundation

public struct TelegramAPIConfiguration: Equatable, Sendable {

    public let apiID: Int
    public let apiHash: String
    public let useTestDC: Bool

    public init(apiID: Int, apiHash: String, useTestDC: Bool = false) {
        self.apiID = apiID
        self.apiHash = apiHash
        self.useTestDC = useTestDC
    }

    public static func load(from bundle: Bundle = .main) -> TelegramAPIConfiguration? {
        let rawAPIID = bundle.object(forInfoDictionaryKey: "BZGRAM_TELEGRAM_API_ID") as? String
        let rawAPIHash = bundle.object(forInfoDictionaryKey: "BZGRAM_TELEGRAM_API_HASH") as? String
        let rawUseTestDC = bundle.object(forInfoDictionaryKey: "BZGRAM_TELEGRAM_USE_TEST_DC")

        guard
            let apiIDString = rawAPIID?.trimmingCharacters(in: .whitespacesAndNewlines),
            let apiID = Int(apiIDString),
            let apiHash = rawAPIHash?.trimmingCharacters(in: .whitespacesAndNewlines),
            !apiHash.isEmpty
        else {
            return nil
        }

        return TelegramAPIConfiguration(
            apiID: apiID,
            apiHash: apiHash,
            useTestDC: Self.boolValue(from: rawUseTestDC)
        )
    }

    private static func boolValue(from rawValue: Any?) -> Bool {
        switch rawValue {
        case let value as Bool:
            return value
        case let value as String:
            return ["1", "true", "yes"].contains(value.lowercased())
        case let value as NSNumber:
            return value.boolValue
        default:
            return false
        }
    }
}
