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
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testPropertyMicrophoneLevel() {
        let recorder = FDSoundActivatedRecorder()
        let expectedVolume = 0.0
        XCTAssertEqual(recorder.microphoneLevel, expectedVolume)
    }
}
