// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SudokuEngine",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "SudokuEngine", targets: ["SudokuEngine"])],
    targets: [
        .target(name: "SudokuEngine"),
        .testTarget(name: "SudokuEngineTests", dependencies: ["SudokuEngine"]),
    ],
    swiftLanguageModes: [.v6]
)
