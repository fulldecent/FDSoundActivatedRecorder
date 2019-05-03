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
    var totalSamples = 0
    let sampleSize: CGFloat = 10.0
    var listeningIntervals = [Float]()
    var listeningHighLow: UIView? = nil
    var listeningAverage: UIView? = nil
    var triggerCount = 0
    
    func resetGraph() {
        sampleSquares.forEach { sampleSquare in
            sampleSquare.removeFromSuperview()
        }
        sampleSquares = []
        totalSamples = 0
        listeningHighLow?.removeFromSuperview()
        listeningAverage?.removeFromSuperview()
        listeningHighLow = UIView()
        listeningHighLow!.backgroundColor = .init(displayP3Red: 0.9, green: 0.9, blue: 0.3, alpha: 0.4)
        listeningHighLow!.frame = CGRect.zero
        graph!.addSubview(listeningHighLow!)
        listeningAverage = UIView()
        listeningAverage!.backgroundColor = .init(displayP3Red: 0.3, green: 0.5, blue: 0.3, alpha: 0.6)
        listeningAverage!.frame = CGRect.zero
        graph!.addSubview(listeningAverage!)
        listeningIntervals = []
        triggerCount = 0

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
        
        // Translate from [microphoneLevelSilenceThreshold, 0] to [0, 1]
        let valueScaled = CGFloat((currentLevel - recorder.microphoneLevelSilenceThreshold) / -recorder.microphoneLevelSilenceThreshold)
        
        // Handle the dots ////////////////////////////////////////////////////////////////////
        let newSample = UIView();
        newSample.backgroundColor = totalSamples < recorder.listeningMinimumIntervals ? .black : .darkGray
        newSample.center = CGPoint(x: graph.frame.width, y: (1 - valueScaled) * graph.frame.height)
        newSample.bounds.size = CGSize(width: sampleSize, height: sampleSize)
        
        sampleSquares.append(newSample)
        graph.addSubview(newSample)
        
        // Handle listening threshold dot ////////////////////////////////////////////////////////////////
        if recorder.status == .listening {
            let listeningAverageLevel = listeningIntervals.reduce(0.0, +) / Float(listeningIntervals.count)
            if listeningIntervals.count >= recorder.listeningMinimumIntervals {
                let threshold = Float(listeningAverageLevel + recorder.riseTriggerDb)
                let valueScaled = CGFloat((threshold - recorder.microphoneLevelSilenceThreshold) / -recorder.microphoneLevelSilenceThreshold)
                let newSample = UIView();
                newSample.backgroundColor = .orange
                newSample.center = CGPoint(x: graph.frame.width, y: (1 - valueScaled) * graph.frame.height)
                newSample.bounds.size = CGSize(width: sampleSize, height: sampleSize)
                sampleSquares.append(newSample)
                graph.addSubview(newSample)
            }
            
            if listeningIntervals.count >= recorder.listeningMinimumIntervals && currentLevel >= listeningAverageLevel + recorder.riseTriggerDb {
                triggerCount += 1
                newSample.backgroundColor = .red
                let animation = UIViewPropertyAnimator(duration: recorder.intervalSeconds, curve: .linear, animations: {
                    self.listeningAverage?.center.x -= CGFloat(self.sampleSize)
                })
                animation.startAnimation()
                let animation2 = UIViewPropertyAnimator(duration: recorder.intervalSeconds, curve: .linear, animations: {
                    self.listeningHighLow?.center.x -= CGFloat(self.sampleSize)
                })
                animation2.startAnimation()
            } else {
                triggerCount = 0
                //TODO undo show all red
                listeningIntervals.append(currentLevel)
                if listeningIntervals.count > recorder.listeningAveragingIntervals {
                    listeningIntervals.remove(at: 0)
                }
                let newListeningAverageLevel = listeningIntervals.reduce(0.0, +) / Float(listeningIntervals.count)
                let newListeningMinLevel = listeningIntervals.reduce(Float.infinity, {a, b in min(a,b)})
                let newListeningMaxLevel = listeningIntervals.reduce(-Float.infinity, {a, b in max(a,b)})
                let maxScaled: CGFloat = CGFloat(1.0 - newListeningMaxLevel / recorder.microphoneLevelSilenceThreshold)
                let minScaled: CGFloat = CGFloat(1.0 - newListeningMinLevel / recorder.microphoneLevelSilenceThreshold)
                let avgScaled: CGFloat = CGFloat(1.0 - newListeningAverageLevel / recorder.microphoneLevelSilenceThreshold)
                listeningAverage?.center = CGPoint(x: graph.frame.width - sampleSize * CGFloat(recorder.listeningAveragingIntervals-1) / 2.0,
                                                   y: (1 - avgScaled) * graph.frame.height)
                listeningAverage?.bounds.size = CGSize(width: sampleSize * CGFloat(recorder.listeningAveragingIntervals),
                                                       height: sampleSize)
                listeningHighLow?.center = CGPoint(x: graph.frame.width - sampleSize * CGFloat(recorder.listeningAveragingIntervals-1) / 2.0,
                                                   y: (1 - minScaled - (maxScaled-minScaled)/2) * graph.frame.height)
                listeningHighLow?.bounds.size = CGSize(width: sampleSize * CGFloat(recorder.listeningAveragingIntervals),
                                                       height: (maxScaled - minScaled) * graph.frame.height)
                let animation = UIViewPropertyAnimator(duration: recorder.intervalSeconds, curve: .linear, animations: {
                    self.listeningAverage?.center.x -= CGFloat(self.sampleSize)
                })
                animation.startAnimation()
                let animation2 = UIViewPropertyAnimator(duration: recorder.intervalSeconds, curve: .linear, animations: {
                    self.listeningHighLow?.center.x -= CGFloat(self.sampleSize)
                })
                animation2.startAnimation()
            }
            if triggerCount >= recorder.riseTriggerIntervals {
                // startRecording()
            }
            
            /*
  */
            /*
            let y = (1 - avgScaled - CGFloat(sampleSize) / 2) * graph.frame.size.height
            listeningAverage!.frame = CGRect(x: CGFloat(graph!.frame.width - CGFloat(sampleSize) * CGFloat(recorder.listeningAveragingIntervals)),
                                             y: y,
                                             width: CGFloat(sampleSize * recorder.listeningAveragingIntervals),
                                             height: sampleSize)
 */
            // Calculate average
        } else if recorder.status == .recording {
            newSample.backgroundColor = .blue
            let animation = UIViewPropertyAnimator(duration: recorder.intervalSeconds, curve: .linear, animations: {
                self.listeningAverage?.center.x -= CGFloat(self.sampleSize)
            })
            animation.startAnimation()
            let animation2 = UIViewPropertyAnimator(duration: recorder.intervalSeconds, curve: .linear, animations: {
                self.listeningHighLow?.center.x -= CGFloat(self.sampleSize)
            })
            animation2.startAnimation()

        }
   

        sampleSquares.forEach { (sampleSquare) in
            let animation = UIViewPropertyAnimator(duration: recorder.intervalSeconds, curve: .linear, animations: {
                sampleSquare.center.x -= CGFloat(self.sampleSize)
            })
            animation.startAnimation()
        }
        while let square = sampleSquares.first, !graph!.frame.contains(square.frame) {
            square.removeFromSuperview()
            sampleSquares.removeFirst()
        }
        
        totalSamples += 1
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
