// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "DccCachingService",
    platforms: [
        .iOS(.v12),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "DccCachingService",
            targets: ["DccCachingService"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", .upToNextMajor(from: "3.7.0")),
        .package(url: "https://github.com/ehn-dcc-development/ValidationCore", .branch("main"))
    ],
    targets: [
        .target(
            name: "DccCachingService",
            dependencies: ["ValidationCore",
                           .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack")
            ]),
        .testTarget(
            name: "DccCachingServiceTests",
            dependencies: ["DccCachingService"]),
    ]
)
