//
//  FDSoundActivatedRecorderTests.swift
//  FDSoundActivatedRecorderTests
//
//  Created by William Entriken on 1/30/16.
//  Copyright © 2016 William Entriken. All rights reserved.
//

import XCTest
@testable import FDSoundActivatedRecorder

final class FDSoundActivatedRecorderTests: XCTestCase {
    func testPropertyMicrophoneLevel() {
        let recorder = FDSoundActivatedRecorder()
        let expectedVolume: Float = 0.0
        XCTAssertEqual(recorder.microphoneLevel, expectedVolume)
    }
    
    static var allTests = [
        ("testPropertyMicrophoneLevel", testPropertyMicrophoneLevel),
    ]
}
