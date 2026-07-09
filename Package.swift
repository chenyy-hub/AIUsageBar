// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIUsageBar",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "AIUsageBar",
            dependencies: [],
            path: "Sources/AIUsageBar",
            resources: []
        )
    ]
)
