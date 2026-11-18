// Runs the production NSURLSession/head-check path against the Postman fixture.
#import "../save_sync.m"
#include <assert.h>
static _Atomic uint64_t commits;
void dm_fs_set_sync_callback(void (*callback)(void)) {}
void dm_fs_sync_capture(void) {}
void dm_fs_capture_with(void (*callback)(void *), void *context) { callback(context); }
uint64_t dm_fs_commit_count(void) { return commits; }
int main(int argc, char **argv) { @autoreleasepool {
    assert(argc==2); NSString *server=@(argv[1]);
    worker=dispatch_queue_create("test.http",DISPATCH_QUEUE_SERIAL); dispatch_queue_set_specific(worker,&workerKey,&workerKey,NULL);
    for (NSString *mode in @[@"ok",@"new-head",@"revoked",@"html",@"lost",@"commit"]) {
        dispatch_sync(worker,^{
            credentials=@{@"server":[server stringByAppendingFormat:@"/%@",mode],@"token":@"synthetic"};
            state=[@{@"base":@"12345678-1234-4234-8234-123456789012",@"queue":[NSMutableArray array]} mutableCopy];
            processedCommit=commits=0; lastError=nil; remoteAdvanced=NO; localDirty=NO; handoffRevision=nil; handoffWaiting=YES;
            if ([mode isEqual:@"commit"]) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{ commits++; });
            checkHandoff();
            if ([makeStatus()[@"handoffReady"] boolValue] != [mode isEqual:@"ok"]) fprintf(stderr,"Scenario %s: %s\n",mode.UTF8String,currentStatus().UTF8String);
            assert([makeStatus()[@"handoffReady"] boolValue] == [mode isEqual:@"ok"]);
            if ([mode isEqual:@"new-head"]) assert(remoteAdvanced);
            if ([mode isEqual:@"commit"]) assert(commits==1 && handoffWaiting);
            printf("PASS: real HTTP handoff %s\n",mode.UTF8String);
        });
    }
} return 0; }
