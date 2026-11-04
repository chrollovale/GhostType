// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyInjector",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GhostType", targets: ["KeyInjector"])
    ],
    targets: [
        .executableTarget(
            name: "KeyInjector",
            path: "Sources"
        )
    ]
)
