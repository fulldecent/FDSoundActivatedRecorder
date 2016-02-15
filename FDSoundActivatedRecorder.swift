//
//  FDSoundActivatedRecorder.swift
//  FDSoundActivatedRecorder
//
//  Created by William Entriken on 1/28/16.
//  Copyright © 2016 William Entriken. All rights reserved.
//

import Foundation
import AVFoundation

/*
* HOW RECORDING WORKS
*
* V               Recording
* O             /-----------\
* L            /             \Fall
* U           /Rise           \
* M          /                 \
* E  --------                   --------
*    Listening                  Done
*
* We listen and save audio levels every `INTERVAL`
* When several levels exceed the recent moving average by a threshold, we record
* (The exceeding levels are not included in the moving average)
* When several levels deceed the recent moving average by a threshold, we stop recording
* (The deceeding levels are not included in the moving average)
*
* The final recording includes RISE, RECORDING, and FALL sections and the RISE and FALL
* parts are faded in and out to avoid clicking sounds at either end, you're welcome! Please
* mail a case of beer to: Wm Entriken / 410 Keats Rd / Huntingdon Vy PA 19006 USA
*
* Our "averages" are time averages of log squared power, an odd definition
* SEE: Averaging logs http://physics.stackexchange.com/questions/46228/averaging-decibels
*
* Please don't forget to use:
* try? AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
*/

/// These should be optional but I don't know how to do that is Swift
@objc public protocol FDSoundActivatedRecorderDelegate {
    /// A recording was triggered or manually started
    func soundActivatedRecorderDidStartRecording(recorder: FDSoundActivatedRecorder)
    
    /// No recording has started or been completed after listening for `TOTAL_TIMEOUT_SECONDS`
    func soundActivatedRecorderDidTimeOut(recorder: FDSoundActivatedRecorder)
    
    /// The recording and/or listening ended and no recording was captured
    func soundActivatedRecorderDidAbort(recorder: FDSoundActivatedRecorder)
    
    /// A recording was successfully captured
    func soundActivatedRecorderDidFinishRecording(recorder: FDSoundActivatedRecorder, andSaved file:NSURL)
}

private enum FDSoundActivatedRecorderStatus: Int {
    case Inactive
    case Listening
    case Recording
    case ProcessingRecording
}

public class FDSoundActivatedRecorder: NSObject, AVAudioRecorderDelegate {
    private let TOTAL_TIMEOUT_SECONDS = 10.0
    /// A time interval in seconds to base all `INTERVALS` below
    private let INTERVAL_SECONDS = 0.05
    private let LISTENING_MINIMUM_INTERVALS = 2
    private let LISTENING_AVERAGING_INTERVALS = 7
    private let RISE_TRIGGER_DB = 13.0
    private let RISE_TRIGGER_INTERVALS = 2
    private let RECORDING_MINIMUM_INTERVALS = 4
    private let RECORDING_AVERAGING_INTERVALS = 15
    private let FALL_TRIGGER_DB = 10.0
    private let FALL_TRIGGER_INTERVALS = 2
    private let SAVING_SAMPLES_PER_SECOND = 22050
    
    /// Location of the recorded file
    private lazy var recordedFileURL: NSURL = {
        let file = "recording\(arc4random()).caf"
        let url = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent(file)
        NSLog("FDSoundActivatedRecorder opened recording file: %@", url)
        return url
    }()
    
    private lazy var audioRecorder: AVAudioRecorder = {
        // USE kAudioFormatLinearPCM
        // SEE IMA4 vs M4A http://stackoverflow.com/questions/3509921/recorder-works-on-iphone-3gs-but-not-on-iphone-3g
        let recordSettings: [String : Int] = [
            AVSampleRateKey : self.SAVING_SAMPLES_PER_SECOND,
            AVFormatIDKey : Int(kAudioFormatLinearPCM),
            AVNumberOfChannelsKey : Int(1),
            AVLinearPCMIsFloatKey : 0,
            AVEncoderAudioQualityKey : Int.max
        ]
        //FIXME: do not use ! here
        let audioRecorder = try! AVAudioRecorder(URL: self.recordedFileURL, settings: recordSettings)
        audioRecorder.delegate = self
        audioRecorder.meteringEnabled = true
        if !audioRecorder.prepareToRecord() {
            NSLog("FDSoundActivateRecorder can't prepare recorder")
        }
        return audioRecorder
    }()
    
