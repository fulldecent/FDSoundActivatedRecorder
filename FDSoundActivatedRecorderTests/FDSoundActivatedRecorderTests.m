//
//  FDSoundActivatedRecorderTests.m
//  FDSoundActivatedRecorderTests
//
//  Created by William Entriken on 12/22/13.
//  Copyright (c) 2013 William Entriken. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FDSoundActivatedRecorder.h"

@interface FDSoundActivatedRecorderTests : XCTestCase

@end

@implementation FDSoundActivatedRecorderTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testPropertyMicrophoneLevel
{
    FDSoundActivatedRecorder *recorder = [[FDSoundActivatedRecorder alloc] init];
    NSNumber *magicValue = @(0.667);
    recorder.microphoneLevel = magicValue;
    XCTAssertEqualObjects(recorder.microphoneLevel, magicValue, @"Problem setting property %s", __PRETTY_FUNCTION__);
}

- (void)testPropertyRecordedDuration
{
    FDSoundActivatedRecorder *recorder = [[FDSoundActivatedRecorder alloc] init];
    XCTAssertTrue([recorder respondsToSelector:@selector(recordedDuration)], @"Problem reading property %s", __PRETTY_FUNCTION__);
}

- (void)testPropertyRecordedFilePath
{
    FDSoundActivatedRecorder *recorder = [[FDSoundActivatedRecorder alloc] init];
    XCTAssertTrue([recorder respondsToSelector:@selector(recordedFilePath)], @"Problem reading property %s", __PRETTY_FUNCTION__);
}

- (void)testPropertyDelegate
{
    FDSoundActivatedRecorder *recorder = [[FDSoundActivatedRecorder alloc] init];
    XCTAssertTrue([recorder respondsToSelector:@selector(delegate)], @"Problem reading property %s", __PRETTY_FUNCTION__);
}

@end
