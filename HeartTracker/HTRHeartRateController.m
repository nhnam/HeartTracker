//
//  HTRBluetoothController.m
//  HeartTracker
//
//  Created by Zeke Shearer on 9/11/14.
//  Copyright (c) 2014 Zeke Shearer. All rights reserved.
//

#import "HTRHeartRateController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <HealthKit/HealthKit.h>

@interface HTRHeartRateController () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, strong) NSMutableArray *heartRateMonitors;
@property (nonatomic, strong) CBCentralManager *manager;
@property (nonatomic, strong) CBPeripheral *peripheral;

@property (nonatomic, strong) HKHealthStore *healthStore;
@property (nonatomic, assign) NSInteger location;
@property (nonatomic, assign, readwrite) BOOL shouldSave;
@property (strong, nonatomic) NSDate *lastSaveDate;

@end

#define HTRUPDATE_INTERVAL 10

@implementation HTRHeartRateController

- (void)startMonitoringHeartRate
{
    self.heartRateMonitors = [NSMutableArray array];
    self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    self.healthStore = [[HKHealthStore alloc] init];
    [self.healthStore requestAuthorizationToShareTypes:[NSSet setWithObject:[HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate]] readTypes:[NSSet set] completion:^(BOOL success, NSError *error) {
        self.shouldSave = success;
    }];
}

#pragma mark - Start/Stop Scan methods

// Use CBCentralManager to check whether the current platform/hardware supports Bluetooth LE.
- (BOOL)isLECapableHardware
{
    NSString *state;
    switch ( [self.manager state] ) {
        case CBCentralManagerStateUnsupported:
            state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"The app is not authorized to use Bluetooth Low Energy.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            break;
        case CBCentralManagerStatePoweredOn:
            NSLog(@"Start Scan");
            [self startScan];
            return TRUE;
        case CBCentralManagerStateUnknown:
        default:
            return FALSE;
    }
    NSLog(@"Central manager state: %@", state);
    return FALSE;
}

// Request CBCentralManager to scan for heart rate peripherals using service UUID 0x180D
- (void)startScan
{
    [self.manager scanForPeripheralsWithServices:[NSArray arrayWithObject:[CBUUID UUIDWithString:@"180D"]] options:nil];
}

// Request CBCentralManager to stop scanning for heart rate peripherals
- (void) stopScan
{
    [self.manager stopScan];
}

#pragma mark - CBCentralManager delegate methods

// Invoked when the central manager's state is updated.
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    [self isLECapableHardware];
}

// Invoked when the central discovers heart rate peripheral while scanning.
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)aPeripheral advertisementData: (NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSMutableArray *peripherals = [self mutableArrayValueForKey:@"heartRateMonitors"];
    if ( ![self.heartRateMonitors containsObject:aPeripheral] ) {
        [peripherals addObject:aPeripheral];
        [self.manager connectPeripheral:aPeripheral options:[NSDictionary dictionaryWithObject:@YES forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
    } else {
        [self.manager retrievePeripheralsWithIdentifiers:@[aPeripheral.identifier]];
    }
}

// Invoked when the central manager retrieves the list of known peripherals.
// Automatically connect to first known peripheral
- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals
{
    NSLog(@"Retrieved peripheral: %lu - %@", (unsigned long)[peripherals count], peripherals);
    [self stopScan];
    // If there are any known devices, automatically connect to it.
    if ( [peripherals count] >= 1 ) {
        self.peripheral = [peripherals objectAtIndex:0];
        [self.manager connectPeripheral:self.peripheral options:[NSDictionary dictionaryWithObject:@YES forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
    }
}

// Invoked when a connection is succesfully created with the peripheral.
// Discover available services on the peripheral
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)aPeripheral
{
    NSLog(@"connected");
    self.peripheral = aPeripheral;
    [aPeripheral setDelegate:self];
    [aPeripheral discoverServices:nil];
}

// Invoked when an existing connection with the peripheral is torn down.
// Reset local variables
- (void) centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
    if ( self.peripheral ) {
        [self.peripheral setDelegate:nil];
        self.peripheral = nil;
    }
}

// Invoked when the central manager fails to create a connection with the peripheral.
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
    NSLog(@"Fail to connect to peripheral: %@ with error = %@", aPeripheral, [error localizedDescription]);
    if ( self.peripheral ) {
        [self.peripheral setDelegate:nil];
        self.peripheral = nil;
    }
}

#pragma mark - CBPeripheral delegate methods

// Invoked upon completion of a -[discoverServices:] request.
// Discover available characteristics on interested services
- (void)peripheral:(CBPeripheral *)aPeripheral didDiscoverServices:(NSError *)error
{
    for ( CBService *aService in aPeripheral.services ) {
        NSLog(@"Service found with UUID: %@", aService.UUID);
        
        /* Heart Rate Service */
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:@"180D"]]) {
            [aPeripheral discoverCharacteristics:nil forService:aService];
        }
        
        /* Device Information Service */
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:@"180A"]]) {
            [aPeripheral discoverCharacteristics:nil forService:aService];
        }
    }
}

