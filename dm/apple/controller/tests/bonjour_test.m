// Exercise the actual published SRV/TXT service and encrypted service-name
// connection, rather than bypassing Bonjour with a numeric loopback endpoint.
#import "../DMControllerSession.h"
#include <assert.h>
@interface BonjourProbe : NSObject <NSNetServiceDelegate>
@property BOOL resolved, failed;
@property NSInteger port;
@end
@implementation BonjourProbe
- (void)netServiceDidResolveAddress:(NSNetService *)service {
    NSDictionary *txt = [NSNetService dictionaryFromTXTRecordData:service.TXTRecordData];
    assert(txt.count == 1 && [txt[@"txtvers"] isEqual:[@"1" dataUsingEncoding:NSUTF8StringEncoding]]);
    assert(service.addresses.count && service.port == self.port);
    self.resolved = YES;
}
- (void)netService:(NSNetService *)service didNotResolve:(NSDictionary *)error { self.failed = YES; }
@end
int main(void) {
    @autoreleasepool {
        DMControllerSession *host = [DMControllerSession new], *phone = [DMControllerSession new];
        BonjourProbe *probe = [BonjourProbe new];
        __block NSNetService *service;
        NSString *name = [@"nx-control-test-" stringByAppendingString:NSUUID.UUID.UUIDString];
        __block NSString *registeredName;
        NSString *key = DMControllerSession.newInvitation; assert(key);
        __weak DMControllerSession *weakHost = host;
        host.statusChanged = ^(NSString *status) {
            if (weakHost.port && weakHost.pairingServiceName && !service) {
                probe.port = weakHost.port;
                registeredName = weakHost.pairingServiceName;
                assert(![registeredName isEqual:name] && [registeredName lengthOfBytesUsingEncoding:NSUTF8StringEncoding] <= 63);
                service = [[NSNetService alloc] initWithDomain:@"local." type:DMControllerServiceType name:registeredName];
                service.delegate = probe; [service resolveWithTimeout:5];
            }
        };
        assert([host listenWithInvitation:key name:name peerToPeer:NO]);
        uint64_t start = DMControllerNow(), connectedAt = 0; BOOL connecting = NO;
        while (DMControllerNow() - start < UINT64_C(8000000000) && !probe.failed) {
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];
            if (probe.resolved && !connecting) {
                connecting = YES; [service stop];
                assert([phone connectTo:nw_endpoint_create_bonjour_service(registeredName.UTF8String, DMControllerServiceType.UTF8String, "local.") invitation:key peerToPeer:NO]);
            }
            if (host.connected && phone.connected) {
                if (!connectedAt) connectedAt = DMControllerNow();
                if (DMControllerNow() - connectedAt > UINT64_C(300000000)) break;
            }
        }
        assert(probe.resolved && host.connected && phone.connected && phone.lastRoundTripNS);
        service.delegate = nil; [service stop]; host.statusChanged = nil;
        [phone stop:@"Test complete"]; [host stop:@"Test complete"];
        puts("PASS: confirmed fresh Bonjour name, SRV/TXT resolution, version-only metadata, encrypted service-name connection and heartbeat ACKs");
    }
}
