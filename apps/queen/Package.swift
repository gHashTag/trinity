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
            // cerebellum_tests.swift imports XCTest. Compiling it into the
            // product library made libQueenUILib.dylib link
            // libXCTestSwiftSupport.dylib, which is absent at runtime outside a
            // test host - every app embedding this library died at launch with
            // "Library not loaded: @rpath/libXCTestSwiftSupport.dylib".
            // Unit tests belong in the QueenUITests target, not in the library.
            exclude: ["Entry", "Cortex/Calibration/cerebellum_tests.swift"]),
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
