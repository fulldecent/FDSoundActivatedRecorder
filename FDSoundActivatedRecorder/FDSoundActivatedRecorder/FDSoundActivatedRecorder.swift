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

/// These should be optional but I don't know how to do that is Swift
@objc public protocol FDSoundActivatedRecorderDelegate {
    /// A recording was triggered or manually started
    func soundActivatedRecorderDidStartRecording(_ recorder: FDSoundActivatedRecorder)
    
    /// No recording has started or been completed after listening for `TOTAL_TIMEOUT_SECONDS`
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
    fileprivate let TOTAL_TIMEOUT_SECONDS = 10.0
    /// A time interval in seconds to base all `INTERVALS` below
    fileprivate let INTERVAL_SECONDS = 0.05
    fileprivate let LISTENING_MINIMUM_INTERVALS = 2
    fileprivate let LISTENING_AVERAGING_INTERVALS = 7
    fileprivate let RISE_TRIGGER_DB = 13.0
    fileprivate let RISE_TRIGGER_INTERVALS = 2
    fileprivate let RECORDING_MINIMUM_INTERVALS = 4
    fileprivate let RECORDING_AVERAGING_INTERVALS = 15
    fileprivate let FALL_TRIGGER_DB = 10.0
    fileprivate let FALL_TRIGGER_INTERVALS = 2
    fileprivate let SAVING_SAMPLES_PER_SECOND = 22050
    
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
            AVSampleRateKey : self.SAVING_SAMPLES_PER_SECOND,
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
    fileprivate var listeningIntervals = [Double]()
    fileprivate var recordingIntervals = [Double]()
    fileprivate var triggerCount = 0
    fileprivate var intervalTimer = Timer()
    fileprivate var recordingBeginTime = CMTime()
    fileprivate var recordingEndTime = CMTime()
    
    /// A log-scale reading between 0.0 (silent) and 1.0 (loud), nil if not recording
    /// TODO: make this optional (KVO needs Objective-C compatible classes, Swift bug)
    dynamic open var microphoneLevel: Double = 0.0
    
    /// Receiver for status updates
    open weak var delegate: FDSoundActivatedRecorderDelegate?
    
    deinit {
        self.abort()
    }
    
