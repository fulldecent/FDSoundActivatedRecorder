NOTICE: Development on this project is on pause until CocoaPods releases full support for Swift. Then we will work to upgrade this project. See https://github.com/CocoaPods/CocoaPods/pull/2835


FDSoundActivatedRecorder [![Build Status](https://travis-ci.org/fulldecent/FDSoundActivatedRecorder.svg?branch=master)](https://travis-ci.org/fulldecent/FDSoundActivatedRecorder)
========================

Start recording when the user speaks. All you have to do is tell us when to start listening. 
Then we wait for an audible noise and start recording. This is mostly useful for user speech
input and the "Start talking now prompt".

<p align="center">
  <img src="http://i.imgur.com/wgOcYMl.png">
</p>


Features
-------------------------

 * You can start recording when sound is detected, or immediately
 * Sound stops recording when the user is done talking
 * Works with ARC and iOS 5+


Usage
-------------------------

First, install by adding `pod 'FDSoundActivatedRecorder', '~> 0.9.0'` to your <a href="https://github.com/AFNetworking/AFNetworking/wiki/Getting-Started-with-AFNetworking">Podfile</a>.

Include the header `FDSoundActivatedRecorder.h` and create a property of `FDSoundActivatedRecorder` in your controller class. Then begin listening with:

    self.recorder = [[FDSoundActivatedRecorder alloc] init];
    self.recorder.delegate = self;
    [self.recorder startListening];

A full implementation example is provided in this project.

If your app is in the app store, I would much appreciate if you could add your app to https://www.cocoacontrols.com/controls/fdsoundactivatedrecorder under "Apps using this control" and "I Use This Control".


Full API
-------------------------

The full API, from <a href="https://github.com/fulldecent/FDSoundActivatedRecorder/blob/master/FDSoundActivatedRecorder.h">`FDSoundActivatedRecorder.h`</a> is copied below:

````
@protocol FDSoundActivatedRecorderDelegate <NSObject>
@optional
- (void)soundActivatedRecorderDidStartRecording:(FDSoundActivatedRecorder *)recorder;
- (void)soundActivatedRecorderDidStopRecording:(FDSoundActivatedRecorder *)recorder andSavedSound:(BOOL)didSave;
@end

@interface FDSoundActivatedRecorder : NSObject
- (void)startListening; // ... and record when ready
- (void)startRecording;
- (void)stopListeningAndKeepRecordingIfInProgress:(BOOL)keep;
- (void)deleteRecording;
@property (strong, nonatomic) NSNumber *microphoneLevel; // sort of 0 to 1.0
@property (strong, nonatomic) NSNumber *recordedDuration;
@property (strong, nonatomic) NSString *recordedFilePath;
@property (weak, nonatomic) id <FDSoundActivatedRecorderDelegate> delegate;
@end

````


Technical discussion
-------------------------

This library is tuned for human speech detection using Apple retail iOS devices in a quiet or noisy environement. You are welcome to tune the audio detection constants of this program for any special needs you may have. Following is a technical description of how the algorithm works from <a href="https://github.com/fulldecent/FDSoundActivatedRecorder/blob/master/FDSoundActivatedRecorder.m">`FDSoundActivatedRecorder.m`</a>.

```
/*
 * HOW RECORDING WORKS
 *
 * V            Recording
 * O          /-----------\
 * L         /             \Fall
 * U        /Rise           \
 * M       /                 \
 * E  -----                   --------
 *    Listening                Done
 *
 * We start off by listening and saving the audio level every INTERVAL
 * When the level exceeds the moving average of recent levels by a threshold, we record
 * While recording, we average levels and look for a drop of a certain threshold
 * If the level drops, the average will not include them
 * If a certain number of consecutive levels are a drop then we stop recording
 *
 * SEE: Averaging logs http://physics.stackexchange.com/questions/46228/averaging-decibels
 * Our "averages" are time averages of log squared power, an odd definition
 */
```
