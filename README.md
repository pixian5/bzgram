# BZGram

A third-party Telegram client for iOS with unlimited account support and built-in auto-translation.

## Features

- iOS native UI built with SwiftUI
- Unlimited Telegram account management
- Global auto-translation settings
- Per-conversation translation overrides
- Core logic separated into `BZGramCore` for easier testing

## Requirements

- macOS with Xcode 15 or later
- iOS 16.0+
- Swift 5.9+
- `xcodegen` if you want to generate `BZGram.xcodeproj` locally from `project.yml`

## Current Build Flow

This repository now supports two parallel ways of preparing an iOS build:

1. `Package.swift`
   Used for the pure Swift core library and tests.
2. `project.yml`
   Used by XcodeGen to generate `BZGram.xcodeproj`, which opens directly in Xcode as an iOS app project.

The GitHub Actions workflow runs on macOS and does the following:

1. Installs XcodeGen
2. Generates `BZGram.xcodeproj`
3. Builds the `BZGram` iOS app target for `iphonesimulator`
4. Uploads a zip containing the generated Xcode project and source code

This does not produce a signed `.ipa` in CI, because `.ipa` export requires Apple signing assets. It does produce a package that is intentionally close to the final IPA step: download the zip, open `BZGram.xcodeproj` in Xcode, configure signing, then Archive and export an IPA locally.

## Local Usage

### Option 1: Generate the Xcode project yourself

```bash
brew install xcodegen
xcodegen generate
open BZGram.xcodeproj
```

### Option 2: Use the workflow artifact or release zip

1. Download the generated `BZGram-iOS-project-v*.zip` from GitHub Actions or Releases.
2. Unzip it locally.
3. Open `BZGram.xcodeproj` in Xcode.
4. Set your Team, Bundle Identifier, and signing profile.
5. Build, Archive, and export the IPA from Xcode.

## Project Structure

```text
BZGram/
  Sources/
    App/      iOS app entry point
    Core/     Models, services, and view-models
    Views/    SwiftUI screens
  Tests/      Unit tests for the core module
```

## Notes

- If normal local running fails because the Xcode project is missing, generate it with `xcodegen generate`.
- CI intentionally builds for `iphonesimulator` without signing, so that validation works without Apple certificates.
- To export a real `.ipa`, continue in Xcode on macOS with your own signing configuration.

## License

MIT
