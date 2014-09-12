//
//  HTRViewController.m
//  HeartTracker
//
//  Created by Zeke Shearer on 9/11/14.
//  Copyright (c) 2014 Zeke Shearer. All rights reserved.
//

#import "HTRViewController.h"
#import "HTRHeartRateController.h"

@interface HTRViewController () <HTRHeartRateControllerDelegate>

@property (weak, nonatomic) IBOutlet UILabel *heartRateLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UIImageView *heartView;

@property (nonatomic, strong) HTRHeartRateController *heartRateController;
@property (nonatomic, strong) NSTimer *pulseTimer;
@property (nonatomic, assign) NSInteger heartRate;

@end

#define PULSESCALE 1.2
#define PULSEDURATION 0.2

@implementation HTRViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.heartRateController = [[HTRHeartRateController alloc] init];
    self.heartRateController.delegate = self;
    [self.heartRateController startMonitoringHeartRate];

    
    
}

#pragma mark - HeartRateController Delegate

- (void)heartRateController:(HTRHeartRateController *)heartRateController didUpdateHeartRate:(NSInteger)heartRate
{
    self.heartRateLabel.text = [NSString stringWithFormat:@"%li", (long)heartRate];
    self.heartRate = heartRate;
    if ( !self.pulseTimer ) {
        [self pulse];
    }
}

- (void)heartRateControllerDidStartUpdates:(HTRHeartRateController *)heartRateController
{
    [self.activityIndicator stopAnimating];
}





#pragma mark - Animation Methods

- (void)pulse
{
    CABasicAnimation *pulseAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    
    pulseAnimation.toValue = [NSNumber numberWithFloat:PULSESCALE];
    pulseAnimation.fromValue = [NSNumber numberWithFloat:1.0];
    
    pulseAnimation.duration = PULSEDURATION;
    pulseAnimation.repeatCount = 1;
    pulseAnimation.autoreverses = YES;
    pulseAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    
    [[self.heartView layer] addAnimation:pulseAnimation forKey:@"scale"];
    
    self.pulseTimer = [NSTimer scheduledTimerWithTimeInterval:(60. / self.heartRate) target:self selector:@selector(pulse) userInfo:nil repeats:NO];
}





















































@end
