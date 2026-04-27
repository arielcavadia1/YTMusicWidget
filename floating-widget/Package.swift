// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YTMusicWidget",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "YTMusicWidget",
            path: "Sources/YTMusicWidget"
        )
    ]
)
