// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MDK",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MDKPlayer", targets: ["MDKPlayer"]),
    ],
    targets: [
        .binaryTarget(
            name: "mdk",
            url: "https://github.com/wang-bin/mdk-sdk/releases/download/v0.38.0/mdk-sdk-apple.zip",
            checksum: "dfae61b90ae1cc543d173b3b4cf2411856c98d61a3a56d7b032573080b8d18a5"
        ),
        .target(name: "MDKPlayer", dependencies: ["mdk"]),
    ]
)
