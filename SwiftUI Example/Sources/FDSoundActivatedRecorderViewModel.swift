//
//  FDSoundActivatedRecorderViewModel.swift
//  FDSoundActivatedRecorderViewModel-SwiftUI
//
//  Created by Engin BULANIK on 25.08.2020.
//  Copyright © 2020 William Entriken. All rights reserved.
//
import SwiftUI
import Foundation
import AVKit
import AVFoundation
@testable import FDSoundActivatedRecorder

var audioSession: AVAudioSession?

class FDSoundActivatedRecorderViewModel: NSObject, ObservableObject, FDSoundActivatedRecorderDelegate {
    var recorder = FDSoundActivatedRecorderMock()
    @Published var savedURL: URL? = nil
    var player = AVPlayer()
    
    /// Most recent are added to end
    @Published var sampleSquares = [Sample]()
    @Published var progressBarLevel: CGFloat = 0
    @Published var progressTintColor = Color.blue
    @Published var microphoneLevel = String(format: "%0.2f", 0)
    
    let graphSampleSize: CGFloat = 5
    let menuWidth: CGFloat = 300
    
    func resetGraph() {
        sampleSquares = []
    }
    
    func pressedStartListening() {
        resetGraph()
        recorder.startListening()
    }
    
    func pressedStartRecording() {
        resetGraph()
        recorder.regularRecording = true
        recorder.startListening()
        recorder.startRecording()
    }
    
    func pressedStopAndSaveRecording() {
        recorder.stopAndSaveRecording()
        recorder.regularRecording = false
        progressBarLevel = 0
    }
    
    func pressedAbort() {
        recorder.abort()
    }
    
    func pressedPlay() {
        player = AVPlayer(url: savedURL!)
        player.play()
    }
    
    func soundActivatedRecorderDidStartRecording(_ recorder: FDSoundActivatedRecorder) {
        print("soundActivatedRecorderDidStartRecording")
        progressTintColor = Color.red
    }
    
    func soundActivatedRecorderDidTimeOut(_ recorder: FDSoundActivatedRecorder) {
        print("soundActivatedRecorderDidTimeOut")
        progressTintColor = Color.blue
    }
    
    func soundActivatedRecorderDidAbort(_ recorder: FDSoundActivatedRecorder) {
        print("soundActivatedRecorderDidAbort")
        progressTintColor = Color.blue
        progressBarLevel = 0
        microphoneLevel = String(format: "%0.2f", 0)
    }
    
    func soundActivatedRecorderDidFinishRecording(_ recorder: FDSoundActivatedRecorder, andSaved file: URL) {
        print("soundActivatedRecorderDidFinishRecording")
        progressTintColor = Color.blue
        progressBarLevel = 0
        microphoneLevel = String(format: "%0.2f", 0)
        savedURL = file
    }

    override init() {
        super.init()
        
        recorder.delegate = self
        //recorder.addObserver(self, forKeyPath: "microphoneLevel", options:.new, context: nil)
        recorder.intervalCallback = {currentLevel in self.drawSample(currentLevel: currentLevel)}
        recorder.microphoneLevelSilenceThreshold = -60
        
        // Get the singleton instance.
        audioSession = AVAudioSession.sharedInstance()
        _ = try? audioSession!.setCategory(AVAudioSession.Category(rawValue:AVAudioSession.Category.playAndRecord.rawValue))
        _ = try? audioSession!.setActive(true)
    }
    
    func micLevel (_ currentLevel: Float)-> Float {
        switch currentLevel {
        case _ where currentLevel > 0:
            return 1
        case _ where currentLevel < recorder.microphoneLevelSilenceThreshold:
            return 0
        default:
            return 1 + currentLevel / recorder.microphoneLevelSilenceThreshold * -1.0
        }
    }
    
    func drawSample(currentLevel: Float) {
        print(String.init(format: "%0.3f", currentLevel));
        
        let level = micLevel(currentLevel)
        progressBarLevel = CGFloat(level)
        microphoneLevel = String(format: "%0.2f", level)
        
        // Translate from [microphoneLevelSilenceThreshold, 0] to [0, 1]
        let valueScaled = CGFloat(1 - currentLevel / recorder.microphoneLevelSilenceThreshold)
        var sampleColor: Color = .green
        
        switch recorder.status {
        case .listening:
            sampleColor = .yellow
            if recorder.averagingIntervals.count < recorder.listeningMinimumIntervals {
                sampleColor = .gray
            }
            if let triggerLevel = recorder.triggerLevel, currentLevel >= triggerLevel {
                sampleColor = .purple
            }
        case .recording:
            sampleColor = .red
            if recorder.averagingIntervals.count < recorder.recordingMinimumIntervals {
                sampleColor = .orange
            }
            if let triggerLevel = recorder.triggerLevel, currentLevel <= triggerLevel {
                sampleColor = .blue
            }
        default:
            sampleColor = .green
        }

        var triggerLevelValueScaled: CGFloat = 0
        var triggerLevelColor: Color = .clear
        
        // Create threshold dot //////////////////////////////////////////////////
        if let triggerLevel = recorder.triggerLevel {
            triggerLevelValueScaled = CGFloat(1 - triggerLevel / recorder.microphoneLevelSilenceThreshold)
            triggerLevelColor = .black
        }
        
        // Create the sample dot ///////////////////////////////////////////////
        sampleSquares.append(Sample(color: sampleColor, value: valueScaled, thresholdColor: triggerLevelColor, thresholdValue: triggerLevelValueScaled))
    }

}

struct Sample {
    var id = UUID()
    var color: Color
    var value: CGFloat
    var thresholdColor: Color
    var thresholdValue: CGFloat
}

class FDSoundActivatedRecorderMock: FDSoundActivatedRecorder {
    var intervalCallback: (Float)->() = {_ in}
    var regularRecording = false
    
    override func interval(currentLevel: Float) {
        self.intervalCallback(currentLevel)
        if regularRecording == false {
            super.interval(currentLevel: currentLevel)
        }
    }
    
    override init() {
        super.init()
    }
    
    override func abort() {
        print("FDSoundActivatedRecorderMock: abort()")
        regularRecording = false
        if status == .recording {
            stopAndSaveRecording()
        }
        super.abort()
    }
}
