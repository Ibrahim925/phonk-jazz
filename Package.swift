// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PhonkJazz",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // Pure, headless-testable domain logic. No AppKit/WebKit here so it
        // builds and tests without a display. This is the seam the GUI drives.
        .target(
            name: "PhonkJazzCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // The macOS menubar app: AppKit + WebKit. Links PhonkJazzCore for logic.
        .executableTarget(
            name: "PhonkJazz",
            dependencies: ["PhonkJazzCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PhonkJazzCoreTests",
            dependencies: ["PhonkJazzCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
