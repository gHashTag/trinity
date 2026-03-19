// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TrinityBridge",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "TrinityBridge",
            targets: ["TrinityBridge"]),
    ],
    targets: [
        .target(
            name: "TrinityBridge",
            dependencies: ["CTrinityQueen"],
            path: "Sources/TrinityBridge"),
        .systemLibrary(
            name: "CTrinityQueen",
            path: "include",
            pkgConfig: nil,
            providers: nil),
    ]
)
