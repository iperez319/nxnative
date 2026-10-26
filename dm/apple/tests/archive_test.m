#import "../save_sync.h"
#include <sys/xattr.h>
#include <assert.h>
static void mkdirp(NSString *p) { assert([NSFileManager.defaultManager createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:nil]); }
static void put(NSString *p, NSString *value) { assert([value writeToFile:p atomically:NO encoding:NSUTF8StringEncoding error:nil]); }
static NSString *readText(NSString *p) { return [NSString stringWithContentsOfFile:p encoding:NSUTF8StringEncoding error:nil]; }
int main(int argc, char **argv) { @autoreleasepool {
    assert(argc>=3); NSString *mode=@(argv[1]), *base=@(argv[2]);
    NSString *save=[base stringByAppendingPathComponent:@"save"], *state=[base stringByAppendingPathComponent:@"state"], *source=[base stringByAppendingPathComponent:@"source"], *stage=[base stringByAppendingPathComponent:@"stage"], *archive=[base stringByAppendingPathComponent:@"snapshot.nxsave"];
    if ([mode isEqual:@"recover"]) {
        [DMSaveArchive recover:state save:save];
        assert([readText([save stringByAppendingPathComponent:@"old"]) isEqual:@"account-old"]);
        assert([readText([[save stringByAppendingString:@"_device"] stringByAppendingPathComponent:@"old"]) isEqual:@"device-old"]);
        assert([readText([state stringByAppendingPathComponent:@"state.json"]) containsString:@"old-parent"]);
        return 0;
    }
    if ([mode isEqual:@"validate"]) { @try { [DMSaveArchive read:archive into:nil]; return 0; } @catch(NSException *e) { return 2; } }
    mkdirp([source stringByAppendingPathComponent:@"account/empty"]); mkdirp([source stringByAppendingPathComponent:@"device"]);
    put([source stringByAppendingPathComponent:@"account/Case"],@"one");
    NSString *alias=[source stringByAppendingPathComponent:@"account/alias"];
    put(alias,@"two"); assert(setxattr(alias.fileSystemRepresentation,"org.d2rmobile.guest-name","case",4,0,0)==0);
    put([source stringByAppendingPathComponent:@"device/device-save"],@"device");
    if ([mode isEqual:@"delete-device"]) assert([NSFileManager.defaultManager removeItemAtPath:[source stringByAppendingPathComponent:@"device"] error:nil]);
    NSDictionary *inv=[DMSaveArchive inventory:source]; NSMutableDictionary *m=[inv mutableCopy];
    [m addEntriesFromDictionary:@{@"format":@1,@"revision":@"12345678-1234-4234-8234-123456789012",@"parent":NSNull.null,@"title":@"01008DB008C2C000",@"profile":@"default",@"device":@"22345678-1234-4234-8234-123456789012",@"displayTime":@"2026-10-26T00:00:00Z",@"compatibility":@{@"version":@"1",@"builds":@[@"test"],@"dlc":@[]}}];
    [DMSaveArchive write:m capture:source to:archive];
    NSDictionary *decoded=[DMSaveArchive read:archive into:stage];
    assert([[DMSaveArchive inventory:stage] isEqual:inv]); assert([decoded isEqual:m]);
    mkdirp(save); mkdirp([save stringByAppendingString:@"_device"]); mkdirp(state);
    put([save stringByAppendingPathComponent:@"old"],@"account-old"); put([[save stringByAppendingString:@"_device"] stringByAppendingPathComponent:@"old"],@"device-old");
    dm_save_json([state stringByAppendingPathComponent:@"state.json"],@{@"base":@"old-parent"});
    [DMSaveArchive restore:stage manifest:m state:state save:save metadata:@{@"base":m[@"revision"]}];
    assert([readText([save stringByAppendingPathComponent:@"Case"]) isEqual:@"one"]);
    assert(![NSFileManager.defaultManager fileExistsAtPath:[save stringByAppendingPathComponent:@"old"]]);
    if ([m[@"roots"][@"device"] boolValue]) assert([readText([[save stringByAppendingString:@"_device"] stringByAppendingPathComponent:@"device-save"]) isEqual:@"device"]);
    else assert(![NSFileManager.defaultManager fileExistsAtPath:[save stringByAppendingString:@"_device"]]);
    unsigned char flag=0; assert(getxattr(save.fileSystemRepresentation,"org.nxnative.restored",&flag,1,0,0)==1 && flag);
    [DMSaveArchive recover:state save:save]; // no journal: successful restore remains installed
    assert([readText([save stringByAppendingPathComponent:@"Case"]) isEqual:@"one"]);
    return 0;
} }
