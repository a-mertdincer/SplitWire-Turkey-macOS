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
            path: "Sources/SplitWireTurkey"
            // ciadpi is not a SwiftPM resource: build.sh compiles it (universal) from byedpi/
            // and places it at Contents/Resources/bin/ciadpi. For `swift run` / `swift test`,
            // build it with scripts/build-ciadpi.sh (writes byedpi/ciadpi).
        ),
        .testTarget(
            name: "SplitWireTurkeyTests",
            dependencies: ["SplitWireTurkey"],
            path: "Tests/SplitWireTurkeyTests"
        )
    ]
)
