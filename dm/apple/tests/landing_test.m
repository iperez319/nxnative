// Exercise the real inline launcher gate with synthetic local saves, no network.
#import "../save_sync.m"
#include <assert.h>
void dm_fs_set_sync_callback(void (*callback)(void)) {}
void dm_fs_sync_capture(void) {}
void dm_fs_capture_with(void (*callback)(void *), void *context) { callback(context); }
uint64_t dm_fs_commit_count(void) { return 0; }
static BOOL launched;
static void didLaunch(void) { launched=YES; }
int main(int argc, char **argv) { @autoreleasepool {
    assert(argc==2);
    worker=dispatch_queue_create("test.landing",DISPATCH_QUEUE_SERIAL);
    dispatch_queue_set_specific(worker,&workerKey,&workerKey,NULL);
    dispatch_sync(worker,^{
        savePath=[@(argv[1]) stringByAppendingPathComponent:@"save"];
        statePath=[@(argv[1]) stringByAppendingPathComponent:@"sync"];
        assert([NSFileManager.defaultManager createDirectoryAtPath:savePath withIntermediateDirectories:YES attributes:nil error:nil]);
        assert([NSFileManager.defaultManager createDirectoryAtPath:statePath withIntermediateDirectories:YES attributes:nil error:nil]);
        state=[NSMutableDictionary dictionary]; persist();
        landingActive=YES; launchReady=didLaunch;
        dm_sync_menu(NULL);
        assert(landingAtMenu && landingOptionCount==4 && !running);
        // Pair/restore completion returns to the page; it must not start a guest.
        lastError=@"Previous attempt failed";
        ready(); assert(!lastError && !running && landingActive && landingAtMenu);
        // Required save choices block Play, reject invalid indexes, and consume
        // a valid selection exactly once even if taps arrive before UI redraws.
        __block NSUInteger choices=0;
        choose(@"Choose progress",@"Synthetic conflict",@[@"Local",@"Cloud"],^(NSUInteger i){ choices++; });
        NSUInteger token=landingToken;
        landingAction(@{@"action":@"play",@"token":@(token)}); assert(!running);
        landingAction(@{@"action":@"select",@"token":@(token),@"index":@9}); assert(!choices);
        landingAction(@{@"action":@"select",@"token":@(token),@"index":@1}); assert(choices==1);
        landingAction(@{@"action":@"select",@"token":@(token),@"index":@1}); assert(choices==1);
        assert(!landingAtMenu && !running);
        // A failed recovery stays inline and blocks every form of play.
        dm_save_json([statePath stringByAppendingPathComponent:@"restore.json"],@{@"invalid":@YES});
        dm_sync_menu(NULL);
        landingAction(@{@"action":@"play",@"token":@(landingToken)});
        assert(!running && landingActive && !landingAtMenu && landingOptionCount==2);
        landingAction(@{@"action":@"choice-1",@"token":@(landingToken)});
        assert(landingAtMenu && !running); // Back does not bypass the recovery gate.
        landingAction(@{@"action":@"play",@"token":@(landingToken)});
        assert(!running && !landingAtMenu);
        [NSFileManager.defaultManager removeItemAtPath:[statePath stringByAppendingPathComponent:@"restore.json"] error:nil];
        // Explicit offline play preserves the pause choice before launch.
        credentials=@{@"device":@"test-device"}; dm_sync_menu(NULL);
        assert(landingOptionCount==6);
        landingAction(@{@"action":@"offline",@"token":@(landingToken)});
        assert(running && !landingActive && [state[@"offlinePaused"] boolValue]);
        assert([jsonFile([statePath stringByAppendingPathComponent:@"state.json"])[@"offlinePaused"] boolValue]);
        // The normal Play path also reconciles local-only saves before release.
        running=NO; landingActive=YES; credentials=nil; state=[NSMutableDictionary dictionary]; persist();
        dm_sync_menu(NULL); landingAction(@{@"action":@"play",@"token":@(landingToken)});
        assert(running && !landingActive);
        // Running UI offers useful actions only; it cannot import, restore or
        // pair under the guest. Named actions are independent of display order.
        NSObject *owner=[NSObject new], *other=[NSObject new];
        credentials=@{@"device":@"test-device"}; dashboardOpened(owner);
        NSArray *ids=[inlinePage[@"actions"] valueForKey:@"id"];
        assert(dashboardActive && [ids containsObject:@"sync"] && [ids containsObject:@"export"]);
        assert(![ids containsObject:@"import"] && ![ids containsObject:@"history"] && ![ids containsObject:@"connect"]);
        NSUInteger dashboardToken=landingToken;
        landingAction(@{@"action":@"play",@"token":@(dashboardToken)});
        assert(landingToken==dashboardToken); // The game cannot be launched twice.
        // One explicit Resume & sync starts verification directly, without a
        // confirmation/status dialog chain. No queued work means no HTTP here.
        state[@"offlinePaused"]=@YES; inlineMenu();
        assert([inlinePage[@"actions"][0][@"title"] isEqual:@"Resume & sync"]);
        landingAction(@{@"action":@"sync",@"token":@(landingToken)});
        assert(handoffWaiting && ![state[@"offlinePaused"] boolValue] && landingAtMenu);
        assert(![jsonFile([statePath stringByAppendingPathComponent:@"state.json"])[@"offlinePaused"] boolValue]);
        handoffWaiting=NO; remoteAdvanced=YES; inlineMenu();
        assert(![[inlinePage[@"actions"] valueForKey:@"id"] containsObject:@"sync"]);
        remoteAdvanced=NO;
        // Popping the old screen cannot close a newer one. Leaving the active
        // screen invalidates its choices; background work doesn't reopen it.
        dashboardOpened(other); dashboardClosed(owner); assert(dashboardActive);
        dashboardClosed(other); assert(!dashboardActive && !landingSelection);
        NSUInteger closedToken=landingToken;
        landingAction(@{@"action":@"export",@"token":@(dashboardToken)});
        assert(landingToken==closedToken);
        credentials=nil; dashboardOpened(owner);
        ids=[inlinePage[@"actions"] valueForKey:@"id"];
        assert(![ids containsObject:@"sync"] && ![ids containsObject:@"connect"] && [ids containsObject:@"export"]);
        dashboardClosed(owner);
    });
    while (!launched) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    puts("PASS: inline choices, explicit play/recovery gates, duplicate/stale actions, durable offline play, local reconciliation, dashboard capabilities and lifecycle");
} return 0; }
