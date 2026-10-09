import Testing
@testable import FDSoundActivatedRecorder

@Test func defaultTimeoutSeconds() {
    let recorder = FDSoundActivatedRecorder()
    #expect(recorder.config.timeoutSeconds == 10)
}
