// Exercise durable parent ordering, deduplication and pressure without a network.
#import "../save_sync.m"
#include <assert.h>
#include <fcntl.h>
void dm_fs_set_sync_callback(void (*callback)(void)) { (void)callback; }
void dm_fs_sync_capture(void) {}
int main(int argc,char **argv) { @autoreleasepool {
    assert(argc==2); NSString *base=@(argv[1]); statePath=[base stringByAppendingPathComponent:@"queue"];
    NSString *capture=[base stringByAppendingPathComponent:@"capture"], *root=[capture stringByAppendingPathComponent:@"account"];
    assert([NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil]);
    assert([NSFileManager.defaultManager createDirectoryAtPath:statePath withIntermediateDirectories:YES attributes:nil error:nil]);
    credentials=@{@"device":@"22345678-1234-4234-8234-123456789012"}; state=[NSMutableDictionary dictionary];
    NSString *file=[root stringByAppendingPathComponent:@"save"];
    assert([@"first" writeToFile:file atomically:NO encoding:NSUTF8StringEncoding error:nil]);
    pausePublication();
    assert([jsonFile([statePath stringByAppendingPathComponent:@"state.json"])[@"offlinePaused"] boolValue]);
    enqueue(capture,nil); enqueue(capture,nil); assert([state[@"queue"] count]==1);
    for (NSString *value in @[@"second",@"third"]) { assert([value writeToFile:file atomically:NO encoding:NSUTF8StringEncoding error:nil]); enqueue(capture,nil); }
    // A background-only restart must retain the pause and never construct a transport.
    state=[jsonFile([statePath stringByAppendingPathComponent:@"state.json"]) mutableCopy];
    pump(); assert(!transport && !uploading && [state[@"offlinePaused"] boolValue]);
    resumePublication(); assert(!jsonFile([statePath stringByAppendingPathComponent:@"state.json"])[@"offlinePaused"]);
    assert([state[@"queue"] count]==3); id parent=NSNull.null;
    for (NSDictionary *item in state[@"queue"]) {
        NSDictionary *m=[DMSaveArchive read:[statePath stringByAppendingPathComponent:item[@"file"]] into:nil];
        assert([m[@"parent"] isEqual:parent]); parent=m[@"revision"];
    }
    NSDictionary *disk=jsonFile([statePath stringByAppendingPathComponent:@"state.json"]); assert([disk isEqual:state]);
    assert([@"latest local" writeToFile:file atomically:NO encoding:NSUTF8StringEncoding error:nil]); enqueue(capture,nil);
    assert([state[@"queue"] count]==3); assert(![state[@"lastInventory"] isEqual:inventoryID([DMSaveArchive inventory:capture])]);
    state[@"blocked"]=@YES; enqueue(capture,nil); assert([state[@"queue"] count]==3);
    // A sparse retained-history file exercises the byte quota without allocating 257 MiB.
    NSString *large=[statePath stringByAppendingPathComponent:@"retained"];
    int fd=open(large.fileSystemRepresentation,O_CREAT|O_WRONLY,0600); assert(fd>=0 && ftruncate(fd,257u<<20)==0); close(fd);
    BOOL refused=NO; @try { enqueue(capture,NSNull.null); } @catch(NSException *e) { refused=YES; }
    assert(refused); assert([[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] isEqual:@"latest local"]);
    // Snapshot creation failure never mutates committed progress.
    savePath=root; statePath=file; atomic_store(&enabled,1); dm_sync_committed();
    assert([[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] isEqual:@"latest local"]);
    return 0;
} }
