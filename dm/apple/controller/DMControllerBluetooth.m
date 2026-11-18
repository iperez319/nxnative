#import "DMControllerBluetooth.h"
#import <CoreBluetooth/CoreBluetooth.h>

static nw_parameters_t carrierParameters(BOOL listener) {
    // This local TCP hop transports TLS records, never unencrypted input.
    nw_parameters_t p = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL,
        ^(nw_protocol_options_t tcp) { nw_tcp_options_set_no_delay(tcp, true); });
    if (listener) nw_parameters_set_local_endpoint(p, nw_endpoint_create_host("127.0.0.1", "0"));
    return p;
}
static CBUUID *psmUUID(void) { return [CBUUID UUIDWithString:CBUUIDL2CAPPSMCharacteristicString]; }

@interface DMControllerBluetooth () <CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate, NSStreamDelegate>
@end
@implementation DMControllerBluetooth {
    CBCentralManager *_central;
    CBPeripheralManager *_manager;
    CBPeripheral *_peer;
    CBL2CAPChannel *_channel;
    CBUUID *_service;
    CBL2CAPPSM _psm;
    uint16_t _tlsPort;
    BOOL _receiver, _stopped, _publishing, _localReady, _reading;
    NSUInteger _generation, _pendingLocalWrites;
    nw_listener_t _localListener;
    nw_connection_t _local;
    NSInputStream *_input;
    NSOutputStream *_output;
    NSMutableData *_toBluetooth;
    NSUInteger _outputOffset;
}
+ (void)requestAccess {
    NSAssert(NSThread.isMainThread, @"Main queue only");
    static CBCentralManager *permissionManager;
    if (!permissionManager) permissionManager = [[CBCentralManager alloc] initWithDelegate:nil queue:dispatch_get_main_queue() options:@{CBCentralManagerOptionShowPowerAlertKey:@NO}];
}
- (void)beginReceiver:(BOOL)receiver {
    void (^advertised)(NSString *) = self.advertised;
    void (^ready)(uint16_t) = self.localListenerReady;
    void (^failed)(NSString *) = self.failed;
    [self stop]; self.advertised = advertised; self.localListenerReady = ready; self.failed = failed;
    _stopped = NO; _receiver = receiver;
    DMControllerRecordDiagnostic(receiver ? @"Bluetooth receiver setup started" : @"Bluetooth filtered service search started");
    _toBluetooth = [NSMutableData data]; _outputOffset = _pendingLocalWrites = 0;
    NSUInteger generation = _generation; __weak DMControllerBluetooth *weak = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (receiver ? 60 : 30) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        DMControllerBluetooth *s = weak;
        if (s && !s->_stopped && s->_generation == generation && !s->_localReady)
            [s fail:@"Bluetooth setup expired. Start a fresh receiver and scan again."];
    });
}
- (void)listenForTLSPort:(uint16_t)port {
    NSAssert(NSThread.isMainThread, @"Main queue only");
    [self beginReceiver:YES]; _tlsPort = port;
    if (!port) { [self fail:@"Bluetooth receiver has no local encryption endpoint"]; return; }
    _service = [CBUUID UUIDWithNSUUID:NSUUID.UUID];
    _manager = [[CBPeripheralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:@{CBPeripheralManagerOptionShowPowerAlertKey:@NO}];
}
- (void)connectToServiceUUID:(NSString *)serviceUUID {
    NSAssert(NSThread.isMainThread, @"Main queue only");
    [self beginReceiver:NO]; NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:serviceUUID];
    if (!uuid) { [self fail:@"Invalid Bluetooth pairing hint"]; return; }
    _service = [CBUUID UUIDWithNSUUID:uuid];
    _central = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:@{CBCentralManagerOptionShowPowerAlertKey:@NO}];
}
- (void)fail:(NSString *)reason {
    DMControllerRecordDiagnostic(reason);
    void (^failed)(NSString *) = self.failed; [self stop]; if (failed) failed(reason);
}
- (BOOL)checkState:(CBManagerState)state {
    if (state == CBManagerStateUnknown || state == CBManagerStateResetting) return NO;
    if (state == CBManagerStatePoweredOn) return YES;
    [self fail:state == CBManagerStateUnauthorized ? @"Allow Bluetooth access in Settings, then start and scan again." : @"Bluetooth is unavailable or off. Enable it in Settings and start again."];
    return NO;
}
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)manager {
    if (manager != _manager || _stopped || ![self checkState:manager.state] || _publishing) return;
    _publishing = YES;
    // Link-layer bonding is optional: TLS-PSK authenticates/encrypts the byte
    // stream end to end. Neither this channel nor GATT carries a plaintext key.
    [manager publishL2CAPChannelWithEncryption:NO];
}
- (void)peripheralManager:(CBPeripheralManager *)manager didPublishL2CAPChannel:(CBL2CAPPSM)psm error:(NSError *)error {
    if (manager != _manager || _stopped) return;
    if (error || !psm) { [self fail:@"Could not publish Bluetooth channel"]; return; }
    _psm = psm;
    uint8_t value[] = {(uint8_t)psm, (uint8_t)(psm >> 8)};
    CBMutableCharacteristic *characteristic = [[CBMutableCharacteristic alloc] initWithType:psmUUID()
        properties:CBCharacteristicPropertyRead value:[NSData dataWithBytes:value length:2] permissions:CBAttributePermissionsReadable];
    CBMutableService *service = [[CBMutableService alloc] initWithType:_service primary:YES]; service.characteristics = @[characteristic];
    [manager addService:service];
}
- (void)peripheralManager:(CBPeripheralManager *)manager didAddService:(CBService *)service error:(NSError *)error {
    if (manager != _manager || _stopped) return;
    if (error) { [self fail:@"Could not register Bluetooth service"]; return; }
    [manager startAdvertising:@{CBAdvertisementDataServiceUUIDsKey:@[_service]}];
}
- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)manager error:(NSError *)error {
    if (manager != _manager || _stopped) return;
    if (error) [self fail:@"Could not advertise Bluetooth receiver"];
    else {
        DMControllerRecordDiagnostic(@"Bluetooth service registration confirmed (UUID omitted)");
        if (self.advertised) self.advertised(_service.UUIDString);
    }
}
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central != _central || _stopped || ![self checkState:central.state] || _peer) return;
    [central scanForPeripheralsWithServices:@[_service] options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@NO}];
}
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peer advertisementData:(NSDictionary *)data RSSI:(NSNumber *)rssi {
    if (central != _central || _stopped || _peer) return;
    _peer = peer; peer.delegate = self; [central stopScan]; [central connectPeripheral:peer options:nil];
    DMControllerRecordDiagnostic(@"Bluetooth selected advertised receiver (identity omitted)");
}
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peer {
    if (central == _central && peer == _peer && !_stopped) { DMControllerRecordDiagnostic(@"Bluetooth peripheral connected; discovering channel"); [peer discoverServices:@[_service]]; }
}
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peer error:(NSError *)error {
    if (central == _central && peer == _peer && !_stopped) [self fail:@"Bluetooth connection failed; start and scan again"];
}
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peer error:(NSError *)error {
    if (central == _central && peer == _peer && !_stopped) [self fail:@"Bluetooth disconnected; all input released"];
}
- (void)peripheral:(CBPeripheral *)peer didDiscoverServices:(NSError *)error {
    if (peer != _peer || _stopped) return;
    if (error) { [self fail:@"Bluetooth service discovery failed"]; return; }
    for (CBService *service in peer.services) if ([service.UUID isEqual:_service]) { [peer discoverCharacteristics:@[psmUUID()] forService:service]; return; }
    [self fail:@"Bluetooth pairing service disappeared; start again"];
}
- (void)peripheral:(CBPeripheral *)peer didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (peer != _peer || _stopped) return;
    if (error) { [self fail:@"Bluetooth channel discovery failed"]; return; }
    for (CBCharacteristic *c in service.characteristics) if ([c.UUID isEqual:psmUUID()]) { [peer readValueForCharacteristic:c]; return; }
    [self fail:@"Bluetooth channel metadata is missing"];
}
- (void)peripheral:(CBPeripheral *)peer didUpdateValueForCharacteristic:(CBCharacteristic *)c error:(NSError *)error {
    if (peer != _peer || _stopped || ![c.UUID isEqual:psmUUID()]) return;
    if (error || c.value.length != 2) { [self fail:@"Invalid Bluetooth channel metadata"]; return; }
    const uint8_t *v = c.value.bytes; uint16_t psm = v[0] | ((uint16_t)v[1] << 8);
    if (!psm) { [self fail:@"Invalid Bluetooth channel number"]; return; }
    DMControllerRecordDiagnostic(@"Bluetooth channel metadata resolved");
    [peer openL2CAPChannel:psm];
}
- (void)peripheral:(CBPeripheral *)peer didOpenL2CAPChannel:(CBL2CAPChannel *)channel error:(NSError *)error {
    if (peer == _peer && !_stopped) [self acceptChannel:channel error:error];
}
- (void)peripheralManager:(CBPeripheralManager *)manager didOpenL2CAPChannel:(CBL2CAPChannel *)channel error:(NSError *)error {
    if (manager == _manager && !_stopped) [self acceptChannel:channel error:error];
}
- (void)acceptChannel:(CBL2CAPChannel *)channel error:(NSError *)error {
    if (_channel) { [channel.inputStream close]; [channel.outputStream close]; return; }
    if (error || !channel) { [self fail:@"Bluetooth byte channel could not open"]; return; }
    _channel = channel; [_manager stopAdvertising];
    DMControllerRecordDiagnostic(@"Bluetooth L2CAP byte channel opened");
    [self attachInput:channel.inputStream output:channel.outputStream tlsPort:_tlsPort];
}
- (void)attachInput:(NSInputStream *)input output:(NSOutputStream *)output tlsPort:(uint16_t)port {
    _tlsPort = port;
    _input = input; _output = output;
    for (NSStream *stream in @[_input, _output]) {
        stream.delegate = self; [stream scheduleInRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes]; [stream open];
    }
    if (_receiver) {
        nw_connection_t local = nw_connection_create(nw_endpoint_create_host("127.0.0.1", [NSString stringWithFormat:@"%u", _tlsPort].UTF8String), carrierParameters(NO));
        [self attachLocal:local];
    } else [self openLocalListener];
}
- (void)openLocalListener {
    _localListener = nw_listener_create(carrierParameters(YES));
    if (!_localListener) { [self fail:@"Could not create local Bluetooth encryption bridge"]; return; }
    NSUInteger generation = _generation; __weak DMControllerBluetooth *weak = self;
    nw_listener_set_queue(_localListener, dispatch_get_main_queue());
    nw_listener_set_state_changed_handler(_localListener, ^(nw_listener_state_t state, nw_error_t error) {
        DMControllerBluetooth *s = weak; if (!s || s->_generation != generation) return;
        if (state == nw_listener_state_ready && s.localListenerReady) s.localListenerReady(nw_listener_get_port(s->_localListener));
        else if (state == nw_listener_state_failed) [s fail:@"Local Bluetooth bridge failed"];
    });
    nw_listener_set_new_connection_handler(_localListener, ^(nw_connection_t local) {
        DMControllerBluetooth *s = weak;
        if (!s || s->_generation != generation || s->_local) { nw_connection_cancel(local); return; }
        [s attachLocal:local]; nw_listener_cancel(s->_localListener); s->_localListener = nil;
    });
    nw_listener_start(_localListener);
}
- (void)attachLocal:(nw_connection_t)local {
    _local = local; NSUInteger generation = _generation; __weak DMControllerBluetooth *weak = self;
    nw_connection_set_queue(local, dispatch_get_main_queue());
    nw_connection_set_state_changed_handler(local, ^(nw_connection_state_t state, nw_error_t error) {
        DMControllerBluetooth *s = weak; if (!s || s->_generation != generation) return;
        if (state == nw_connection_state_ready) { s->_localReady = YES; DMControllerRecordDiagnostic(@"Bluetooth local ciphertext bridge ready"); [s readLocal]; [s readBluetooth]; }
        else if (state == nw_connection_state_failed || state == nw_connection_state_waiting) [s fail:@"Local Bluetooth encryption bridge disconnected"];
    });
    nw_connection_start(local);
}
- (void)readLocal {
    if (_stopped || !_localReady || _reading || _toBluetooth.length - _outputOffset >= 16384) return;
    _reading = YES; NSUInteger generation = _generation; __weak DMControllerBluetooth *weak = self;
    nw_connection_receive(_local, 1, 4096, ^(dispatch_data_t content, nw_content_context_t context, bool complete, nw_error_t error) {
        DMControllerBluetooth *s = weak; if (!s || s->_generation != generation) return;
        s->_reading = NO;
        if (content) {
            const void *p; size_t n; dispatch_data_t mapped = dispatch_data_create_map(content, &p, &n);
            if (mapped && n) [s->_toBluetooth appendBytes:p length:n];
        }
        if (s->_toBluetooth.length > 65536 || error || complete) { [s fail:@"Bluetooth bridge ended or fell behind; input released"]; return; }
        [s writeBluetooth]; [s readLocal];
    });
}
- (void)writeBluetooth {
    while (!_stopped && _output.hasSpaceAvailable && _outputOffset < _toBluetooth.length) {
        NSInteger n = [_output write:(const uint8_t *)_toBluetooth.bytes + _outputOffset maxLength:_toBluetooth.length - _outputOffset];
        if (n < 0) { [self fail:@"Bluetooth output stream failed"]; return; }
        if (!n) break;
        _outputOffset += (NSUInteger)n;
    }
    if (_outputOffset) { [_toBluetooth replaceBytesInRange:NSMakeRange(0, _outputOffset) withBytes:NULL length:0]; _outputOffset = 0; }
}
- (void)readBluetooth {
    while (!_stopped && _localReady && _input.hasBytesAvailable && _pendingLocalWrites < 16) {
        uint8_t bytes[4096]; NSInteger n = [_input read:bytes maxLength:sizeof bytes];
        if (n < 0) { [self fail:@"Bluetooth input stream failed"]; return; }
        if (!n) break;
        NSData *data = [NSData dataWithBytes:bytes length:(NSUInteger)n];
        dispatch_data_t payload = dispatch_data_create(data.bytes, data.length, dispatch_get_main_queue(), ^{ (void)data; });
        _pendingLocalWrites++; NSUInteger generation = _generation; __weak DMControllerBluetooth *weak = self;
        nw_connection_send(_local, payload, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t error) {
            DMControllerBluetooth *s = weak; if (!s || s->_generation != generation) return;
            s->_pendingLocalWrites--;
            if (error) [s fail:@"Bluetooth encryption bridge could not forward data"]; else [s readBluetooth];
        });
    }
}
- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)event {
    if (_stopped || (stream != _input && stream != _output)) return;
    if (event & (NSStreamEventErrorOccurred | NSStreamEventEndEncountered)) { [self fail:@"Bluetooth stream closed; all input released"]; return; }
    if (event & NSStreamEventHasBytesAvailable) [self readBluetooth];
    if (event & (NSStreamEventHasSpaceAvailable | NSStreamEventOpenCompleted)) { [self writeBluetooth]; [self readLocal]; }
}
- (void)stop {
    NSAssert(NSThread.isMainThread, @"Main queue only");
    _generation++; _stopped = YES; _localReady = _reading = _publishing = NO;
    if (_central.state == CBManagerStatePoweredOn) { [_central stopScan]; if (_peer) [_central cancelPeripheralConnection:_peer]; }
    _peer.delegate = nil;
    _central.delegate = nil; _central = nil; _peer = nil;
    if (_manager.state == CBManagerStatePoweredOn) { [_manager stopAdvertising]; if (_psm) [_manager unpublishL2CAPChannel:_psm]; [_manager removeAllServices]; }
    _manager.delegate = nil; _manager = nil; _psm = 0;
    for (NSStream *stream in @[(id)_input ?: NSNull.null, (id)_output ?: NSNull.null]) if ([stream isKindOfClass:NSStream.class]) {
        stream.delegate = nil; [stream close]; [stream removeFromRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
    _input = nil; _output = nil; _channel = nil;
    if (_local) nw_connection_cancel(_local); _local = nil;
    if (_localListener) nw_listener_cancel(_localListener); _localListener = nil;
    _toBluetooth = nil; _service = nil; _tlsPort = 0; _pendingLocalWrites = 0;
    self.advertised = nil; self.localListenerReady = nil; self.failed = nil;
}
- (void)dealloc { [self stop]; }
@end
