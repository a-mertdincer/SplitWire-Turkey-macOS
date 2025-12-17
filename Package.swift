// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SplitWire-Turkey-macOS",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SplitWire-Turkey",
            targets: ["SplitWireTurkey"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SplitWireTurkey",
            dependencies: [],
            path: "Sources/SplitWireTurkey",
            resources: [
                .process("Resources/bin"),
                .copy("Resources")
            ]
        )
    ]
)
