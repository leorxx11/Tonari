// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TonariCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "TonariCore", targets: ["TonariCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.11.1"),
        .package(url: "https://github.com/scinfu/SwiftSoup", from: "2.13.9"),
    ],
    targets: [
        .target(
            name: "TonariCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
            ]
        ),
        .testTarget(
            name: "TonariCoreTests",
            dependencies: ["TonariCore"]
        ),
    ]
)
