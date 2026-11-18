#pragma once
#import "../controller/DMControllerSession.h"
NS_ASSUME_NONNULL_BEGIN
// Main queue only. The host owns the receiver beyond the pairing screen's
// lifetime; leaving an unconnected screen cancels its invitation.
@interface DMControllerHost : NSObject
+ (instancetype)shared;
@property(nonatomic, copy, nullable) void (^changed)(void);
@property(nonatomic, readonly) BOOL connected;
@property(nonatomic, readonly, copy) NSString *status;
@property(nonatomic, readonly, copy, nullable) NSString *pairingCode;
@property(nonatomic, readonly, copy, nullable) NSString *invitation;
@property(nonatomic, readonly) dm_control_state state;
- (void)startBluetooth:(BOOL)bluetooth;
- (void)stop:(NSString *)reason;
- (void)endPairing;   // keep an established session; otherwise close listener
@end
NS_ASSUME_NONNULL_END
