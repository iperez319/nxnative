// Compile under Sword: even a matching Shield build and readable callbacks must stay isolated.
#import "../../host/shield_guide_mac.m"
#include "../shield_guide_live.h"
#include "../../games/01008DB008C2C000/guide_live_profile.h"
#include <assert.h>

static unsigned saveReads, heapReads;
static int openUnexpected(void) { saveReads++; return -1; }
static bool heapUnexpected(uint64_t address, void *out, size_t count) {
    (void)address; (void)out; (void)count;
    heapReads++;
    return false;
}
int main(void) {
    @autoreleasepool {
        assert(!dm_shield_guide_available());
        NSMenu *bar = [NSMenu new];
        dm_shield_guide_mac_menu(bar);
        assert(![bar itemWithTitle:@"Guide"]);
        NSMutableData *module = [NSMutableData dataWithLength:dmShieldLocationRoot + sizeof(uint64_t)];
        dm_shield_guide_configure(DM_SHIELD_GUIDE_BUILD, openUnexpected);
        dm_shield_guide_configure_live(DM_SHIELD_GUIDE_BUILD, module.bytes, module.length, heapUnexpected);
        assert(!DMGuideLiveLocation.currentLocation);
        DMGuideSaveMonitor *monitor = [DMGuideSaveMonitor new];
        __block BOOL changed = NO;
        [monitor refresh:^{ changed = YES; }];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3];
        while (!changed && deadline.timeIntervalSinceNow > 0)
            [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        assert(changed && !monitor.context && !monitor.stale && !saveReads && !heapReads);
        puts("PASS: non-Shield profile hides Guide and rejects matching-build save/live callbacks");
    }
}
