#import <UIKit/UIKit.h>
#import "GuideHarness.h"
#include "shield_guide_live.h"
#include "guide_live_profile.h"
#include <fcntl.h>

static NSString *committed;
static uint64_t primary[12], mirrorRoot[64], mirror[14];
static NSMutableData *module;
static int openCommitted(void) { return open(committed.fileSystemRepresentation, O_RDONLY | O_CLOEXEC); }
static bool heapRead(uint64_t address, void *out, size_t count) {
    uint64_t *objects[] = {primary, mirrorRoot, mirror};
    size_t sizes[] = {sizeof(primary), sizeof(mirrorRoot), sizeof(mirror)};
    for (NSUInteger i = 0; i < 3; i++) {
        uintptr_t start = (uintptr_t)objects[i];
        if (address < start || count > sizes[i] || address - start > sizes[i] - count) continue;
        memcpy(out, (void *)(uintptr_t)address, count);
        return true;
    }
    return false;
}
static void installFixture(NSString *name) {
    NSString *root = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Fixtures"];
    NSData *data = [NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:name]];
    if ([name isEqualToString:@"broken"]) data = [@"broken" dataUsingEncoding:NSUTF8StringEncoding];
    [NSFileManager.defaultManager removeItemAtPath:committed error:nil];
    if (data) [data writeToFile:committed atomically:YES];
}
void GuideHarnessPrepare(void) {
    NSDictionary *env = NSProcessInfo.processInfo.environment;
    // Isolated app bundle and test-only defaults, never production preferences.
    [NSUserDefaults.standardUserDefaults removePersistentDomainForName:NSBundle.mainBundle.bundleIdentifier];
    [NSUserDefaults.standardUserDefaults setInteger:[env[@"GUIDE_AREA"] integerValue] forKey:@"shieldGuide.area"];
    committed = [NSTemporaryDirectory() stringByAppendingPathComponent:@"synthetic-main"];
    installFixture(env[@"GUIDE_FIXTURE"] ?: @"none");
    dm_shield_guide_configure(DM_SHIELD_GUIDE_BUILD, openCommitted);
    if ([env[@"GUIDE_LIVE"] isEqualToString:@"motostoke"]) {
        module = [NSMutableData dataWithLength:dmShieldLocationRoot + sizeof(uint64_t)];
        uint8_t *base = module.mutableBytes;
        *(uint64_t *)(base + dmShieldLocationRoot) = (uintptr_t)primary;
        *(uint64_t *)(base + dmShieldMirrorRoot) = (uintptr_t)mirrorRoot;
        mirrorRoot[dmShieldMirrorPointer / 8] = (uintptr_t)mirror;
        primary[0] = (uintptr_t)base + dmShieldLocationVtable;
        mirror[dmShieldMirrorVtableField / 8] = (uintptr_t)base + dmShieldMirrorVtable;
        primary[dmShieldLocationPair / 8] = 0x92DABAD379E43890;
        primary[dmShieldLocationPair / 8 + 1] = mirror[dmShieldMirrorZone / 8] = 0xE0D6E5E78C91F4A7;
        dm_shield_guide_configure_live(DM_SHIELD_GUIDE_BUILD, base, module.length, heapRead);
    }
    if (env[@"GUIDE_REPLACEMENT"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            installFixture(env[@"GUIDE_REPLACEMENT"]);
        });
    }
    if (env[@"GUIDE_RECOVERY"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 12 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            installFixture(env[@"GUIDE_RECOVERY"]);
        });
    }
}
void dm_host_present(void *parent, void *controller) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindow *window = ((UIWindowScene *)scene).windows.firstObject;
        [window.rootViewController presentViewController:(__bridge UIViewController *)controller animated:NO completion:nil];
        break;
    }
}
