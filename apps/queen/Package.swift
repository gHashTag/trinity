// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "trinity",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "QueenUILib",
            type: .dynamic,
            targets: ["QueenUILib"]),
        .executable(
            name: "trinity",
            targets: ["trinity"]),
    ],
    targets: [
        .target(
            name: "QueenUILib",
            path: "QueenUI",
            exclude: ["Entry"]),
        .executableTarget(
            name: "trinity",
            dependencies: ["QueenUILib"],
            path: "QueenUI/Entry"),
        .testTarget(
            name: "QueenUITests",
            dependencies: ["QueenUILib"],
            path: "Tests/QueenUITests"),
    ]
)
