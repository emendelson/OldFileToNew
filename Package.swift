// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OldFileToNew",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "OldFileToNew",
            path: "Sources/OldFileToNew",
            // The CLI tool and Help page are bundled by make_app.sh, not SwiftPM.
            exclude: ["Resources"]
        )
    ]
)
