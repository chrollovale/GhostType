// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GhostType",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GhostType", targets: ["GhostType"])
    ],
    targets: [
        .executableTarget(
            name: "GhostType",
            path: "Sources",
            resources: [.copy("GhostTypeMark.png")]
        )
    ]
)
