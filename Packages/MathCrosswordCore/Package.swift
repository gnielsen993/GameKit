// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MathCrosswordCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "MathCrosswordCore", targets: ["MathCrosswordCore"])
    ],
    targets: [
        .target(name: "MathCrosswordCore"),
        .testTarget(name: "MathCrosswordCoreTests", dependencies: ["MathCrosswordCore"])
    ],
    swiftLanguageVersions: [.v5]
)