    /// Listen and start recording when triggered
    open func startListening() {
        status = .listening
        audioRecorder.stop()
        audioRecorder.record(forDuration: TOTAL_TIMEOUT_SECONDS)
        intervalTimer = Timer.scheduledTimer(timeInterval: INTERVAL_SECONDS, target: self, selector: #selector(FDSoundActivatedRecorder.interval), userInfo: nil, repeats: true)
        self.listeningIntervals.removeAll()
        self.recordingIntervals.removeAll()
        self.triggerCount = 0
    }
    
    /// Go back in time and start recording `RISE_TRIGGER_INTERVALS` ago
    open func startRecording() {
        status = .recording
        delegate?.soundActivatedRecorderDidStartRecording(self)
        triggerCount = 0
        let timeSamples = max(0.0, audioRecorder.currentTime - Double(INTERVAL_SECONDS) * Double(RISE_TRIGGER_INTERVALS)) * Double(SAVING_SAMPLES_PER_SECOND)
        recordingBeginTime = CMTimeMake(Int64(timeSamples), Int32(SAVING_SAMPLES_PER_SECOND))
    }
    
    /// End the recording and send any processed & saved file to `delegate`
    open func stopAndSaveRecording() {
        self.intervalTimer.invalidate()
        guard status == .recording else {
            return
        }
        status = .processingRecording
        self.microphoneLevel = 0.0
        let timeSamples = audioRecorder.currentTime * Double(SAVING_SAMPLES_PER_SECOND)
        recordingEndTime = CMTimeMake(Int64(timeSamples), Int32(SAVING_SAMPLES_PER_SECOND))
        audioRecorder.stop()
        
        // Prepare output
        let trimmedAudioFileBaseName = "recordingConverted\(UUID().uuidString).caf"
        let trimmedAudioFileURL = NSURL.fileURL(withPathComponents: [NSTemporaryDirectory(), trimmedAudioFileBaseName])!
        if (trimmedAudioFileURL as NSURL).checkResourceIsReachableAndReturnError(nil) {
            let fileManager = FileManager.default
            _ = try? fileManager.removeItem(at: trimmedAudioFileURL)
        }
        
        // Create time ranges for trimming and fading
        let fadeInDoneTime = CMTimeAdd(recordingBeginTime, CMTimeMake(Int64(Double(RISE_TRIGGER_INTERVALS) * Double(INTERVAL_SECONDS) * Double(SAVING_SAMPLES_PER_SECOND)), Int32(SAVING_SAMPLES_PER_SECOND)))
        let fadeOutStartTime = CMTimeSubtract(recordingEndTime, CMTimeMake(Int64(Double(FALL_TRIGGER_INTERVALS) * Double(INTERVAL_SECONDS) * Double(SAVING_SAMPLES_PER_SECOND)), Int32(SAVING_SAMPLES_PER_SECOND)))
        let exportTimeRange = CMTimeRangeFromTimeToTime(recordingBeginTime, recordingEndTime)
        let fadeInTimeRange = CMTimeRangeFromTimeToTime(recordingBeginTime, fadeInDoneTime)
        let fadeOutTimeRange = CMTimeRangeFromTimeToTime(fadeOutStartTime, recordingEndTime)
        
        // Set up the AVMutableAudioMix which does fading
        let avAsset = AVAsset(url: self.audioRecorder.url)
        let tracks = avAsset.tracks(withMediaType: AVMediaTypeAudio)
        let track = tracks[0]
        let exportAudioMix = AVMutableAudioMix()
        let exportAudioMixInputParameters = AVMutableAudioMixInputParameters(track: track)
        exportAudioMixInputParameters.setVolumeRamp(fromStartVolume: 0.0, toEndVolume: 1.0, timeRange: fadeInTimeRange)
        exportAudioMixInputParameters.setVolumeRamp(fromStartVolume: 1.0, toEndVolume: 0.0, timeRange: fadeOutTimeRange)
        exportAudioMix.inputParameters = [exportAudioMixInputParameters]
        
        // Configure AVAssetExportSession which sets audio format
        let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetAppleM4A)!
        exportSession.outputURL = trimmedAudioFileURL
        exportSession.outputFileType = AVFileTypeAppleM4A
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
        self.intervalTimer.invalidate()
        self.audioRecorder.stop()
        if status == .recording {
            status = .inactive
            self.delegate?.soundActivatedRecorderDidAbort(self)
            let fileManager: FileManager = FileManager.default
            _ = try? fileManager.removeItem(at: self.audioRecorder.url)
        }
    }
    
    /// This is a PRIVATE method but it must be public because a selector is used in NSTimer (Swift bug)
    open func interval() {
        guard self.audioRecorder.isRecording else {
            // Timed out
            self.abort()
            return
        }
        
        self.audioRecorder.updateMeters()
        let currentLevel = Double(self.audioRecorder.averagePower(forChannel: 0))
        switch currentLevel {
        case _ where currentLevel > 0:
            microphoneLevel = 1
        case _ where currentLevel < -85:
            microphoneLevel = 0
        default:
            microphoneLevel = 1 + currentLevel / 85
        }
        
        switch status {
        case .recording:
            let recordingAverageLevel = recordingIntervals.reduce(0.0, +) / Double(recordingIntervals.count)
            if recordingIntervals.count >= RECORDING_MINIMUM_INTERVALS && currentLevel <= recordingAverageLevel - FALL_TRIGGER_DB {
                triggerCount = triggerCount + 1
            } else {
                triggerCount = 0
                recordingIntervals.append(currentLevel)
                if recordingIntervals.count > RECORDING_AVERAGING_INTERVALS {
                    recordingIntervals.remove(at: 0)
                }
            }
            if triggerCount >= FALL_TRIGGER_INTERVALS {
                stopAndSaveRecording()
            }
        case .listening:
            let listeningAverageLevel = listeningIntervals.reduce(0.0, +) / Double(listeningIntervals.count)
            if listeningIntervals.count >= LISTENING_MINIMUM_INTERVALS && currentLevel >= listeningAverageLevel + RISE_TRIGGER_DB {
                triggerCount = triggerCount + 1
            } else {
                triggerCount = 0
                listeningIntervals.append(currentLevel)
                if listeningIntervals.count > LISTENING_AVERAGING_INTERVALS {
                    listeningIntervals.remove(at: 0)
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
