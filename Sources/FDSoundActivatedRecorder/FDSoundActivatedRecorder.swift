//
//  FDSoundActivatedRecorder.swift
//  FDSoundActivatedRecorder
//
//  Created by William Entriken on 1/28/16.
//  Copyright © William Entriken
//

import Foundation
import AVFoundation
import CoreMedia

/*
 * HOW RECORDING WORKS
 *
 * V
 * O                 /-----------\
 * L                /             \
 * U          Rise /               \ Fall
 * M              /                 \
 * E  -----------/                   \-----------
 *
 *       Quiet   |   Recorded file   |   Quiet
 *
 * We listen and save audio levels every `INTERVAL`
 * When several consecutive levels exceed the recent moving average by a threshold, we save
 * (The exceeding levels are not included in the moving average)
 * When several consecutive levels deceed the recent moving average by a threshold, we stop saving
 * (The deceeding levels are not included in the moving average)
 *
 * The final recording includes RISE, SAVING, and FALL sections and the RISE and FALL
 * parts are faded in and out to avoid clicking sounds at either end, you're welcome!
 *
 * Our "averages" are time averages of log squared power, an odd definition
 * SEE: Averaging logs https://physics.stackexchange.com/questions/46228/averaging-decibels
 */

public actor FDSoundActivatedRecorder {

    // MARK: – Nested types ---------------------------------------------------

    public struct Configuration: Sendable {
        public var timeoutSeconds:                Double = 10
        public var intervalSeconds:               Double = 0.05
        public var listeningMinimumIntervals:     Int    = 2
        public var listeningAveragingIntervals:   Int    = 7
        public var riseTriggerDecibel:            Float  = 13          // dB above average to start saving
        public var riseTriggerIntervals:          Int    = 2
        public var savingMinimumIntervals:        Int    = 4
        public var savingAveragingIntervals:      Int    = 15
        public var fallTriggerDecibel:            Float  = 10          // dB below average to stop saving
        public var fallTriggerIntervals:          Int    = 2
        public var savingSamplesPerSecond:        Int    = 22_050
        public var microphoneLevelSilenceThreshold: Float = -44        // dB
        public init() {}
        public func with(_ mutate: (inout Self) -> Void) -> Self {
            var c = self; mutate(&c); return c
        }
    }

    public enum Status: Sendable {
        case inactive
        case listening  // provides metering
        case saving     // actively capturing samples (old “recording”)
    }

    // MARK: – Delegate -------------------------------------------------------

    @MainActor
    public protocol Delegate: AnyObject {
        /// Called the moment audio capture begins
        func recorderDidStartSaving(_ recorder: FDSoundActivatedRecorder)

        /// Called immediately after capture stops (file not yet written)
        func recorderDidFinishSaving(_ recorder: FDSoundActivatedRecorder)

        /// Called when the file has been exported to disk
        func recorderDidSaveFile(_ recorder: FDSoundActivatedRecorder, to url: URL)

        /// Listening ended without ever starting to save
        func recorderDidTimeOut(_ recorder: FDSoundActivatedRecorder)

        /// Anything aborted the process and no output is produced
        func recorderDidAbort(_ recorder: FDSoundActivatedRecorder)

        /// Metering callback every `intervalSeconds`
        func recorder(_ recorder: FDSoundActivatedRecorder,
                      didReceiveMetering update: FDSoundActivatedRecorder.MeteringUpdate)
    }

    public struct MeteringUpdate: Sendable {
        /// Scaled microphone power in the range 0 (silence) … 1 (max)
        public let level: Float
        /// Scaled trigger level in the same 0…1 range; `nil` if not yet calculated
        public let triggerLevel: Float?
        /// Number of values currently in the moving‑average window
        public let averagingCount: Int
    }

    // MARK: – Public interface ----------------------------------------------

    public nonisolated let config: Configuration
    public nonisolated(unsafe) weak var delegate: Delegate?
    public private(set) var status: Status = .inactive

    public init(config: Configuration = .init()) {
        self.config = config

        // scratch directory & recorder
        scratchDir  = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: scratchDir,
                                                 withIntermediateDirectories: true)

        recordedURL = scratchDir.appendingPathComponent("raw.caf")
        recorder = try? AVAudioRecorder(url: recordedURL, settings: [
            AVSampleRateKey:           config.savingSamplesPerSecond,
            AVFormatIDKey:             kAudioFormatLinearPCM,
            AVNumberOfChannelsKey:     1,
            AVLinearPCMIsFloatKey:     false,
            AVEncoderAudioQualityKey:  AVAudioQuality.max.rawValue
        ])
        recorder?.isMeteringEnabled = true
    }

    deinit {
        monitorTask?.cancel()
        recorder?.stop()
        try? FileManager.default.removeItem(at: scratchDir)
    }

    /// Begin listening; capture will start automatically when the rise‑trigger is met.
    public func startListening() {
        monitorTask?.cancel()
        status = .listening
        prepareSession()
        recorder?.record(forDuration: config.timeoutSeconds)

        averaging.removeAll()
        triggerCount = 0
        triggerLevel = nil

        startMonitorLoop()
    }

    /// Cancel everything immediately and clean up.
    public func abort() {
        monitorTask?.cancel()
        recorder?.stop()
        status = .inactive
        Task { @MainActor in delegate?.recorderDidAbort(self) }
    }

    // MARK: – Private properties ---------------------------------------------

    private let scratchDir: URL
    private let recordedURL: URL
    private var recorder: AVAudioRecorder?
    private var monitorTask: Task<Void, Never>?

    private var triggerLevel: Float?
    private var triggerCount = 0
    private var averaging: [Float] = []
    private var savingBegin = CMTime.zero
    private var savingEnd   = CMTime.zero

    // MARK: – Session / monitor ----------------------------------------------

    private func prepareSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? s.setActive(true)
    }

    private func startMonitorLoop() {
        let millis = Int(config.intervalSeconds * 1_000)

        monitorTask = Task {
            while true {
                try? await Task.sleep(for: .milliseconds(millis))
                guard let recorder = await self.recorder else { continue }

                await recorder.updateMeters()

                // Timed‑out while listening and never started saving
                if !recorder.isRecording {
                    if await self.status == .listening {
                        await self.finishByTimeout()
                    }
                    break
                }

                let level = recorder.averagePower(forChannel: 0)
                await self.handleInterval(level)
            }
        }
    }

    // MARK: – Interval processing --------------------------------------------

    private func handleInterval(_ rawLevel: Float) async {
        // Convert dB (negative) to 0…1 scale for the delegate
        let scaled = scale(rawLevel)
        let scaledTrigger = triggerLevel.map(scale)
        let averagingCount = averaging.count

        await MainActor.run {
            delegate?.recorder(
                self,
                didReceiveMetering: MeteringUpdate(level: scaled,
                                                   triggerLevel: scaledTrigger,
                                                   averagingCount: averagingCount)
            )
        }

        switch status {

        // ----------------------------- LISTENING -----------------------------
        case .listening:
            if averaging.count >= config.listeningMinimumIntervals {
                triggerLevel = averaging.reduce(0, +) / Float(averaging.count)
                              + config.riseTriggerDecibel
            }
            if let t = triggerLevel, rawLevel >= t {
                triggerCount += 1
                if triggerCount >= config.riseTriggerIntervals { startSaving() }
            } else {
                triggerCount = 0
                averaging.append(rawLevel)
                averaging.trim(to: config.listeningAveragingIntervals)
            }

        // ------------------------------ SAVING ------------------------------
        case .saving:
            if averaging.count >= config.savingMinimumIntervals {
                triggerLevel = averaging.reduce(0, +) / Float(averaging.count)
                              - config.fallTriggerDecibel
            }
            if let t = triggerLevel, rawLevel <= t {
                triggerCount += 1
                if triggerCount >= config.fallTriggerIntervals { stopSaving() }
            } else {
                triggerCount = 0
                averaging.append(rawLevel)
                averaging.trim(to: config.savingAveragingIntervals)
            }

        // --------------------------------------------------------------------
        case .inactive:
            break
        }
    }

    // MARK: – State transitions ----------------------------------------------

    /// Transition from listening → saving
    private func startSaving() {
        guard status == .listening else { return }

        status = .saving
        Task { @MainActor in delegate?.recorderDidStartSaving(self) }

        let offset   = Double(config.riseTriggerIntervals) * config.intervalSeconds
        let beginSec = max(0.0, (recorder?.currentTime ?? 0) - offset)

        savingBegin = CMTime(seconds: beginSec,
                             preferredTimescale: CMTimeScale(config.savingSamplesPerSecond))

        // Reset windows for “fall” detection
        averaging.removeAll()
        triggerCount = 0
        triggerLevel = nil
    }

    /// Transition from saving → finished (file export still pending)
    private func stopSaving() {
        guard status == .saving else { return }

        monitorTask?.cancel()          // stop the metering loop
        status = .inactive

        savingEnd = CMTime(seconds: recorder?.currentTime ?? 0,
                           preferredTimescale: CMTimeScale(config.savingSamplesPerSecond))

        recorder?.stop()

        Task { @MainActor in delegate?.recorderDidFinishSaving(self) }
        Task { await self.exportAndSave() }
    }

    /// Called when the timeout expires with no capture
    private func finishByTimeout() async {
        recorder?.stop()
        status = .inactive
        await MainActor.run { delegate?.recorderDidTimeOut(self) }
    }

    // MARK: – Export ----------------------------------------------------------

    private func exportAndSave() async {
        let outURL = scratchDir.appendingPathComponent("\(UUID().uuidString).m4a")

        guard let track = AVAsset(url: recordedURL)
                .tracks(withMediaType: .audio).first,
              let export = AVAssetExportSession(asset: AVAsset(url: recordedURL),
                                                presetName: AVAssetExportPresetAppleM4A) else {
            await MainActor.run { delegate?.recorderDidAbort(self) }
            return
        }

        // Fade‑in/out ranges
        let fadeInDur = CMTime(seconds: Double(config.riseTriggerIntervals) * config.intervalSeconds,
                               preferredTimescale: CMTimeScale(config.savingSamplesPerSecond))
        let fadeOutDur = CMTime(seconds: Double(config.fallTriggerIntervals) * config.intervalSeconds,
                                preferredTimescale: CMTimeScale(config.savingSamplesPerSecond))

        let mix      = AVMutableAudioMix()
        let params   = AVMutableAudioMixInputParameters(track: track)
        params.setVolumeRamp(fromStartVolume: 0, toEndVolume: 1,
                             timeRange: CMTimeRange(start: savingBegin,
                                                    duration: fadeInDur))
        params.setVolumeRamp(fromStartVolume: 1, toEndVolume: 0,
                             timeRange: CMTimeRange(start: CMTimeSubtract(savingEnd, fadeOutDur),
                                                    duration: fadeOutDur))
        mix.inputParameters = [params]

        export.outputURL      = outURL
        export.outputFileType = .m4a
        export.timeRange      = CMTimeRange(start: savingBegin, end: savingEnd)
        export.audioMix       = mix

        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            export.exportAsynchronously { c.resume() }
        }

        await MainActor.run { delegate?.recorderDidSaveFile(self, to: outURL) }
    }

    // MARK: – Helpers ---------------------------------------------------------

    /// Convert raw dB power to 0 … 1 range using `microphoneLevelSilenceThreshold`
    private func scale(_ level: Float) -> Float {
        if level >= 0                 { return 1 }
        if level <= config.microphoneLevelSilenceThreshold { return 0 }
        return 1 - level / config.microphoneLevelSilenceThreshold
    }
}

// MARK: – Array helper -------------------------------------------------------

private extension Array {
    mutating func trim(to maxCount: Int) {
        if count > maxCount { removeFirst(count - maxCount) }
    }
}

// MARK: – Default delegate implementations ----------------------------------

public extension FDSoundActivatedRecorder.Delegate {
    func recorderDidStartSaving(_ recorder: FDSoundActivatedRecorder) {}
    func recorderDidFinishSaving(_ recorder: FDSoundActivatedRecorder) {}
    func recorderDidSaveFile(_ recorder: FDSoundActivatedRecorder, to url: URL) {}
    func recorderDidTimeOut(_ recorder: FDSoundActivatedRecorder) {}
    func recorderDidAbort(_ recorder: FDSoundActivatedRecorder) {}
    func recorder(_ recorder: FDSoundActivatedRecorder,
                  didReceiveMetering update: FDSoundActivatedRecorder.MeteringUpdate) {}
}
