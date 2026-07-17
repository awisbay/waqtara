// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Waqtara",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "WaqtaraCore", targets: ["WaqtaraCore"]),
        .executable(name: "waqtara-cli", targets: ["WaqtaraCLI"]),
        .executable(name: "Waqtara", targets: ["WaqtaraApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/batoulapps/adhan-swift", branch: "main"),
    ],
    targets: [
        .target(
            name: "WaqtaraCore",
            dependencies: [.product(name: "Adhan", package: "adhan-swift")],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "WaqtaraCLI",
            dependencies: ["WaqtaraCore"]
        ),
        .executableTarget(
            name: "WaqtaraApp",
            dependencies: ["WaqtaraCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "WaqtaraCoreTests",
            dependencies: ["WaqtaraCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
