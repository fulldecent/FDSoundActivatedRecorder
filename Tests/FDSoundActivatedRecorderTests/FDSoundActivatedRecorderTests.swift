//
//  FDSoundActivatedRecorderTests.swift
//  FDSoundActivatedRecorderTests
//
//  Created by Full Decent on 1/30/16.
//  Copyright © 2016 William Entriken. All rights reserved.
//

import XCTest
@testable import FDSoundActivatedRecorder

class FDSoundActivatedRecorderTests: XCTestCase {
    func testPropertyMicrophoneLevel() {
        let recorder = FDSoundActivatedRecorder()
        let expectedVolume: Float = 0.0
        XCTAssertEqual(recorder.microphoneLevel, expectedVolume, accuracy: 0.001)
    }
}

extension FDSoundActivatedRecorderTests {
    static var allTests = [
        ("testPropertyMicrophoneLevel", testPropertyMicrophoneLevel)
    ]
}
