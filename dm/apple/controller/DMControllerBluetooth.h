#pragma once
#import "DMControllerSession.h"
NS_ASSUME_NONNULL_BEGIN
// Foreground-only experimental byte carrier. Both loopback endpoints bind to
// 127.0.0.1; only the existing end-to-end TLS ciphertext crosses Bluetooth.
// The carrier never receives an invitation or a decoded controller state.
@interface DMControllerBluetooth : NSObject <DMControllerTransportLifetime>
+ (void)requestAccess;
@property(nonatomic, copy, nullable) void (^advertised)(NSString *serviceUUID);
@property(nonatomic, copy, nullable) void (^localListenerReady)(uint16_t port);
@property(nonatomic, copy, nullable) void (^failed)(NSString *reason);
- (void)listenForTLSPort:(uint16_t)port;
- (void)connectToServiceUUID:(NSString *)serviceUUID;
- (void)stop;
@end
NS_ASSUME_NONNULL_END