// Invoked upon completion of a -[discoverCharacteristics:forService:] request.
// Perform appropriate operations on interested characteristics
- (void) peripheral:(CBPeripheral *)aPeripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if ( [service.UUID isEqual:[CBUUID UUIDWithString:@"180D"]] ) {
        for ( CBCharacteristic *aChar in service.characteristics ) {
            // Set notification on heart rate measurement
            if ( [aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A37"]] ) {
                [self.peripheral setNotifyValue:YES forCharacteristic:aChar];
                NSLog(@"Found a Heart Rate Measurement Characteristic");
            }
            
            // Read body sensor location
            if ( [aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A38"]] ) {
                [aPeripheral readValueForCharacteristic:aChar];
                NSLog(@"Found a Body Sensor Location Characteristic");
            }
            
            // Write heart rate control point
            if ( [aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A39"]] ) {
                uint8_t val = 1;
                NSData* valData = [NSData dataWithBytes:(void*)&val length:sizeof(val)];
                [aPeripheral writeValue:valData forCharacteristic:aChar type:CBCharacteristicWriteWithResponse];
            }
        }
    }
    
    if ( [service.UUID isEqual:[CBUUID UUIDWithString:@"180A"]] ) {
        for ( CBCharacteristic *aChar in service.characteristics ) {
            // Read manufacturer name
            if ( [aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A29"]] ) {
                [aPeripheral readValueForCharacteristic:aChar];
                NSLog(@"Found a Device Manufacturer Name Characteristic");
            }
        }
    }
}

// Update UI with heart rate data received from device
- (void)updateWithHRMData:(NSData *)data
{
    const uint8_t *reportData = [data bytes];
    uint16_t bpm = 0;
    
    if ((reportData[0] & 0x01) == 0) {
        // uint8 bpm
        bpm = reportData[1];
    } else {
        // uint16 bpm
        bpm = CFSwapInt16LittleToHost(*(uint16_t *)(&reportData[1]));
    }
    NSLog(@"bpm %d", bpm);
    [self.delegate heartRateController:self didUpdateHeartRate:bpm];
    
    if ( self.shouldSave && (!self.lastSaveDate || abs([self.lastSaveDate timeIntervalSinceNow]) > HTRUPDATE_INTERVAL) ) {
        [self saveHeartRate:bpm];
        self.lastSaveDate = [NSDate date];
    }
}

// Invoked upon completion of a -[readValueForCharacteristic:] request
// or on the reception of a notification/indication.
- (void)peripheral:(CBPeripheral *)aPeripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    // Updated value for heart rate measurement received
    if ( [characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A37"]] ) {
        if ( characteristic.value || !error ) {
            NSLog(@"received value: %@", characteristic.value);
            // Update UI with heart rate data
            [self updateWithHRMData:characteristic.value];
        }
    } // Value for body sensor location received
    else if ( [characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A38"]] ) {
        NSData * updatedValue = characteristic.value;
        uint8_t* dataPointer = (uint8_t*)[updatedValue bytes];
        if ( dataPointer ) {
            self.location = dataPointer[0];
            NSString*  locationString;
            switch ( self.location ) {
                case 0:
                    locationString = @"Other";
                    break;
                case 1:
                    locationString = @"Chest";
                    break;
                case 2:
                    locationString = @"Wrist";
                    break;
                case 3:
                    locationString = @"Finger";
                    break;
                case 4:
                    locationString = @"Hand";
                    break;
                case 5:
                    locationString = @"Ear Lobe";
                    break;
                case 6:
                    locationString = @"Foot";
                    break;
                default:
                    locationString = @"Reserved";
                    break;
            }
            NSLog(@"Body Sensor Location = %@ (%li)", locationString, (long)self.location);
        }
    }
    // Value for manufacturer name received
    else if ( [characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A29"]] ) {
        NSString *manufacturer = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        NSLog(@"Manufacturer Name = %@", manufacturer);
    }
}

#pragma mark - HealthKit

- (void)saveHeartRate:(double)heartRate
{
    HKQuantityType *quantityType;
    HKQuantity *heartRateQuantity;
    NSDictionary *metaData;
    HKQuantitySample *sample;
    
    quantityType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
    
    heartRateQuantity = [HKQuantity quantityWithUnit:[[HKUnit countUnit] unitDividedByUnit:[HKUnit minuteUnit]] doubleValue:heartRate];
    
    metaData = @{HKMetadataKeyHeartRateSensorLocation:@(self.location)};
    
    sample = [HKQuantitySample quantitySampleWithType:quantityType quantity:heartRateQuantity startDate:[NSDate date] endDate:[NSDate date] metadata:metaData];
    [self.healthStore saveObject:sample withCompletion:nil];
}

- (void)dealloc
{
    [self.manager stopScan];
}

@end
