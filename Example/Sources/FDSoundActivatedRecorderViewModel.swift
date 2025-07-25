//
//  FDSoundActivatedRecorderViewModel.swift
//  FDSoundActivatedRecorderViewModel-SwiftUI
//
//  Created by Engin BULANIK on 25.08.2020.
//  Copyright © 2020 William Entriken. All rights reserved.
//

import SwiftUI
import AVFoundation
import FDSoundActivatedRecorder

@MainActor
final class FDSoundActivatedRecorderViewModel: ObservableObject {

    // ─────────────────────────── UI STATE ──────────────────────────────
    @Published private(set) var savedURL: URL?          = nil
    @Published private(set) var sampleSquares: [Sample] = []
    @Published private(set) var progressBarLevel: CGFloat = 0
    @Published private(set) var progressTintColor: Color  = .blue
    @Published private(set) var microphoneLevelText       = "0.00"

    // Bar‑graph layout constants (unchanged)
    let graphSampleSize: CGFloat = 5
    let menuWidth: CGFloat       = 300

    // ─────────────────────────── Private ───────────────────────────────
    private let recorder: FDSoundActivatedRecorder
    private var player = AVPlayer()
    private var currentStatus: FDSoundActivatedRecorder.Status = .inactive

    // MARK: ‑ init
    init() {
        let cfg = FDSoundActivatedRecorder.Configuration()
            .with { $0.microphoneLevelSilenceThreshold = -60 }
        recorder = FDSoundActivatedRecorder(config: cfg)
        recorder.delegate = self                               // <‑‑ NEW API

        // Basic AVAudioSession prep (unchanged)
        let s = AVAudioSession.sharedInstance()
        _ = try? s.setCategory(.playAndRecord, mode: .default)
        _ = try? s.setActive(true)
    }

    // MARK: ‑ User actions --------------------------------------------------

    func pressedStartListening() {
        resetGraph()
        currentStatus      = .listening
        progressTintColor  = .yellow

        Task { await recorder.startListening() }
    }

    /// Stops everything immediately.
    func pressedAbort() {
        Task { await recorder.abort() }
    }

    func pressedPlay() {
        guard let url = savedURL else { return }
        player = AVPlayer(url: url)
        player.play()
    }

    // MARK: ‑ Helpers -------------------------------------------------------

    private func resetGraph() {
        sampleSquares.removeAll()
        progressBarLevel    = 0
        microphoneLevelText = "0.00"
    }

    /// Adds one bar to the waveform display.
    private func drawSample(from update: FDSoundActivatedRecorder.MeteringUpdate) {
        let level = update.level                                 // 0…1 already
        progressBarLevel    = CGFloat(level)
        microphoneLevelText = String(format: "%.2f", level)

        // Bar height is linear with loudness
        let barValue      = CGFloat(level)
        let thresholdVal  = CGFloat(update.triggerLevel ?? 0)

        // Colour logic (simplified but keeps old spirit)
        var colour: Color
        switch currentStatus {
        case .listening:
            if update.averagingCount < recorder.config.listeningMinimumIntervals {
                colour = .gray
            } else if let t = update.triggerLevel, level >= t {
                colour = .purple
            } else {
                colour = .yellow
            }
        case .saving:
            if update.averagingCount < recorder.config.savingMinimumIntervals {
                colour = .orange
            } else if let t = update.triggerLevel, level <= t {
                colour = .blue
            } else {
                colour = .red
            }
        case .inactive:
            colour = .green
        }

        sampleSquares.append(
            Sample(color: colour,
                   value: barValue,
                   thresholdColor: update.triggerLevel == nil ? .clear : .cyan,
                   thresholdValue: thresholdVal)
        )
    }
}

// MARK: ‑ Recorder delegate --------------------------------------------------

extension FDSoundActivatedRecorderViewModel: FDSoundActivatedRecorder.Delegate {

    func recorderDidStartSaving(_ r: FDSoundActivatedRecorder) {
        currentStatus     = .saving
        progressTintColor = .red
    }

    func recorderDidFinishSaving(_ r: FDSoundActivatedRecorder) {
        // File still exporting; leave tint red so the user knows it’s busy
    }

    func recorderDidSaveFile(_ r: FDSoundActivatedRecorder, to url: URL) {
        currentStatus      = .inactive
        progressTintColor  = .blue
        progressBarLevel   = 0
        microphoneLevelText = "0.00"
        savedURL = url
    }

    func recorderDidTimeOut(_ r: FDSoundActivatedRecorder) {
        currentStatus      = .inactive
        progressTintColor  = .blue
    }

    func recorderDidAbort(_ r: FDSoundActivatedRecorder) {
        currentStatus      = .inactive
        progressTintColor  = .blue
        resetGraph()
    }

    func recorder(_ r: FDSoundActivatedRecorder,
                  didReceiveMetering update: FDSoundActivatedRecorder.MeteringUpdate) {
        drawSample(from: update)
    }
}

// MARK: ‑ Sample model (unchanged) ------------------------------------------

struct Sample: Identifiable {
    let id = UUID()
    let color: Color
    let value: CGFloat
    let thresholdColor: Color
    let thresholdValue: CGFloat
}
