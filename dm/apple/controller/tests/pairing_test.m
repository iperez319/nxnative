#import "../DMControllerPairing.h"
#import "../../../controller/Sources/DMQRCode.h"
#include <assert.h>
int main(void) {
    @autoreleasepool {
        NSString *key = [@"0123456789abcdef" stringByPaddingToLength:64 withString:@"0123456789abcdef" startingAtIndex:0];
        for (NSNumber *p2p in @[@NO, @YES]) {
            NSString *code = [DMControllerPairing codeForInvitation:key receiverName:@"My iPad & Mac + test" peerToPeer:p2p.boolValue];
            assert(code && code.length <= 1024);
            DMControllerPairing *parsed = [DMControllerPairing parseCode:code];
            assert([parsed.invitation isEqual:key] && [parsed.receiverName isEqual:@"My iPad & Mac + test"] && parsed.peerToPeer == p2p.boolValue);
            // Decode the actual QR renderer used by the iPad app, not a second
            // implementation of the payload-to-image conversion.
            CGImageRef image = DMCreatePairingQR(code); assert(image);
            CIImage *ci = [CIImage imageWithCGImage:image];
            CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:[CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer:@YES}] options:@{CIDetectorAccuracy:CIDetectorAccuracyHigh}];
            NSArray *features = [detector featuresInImage:ci];
            assert(features.count == 1);
            assert([((CIQRCodeFeature *)features.firstObject).messageString isEqual:code]);
            CGImageRelease(image);
            for (NSString *bad in @[
                [code stringByReplacingOccurrencesOfString:@"v=1" withString:@"v=2"],
                [code stringByReplacingOccurrencesOfString:@"nxcontroller:" withString:@"https:"],
                [code stringByAppendingString:@"&v=1"], [code stringByAppendingString:@"#fragment"],
                [code stringByReplacingOccurrencesOfString:@"pair?" withString:@"pair/extra?"],
                [code stringByReplacingOccurrencesOfString:key withString:@"123456"],
                [code stringByReplacingOccurrencesOfString:key withString:[@"z" stringByPaddingToLength:64 withString:@"z" startingAtIndex:0]]
            ]) assert(![DMControllerPairing parseCode:bad]);
        }
        assert(![DMControllerPairing parseCode:@""]);
        assert(![DMControllerPairing parseCode:[@"x" stringByPaddingToLength:1025 withString:@"x" startingAtIndex:0]]);
        assert(![DMControllerPairing codeForInvitation:key receiverName:@"bad\nname" peerToPeer:NO]);
        assert(![DMControllerPairing codeForInvitation:@"123456" receiverName:@"iPad" peerToPeer:NO]);
        NSString *uuid = NSUUID.UUID.UUIDString;
        NSString *bluetooth = [DMControllerPairing bluetoothCodeForInvitation:key serviceUUID:uuid];
        DMControllerPairing *parsed = [DMControllerPairing parseCode:bluetooth];
        assert(parsed.bluetooth && !parsed.peerToPeer && [parsed.invitation isEqual:key] && [parsed.receiverName isEqual:uuid]);
        for (NSString *bad in @[[bluetooth stringByReplacingOccurrencesOfString:@"transport=ble" withString:@"transport=tcp"],
            [bluetooth stringByReplacingOccurrencesOfString:@"transport=ble" withString:@"p2p=1"],
            [bluetooth stringByReplacingOccurrencesOfString:@"v=2" withString:@"v=1"],
            [bluetooth stringByReplacingOccurrencesOfString:uuid withString:@"not-a-uuid"]]) assert(![DMControllerPairing parseCode:bad]);
        assert(![DMControllerPairing bluetoothCodeForInvitation:key serviceUUID:@"invalid"]);
        puts("PASS: QR rendering/decoding, pairing URI bounds/version/field validation and mode transfer; full invitation preserved");
    }
}
