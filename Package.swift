// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "FDSoundActivatedRecorder",
    platforms: [.iOS(.v10)],
    products: [
        .library(name: "FDSoundActivatedRecorder", targets: ["FDSoundActivatedRecorder"])
    ],
    targets: [
        .target(
            name: "FDSoundActivatedRecorder",
            path: "FDSoundActivatedRecorder/FDSoundActivatedRecorder",
            exclude: ["FDSoundActivatedRecorderDemo"]
        ),
        .testTarget(
            name: "FDSoundActivatedRecorderTests",
            dependencies: ["FDSoundActivatedRecorder"],
            path: "FDSoundActivatedRecorder/FDSoundActivatedRecorderTests",
            exclude:  ["FDSoundActivatedRecorderDemo"]
        )
    ]
)
