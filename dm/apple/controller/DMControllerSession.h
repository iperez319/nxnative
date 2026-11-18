#pragma once
#import <Foundation/Foundation.h>
#import <Network/Network.h>
#include "controller_protocol.h"

NS_ASSUME_NONNULL_BEGIN
@class DMControllerDiscovery;
@protocol DMControllerTransportLifetime <NSObject>
- (void)stop;
@end
FOUNDATION_EXPORT NSString *const DMControllerServiceType;
FOUNDATION_EXPORT uint64_t DMControllerNow(void);
// Opt-in, bounded diagnostics. Only status/error/path events are recorded;
// invitations, peer names, input packets and credentials are never logged.
FOUNDATION_EXPORT void DMControllerSetDiagnosticFile(NSString * _Nullable path);
// Only credential-free state/error/count events; never pass peer data here.
FOUNDATION_EXPORT void DMControllerRecordDiagnostic(NSString *event);

// Phase-1 transport, deliberately separate from host input storage. All calls
// and callbacks use the main queue. One explicit start admits one peer, with a
// fresh 256-bit out-of-band invitation; there is no automatic trust/reconnect.
@interface DMControllerSession : NSObject
@property(nonatomic, copy, nullable) void (^statusChanged)(NSString *status);
@property(nonatomic, copy, nullable) void (^receivedState)(dm_control_state state);
@property(nonatomic, readonly) BOOL connected;
@property(nonatomic, readonly) uint16_t port;
@property(nonatomic, readonly) BOOL pairingAvailable;
@property(nonatomic, readonly, copy, nullable) NSString *pairingServiceName;
@property(nonatomic, readonly) uint64_t lastRoundTripNS;
// Diagnostic apps only: after a watchdog releases input, discard/read frames
// for at most five seconds to identify late delivery. Never resumes the session.
// Disabled by default; focus loss/stop still cancels the transport immediately.
@property(nonatomic) BOOL diagnoseInputStalls;
// An optional byte carrier lives exactly as long as this session. It carries
// TLS ciphertext; it must not decode or publish controller input itself.
@property(nonatomic, strong, nullable) id<DMControllerTransportLifetime> auxiliaryTransport;
// Raw path/interface observations for diagnostics, never a claim that traffic
// is direct merely because peer-to-peer support was requested.
@property(nonatomic, readonly, copy) NSString *pathSummary;
+ (nullable NSString *)newInvitation;
- (BOOL)listenWithInvitation:(NSString *)invitation name:(NSString *)name peerToPeer:(BOOL)peerToPeer;
- (BOOL)listenOnLoopbackWithInvitation:(NSString *)invitation;
- (BOOL)connectTo:(nw_endpoint_t)endpoint invitation:(NSString *)invitation peerToPeer:(BOOL)peerToPeer;
// Consumes discovery for the experimental foreground peer-to-peer lifetime.
- (BOOL)connectTo:(nw_endpoint_t)endpoint invitation:(NSString *)invitation peerToPeer:(BOOL)peerToPeer discovery:(nullable DMControllerDiscovery *)discovery;
- (void)publish:(dm_control_state)state;
- (void)stop:(NSString *)reason;
@end

@interface DMControllerDiscovery : NSObject
@property(nonatomic, readonly) BOOL searching;
@property(nonatomic, copy, nullable) void (^changed)(NSArray *endpoints);
@property(nonatomic, copy, nullable) void (^statusChanged)(NSString *status);
- (void)startWithPeerToPeer:(BOOL)peerToPeer;
- (void)handoffForConnectionSetup;
- (void)connectionEstablished;
- (void)stop;
@end
NS_ASSUME_NONNULL_END