    private var status = FDSoundActivatedRecorderStatus.Inactive
    private var listeningIntervals = [Double]()
    private var recordingIntervals = [Double]()
    private var triggerCount = 0
    private var intervalTimer = NSTimer()
    private var recordingBeginTime = CMTime()
    private var recordingEndTime = CMTime()
    
    /// A log-scale reading between 0.0 (silent) and 1.0 (loud), nil if not recording
    /// TODO: make this optional (KVO needs Objective-C compatible classes, Swift bug)
    dynamic public var microphoneLevel: Double = 0.0
    
    /// Receiver for status updates
    public weak var delegate: FDSoundActivatedRecorderDelegate?
    
    deinit {
        self.abort()
    }
    
    /// Listen and start recording when triggered
    public func startListening() {
        status = .Listening
        audioRecorder.stop()
        audioRecorder.recordForDuration(TOTAL_TIMEOUT_SECONDS)
        intervalTimer = NSTimer.scheduledTimerWithTimeInterval(INTERVAL_SECONDS, target: self, selector: "interval", userInfo: nil, repeats: true)
        self.listeningIntervals.removeAll()
        self.recordingIntervals.removeAll()
        self.triggerCount = 0
    }
    
    /// Go back in time and start recording `RISE_TRIGGER_INTERVALS` ago
    public func startRecording() {
        status = .Recording
        delegate?.soundActivatedRecorderDidStartRecording(self)
        triggerCount = 0
        let timeSamples = max(0.0, audioRecorder.currentTime - Double(INTERVAL_SECONDS) * Double(RISE_TRIGGER_INTERVALS)) * Double(SAVING_SAMPLES_PER_SECOND)
        recordingBeginTime = CMTimeMake(Int64(timeSamples), Int32(SAVING_SAMPLES_PER_SECOND))
    }
    
    /// End the recording and send any processed & saved file to `delegate`
    public func stopAndSaveRecording() {
        self.intervalTimer.invalidate()
        guard status == .Recording else {
            return
        }
        self.microphoneLevel = 0.0
        let timeSamples = audioRecorder.currentTime * Double(SAVING_SAMPLES_PER_SECOND)
        recordingEndTime = CMTimeMake(Int64(timeSamples), Int32(SAVING_SAMPLES_PER_SECOND))
        audioRecorder.stop()
        
        // Prepare output
        let trimmedAudioFileBaseName = "recordingConverted\(NSUUID().UUIDString).caf"
        let trimmedAudioFileURL = NSURL.fileURLWithPathComponents([NSTemporaryDirectory(), trimmedAudioFileBaseName])!
        if trimmedAudioFileURL.checkResourceIsReachableAndReturnError(nil) {
            let fileManager = NSFileManager.defaultManager()
            _ = try? fileManager.removeItemAtURL(trimmedAudioFileURL)
        }
        
        NSLog("FDSoundActivatedRecorder saving cleaned file to %@", trimmedAudioFileURL)
        
        // Create time ranges for trimming and fading
        let fadeInDoneTime = CMTimeAdd(recordingBeginTime, CMTimeMake(Int64(Double(RISE_TRIGGER_INTERVALS) * Double(INTERVAL_SECONDS) * Double(SAVING_SAMPLES_PER_SECOND)), Int32(SAVING_SAMPLES_PER_SECOND)))
        let fadeOutStartTime = CMTimeSubtract(recordingEndTime, CMTimeMake(Int64(Double(FALL_TRIGGER_INTERVALS) * Double(INTERVAL_SECONDS) * Double(SAVING_SAMPLES_PER_SECOND)), Int32(SAVING_SAMPLES_PER_SECOND)))
        let exportTimeRange = CMTimeRangeFromTimeToTime(recordingBeginTime, recordingEndTime)
        let fadeInTimeRange = CMTimeRangeFromTimeToTime(recordingBeginTime, fadeInDoneTime)
        let fadeOutTimeRange = CMTimeRangeFromTimeToTime(fadeOutStartTime, recordingEndTime)
        
        // Set up the AVMutableAudioMix which does fading
        let avAsset = AVAsset(URL: self.audioRecorder.url)
        let tracks = avAsset.tracksWithMediaType(AVMediaTypeAudio)
        let track = tracks[0]
        let exportAudioMix = AVMutableAudioMix()
        let exportAudioMixInputParameters = AVMutableAudioMixInputParameters(track: track)
        exportAudioMixInputParameters.setVolumeRampFromStartVolume(0.0, toEndVolume: 1.0, timeRange: fadeInTimeRange)
        exportAudioMixInputParameters.setVolumeRampFromStartVolume(1.0, toEndVolume: 0.0, timeRange: fadeOutTimeRange)
        exportAudioMix.inputParameters = [exportAudioMixInputParameters]
        
        // Configure AVAssetExportSession which sets audio format
        let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetAppleM4A)!
        exportSession.outputURL = trimmedAudioFileURL
        exportSession.outputFileType = AVFileTypeAppleM4A
        exportSession.timeRange = exportTimeRange
        exportSession.audioMix = exportAudioMix
        
