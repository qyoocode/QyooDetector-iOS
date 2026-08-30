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
        .executable(name: "QyooDetectorBenchmark", targets: ["QyooDetectorBenchmark"]),
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
        .executableTarget(
            name: "QyooDetectorBenchmark",
            dependencies: ["QyooDetector", "CQyooDetectorCore"]
        ),
        .testTarget(
            name: "QyooDetectorTests",
            dependencies: ["QyooDetector", "CQyooDetectorCore"],
            resources: [.copy("Fixtures")]
        ),
    ],
    cxxLanguageStandard: .cxx11
)
