// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ZIPServeKit",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "ZIPServeKit",
            targets: ["ZIPServeKit"]
        ),
    ],
    targets: [
        .target(
            name: "ZIPServeKit"
        )
    ]
)
