// Test the production byte pump with real streams and end-to-end TLS. No
// Bluetooth manager is created; physical radio behavior is a separate gate.
#import "../DMControllerBluetooth.m"
#include <assert.h>
#include <sys/socket.h>

// Force small writes to exercise offset/backpressure handling, independent of
// how much data a particular machine's stream accepts in one call.
@interface FragmentOutput : NSOutputStream <NSStreamDelegate>
@property NSOutputStream *base;
@property(weak) id<NSStreamDelegate> sink;
@property BOOL blocked;
@property unsigned writes;
@end
@implementation FragmentOutput
- (id<NSStreamDelegate>)delegate { return self.sink; }
- (void)setDelegate:(id<NSStreamDelegate>)delegate { self.sink = delegate; self.base.delegate = self; }
- (void)open { [self.base open]; }
- (void)close { [self.base close]; }
- (BOOL)hasSpaceAvailable { return !self.blocked && self.base.hasSpaceAvailable; }
- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)length {
    if (++_writes % 3 == 0) {
        self.blocked = YES; __weak FragmentOutput *weak = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1000000), dispatch_get_main_queue(), ^{
            FragmentOutput *s = weak; if (!s) return;
            s.blocked = NO; [s.sink stream:s handleEvent:NSStreamEventHasSpaceAvailable];
        });
        return 0;
    }
    return [self.base write:buffer maxLength:MIN(length, 7)];
}
- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSRunLoopMode)mode { [self.base scheduleInRunLoop:runLoop forMode:mode]; }
- (void)removeFromRunLoop:(NSRunLoop *)runLoop forMode:(NSRunLoopMode)mode { [self.base removeFromRunLoop:runLoop forMode:mode]; }
- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)event { [self.sink stream:self handleEvent:event]; }
@end

static void streams(int fd, NSInputStream **input, NSOutputStream **output) {
    CFReadStreamRef read; CFWriteStreamRef write;
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, fd, &read, &write); assert(read && write);
    CFReadStreamSetProperty(read, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
    CFWriteStreamSetProperty(write, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
    *input = CFBridgingRelease(read);
    FragmentOutput *fragmented = [FragmentOutput new]; fragmented.base = CFBridgingRelease(write); *output = fragmented;
}
int main(int argc, const char **argv) {
    @autoreleasepool {
        assert(argc == 2); BOOL wrongKey = !strcmp(argv[1], "wrong-key");
        DMControllerSession *host = [DMControllerSession new], *phone = [DMControllerSession new];
        DMControllerBluetooth *hostBridge = [DMControllerBluetooth new], *phoneBridge = [DMControllerBluetooth new];
        NSString *key = DMControllerSession.newInvitation;
        __block BOOL started = NO, pressed = NO, released = NO, rejected = NO;
        host.receivedState = ^(dm_control_state state) { if (state.buttons == 1) pressed = YES; if (!state.buttons && pressed) released = YES; };
        phone.statusChanged = ^(NSString *status) { fprintf(stderr, "bridge phone: %s\n", status.UTF8String); if ([status containsString:@"authentication failed"]) rejected = YES; };
        __weak DMControllerSession *weakHost = host, *weakPhone = phone;
        hostBridge.failed = ^(NSString *reason) { [weakHost stop:reason]; };
        phoneBridge.failed = ^(NSString *reason) { [weakPhone stop:reason]; };
        __weak DMControllerBluetooth *weakPhoneBridge = phoneBridge;
        phoneBridge.localListenerReady = ^(uint16_t port) {
            assert([weakPhone connectTo:nw_endpoint_create_host("127.0.0.1", [NSString stringWithFormat:@"%u", port].UTF8String)
                invitation:wrongKey ? DMControllerSession.newInvitation : key peerToPeer:NO]);
            weakPhone.auxiliaryTransport = weakPhoneBridge;
        };
        host.statusChanged = ^(NSString *status) {
            fprintf(stderr, "bridge host: %s\n", status.UTF8String);
            if ([status containsString:@"authentication failed"]) rejected = YES;
            DMControllerSession *s = weakHost; if (!s.port || started) return;
            started = YES; assert(!s.pairingServiceName);
            int pair[2]; assert(socketpair(AF_UNIX, SOCK_STREAM, 0, pair) == 0);
            NSInputStream *hostIn, *phoneIn; NSOutputStream *hostOut, *phoneOut;
            streams(pair[0], &hostIn, &hostOut); streams(pair[1], &phoneIn, &phoneOut);
            s.auxiliaryTransport = hostBridge;
            [hostBridge beginReceiver:YES]; [hostBridge attachInput:hostIn output:hostOut tlsPort:s.port];
            [phoneBridge beginReceiver:NO]; [phoneBridge attachInput:phoneIn output:phoneOut tlsPort:0];
        };
        assert([host listenOnLoopbackWithInvitation:key]);
        uint64_t start = DMControllerNow(), connected = 0; BOOL tapped = NO;
        while (DMControllerNow() - start < UINT64_C(5000000000)) {
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];
            if (wrongKey && rejected) break;
            if (!wrongKey && host.connected && phone.connected) {
                if (!connected) connected = DMControllerNow();
                if (!tapped) { tapped = YES; [phone publish:(dm_control_state){.buttons=1}]; [phone publish:(dm_control_state){0}]; }
                if (DMControllerNow() - connected > UINT64_C(400000000) && pressed && released && phone.lastRoundTripNS) break;
            }
        }
        if (wrongKey) assert(rejected && !host.connected && !pressed);
        else assert(pressed && released && host.connected && phone.connected && phone.lastRoundTripNS);
        host.statusChanged = nil;
        [phone stop:@"Phone focus lost"]; [host stop:@"Receiver focus lost"];
        assert(!host.auxiliaryTransport && !phone.auxiliaryTransport && !host.connected && !phone.connected);
        puts(wrongKey ? "PASS: wrong invitation rejected across fragmented byte carrier" : "PASS: end-to-end TLS, short taps and heartbeats across fragmented byte carrier; lifetime cleanup");
    }
}
