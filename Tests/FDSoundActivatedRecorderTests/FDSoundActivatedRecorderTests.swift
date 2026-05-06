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
    func testDefaultTimeoutSeconds() {
        let recorder = FDSoundActivatedRecorder()
        XCTAssertEqual(recorder.config.timeoutSeconds, 10)
    }
}
