//
//  ViewController.swift
//  FDSoundActivatedRecorder
//
//  Created by William Entriken on 1/30/16.
//  Copyright © 2016 William Entriken. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation
@testable import FDSoundActivatedRecorder


class ViewController: UIViewController {
    var recorder = FDSoundActivatedRecorderMock()
    var savedURL: URL? = nil
    var player = AVPlayer()
    
    /// Most recent are added to end
    var sampleSquares: [UIView] = []
    let sampleSize: CGFloat = 10.0
    
    func resetGraph() {
        sampleSquares.forEach { sampleSquare in
            sampleSquare.removeFromSuperview()
        }
        sampleSquares = []
    }
    
    @IBAction func pressedStartListening() {
        resetGraph()
        recorder.startListening()
    }
    
    @IBAction func pressedStartRecording() {
        resetGraph()
        recorder.startRecording()
    }
    
    @IBAction func pressedStopAndSaveRecording() {
        recorder.stopAndSaveRecording()
    }
    
    @IBAction func pressedAbort() {
        recorder.abort()
    }
    
    @IBAction func pressedPlayBack() {
        player = AVPlayer(url: savedURL!)
        player.play()
    }
    
    @IBOutlet weak var progressView: UIProgressView!
    
    @IBOutlet weak var microphoneLevel: UILabel!
    
    @IBOutlet weak var graph: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        recorder.delegate = self
        recorder.addObserver(self, forKeyPath: "microphoneLevel", options:.new, context: nil)
        recorder.intervalCallback = {currentLevel in self.drawSample(currentLevel: currentLevel)}
        recorder.microphoneLevelSilenceThreshold = -60
        
        let audioSession = AVAudioSession.sharedInstance()
        _ = try? audioSession.setCategory(AVAudioSession.Category(rawValue:AVAudioSession.Category.playAndRecord.rawValue))
        _ = try? audioSession.setActive(true)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch change![NSKeyValueChangeKey.newKey] {
        case let level as Float:
            progressView.progress = level
            microphoneLevel.text = String(format: "%0.2f", level)
        default:
            break
        }
    }
    
    func drawSample(currentLevel: Float) {
        print(String.init(format: "%0.3f", currentLevel));
        
        // Create the sample dot ///////////////////////////////////////////////
        let newSample = UIView();
        // Translate from [microphoneLevelSilenceThreshold, 0] to [0, 1]
        let valueScaled = CGFloat(1 - currentLevel / recorder.microphoneLevelSilenceThreshold)
        newSample.center = CGPoint(x: graph.frame.width, y: (1 - valueScaled) * graph.frame.height)
        newSample.bounds.size = CGSize(width: sampleSize, height: sampleSize)

        switch recorder.status {
        case .listening:
            newSample.backgroundColor = .black
            if recorder.averagingIntervals.count < recorder.listeningMinimumIntervals {
                newSample.backgroundColor = .init(red: 0, green: 0, blue: 0, alpha: 0.4)
            }
            if let triggerLevel = recorder.triggerLevel, currentLevel >= triggerLevel {
                newSample.backgroundColor = .white
            }
        case .recording:
            newSample.backgroundColor = .red
            if recorder.averagingIntervals.count < recorder.recordingMinimumIntervals {
                newSample.backgroundColor = .init(red: 1, green: 0, blue: 0, alpha: 0.4)
            }
            if let triggerLevel = recorder.triggerLevel, currentLevel <= triggerLevel {
                newSample.backgroundColor = .white
            }
        default:
            newSample.backgroundColor = .green
        }

        sampleSquares.append(newSample)
        graph.addSubview(newSample)
        
        // Create threshold dot //////////////////////////////////////////////////
        if let triggerLevel = recorder.triggerLevel {
            let newSample = UIView();
            let valueScaled = CGFloat(1 - triggerLevel / recorder.microphoneLevelSilenceThreshold)
            newSample.backgroundColor = .init(red: 1, green: 1, blue: 0, alpha: 0.4)
            newSample.center = CGPoint(x: graph.frame.width, y: (1 - valueScaled) * graph.frame.height)
            newSample.bounds.size = CGSize(width: sampleSize, height: sampleSize)
            sampleSquares.append(newSample)
            graph.addSubview(newSample)
        }
        
        // Scroll ///////////////////////////////////////////////////////////////
        for sampleSquare in sampleSquares {
            let animation = UIViewPropertyAnimator(duration: recorder.intervalSeconds, curve: .linear, animations: {
                sampleSquare.center.x -= CGFloat(self.sampleSize)
            })
            animation.startAnimation()
        }
        while let square = sampleSquares.first, !graph!.frame.contains(square.frame) {
            square.removeFromSuperview()
            sampleSquares.removeFirst()
        }
    }
}

extension ViewController: FDSoundActivatedRecorderDelegate {
    /// A recording was triggered or manually started
    func soundActivatedRecorderDidStartRecording(_ recorder: FDSoundActivatedRecorder) {
        progressView.progressTintColor = UIColor.red
    }
    
    /// No recording has started or been completed after listening for `TOTAL_TIMEOUT_SECONDS`
    func soundActivatedRecorderDidTimeOut(_ recorder: FDSoundActivatedRecorder) {
        progressView.progressTintColor = UIColor.blue
    }
    
    /// The recording and/or listening ended and no recording was captured
    func soundActivatedRecorderDidAbort(_ recorder: FDSoundActivatedRecorder) {
        progressView.progressTintColor = UIColor.blue
    }
    
    /// A recording was successfully captured
    func soundActivatedRecorderDidFinishRecording(_ recorder: FDSoundActivatedRecorder, andSaved file: URL) {
        progressView.progressTintColor = UIColor.blue
        savedURL = file
    }
}

class FDSoundActivatedRecorderMock: FDSoundActivatedRecorder {
    var intervalCallback: (Float)->() = {_ in}
    
    override func interval(currentLevel: Float) {
        self.intervalCallback(currentLevel);
        super.interval(currentLevel: currentLevel);
    }
    
    override init() {
        super.init();
    }
}
