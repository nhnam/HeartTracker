//
//  HTRBluetoothController.h
//  HeartTracker
//
//  Created by Zeke Shearer on 9/11/14.
//  Copyright (c) 2014 Zeke Shearer. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol HTRHeartRateControllerDelegate;

@interface HTRHeartRateController : NSObject

- (void)startMonitoringHeartRate;

@property (nonatomic, assign) id<HTRHeartRateControllerDelegate> delegate;

@end

@protocol HTRHeartRateControllerDelegate <NSObject>

- (void)heartRateController:(HTRHeartRateController *)heartRateController didUpdateHeartRate:(NSInteger)heartRate;

@end