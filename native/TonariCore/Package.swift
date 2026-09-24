// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TonariCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TonariCore", targets: ["TonariCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.11.1"),
    ],
    targets: [
        .target(
            name: "TonariCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
        .testTarget(
            name: "TonariCoreTests",
            dependencies: ["TonariCore"]
        ),
    ]
)
