// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "TrinityVSA",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "TrinityVSA",
            targets: ["TrinityVSA"]),
    ],
    targets: [
        .target(
            name: "TrinityVSA",
            dependencies: []),
        .testTarget(
            name: "TrinityVSATests",
            dependencies: ["TrinityVSA"]),
    ]
)
