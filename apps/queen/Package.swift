// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "trinity",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [],
    targets: [
        .executableTarget(
            name: "trinity",
            path: "QueenUI")
    ]
)
