// Synthetic local backup and coordinator transitions; no player files/network.
#import "../save_sync.m"
#include <assert.h>
static uint64_t commits;
@interface LateTask : NSObject
@property NSString *taskDescription;
@end
@implementation LateTask
@end
void dm_fs_set_sync_callback(void (*callback)(void)) {}
void dm_fs_sync_capture(void) {}
void dm_fs_capture_with(void (*callback)(void *), void *context) { callback(context); }
uint64_t dm_fs_commit_count(void) { return commits; }
static void put(NSString *path, NSString *value) { assert([value writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:nil]); }
int main(int argc, char **argv) { @autoreleasepool {
    assert(argc==2);
    worker=dispatch_queue_create("test.experience",DISPATCH_QUEUE_SERIAL);
    dispatch_queue_set_specific(worker,&workerKey,&workerKey,NULL);
    __block NSDictionary *callbackState;
    dispatch_sync(worker,^{
        NSString *base=@(argv[1]); savePath=[base stringByAppendingPathComponent:@"save"]; statePath=[base stringByAppendingPathComponent:@"state"];
        assert([NSFileManager.defaultManager createDirectoryAtPath:savePath withIntermediateDirectories:YES attributes:nil error:nil]);
        assert([NSFileManager.defaultManager createDirectoryAtPath:statePath withIntermediateDirectories:YES attributes:nil error:nil]);
        state=[NSMutableDictionary dictionary]; credentials=nil;
        NSString *data=[savePath stringByAppendingPathComponent:@"progress"];
        put(data,@"local offline progress");
        NSString *capture=captureCommitted(), *workspace=newWorkspace(@"export-");
        NSString *file=writeBackup(capture,workspace,YES);
        NSDictionary *manifest=[DMSaveArchive read:file into:nil];
        assert([manifest[@"title"] isEqual:@DM_GAME_ID]); assert(!credentials && ![state[@"queue"] count]);
        assert([makeStatus()[@"operation"] isEqual:@"localOnly"]);
        put(data,@"newer local progress");
        // Stage exactly the archive the file picker would select. The real import
        // install path must preserve the newer data as verified recovery content.
        NSString *stage=newWorkspace(@"import-"); NSString *input=[stage stringByAppendingPathComponent:@"selected.nxsave"];
        copyBounded([NSURL fileURLWithPath:file],input); installImport(input,stage);
        assert([[NSString stringWithContentsOfFile:data encoding:NSUTF8StringEncoding error:nil] isEqual:@"local offline progress"]);
        BOOL found=NO;
        for (NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:statePath error:nil]) if ([name hasPrefix:@"backup-"]) {
            NSString *old=[[[statePath stringByAppendingPathComponent:name] stringByAppendingPathComponent:@"account"] stringByAppendingPathComponent:@"progress"];
            if ([[NSString stringWithContentsOfFile:old encoding:NSUTF8StringEncoding error:nil] isEqual:@"newer local progress"]) found=YES;
        }
        assert(found);
        // Paired import keeps pending branches and the previous pause choice.
        credentials=@{@"device":@"22345678-1234-4234-8234-123456789012"};
        state=[@{@"base":@"12345678-1234-4234-8234-123456789012",@"queue":[NSMutableArray arrayWithObject:@{@"revision":@"32345678-1234-4234-8234-123456789012",@"file":@"retained.nxsave"}],@"offlinePaused":@YES} mutableCopy];
        persist(); stage=newWorkspace(@"import-"); input=[stage stringByAppendingPathComponent:@"selected.nxsave"]; copyBounded([NSURL fileURLWithPath:file],input);
        installImport(input,stage);
        assert([state[@"queue"] count]==1 && [state[@"offlinePaused"] boolValue] && [state[@"importNeedsReconciliation"] boolValue]);
        assert([makeStatus()[@"operation"] isEqual:@"conflict"]); pump(); assert(!transport && !uploading);
        assert([jsonFile([statePath stringByAppendingPathComponent:@"state.json"])[@"importNeedsReconciliation"] boolValue]);
        // A rejected archive must not replace progress or ancestry.
        stage=newWorkspace(@"import-"); input=[stage stringByAppendingPathComponent:@"selected.nxsave"]; put(input,@"malformed");
        NSDictionary *before=[state copy]; installImport(input,stage);
        assert([before isEqual:state]); assert([[NSString stringWithContentsOfFile:data encoding:NSUTF8StringEncoding error:nil] isEqual:@"local offline progress"]);
        // Wrong-title archives and outstanding transfers cannot change live data.
        stage=newWorkspace(@"import-"); input=[stage stringByAppendingPathComponent:@"selected.nxsave"];
        NSMutableDictionary *wrong=[manifest mutableCopy]; wrong[@"title"]=@"0100000000000000";
        [DMSaveArchive write:wrong capture:capture to:input]; installImport(input,stage); assert([before isEqual:state]);
        stage=newWorkspace(@"import-"); input=[stage stringByAppendingPathComponent:@"selected.nxsave"]; copyBounded([NSURL fileURLWithPath:file],input);
        uploading=YES; installImport(input,stage); assert([before isEqual:state]); uploading=NO;
        // Pending captures and commits invalidate readiness even with an empty queue.
        NSString *revision=@"12345678-1234-4234-8234-123456789012";
        state=[@{@"base":revision,@"queue":[NSMutableArray array]} mutableCopy];
        localDirty=NO; lastError=nil; handoffWaiting=YES; processedCommit=commits=4;
        NSDictionary *head=@{@"revision":revision,@"deviceName":@"Test device"};
        finishHandoff(head,4,revision); assert([makeStatus()[@"handoffReady"] boolValue]);
        commits++; assert(![makeStatus()[@"handoffReady"] boolValue]); assert([makeStatus()[@"pendingLocalChanges"] boolValue]);
        handoffRevision=nil; handoffWaiting=YES; captures=1; finishHandoff(head,5,revision); assert(!handoffRevision); captures=0;
        processedCommit=5; handoffWaiting=YES; finishHandoff(head,5,revision); assert([makeStatus()[@"handoffReady"] boolValue]);
        handoffWaiting=YES; finishHandoff(@{@"revision":@"other"},5,revision); assert(![makeStatus()[@"handoffReady"] boolValue]);
        state[@"offlinePaused"]=@YES; handoffWaiting=YES; finishHandoff(head,5,revision); assert(!handoffRevision);
        assert([makeStatus()[@"operation"] isEqual:@"offlinePaused"]);
        [state removeObjectForKey:@"offlinePaused"]; lastError=@"Receipt unknown";
        assert([makeStatus()[@"operation"] isEqual:@"recoveryRequired"]);
        // Export cancellation only removes its disposable workspace.
        [NSFileManager.defaultManager removeItemAtPath:workspace error:nil];
        assert([NSFileManager.defaultManager fileExistsAtPath:data]);
        // An old completion after import must not acknowledge or remove a branch,
        // even if publication had not been paused before the import.
        state=[@{@"base":revision,@"queue":[NSMutableArray arrayWithObject:@{@"revision":revision,@"file":@"old.nxsave"}],@"importNeedsReconciliation":@YES} mutableCopy];
        callbackState=[state copy]; LateTask *old=[LateTask new]; old.taskDescription=revision;
        [[DMSaveTransport alloc] URLSession:NSURLSession.sharedSession task:(id)old didCompleteWithError:nil];
    });
    dispatch_sync(worker,^{
        assert([state isEqual:callbackState]);
        uploading=YES; LateTask *stale=[LateTask new]; stale.taskDescription=@"unrelated old task";
        [[DMSaveTransport alloc] URLSession:NSURLSession.sharedSession task:(id)stale didCompleteWithError:nil];
    });
    dispatch_sync(worker,^{
        assert(uploading && [state isEqual:callbackState]);
        puts("PASS: backup round-trip/recovery, paired import ancestry/pause, malformed/wrong-title/in-flight import rejection, stale callbacks, capture/commit/head handoff races");
    });
} return 0; }
