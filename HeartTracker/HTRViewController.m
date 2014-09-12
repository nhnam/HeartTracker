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

@property (nonatomic, strong) HTRHeartRateController *heartRateController;

@end

@implementation HTRViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.heartRateController = [[HTRHeartRateController alloc] init];
    self.heartRateController.delegate = self;
    [self.heartRateController startMonitoringHeartRate];
	// Do any additional setup after loading the view, typically from a nib.
}

#pragma mark - HeartRateController Delegate

- (void)heartRateController:(HTRHeartRateController *)heartRateController didUpdateHeartRate:(NSInteger)heartRate
{
    self.heartRateLabel.text = [NSString stringWithFormat:@"%li", (long)heartRate];
}































































@end
