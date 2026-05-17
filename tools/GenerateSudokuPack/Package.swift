// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GenerateSudokuPack",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(path: "../../Packages/SudokuCore")
    ],
    targets: [
        .executableTarget(
            name: "GenerateSudokuPack",
            dependencies: [
                .product(name: "SudokuCore", package: "SudokuCore")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
