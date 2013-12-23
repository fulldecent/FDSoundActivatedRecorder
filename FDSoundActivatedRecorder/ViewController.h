//
//  ViewController.h
//  FDSoundActivatedRecorder
//
//  Created by William Entriken on 12/22/13.
//  Copyright (c) 2013 William Entriken. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController
- (IBAction)startTapped:(id)sender;
- (IBAction)stopTapped:(id)sender;
- (IBAction)playBackTapped:(id)sender;
@property (weak, nonatomic) IBOutlet UIView *feedbackView;

@end
