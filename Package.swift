// swift-tools-version:5.5.0
import PackageDescription

let package = Package(
    name: "FDSoundActivatedRecorder",
    platforms: [.iOS(.v12)],
    products: [
        .library(
            name: "FDSoundActivatedRecorder",
            targets: ["FDSoundActivatedRecorder"]
        )
    ],
    targets: [
        .target(
            name: "FDSoundActivatedRecorder",
            dependencies: []
        ),
        .testTarget(
            name: "FDSoundActivatedRecorderTests",
            dependencies: ["FDSoundActivatedRecorder"]
        )
    ]
)
