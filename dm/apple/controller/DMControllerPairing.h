#pragma once
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
// A bounded, versioned QR payload. The receiver name is only a discovery hint;
// the fresh invitation authenticates the TLS session. Never log this object’s
// code or invitation, persist it, or open its URL in a browser.
@interface DMControllerPairing : NSObject
@property(nonatomic, readonly, copy) NSString *invitation;
@property(nonatomic, readonly, copy) NSString *receiverName;
@property(nonatomic, readonly) BOOL peerToPeer;
@property(nonatomic, readonly) BOOL bluetooth;
+ (nullable NSString *)codeForInvitation:(NSString *)invitation receiverName:(NSString *)name peerToPeer:(BOOL)peerToPeer;
+ (nullable NSString *)bluetoothCodeForInvitation:(NSString *)invitation serviceUUID:(NSString *)serviceUUID;
+ (nullable instancetype)parseCode:(NSString *)code;
@end
NS_ASSUME_NONNULL_END
