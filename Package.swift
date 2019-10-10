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
            path: "Sources",
        //    exclude: ["DiskExample"]
        ),
        .testTarget(
            name: "FDSoundActivatedRecorderTests",
            dependencies: ["FDSoundActivatedRecorder"],
            path: "Tests",
        //    exclude:  ["DiskExample"]
        )
    ]
)
