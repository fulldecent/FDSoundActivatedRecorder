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
 * When several consecutive levels exceed the recent moving average by a threshold, we record
 * (The exceeding levels are not included in the moving average)
 * When several consecutive levels deceed the recent moving average by a threshold, we stop recording
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

/// These should be optional but I don't know how to do that in Swift
@objc public protocol FDSoundActivatedRecorderDelegate {
    /// A recording was triggered or manually started
    func soundActivatedRecorderDidStartRecording(_ recorder: FDSoundActivatedRecorder)
    
    /// No recording has started or been completed after listening for `timeoutSeconds`
    func soundActivatedRecorderDidTimeOut(_ recorder: FDSoundActivatedRecorder)
    
    /// The recording and/or listening ended and no recording was captured
    func soundActivatedRecorderDidAbort(_ recorder: FDSoundActivatedRecorder)
    
    /// A recording was successfully captured
    func soundActivatedRecorderDidFinishRecording(_ recorder: FDSoundActivatedRecorder, andSaved file:URL)
}

@objc public enum FDSoundActivatedRecorderStatus: Int {
    case inactive
    case listening
    case recording
    case processingRecording
}

/// An automated listener / recorder
open class FDSoundActivatedRecorder: NSObject, AVAudioRecorderDelegate {
    
    /// Number of seconds until recording stops automatically
    public var timeoutSeconds = 10.0
    
    /// A time interval in seconds to base all `INTERVALS` below
    public var intervalSeconds = 0.05
    
    /// Minimum amount of time (in INTERVALS) to listen but not cause rise triggers
    public var listeningMinimumIntervals = 2
    
    /// Amount of time (in INTERVALS) to average when deciding to trigger for listening
    public var listeningAveragingIntervals = 7
    
    /// Relative signal strength (in dB) to detect triggers versus average listening level
    public var riseTriggerDb: Float = 13.0
    
    /// Number of consecutive triggers to begin recording
    public var riseTriggerIntervals = 2
    
    /// Minimum amount of time (in INTERVALS) to record
    public var recordingMinimumIntervals = 4
    
    /// Amount of time (in INTERVALS) to average when deciding to stop recording
    public var recordingAveragingIntervals = 15
    
    /// Relative signal strength (in dB) to detect triggers versus average recording level
    public var fallTriggerDb: Float = 10.0
    
    /// Number of consecutive triggers to end recording
    public var fallTriggerIntervals = 2
    
    /// Recording sample rate (in Hz)
    public var savingSamplesPerSecond = 22050
    
    /// Threashold (in Db) which is considered silence for `microphoneLevel`. Does not affect speech detection, only the `microphoneLevel` value.
    public var microphoneLevelSilenceThreshold: Float = -44.0
    
    /// Location of the recorded file
    fileprivate lazy var recordedFileURL: URL = {
        let file = "recording\(arc4random()).caf"
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(file)
        return url
    }()
    
    fileprivate lazy var audioRecorder: AVAudioRecorder = {
        // USE kAudioFormatLinearPCM
        // SEE IMA4 vs M4A http://stackoverflow.com/questions/3509921/recorder-works-on-iphone-3gs-but-not-on-iphone-3g
        let recordSettings: [String : Int] = [
            AVSampleRateKey : self.savingSamplesPerSecond,
            AVFormatIDKey : Int(kAudioFormatLinearPCM),
            AVNumberOfChannelsKey : Int(1),
            AVLinearPCMIsFloatKey : 0,
            AVEncoderAudioQualityKey : Int.max
        ]
        //FIXME: do not use ! here
        let audioRecorder = try! AVAudioRecorder(url: self.recordedFileURL, settings: recordSettings)
        audioRecorder.delegate = self
        audioRecorder.isMeteringEnabled = true
        if !audioRecorder.prepareToRecord() {
            // FDSoundActivateRecorder can't prepare recorder
        }
        return audioRecorder
    }()
    
