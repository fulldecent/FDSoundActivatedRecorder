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

1. Review `actions/checkout` in [`.github/workflows/ci.yml`](.github/workflows/ci.yml) and the `macos-15` runner image.
2. Re-read Swift 6 Module Template at the commit in [References](#references). When `main` has moved, adopt the newer revision and update that citation in the same change.

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

1. The Example app is one application target, package tests use Swift Testing, and the Example, Installation, Development, and maintenance sections follow [Swift 6 Module Template](https://github.com/fulldecent/swift6-module-template) commit [`38d7ba4`](https://github.com/fulldecent/swift6-module-template/commit/38d7ba45d0900e6a24392b833ae681ee58ad230f) (2026-10-02, "update for Xcode 27.0 (27A266a)"). The newest published tag at that commit is [16.4](https://github.com/fulldecent/swift6-module-template/releases/tag/16.4) (2025-07-24). This repository adopted `main` at `38d7ba4`, which is after that tag.
2. Deltas from that commit, kept because this library records on iOS:
   - `Package.swift` stays `swift-tools-version: 6.0` and `.iOS(.v16)`. The library does not enable `ApproachableConcurrency`. The Example app stays on iOS 16.6.
   - Package tests run with `xcodebuild` against an iPhone simulator. See [Development](#development).
   - Continuous integration stays [`.github/workflows/ci.yml`](.github/workflows/ci.yml) on `macos-15`. The template file [`.github/workflows/swiftlang-workflows.yml`](https://github.com/fulldecent/swift6-module-template/blob/38d7ba45d0900e6a24392b833ae681ee58ad230f/.github/workflows/swiftlang-workflows.yml) also builds Linux, Windows, Wasm, and Embedded Swift. Those jobs do not build this package.
   - [`.gitignore`](.gitignore) already inlines [Swift.gitignore](https://github.com/github/gitignore/blob/main/Swift.gitignore), which is the ignore file that commit vendors.