        NSLog("FDSoundActivatedRecorder audio export started")
        exportSession.exportAsynchronouslyWithCompletionHandler {
            switch exportSession.status {
            case .Completed:
                self.delegate?.soundActivatedRecorderDidFinishRecording(self, andSaved: trimmedAudioFileURL)
                NSLog("FDSoundActivatedRecorder audio export succeeded")
            case .Failed:
                // a failure may happen because of an event out of your control
                // for example, an interruption like a phone call comming in
                // make sure and handle this case appropriately
                NSLog("AVAssetExportSessionStatusFailed %@", exportSession.error!.localizedDescription)
                self.delegate?.soundActivatedRecorderDidAbort(self)
            default:
                NSLog("AVAssetExportSessionStatus was not expected")
                self.delegate?.soundActivatedRecorderDidAbort(self)
            }
        }
    }
    
    /// End any recording or listening and discard any recorded file
    public func abort() {
        self.intervalTimer.invalidate()
        self.audioRecorder.stop()
        if status == .Recording {
            status = .Inactive
            self.delegate?.soundActivatedRecorderDidAbort(self)
            let fileManager: NSFileManager = NSFileManager.defaultManager()
            _ = try? fileManager.removeItemAtURL(self.audioRecorder.url)
        }
    }
    
    /// This is a PRIVATE method but it must be public because a selector is used in NSTimer (Swift bug)
    public func interval() {
        guard self.audioRecorder.recording else {
            // Timed out
            self.abort()
            return
        }
        
        self.audioRecorder.updateMeters()
        let currentLevel = Double(self.audioRecorder.averagePowerForChannel(0))
        switch currentLevel {
        case _ where currentLevel > 0:
            microphoneLevel = 1
        case _ where currentLevel < -85:
            microphoneLevel = 0
        default:
            microphoneLevel = 1 + currentLevel / 85
        }
        
        switch status {
        case .Recording:
            let recordingAverageLevel = recordingIntervals.reduce(0.0, combine: +) / Double(recordingIntervals.count)
            NSLog("Recording avg %2.2f current %2.2f Intervals %d Triggers %d", recordingAverageLevel, currentLevel, recordingIntervals.count, triggerCount)
            if recordingIntervals.count >= RECORDING_MINIMUM_INTERVALS && currentLevel <= recordingAverageLevel {
                triggerCount = triggerCount + 1
            } else {
                recordingIntervals.append(currentLevel)
                if recordingIntervals.count > RECORDING_AVERAGING_INTERVALS {
                    recordingIntervals.removeAtIndex(0)
                }
            }
            if triggerCount >= FALL_TRIGGER_INTERVALS {
                stopAndSaveRecording()
            }
        case .Listening:
            let listeningAverageLevel = listeningIntervals.reduce(0.0, combine: +) / Double(listeningIntervals.count)
            NSLog("Listening avg %2.2f current %2.2f Intervals %d Triggers %d", listeningAverageLevel, currentLevel, listeningIntervals.count, triggerCount)
            if listeningIntervals.count >= LISTENING_MINIMUM_INTERVALS && currentLevel >= listeningAverageLevel + RISE_TRIGGER_DB {
                triggerCount = triggerCount + 1
            } else {
                listeningIntervals.append(currentLevel)
                if listeningIntervals.count > LISTENING_AVERAGING_INTERVALS {
                    listeningIntervals.removeAtIndex(0)
                }
            }
            if triggerCount >= RISE_TRIGGER_INTERVALS {
                startRecording()
            }
        default:
            break
        }
    }
}