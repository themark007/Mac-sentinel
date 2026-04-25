// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacSentinel",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacSentinel", targets: ["MacSentinel"])
    ],
    targets: [
        .executableTarget(
            name: "MacSentinel",
            path: "Sources/MacSentinel"
        )
    ]
)
