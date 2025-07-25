// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FDSoundActivatedRecorder",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "FDSoundActivatedRecorder",
            targets: ["FDSoundActivatedRecorder"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "FDSoundActivatedRecorder"),
        .testTarget(
            name: "FDSoundActivatedRecorderTests",
            dependencies: ["FDSoundActivatedRecorder"]
        ),
    ]
)
