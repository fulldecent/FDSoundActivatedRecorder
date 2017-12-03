# FDSoundActivatedRecorder

[![CI Status](http://img.shields.io/travis/fulldecent/FDSoundActivatedRecorder.svg?style=flat)](https://travis-ci.org/fulldecent/FDSoundActivatedRecorder)
[![Version](https://img.shields.io/cocoapods/v/FDSoundActivatedRecorder.svg?style=flat)](http://cocoadocs.org/docsets/FDSoundActivatedRecorder)
[![License](https://img.shields.io/cocoapods/l/FDSoundActivatedRecorder.svg?style=flat)](http://cocoadocs.org/docsets/FDSoundActivatedRecorder)
[![Platform](https://img.shields.io/cocoapods/p/FDSoundActivatedRecorder.svg?style=flat)](http://cocoadocs.org/docsets/FDSoundActivatedRecorder)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Readme Score](http://readme-score-api.herokuapp.com/score.svg?url=fulldecent/FDSoundActivatedRecorder)](http://clayallsopp.github.io/readme-score?url=fulldecent/FDSoundActivatedRecorder)

Start recording when the user speaks. All you have to do is tell us when to
start listening. Then we wait for an audible noise and start recording. This is
mostly useful for user speech input and the "Start talking now prompt".

**:pizza: Virtual tip jar: https://amazon.com/hz/wishlist/ls/EE78A23EEGQB**

Features
--------

-   You can start recording when sound is detected, or immediately
-   Sound stops recording when the user is done talking
-   Works with ARC and iOS 5+

Usage
-----

First, install by adding `pod 'FDSoundActivatedRecorder', '~> 1.0.0'` to your
Podfile.

Import the project with:

    import FDSoundActivatedRecorder

Then begin listening with:

    self.recorder = FDSoundActivatedRecorder()
    self.recorder.delegate = self
    self.recorder.startListening()

A full implementation example is provided in this project.

If your app is in the app store, I would much appreciate if you could add your
app to https://www.cocoacontrols.com/controls/fdsoundactivatedrecorder under
"Apps using this control" and "I Use This Control".

Full API
--------

The full API, from
[FDSoundActivatedRecorder.swift](<https://github.com/fulldecent/FDSoundActivatedRecorder/blob/master/FDSoundActivatedRecorder.swift>)
is copied below:

````
@objc protocol FDSoundActivatedRecorderDelegate {
    /// A recording was triggered or manually started
    func soundActivatedRecorderDidStartRecording(recorder: FDSoundActivatedRecorder)

    /// No recording has started or been completed after listening for `TOTAL_TIMEOUT_SECONDS`
    func soundActivatedRecorderDidTimeOut(recorder: FDSoundActivatedRecorder)

    /// The recording and/or listening ended and no recording was captured
    func soundActivatedRecorderDidAbort(recorder: FDSoundActivatedRecorder)

    /// A recording was successfully captured
    func soundActivatedRecorderDidFinishRecording(recorder: FDSoundActivatedRecorder, andSaved file: NSURL)
}

class FDSoundActivatedRecorder : NSObject {
    /// A log-scale reading between 0.0 (silent) and 1.0 (loud), nil if not recording
    dynamic var microphoneLevel: Double

    /// Receiver for status updates
    weak var delegate: FDSoundActivatedRecorderDelegate?

    /// Listen and start recording when triggered
    func startListening()

    /// Go back in time and start recording `RISE_TRIGGER_INTERVALS` ago
    func startRecording()

    /// End the recording and send any processed & saved file to `delegate`
    func stopAndSaveRecording()

    /// End any recording or listening and discard any recorded file
    func abort()

    /// This is a PRIVATE method but it must be public because a selector is used in NSTimer (Swift bug)
    func interval()
}
````

Technical discussion
--------------------

This library is tuned for human speech detection using Apple retail iOS devices
in a quiet or noisy environement. You are welcome to tune the audio detection
constants of this program for any special needs you may have. Following is a
technical description of how the algorithm works from
`FDSoundActivatedRecorder.swift`.

````
V               Recording
O             /-----------\
L            /             \Fall
U           /Rise           \
M          /                 \
E  --------                   --------
   Listening                  Done
````

* We listen and save audio levels every `INTERVAL`
* When several levels exceed the recent moving average by a threshold, we record
* (The exceeding levels are not included in the moving average)
* When several levels deceed the recent moving average by a threshold, we stop recording
* (The deceeding levels are not included in the moving average)

Sponsorship
-----------

`[ YOUR LOGO HERE `]

Please contact github.com@phor.net to discuss adding your company logo above and supporting this project.
