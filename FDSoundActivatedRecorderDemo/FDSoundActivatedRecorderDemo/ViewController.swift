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
import FDSoundActivatedRecorder

class ViewController: UIViewController {
    var recorder = FDSoundActivatedRecorder()
    var savedURL: URL? = nil
    var player = AVPlayer()
    
    @IBAction func pressedStartListening() {
        recorder.startListening()
    }
    
    @IBAction func pressedStartRecording() {
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        recorder.delegate = self
        recorder.addObserver(self, forKeyPath: "microphoneLevel", options:.new, context: nil)
        
        let audioSession = AVAudioSession.sharedInstance()
        _ = try? audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
        _ = try? audioSession.setActive(true)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch change![NSKeyValueChangeKey.newKey] {
        case let level as Double:
            progressView.progress = Float(level)
            microphoneLevel.text = String(format: "%0.2f", level)
        default:
            break
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