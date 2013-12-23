//
//  ViewController.m
//  FDSoundActivatedRecorder
//
//  Created by William Entriken on 12/22/13.
//  Copyright (c) 2013 William Entriken. All rights reserved.
//

#import "ViewController.h"
#import "FDSoundActivatedRecorder.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController () <FDSoundActivatedRecorderDelegate>
@property FDSoundActivatedRecorder *recorder;
@property AVAudioPlayer *player;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.feedbackView.backgroundColor = [UIColor grayColor];
    self.recorder = [[FDSoundActivatedRecorder alloc] init];
    self.recorder.delegate = self;
}

- (IBAction)startTapped:(id)sender {
    self.feedbackView.backgroundColor = [UIColor greenColor];
    [self.recorder startListening];
}

- (IBAction)stopTapped:(id)sender {
    self.feedbackView.backgroundColor = [UIColor grayColor];
    [self.recorder stopListeningAndKeepRecordingIfInProgress:NO];
}

- (IBAction)playBackTapped:(id)sender {
    NSURL *url = [NSURL fileURLWithPath:self.recorder.recordedFilePath];
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    [self.player play];
}

- (void)soundActivatedRecorderDidStartRecording:(FDSoundActivatedRecorder *)recorder
{
    self.feedbackView.backgroundColor = [UIColor redColor];
}

- (void)soundActivatedRecorderDidStopRecording:(FDSoundActivatedRecorder *)recorder andSavedSound:(BOOL)didSave
{
    self.feedbackView.backgroundColor = [UIColor grayColor];
}

@end
