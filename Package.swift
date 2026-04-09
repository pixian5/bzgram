// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BZGram",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)   // allows running tests on macOS/Linux CI
    ],
    products: [
        // Core library: models, services and view-models (no SwiftUI dependency).
        .library(name: "BZGramCore", targets: ["BZGramCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/Swiftgram/TDLibKit", exact: "1.5.2-tdlib-1.8.63-8ff05a0e")
    ],
    targets: [
        // Pure-Swift core: Models + Services + ViewModels (no SwiftUI).
        .target(
            name: "BZGramCore",
            dependencies: ["TDLibKit"],
            path: "BZGram/Sources/Core"
        ),
        // Unit tests for the core layer – runs on macOS/Linux without SwiftUI.
        .testTarget(
            name: "BZGramTests",
            dependencies: ["BZGramCore"],
            path: "BZGram/Tests"
        )
    ]
)
