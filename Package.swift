// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClaudeProfiles",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ClaudeProfilesCore", targets: ["ClaudeProfilesCore"]),
        .executable(name: "ClaudeProfiles", targets: ["ClaudeProfilesApp"]),
    ],
    targets: [
        .target(name: "ClaudeProfilesCore"),
        .executableTarget(
            name: "ClaudeProfilesApp",
            dependencies: ["ClaudeProfilesCore"]
        ),
        .testTarget(
            name: "ClaudeProfilesCoreTests",
            dependencies: ["ClaudeProfilesCore"]
        ),
    ]
)
