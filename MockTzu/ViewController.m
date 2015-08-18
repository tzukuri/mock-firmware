#import "ViewController.h"
@import CoreBluetooth;

@interface ViewController () <CBPeripheralManagerDelegate, CBPeripheralDelegate>
{
    // peripheral
    BOOL initialised;
    BOOL running;
    unsigned char tickValue;
    long batteryLevel;
    CBPeripheralManager *manager;
    
    // services
    CBUUID *tzuTickServiceUUID;
    CBUUID *batteryServiceUUID;
    CBMutableService *batteryService;
    CBMutableService *tzuTickService;
    CBMutableCharacteristic *batteryCharacteristic;
    CBMutableCharacteristic *tzuTickCharacteristic;
    
    NSTimer *tickTimer;
}

@property IBOutlet NSTextField *statusText;
@property IBOutlet NSButton *button;
@property IBOutlet NSSlider *batterySlider;
@property IBOutlet NSTextField *batteryText;

@end



@implementation ViewController

// -----------------------------
// init
// -----------------------------
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // act as a peripheral
    manager = [[CBPeripheralManager alloc]initWithDelegate:self queue:nil];
    initialised = NO;
    
    // mock system parameters
    running      = NO;
    batteryLevel = 100;
    tickValue    = 0;
    
    // uuids
    tzuTickServiceUUID = [CBUUID UUIDWithString:@"EBA38950-0D9B-4DBA-B0DF-BC7196DD44FC"];
    batteryServiceUUID = [CBUUID UUIDWithString:@"180F"];
}


// -----------------------------
// peripheral
// -----------------------------
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        // prepare the GATT database
        self.button.enabled = YES;
        [self initialisePeripheral];
        
        // set initial values
        [self updateBattery];
        [self updateTick];
        
    } else if (peripheral.state <= CBPeripheralManagerStatePoweredOff) {
        self.button.enabled = NO;
    }
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error {
    if (error == nil) {
        self.statusText.stringValue = @"Advertising";
    } else {
        self.statusText.stringValue = @"Error starting advertising";
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request {
    if ([request.characteristic isEqualTo:batteryCharacteristic])
        request.value = [self batteryData];
    else if ([request.characteristic isEqualTo:tzuTickCharacteristic])
        request.value = [self tickData];
    [manager respondToRequest:request withResult:CBATTErrorSuccess];
}

- (void) initialisePeripheral {
    if (initialised)
        return;
    
    // battery service
    CBUUID *batteryCharacteristicUUID = [CBUUID UUIDWithString:@"2A19"];
    batteryCharacteristic = [[CBMutableCharacteristic alloc] initWithType:batteryCharacteristicUUID
                                                               properties:CBCharacteristicPropertyNotify
                                                                    value:nil
                                                              permissions:CBAttributePermissionsReadable];

    batteryService = [[CBMutableService alloc] initWithType:batteryServiceUUID primary:YES];
    batteryService.characteristics = @[batteryCharacteristic];
    [manager addService:batteryService];
    
    
    // TzuTick service
    CBUUID *tzuTickCharacteristicUUID = [CBUUID UUIDWithString:@"EBA38950-0D9B-4DBA-B0DF-BC7196DD44FD"];
    tzuTickCharacteristic = [[CBMutableCharacteristic alloc] initWithType:tzuTickCharacteristicUUID
                                                               properties:CBCharacteristicPropertyNotify
                                                                    value:nil
                                                              permissions:CBAttributePermissionsReadable];
    
    tzuTickService = [[CBMutableService alloc] initWithType:tzuTickServiceUUID primary:YES];
    tzuTickService.characteristics = @[tzuTickCharacteristic];
    [manager addService:tzuTickService];
    
    tickTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(incrementTick) userInfo:nil repeats:YES];
    
    initialised = YES;
}

- (void) incrementTick {
    tickValue++;
    [self updateTick];
}

- (NSData *) batteryData {
    unsigned char level = (char) batteryLevel;
    return [[NSData alloc] initWithBytes:&level length:sizeof(char)];
}

- (NSData *) tickData {
    return [[NSData alloc] initWithBytes:&tickValue length:sizeof(char)];
}

- (void) updateBattery {
    [manager updateValue:[self batteryData] forCharacteristic:batteryCharacteristic onSubscribedCentrals:nil];
}

- (void) updateTick {
    [manager updateValue:[self tickData] forCharacteristic:tzuTickCharacteristic onSubscribedCentrals:nil];
}


// -----------------------------
// ui
// -----------------------------
- (IBAction) toggleRunning:(id)sender {
    if (running) {
        [manager stopAdvertising];
        self.button.title = @"Start";
        self.statusText.stringValue = @"Not running";
    } else {
        self.button.title = @"Stop";
        [manager startAdvertising:@{
            CBAdvertisementDataLocalNameKey: @"TzuGlasses A",
            CBAdvertisementDataServiceUUIDsKey: @[tzuTickServiceUUID, batteryServiceUUID]
        }];
    }
    
    running = !running;
}

- (IBAction) batteryLevelChanged:(id)sender {
    batteryLevel = self.batterySlider.integerValue;
    self.batteryText.stringValue = [[NSString alloc] initWithFormat:@"%ld%%", batteryLevel];
}

@end
