// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "QyooDetector",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
    ],
    products: [
        .library(name: "QyooDetector", targets: ["QyooDetector"]),
        .executable(name: "QyooDetectorExample", targets: ["QyooDetectorExample"]),
    ],
    targets: [
        .target(
            name: "CQyooDetectorCore",
            path: "Sources/CQyooDetectorCore",
            exclude: ["PROVENANCE.md"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("libgd"),
                .define("HAVE_CONFIG_H"),
            ],
            cxxSettings: [
                .headerSearchPath("."),
                .headerSearchPath("core"),
                .headerSearchPath("libgd"),
                .define("HAVE_CONFIG_H"),
            ]
        ),
        .target(
            name: "QyooDetector",
            dependencies: ["CQyooDetectorCore"]
        ),
        .executableTarget(
            name: "QyooDetectorExample",
            dependencies: ["QyooDetector"]
        ),
    ],
    cxxLanguageStandard: .cxx11
)
