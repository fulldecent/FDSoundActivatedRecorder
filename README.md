# FDSoundActivatedRecorder

![Test](https://github.com/fulldecent/FDSoundActivatedRecorder/actions/workflows/ci.yml/badge.svg?branch=main)

```plain
 * V
 * O                 /-----------\
 * L                /             \
 * U          Rise /               \ Fall
 * M              /                 \
 * E  -----------/                   \-----------
 *
 *       Quiet   |   Recorded file   |   Quiet
```

## Example

Clone the repo and open [Example/Example.xcodeproj](Example/Example.xcodeproj). Run the Example scheme on a recent iPhone simulator.

## Installation

Add this package with Swift Package Manager. In Xcode that is File > Add Package Dependencies...

## Development

Run the package tests on an iPhone simulator. `Package.swift` requires iOS 16 and the library records through AVFoundation, so the destination is a simulator. This is the same command [`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs, with the simulator chosen from the ones installed on this Mac:

```sh
UDID=$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ { print $2; exit }')
xcodebuild -scheme FDSoundActivatedRecorder -destination "id=$UDID" test
```

### Maintenance and dependency updates

Do this every quarter, and send a pull request when an update is safe. The list is the one in [Swift 6 Module Template](https://github.com/fulldecent/swift6-module-template), applied to the files this repository actually has:

1. Review the external Actions in [`.github/workflows/ci.yml`](.github/workflows/ci.yml) and the `xcode-27` runner image. GitHub-supported Actions (the `actions/` organization) need a short review.
2. Re-read [Swift 6 Module Template](https://github.com/fulldecent/swift6-module-template) at the release in [References](#references). When a newer release is published, adopt it and update that citation in the same change.

## License

FDSoundActivatedRecorder is available under the MIT license. See [the LICENSE file](LICENSE) for more information.

## Features

- You can start recording when sound is detected
- Sound stops recording when the user is done talking
- Works with ARC and iOS 16+

## Usage

Import the project with:

```swift
import FDSoundActivatedRecorder
```

Then begin listening with:

```swift
self.recorder = FDSoundActivatedRecorder()
self.recorder.delegate = self
self.recorder.startListening()
```

A full implementation example is provided in this project.

### Regular recorder

If you want to use it as a regular recorder, without trimming the audio, you can tweak the `Configuration` to achieve that.

### Full API

The full API, from
[FDSoundActivatedRecorder.swift](https://github.com/fulldecent/FDSoundActivatedRecorder/blob/main/Sources/FDSoundActivatedRecorder/FDSoundActivatedRecorder.swift)
is copied below:

// FIXME: PASTE HERE

## Technical discussion

This library is tuned for human speech detection using Apple retail iOS devices
in a quiet or noisy environement. You are welcome to tune the audio detection
constants of this program for any special needs you may have. Following is a
technical description of how the algorithm works from
`FDSoundActivatedRecorder.swift`.

```plain
 * V
 * O                 /-----------\
 * L                /             \
 * U          Rise /               \ Fall
 * M              /                 \
 * E  -----------/                   \-----------
 *
 *       Quiet   |   Recorded file   |   Quiet
```

- We listen and save audio levels every `INTERVAL`
- When several levels exceed the recent moving average by a threshold, we record
- (The exceeding levels are not included in the moving average)
- When several levels deceed the recent moving average by a threshold, we stop recording
- (The deceeding levels are not included in the moving average)

## References

1. The Example app is one application target, package tests use Swift Testing, and the Example, Installation, Development, and maintenance sections follow [Swift 6 Module Template](https://github.com/fulldecent/swift6-module-template) release [16.5.0](https://github.com/fulldecent/swift6-module-template/releases/tag/v16.5.0) (2026-10-09), commit [`558b339`](https://github.com/fulldecent/swift6-module-template/commit/558b339c475c0a4f2263e40e5de4a74fbe967eed).
2. From that release, [`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on the GitHub-hosted `xcode-27` image and checks out with `actions/checkout@v7`. The template's macOS job is [`.github/workflows/swiftlang-workflows.yml`](https://github.com/fulldecent/swift6-module-template/blob/v16.5.0/.github/workflows/swiftlang-workflows.yml). `macos-26` stops at Xcode 26. The test command stays `xcodebuild` against an iPhone simulator, because this package imports AVFoundation and declares `.iOS(.v16)`.
3. Deltas from that release, kept because this library records on iOS:
   - `Package.swift` stays `swift-tools-version: 6.0` and `.iOS(.v16)`. The library does not enable `ApproachableConcurrency`. The Example app stays on iOS 16.6. The template package is `swift-tools-version: 6.4` with that upcoming feature, and it has no platform restriction.
   - [`.github/workflows/build-test.yml`](https://github.com/fulldecent/swift6-module-template/blob/v16.5.0/.github/workflows/build-test.yml) builds a release-mode Linux library and [`.github/workflows/release.yml`](https://github.com/fulldecent/swift6-module-template/blob/v16.5.0/.github/workflows/release.yml) publishes it with Release Please. This repository keeps the changelog and the release steps in [CONTRIBUTING.md](CONTRIBUTING.md). Swift Package Manager installs this library from the git tag.
   - The template also builds Linux, Windows, Wasm, and Embedded Swift. Those jobs do not build this package. Soundness in that workflow expects a Swift 6.4 image. This repository does not run it.
   - [`.gitignore`](.gitignore) already inlines [Swift.gitignore](https://github.com/github/gitignore/blob/main/Swift.gitignore), which is the ignore file that release vendors.
