# FDSoundActivatedRecorder

![GitHub tag (latest SemVer)](https://github.com/fulldecent/FDSoundActivatedRecorder/actions/workflows/ci.yml/badge.svg?branch=main)

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

To run the example project, clone this repo, and open Example.xcworkspace from the iOS Example directory.

## Installation

Add this to your project using Swift Package Manager. In Xcode that is simply: File > Swift Packages > Add Package Dependency... and you're done.

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
