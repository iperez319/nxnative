#import "DMControllerPairing.h"

static BOOL validInvitation(NSString *key) {
    if (key.length != 64) return NO;
    return [key rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"] invertedSet]].location == NSNotFound;
}
static BOOL validName(NSString *name) {
    return name.length && [name lengthOfBytesUsingEncoding:NSUTF8StringEncoding] <= 256 &&
        [name rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location == NSNotFound;
}
@implementation DMControllerPairing
+ (NSString *)codeForInvitation:(NSString *)key receiverName:(NSString *)name peerToPeer:(BOOL)p2p {
    if (!validInvitation(key) || !validName(name)) return nil;
    NSURLComponents *url = [NSURLComponents new]; url.scheme = @"nxcontroller"; url.host = @"pair";
    url.queryItems = @[[NSURLQueryItem queryItemWithName:@"v" value:@"1"],
        [NSURLQueryItem queryItemWithName:@"key" value:key.lowercaseString],
        [NSURLQueryItem queryItemWithName:@"name" value:name],
        [NSURLQueryItem queryItemWithName:@"p2p" value:p2p ? @"1" : @"0"]];
    return url.string.length <= 1024 ? url.string : nil;
}
+ (instancetype)parseCode:(NSString *)code {
    if (!code.length || code.length > 1024) return nil;
    NSURLComponents *url = [NSURLComponents componentsWithString:code];
    if (![url.scheme isEqual:@"nxcontroller"] || ![url.host isEqual:@"pair"] ||
        url.user || url.password || url.port || url.fragment || url.path.length || url.queryItems.count != 4) return nil;
    NSMutableDictionary<NSString *, NSString *> *fields = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *item in url.queryItems) {
        if (!item.value || fields[item.name] || ![@[@"v", @"key", @"name", @"p2p", @"transport"] containsObject:item.name]) return nil;
        fields[item.name] = item.value;
    }
    BOOL bluetooth = [fields[@"v"] isEqual:@"2"] && [fields[@"transport"] isEqual:@"ble"] &&
        !fields[@"p2p"] && fields[@"name"].length == 36 && [[NSUUID alloc] initWithUUIDString:fields[@"name"]];
    BOOL network = [fields[@"v"] isEqual:@"1"] && !fields[@"transport"] && [@[@"0", @"1"] containsObject:fields[@"p2p"]];
    if ((!bluetooth && !network) || !validInvitation(fields[@"key"]) || !validName(fields[@"name"])) return nil;
    DMControllerPairing *pairing = [self new];
    pairing->_invitation = fields[@"key"].lowercaseString; pairing->_receiverName = [fields[@"name"] copy];
    pairing->_peerToPeer = [fields[@"p2p"] isEqual:@"1"]; pairing->_bluetooth = bluetooth; return pairing;
}
+ (NSString *)bluetoothCodeForInvitation:(NSString *)key serviceUUID:(NSString *)uuid {
    NSUUID *service = [[NSUUID alloc] initWithUUIDString:uuid];
    if (!validInvitation(key) || uuid.length != 36 || !service) return nil;
    NSURLComponents *url = [NSURLComponents new]; url.scheme = @"nxcontroller"; url.host = @"pair";
    url.queryItems = @[[NSURLQueryItem queryItemWithName:@"v" value:@"2"],
        [NSURLQueryItem queryItemWithName:@"key" value:key.lowercaseString],
        [NSURLQueryItem queryItemWithName:@"name" value:service.UUIDString],
        [NSURLQueryItem queryItemWithName:@"transport" value:@"ble"]];
    return url.string.length <= 1024 ? url.string : nil;
}
@end
