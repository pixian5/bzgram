import Foundation

public enum TelegramClientFactory {

    public static func makeDefaultClient(bundle: Bundle = .main) -> TelegramClient {
        // 直接硬编码 API 密钥，不再依赖 Info.plist 注入
        let configuration = TelegramAPIConfiguration(
            apiID: 28071027,
            apiHash: "449cf3df8937bb8c31bdd4a610a25a5a",
            useTestDC: false
        )
        print("✅ [BZGram] 使用硬编码 API 配置，API ID: \(configuration.apiID)，真实模式。")
        return TDLibTelegramClient(configuration: configuration)
    }
}
