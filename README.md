# BZGram

A third-party Telegram client for iOS with unlimited account support and built-in auto-translation.

## Features

- 📱 **iOS Native** – Built with Swift and SwiftUI for a native iOS experience
- 👥 **Unlimited Accounts** – Log in with as many Telegram accounts as you need; switch between them instantly
- 🌐 **Auto-Translation** – Enable automatic translation for all conversations in one tap
- 💬 **Per-Conversation Translation** – Override the global translation setting for any individual chat, choosing the target language and whether to show the original text alongside the translation
- 🔒 **Privacy Focused** – Your data stays on your device; translation calls are made only when needed

## Requirements

- iOS 16.0+
- Xcode 15+
- Swift 5.9+

## Project Structure

```
BZGram/
├── Sources/
│   ├── App/                   # App entry point and root navigation
│   ├── Models/                # Data models (Account, Chat, Message, TranslationSettings)
│   ├── ViewModels/            # ObservableObject view-models
│   ├── Views/
│   │   ├── Accounts/          # Account list and login/logout flows
│   │   ├── Chats/             # Chat list and message views
│   │   └── Settings/          # Global settings (language & translation)
│   ├── Services/              # AccountManager, TranslationService
│   └── Utilities/             # Extensions and helpers
├── Resources/                 # Assets, localisation strings
└── Tests/
    ├── AccountTests/
    └── TranslationTests/
```

## Getting Started

1. Clone this repository.
2. Open `BZGram.xcodeproj` (or the Swift Package via `Package.swift`) in Xcode.
3. Select an iOS simulator or device and press **Run**.

> **Note:** This project uses the [Telegram Bot API](https://core.telegram.org/api) / TDLib for backend communication.
> You must supply your own `api_id` and `api_hash` from [https://my.telegram.org](https://my.telegram.org)
> and place them in `BZGram/Resources/TelegramConfig.plist`.

## License

MIT