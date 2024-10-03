// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QyooDetector",
    products: [
        .library(
            name: "QyooDetector",
            targets: ["QyooDetector"]),
    ],
    targets: [
        .target(
            name: "QyooDetector",
            dependencies: ["QyooLib"],
            path: "Sources/QyooDetector",
            publicHeadersPath: "."
        ),
        .target(
            name: "QyooLib",
            path: "Sources/QyooLib",
            publicHeadersPath: ".",
            cxxSettings: [
                .headerSearchPath("Sources/QyooLib"),
                .define("USE_OBJCXX", to: "1")
            ]
        ),
        .testTarget(
            name: "QyooDetectorTests",
            dependencies: ["QyooDetector"]),
    ]
)
