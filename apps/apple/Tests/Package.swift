// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BadgeOnBar",
    platforms: [.macOS(.v15)],
    targets: [
        .target(
            name: "BadgeOnBarCore",
            path: "App",
            sources: ["AppSettings.swift"],
            swiftSettings: [.swiftLanguageMode(.v5)],
        ),
        .testTarget(
            name: "BadgeOnBarCoreTests",
            dependencies: ["BadgeOnBarCore"],
            path: "Tests",
            exclude: ["Package.swift"],
        ),
    ]
)
