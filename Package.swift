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
    targets: [
        // Pure-Swift core: Models + Services + ViewModels (no SwiftUI).
        .target(
            name: "BZGramCore",
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