    fileprivate(set) var status = FDSoundActivatedRecorderStatus.inactive
    internal var triggerCount = 0
    internal var triggerLevel: Float? = nil
    internal var averagingIntervals = [Float]()
    fileprivate var intervalTimer = Timer()
    fileprivate var recordingBeginTime = CMTime()
    fileprivate var recordingEndTime = CMTime()
    
    /// A log-scale reading between 0.0 (silent) and 1.0 (loud), nil if not recording
    /// TODO: make this optional (KVO needs Objective-C compatible classes, Swift bug)
    @objc dynamic open var microphoneLevel: Float = 0.0
    
    /// Receiver for status updates
    open weak var delegate: FDSoundActivatedRecorderDelegate?
    
    deinit {
        self.abort()
    }
    
    /// Listen and start recording when triggered
    open func startListening() {
        status = .listening
        audioRecorder.stop()
        audioRecorder.record(forDuration: timeoutSeconds)
        intervalTimer.invalidate()
        intervalTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true, block: { (Timer) in
            guard self.audioRecorder.isRecording else {
                // Timed out
                self.abort()
                return
            }
            self.audioRecorder.updateMeters()
            self.interval(currentLevel: self.audioRecorder.averagePower(forChannel: 0))
        })
        averagingIntervals.removeAll()
        triggerCount = 0
        triggerLevel = nil
    }
    
    /// Go back in time and start recording `riseTriggerIntervals` ago
    open func startRecording() {
        status = .recording
        delegate?.soundActivatedRecorderDidStartRecording(self)
        averagingIntervals.removeAll()
        triggerCount = 0
        triggerLevel = nil
        let timeSamples = max(0.0, audioRecorder.currentTime - Double(intervalSeconds) * Double(riseTriggerIntervals)) * Double(savingSamplesPerSecond)
        recordingBeginTime = CMTimeMake(value: Int64(timeSamples), timescale: Int32(savingSamplesPerSecond))
    }
    
    /// End the recording and send any processed & saved file to `delegate`
    open func stopAndSaveRecording() {
        intervalTimer.invalidate()
        guard status == .recording || status == .listening else {
            return
        }
        status = .processingRecording
        self.microphoneLevel = 0.0
        let timeSamples = audioRecorder.currentTime * Double(savingSamplesPerSecond)
        recordingEndTime = CMTimeMake(value: Int64(timeSamples), timescale: Int32(savingSamplesPerSecond))
        audioRecorder.stop()
        
        // Prepare output
        let trimmedAudioFileBaseName = "recordingConverted\(UUID().uuidString).caf"
        let trimmedAudioFileURL = NSURL.fileURL(withPathComponents: [NSTemporaryDirectory(), trimmedAudioFileBaseName])!
        if (trimmedAudioFileURL as NSURL).checkResourceIsReachableAndReturnError(nil) {
            let fileManager = FileManager.default
            _ = try? fileManager.removeItem(at: trimmedAudioFileURL)
        }
        
        // Create time ranges for trimming and fading
        let fadeInDoneTime = CMTimeAdd(recordingBeginTime, CMTimeMake(value: Int64(Double(riseTriggerIntervals) * Double(intervalSeconds) * Double(savingSamplesPerSecond)), timescale: Int32(savingSamplesPerSecond)))
        let fadeOutStartTime = CMTimeSubtract(recordingEndTime, CMTimeMake(value: Int64(Double(fallTriggerIntervals) * Double(intervalSeconds) * Double(savingSamplesPerSecond)), timescale: Int32(savingSamplesPerSecond)))
        let exportTimeRange = CMTimeRangeFromTimeToTime(start: recordingBeginTime, end: recordingEndTime)
        let fadeInTimeRange = CMTimeRangeFromTimeToTime(start: recordingBeginTime, end: fadeInDoneTime)
        let fadeOutTimeRange = CMTimeRangeFromTimeToTime(start: fadeOutStartTime, end: recordingEndTime)
        
        // Set up the AVMutableAudioMix which does fading
        let avAsset = AVAsset(url: self.audioRecorder.url)
        let tracks = avAsset.tracks(withMediaType: AVMediaType.audio)
        let track = tracks[0]
        let exportAudioMix = AVMutableAudioMix()
        let exportAudioMixInputParameters = AVMutableAudioMixInputParameters(track: track)
        exportAudioMixInputParameters.setVolumeRamp(fromStartVolume: 0.0, toEndVolume: 1.0, timeRange: fadeInTimeRange)
        exportAudioMixInputParameters.setVolumeRamp(fromStartVolume: 1.0, toEndVolume: 0.0, timeRange: fadeOutTimeRange)
        exportAudioMix.inputParameters = [exportAudioMixInputParameters]
        
        // Configure AVAssetExportSession which sets audio format
        let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetAppleM4A)!
        exportSession.outputURL = trimmedAudioFileURL
        exportSession.outputFileType = AVFileType.m4a
        exportSession.timeRange = exportTimeRange
        exportSession.audioMix = exportAudioMix
        
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                self.status = .inactive
                
                switch exportSession.status {
                case .completed:
                    self.delegate?.soundActivatedRecorderDidFinishRecording(self, andSaved: trimmedAudioFileURL)
                case .failed:
                    // a failure may happen because of an event out of your control
                    // for example, an interruption like a phone call comming in
                    // make sure and handle this case appropriately
                    // FIXME: add another delegate method for failing with exportSession.error
                    self.delegate?.soundActivatedRecorderDidAbort(self)
                default:
                    self.delegate?.soundActivatedRecorderDidAbort(self)
                }
            }
        }
    }
    
    /// End any recording or listening and discard any recorded file
    open func abort() {
        intervalTimer.invalidate()
        self.audioRecorder.stop()
        if status != .inactive {
            status = .inactive
            self.delegate?.soundActivatedRecorderDidAbort(self)
            let fileManager: FileManager = FileManager.default
            _ = try? fileManager.removeItem(at: self.audioRecorder.url)
        }
    }
    
    /// A heartbeat for checking conditions
    internal func interval(currentLevel: Float) {
        switch currentLevel {
        case _ where currentLevel > 0:
            microphoneLevel = 1
        case _ where currentLevel < microphoneLevelSilenceThreshold:
            microphoneLevel = 0
        default:
            microphoneLevel = 1 + currentLevel / microphoneLevelSilenceThreshold * -1.0
        }
        
        switch status {
        case .recording:
            if averagingIntervals.count >= recordingMinimumIntervals {
                triggerLevel = averagingIntervals.reduce(0.0, +) / Float(averagingIntervals.count) - fallTriggerDb
            }
            if let triggerLevel = triggerLevel, currentLevel <= triggerLevel {
                triggerCount += 1
                if triggerCount >= fallTriggerIntervals {
                    stopAndSaveRecording()
                }
            } else {
                triggerCount = 0
                averagingIntervals.append(currentLevel)
                if averagingIntervals.count > recordingAveragingIntervals {
                    averagingIntervals.removeFirst()
                }
            }
        case .listening:
            if averagingIntervals.count >= listeningMinimumIntervals {
                triggerLevel = averagingIntervals.reduce(0.0, +) / Float(averagingIntervals.count) + riseTriggerDb
            }
            if let triggerLevel = triggerLevel, currentLevel >= triggerLevel {
                triggerCount += 1
                if triggerCount >= fallTriggerIntervals {
                    startRecording()
                }
            } else {
                triggerCount = 0
                averagingIntervals.append(currentLevel)
                if averagingIntervals.count > listeningAveragingIntervals {
                    averagingIntervals.removeFirst()
                }
            }
        default:
            break
        }
    }
}
