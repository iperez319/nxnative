#import "../apple/save_sync.h"
#import <Security/Security.h>
#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
extern void dm_host_present(void *parent, void *controller);
#else
#import <AppKit/AppKit.h>
#endif
#include <sys/clonefile.h>
#include <stdatomic.h>
#include <sys/stat.h>
#include <errno.h>
#include "game_profile.h"

static NSString *savePath, *statePath;
static dispatch_queue_t worker;
static NSMutableDictionary *state;
static NSDictionary *credentials;
static NSString *statusText=@"Saved locally";
static _Atomic int enabled, captures;
static _Atomic int running;
static BOOL uploading, localDirty, importing, handoffWaiting;
static NSString *lastError, *handoffRevision;
static uint64_t processedCommit, handoffCommit, handoffAttempt;
extern uint64_t dm_fs_commit_count(void);
static NSDictionary *statusSnapshot;
static void checkHandoff(void);
static char workerKey;
static _Atomic int remoteAdvanced;
static dispatch_source_t retryTimer;
static void (^backgroundDone)(void);
static void (*launchReady)(void);
static __weak id presenter;
static __weak id activeStatusAlert;
static BOOL landingActive, dashboardActive, landingAtMenu, launchRequested;
static NSUInteger landingToken;
static NSUInteger landingOptionCount;
static void (^landingSelection)(NSUInteger);
static NSDictionary *inlinePage;
static void pump(void);
static void reconcile(void);
static void cancelOutstanding(void);
// State snapshots are assembled only by the serial coordinator, never by a UI
// callback or under filesystem locks. Text is presentation, not state detection.
static NSDictionary *makeStatus(void) {
    NSString *operation = @"pending", *label = @"Saved locally";
    BOOL pending = captures || localDirty || processedCommit != dm_fs_commit_count() || [state[@"queue"] count];
    if (!credentials) { operation = @"localOnly"; label = @"Local only"; }
    else if ([state[@"importNeedsReconciliation"] boolValue] || [state[@"blocked"] boolValue]) { operation = @"conflict"; label = @"Choose progress"; }
    else if ([state[@"offlinePaused"] boolValue]) { operation = @"offlinePaused"; label = @"Uploads paused"; }
    else if (remoteAdvanced) { operation = @"remoteAdvanced"; label = @"Restart to load"; }
    else if (lastError || [state[@"paused"] boolValue]) { operation = @"recoveryRequired"; label = @"Needs attention"; }
    else if (uploading) { operation = @"uploading"; label = @"Uploading"; }
    else if (!pending && state[@"base"] && state[@"base"] != NSNull.null) { operation = @"uploaded"; label = @"Uploaded"; }
    BOOL ready = handoffRevision && [handoffRevision isEqual:state[@"base"]] && handoffCommit == dm_fs_commit_count() && [operation isEqual:@"uploaded"];
    return @{@"operation":operation, @"label":label, @"message":statusText,
        @"paired":@(credentials!=nil), @"running":@(running),
        @"recoveryPending":@(statePath && [NSFileManager.defaultManager fileExistsAtPath:[statePath stringByAppendingPathComponent:@"restore.json"]]),
        @"pendingCaptures":@(captures), @"pendingUploads":@([state[@"queue"] count]),
        @"pendingLocalChanges":@(pending), @"localRevision":(captures || localDirty || processedCommit != dm_fs_commit_count()) ? NSNull.null : ([[state[@"queue"] lastObject] objectForKey:@"revision"] ?: state[@"base"] ?: NSNull.null),
        @"acknowledgedRevision":state[@"base"] ?: NSNull.null,
        @"lastConfirmedUpload":state[@"lastConfirmedUpload"] ?: NSNull.null,
        @"sourceDevice":state[@"sourceDevice"] ?: NSNull.null,
        @"pausedReason":[state[@"offlinePaused"] boolValue] ? @"user" : lastError ?: ([state[@"paused"] boolValue] ? @"transport" : @""),
        @"handoffReady":@(ready), @"handoffWaiting":@(handoffWaiting),
        @"actions":credentials ? @[@"sync", @"handoff", @"export", @"restartToRestore"] : @[@"pairBeforeLaunch", @"export"]};
}
static NSString *formatStatus(NSDictionary *s);
NSDictionary *dm_sync_status_snapshot(void) { @synchronized(DMSaveArchive.class) { return statusSnapshot; } }
static void setStatus(NSString *s) {
    if (worker && !dispatch_get_specific(&workerKey)) { dispatch_async(worker, ^{ setStatus(s); }); return; }
    statusText = [s copy];
    NSDictionary *snapshot = makeStatus();
    @synchronized(DMSaveArchive.class) { statusSnapshot = snapshot; }
    dispatch_async(dispatch_get_main_queue(),^{
        [NSNotificationCenter.defaultCenter postNotificationName:@"DMSaveSyncStatus" object:snapshot];
#if TARGET_OS_IPHONE
        [activeStatusAlert setMessage:formatStatus(snapshot)];
#else
        [activeStatusAlert setInformativeText:formatStatus(snapshot)];
#endif
    });
}
static NSString *formatStatus(NSDictionary *s) {
    id revision=s[@"acknowledgedRevision"], time=s[@"lastConfirmedUpload"], device=s[@"sourceDevice"];
    return [NSString stringWithFormat:@"%@\n%@\nPending captures: %@ · uploads: %@\nAcknowledged revision: %@\nConfirmed upload: %@\nSource device: %@\nSave in-game first; only committed files are transferred.", s[@"label"], s[@"message"], s[@"pendingCaptures"], s[@"pendingUploads"], revision==NSNull.null ? @"unknown" : revision, time==NSNull.null ? @"unknown" : time, device==NSNull.null ? @"unknown" : device];
}
static NSString *currentStatus(void) { return formatStatus(makeStatus()); }
static NSString *displaySaveTime(id value) {
    NSDate *date=[value isKindOfClass:NSString.class] ? [NSISO8601DateFormatter.new dateFromString:value] : nil;
    return date ? [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle] : @"Unknown save time";
}
static void problem(NSString *s) { @throw [NSException exceptionWithName:@"SaveSync" reason:s userInfo:nil]; }
static NSDictionary *jsonFile(NSString *p) { NSData *d=[NSData dataWithContentsOfFile:p]; return d?[NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:nil]:nil; }
static void persist(void) { dm_save_json([statePath stringByAppendingPathComponent:@"state.json"],state); }
static NSString *inventoryID(NSDictionary *m) { return dm_save_hash([NSJSONSerialization dataWithJSONObject:@{@"roots":m[@"roots"],@"entries":m[@"entries"]} options:NSJSONWritingSortedKeys error:nil]); }
static NSString *keyService(void) { return [@"org.nxnative.cloud-save." stringByAppendingString:@DM_GAME_ID]; }
static NSDictionary *keyQuery(void) { return @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,(__bridge id)kSecAttrService:keyService(),(__bridge id)kSecAttrAccount:@"default"}; }
static NSDictionary *readCredentials(void) {
    NSMutableDictionary *q=[keyQuery() mutableCopy]; q[(__bridge id)kSecReturnData]=@YES; CFTypeRef value=NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)q,&value)!=errSecSuccess) return nil;
    NSData *data=CFBridgingRelease(value); return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
}
static void storeCredentials(NSDictionary *c) {
    NSData *data=[NSJSONSerialization dataWithJSONObject:c options:0 error:nil];
    NSDictionary *a=@{(__bridge id)kSecValueData:data,(__bridge id)kSecAttrAccessible:(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly};
    OSStatus rc=SecItemUpdate((__bridge CFDictionaryRef)keyQuery(),(__bridge CFDictionaryRef)a);
    if (rc==errSecItemNotFound) { NSMutableDictionary *q=[keyQuery() mutableCopy]; [q addEntriesFromDictionary:a]; rc=SecItemAdd((__bridge CFDictionaryRef)q,NULL); }
    if (rc!=errSecSuccess) problem(@"Could not save pairing in Keychain"); credentials=c; atomic_store(&enabled,1);
}
static NSString *api(NSString *suffix) { return [NSString stringWithFormat:@"%@/v1/games/%s/profiles/default/%@",credentials[@"server"],DM_GAME_ID,suffix]; }
@interface DMSaveRequest : NSObject <NSURLSessionDataDelegate>
@property NSMutableData *data;
@property dispatch_semaphore_t done;
@property NSInteger code;
@property NSUInteger limit;
@end
@implementation DMSaveRequest
- (void)URLSession:(NSURLSession *)s task:(NSURLSessionTask *)t willPerformHTTPRedirection:(NSHTTPURLResponse *)r newRequest:(NSURLRequest *)n completionHandler:(void (^)(NSURLRequest *))handler { handler(nil); }
- (void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t didReceiveResponse:(NSURLResponse *)r completionHandler:(void (^)(NSURLSessionResponseDisposition))handler {
    self.code=[(NSHTTPURLResponse *)r statusCode];
    handler(r.expectedContentLength>(int64_t)self.limit?NSURLSessionResponseCancel:NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t didReceiveData:(NSData *)d {
    if (d.length>self.limit-self.data.length) { self.code=0; [t cancel]; } else [self.data appendData:d];
}
- (void)URLSession:(NSURLSession *)s task:(NSURLSessionTask *)t didCompleteWithError:(NSError *)e { if (e) self.code=0; dispatch_semaphore_signal(self.done); }
@end
static NSData *request(NSString *url, NSString *method, NSData *body, NSInteger *code) {
    NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30]; r.HTTPMethod=method; r.HTTPBody=body;
    if (credentials[@"token"] && ![url hasSuffix:@"/v1/pair"]) [r setValue:[@"Bearer " stringByAppendingString:credentials[@"token"]] forHTTPHeaderField:@"Authorization"];
    if (body) [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    DMSaveRequest *delegate=[DMSaveRequest new]; delegate.data=[NSMutableData data]; delegate.done=dispatch_semaphore_create(0); delegate.limit=[url hasSuffix:@"/archive"]?(128u<<20):(16u<<20);
    NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration; config.timeoutIntervalForResource=60;
    NSURLSession *session=[NSURLSession sessionWithConfiguration:config delegate:delegate delegateQueue:nil];
    [[session dataTaskWithRequest:r] resume]; dispatch_semaphore_wait(delegate.done,DISPATCH_TIME_FOREVER); [session invalidateAndCancel]; *code=delegate.code; return delegate.code?delegate.data:nil;
}
static NSDictionary *get(NSString *suffix) {
    NSInteger code; NSData *d=request(api(suffix),@"GET",nil,&code);
    if (code!=200) problem(code==401?@"Pairing revoked — pair again":@"Cloud could not be checked");
    NSDictionary *v=[NSJSONSerialization JSONObjectWithData:d options:0 error:nil]; if (![v isKindOfClass:NSDictionary.class]) problem(@"Invalid server response"); return v;
}
static NSDictionary *compatibility(void) {
    NSMutableArray *builds=[NSMutableArray array], *dlc=[NSMutableArray array];
    NSString *dm=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"dm"];
    if (![NSFileManager.defaultManager fileExistsAtPath:dm]) dm=NSProcessInfo.processInfo.arguments.count>1?NSProcessInfo.processInfo.arguments[1]:@".";
    for (NSString *file in [[NSFileManager.defaultManager contentsOfDirectoryAtPath:dm error:nil] sortedArrayUsingSelector:@selector(compare:)]) if ([file hasSuffix:@".fixups.tsv"]) {
        NSString *text=[NSString stringWithContentsOfFile:[dm stringByAppendingPathComponent:file] encoding:NSUTF8StringEncoding error:nil];
        for (NSString *line in [text componentsSeparatedByString:@"\n"]) if ([line hasPrefix:@"# BUILD_ID"]) [builds addObject:[NSString stringWithFormat:@"%@:%@",file,line]];
    }
    const char *aoc=getenv("DM_AOC_DIR"); if (aoc) [dlc addObjectsFromArray:[[NSFileManager.defaultManager contentsOfDirectoryAtPath:@(aoc) error:nil] sortedArrayUsingSelector:@selector(compare:)]?:@[]];
    return @{@"version":[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]?:@"unknown",@"builds":builds,@"dlc":dlc};
}
static NSString *captureNow(void) {
    NSString *path=[statePath stringByAppendingPathComponent:[@"capture-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    if (![NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil]) return nil;
    for (NSString *root in @[@"account",@"device"]) {
        NSString *source=[root isEqual:@"account"]?savePath:[savePath stringByAppendingString:@"_device"];
        struct stat info;
        int rc=lstat(source.fileSystemRepresentation,&info);
        if ((rc && errno!=ENOENT) || (!rc && (!S_ISDIR(info.st_mode) || clonefile(source.fileSystemRepresentation,[path stringByAppendingPathComponent:root].fileSystemRepresentation,0)))) {
            [NSFileManager.defaultManager removeItemAtPath:path error:nil]; return nil;
        }
    }
    return path;
}
static unsigned long long localBytes(void) {
    unsigned long long bytes=0;
    for (NSString *p in [NSFileManager.defaultManager enumeratorAtPath:statePath]) bytes += [[NSFileManager.defaultManager attributesOfItemAtPath:[statePath stringByAppendingPathComponent:p] error:nil] fileSize];
    return bytes;
}
static void enqueue(NSString *capture, id parentOverride) {
    NSDictionary *inventory=[DMSaveArchive inventory:capture]; NSString *identity=inventoryID(inventory);
    NSMutableArray *queue=state[@"queue"]; if (!queue) state[@"queue"]=queue=[NSMutableArray array];
    if (!parentOverride && [state[@"lastInventory"] isEqual:identity]) { localDirty=NO; if (!queue.count && ![state[@"blocked"] boolValue]) setStatus(state[@"base"] && state[@"base"]!=NSNull.null?@"Uploaded":@"Saved locally"); return; }
    localDirty=YES;
    if (localBytes() > (256u<<20)) problem(@"Saved locally — snapshot storage full");
    if (queue.count>=3 || [state[@"blocked"] boolValue]) { setStatus([state[@"blocked"] boolValue]?@"Conflict":@"Saved locally — queue full"); return; }
    NSString *revision=NSUUID.UUID.UUIDString.lowercaseString;
    id parent=parentOverride?:([queue.lastObject objectForKey:@"revision"]?:state[@"base"]?:NSNull.null);
    NSMutableDictionary *m=[inventory mutableCopy]; [m addEntriesFromDictionary:@{@"format":@1,@"revision":revision,@"parent":parent,@"title":@DM_GAME_ID,@"profile":@"default",@"device":credentials[@"device"],@"displayTime":[NSISO8601DateFormatter.new stringFromDate:NSDate.date],@"compatibility":compatibility()}];
    NSString *filename=[revision stringByAppendingString:@".nxsave"], *path=[statePath stringByAppendingPathComponent:filename];
    [DMSaveArchive write:m capture:capture to:path];
    [queue addObject:[@{@"revision":revision,@"file":filename,@"inventory":identity} mutableCopy]]; state[@"lastInventory"]=identity; localDirty=NO; persist();
    if ([state[@"offlinePaused"] boolValue]) setStatus(@"Offline — uploads paused");
}
static void pausePublication(void) {
    state[@"offlinePaused"]=@YES;
    persist(); // survive process termination and background-only relaunch
    cancelOutstanding();
    setStatus(@"Offline — uploads paused");
}
static void resumePublication(void) {
    [state removeObjectForKey:@"offlinePaused"];
    persist();
}
static void landingChooseContext(NSString *title, NSString *message, NSArray *options, BOOL menu, NSDictionary *context, void (^selected)(NSUInteger)) {
    landingAtMenu=menu; landingSelection=[selected copy]; landingOptionCount=options.count;
    NSMutableArray *actions=[NSMutableArray array];
    for (NSUInteger i=0;i<options.count;i++) [actions addObject:@{@"id":[NSString stringWithFormat:@"choice-%lu",(unsigned long)i], @"title":options[i]}];
    NSMutableDictionary *values=[@{@"title":title, @"message":message, @"options":options, @"actions":actions, @"menu":@(menu), @"running":@(running), @"token":@(++landingToken)} mutableCopy];
    if (context) [values addEntriesFromDictionary:context];
    NSDictionary *page=[values copy]; inlinePage=page;
    dispatch_async(dispatch_get_main_queue(),^{ [NSNotificationCenter.defaultCenter postNotificationName:@"DMSaveLauncherState" object:page]; });
}
static void landingChoose(NSString *title, NSString *message, NSArray *options, BOOL menu, void (^selected)(NSUInteger)) {
    landingChooseContext(title,message,options,menu,nil,selected);
}
static void ready(void) {
    // A completed reconciliation/restore must not keep presenting a transient
    // error from an earlier attempt as the current state.
    lastError=nil;
    // Pairing and restoring from the landing page return to it. Only an explicit
    // Play (or Play offline) may release the guest's prelaunch gate.
    if (landingActive && !launchRequested) { setStatus(statusText); dm_sync_menu(NULL); return; }
    landingActive=NO; landingSelection=nil;
    running=YES;
    setStatus(statusText);
    dispatch_async(dispatch_get_main_queue(),^{ if (launchReady) { void (*fn)(void)=launchReady; launchReady=NULL; fn(); } });
}
static void chooseContext(NSString *title, NSString *message, NSArray<NSString *> *options, NSDictionary *context, void (^selected)(NSUInteger)) {
    if (landingActive || dashboardActive) { landingChooseContext(title,message,options,NO,context,selected); return; }
#if TARGET_OS_IPHONE
    if (running) return; // The player may have closed the dashboard during work.
#endif
    for (NSDictionary *copy in context[@"comparisons"]) message=[message stringByAppendingFormat:@"\n%@: %@ · version %@ · saved %@",copy[@"title"],copy[@"device"],copy[@"version"],copy[@"time"]==NSNull.null ? @"unknown" : copy[@"time"]];
    dispatch_async(dispatch_get_main_queue(),^{
#if TARGET_OS_IPHONE
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        for (NSUInteger i=0;i<options.count;i++) [alert addAction:[UIAlertAction actionWithTitle:options[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ dispatch_async(worker,^{selected(i);}); }]];
        if (running && [title isEqual:@"Cloud saves"]) activeStatusAlert=alert;
        dm_host_present((__bridge void *)presenter, (__bridge void *)alert);
#else
        NSAlert *alert=[NSAlert new]; alert.messageText=title; alert.informativeText=message;
        if (running && [title isEqual:@"Cloud saves"]) activeStatusAlert=alert;
        for (NSString *s in options) [alert addButtonWithTitle:s]; NSUInteger i=[alert runModal]-NSAlertFirstButtonReturn; dispatch_async(worker,^{selected(i);});
#endif
    });
}
static void choose(NSString *title, NSString *message, NSArray<NSString *> *options, void (^selected)(NSUInteger)) {
    chooseContext(title,message,options,nil,selected);
}
static void protectedAction(void (^action)(void)) {
    @try { action(); } @catch (NSException *e) { lastError=e.reason; setStatus(e.reason); choose(@"Save operation paused",e.reason,@[@"Back"],^(NSUInteger i){ dm_sync_menu(NULL); }); }
}

@interface DMSaveTransport : NSObject <NSURLSessionDataDelegate>
@property NSURLSession *session;
@end
static DMSaveTransport *transport;
@implementation DMSaveTransport
- (void)URLSession:(NSURLSession *)s task:(NSURLSessionTask *)t willPerformHTTPRedirection:(NSHTTPURLResponse *)r newRequest:(NSURLRequest *)n completionHandler:(void (^)(NSURLRequest *))handler { handler(nil); }
- (instancetype)init {
    if ((self=[super init])) {
        NSString *identifier=[NSString stringWithFormat:@"%@.cloud-save.v1",NSBundle.mainBundle.bundleIdentifier?:keyService()];
#if TARGET_OS_IPHONE
        NSURLSessionConfiguration *config=[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier]; config.sessionSendsLaunchEvents=YES; config.discretionary=NO;
#else
        NSURLSessionConfiguration *config=NSURLSessionConfiguration.defaultSessionConfiguration; (void)identifier;
#endif
        config.requestCachePolicy=NSURLRequestReloadIgnoringLocalCacheData;
        self.session=[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    } return self;
}
- (void)URLSession:(NSURLSession *)s task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    dispatch_async(worker,^{
        @try {
            NSDictionary *current=[state[@"queue"] firstObject];
            if (![current[@"revision"] isEqual:task.taskDescription]) return;
            uploading=NO;
            if ([state[@"offlinePaused"] boolValue] || [state[@"importNeedsReconciliation"] boolValue]) { setStatus(@"Publication paused — reconcile before uploading"); return; }
            NSMutableArray *q=state[@"queue"]; NSDictionary *item=q.firstObject;
            if (!item || ![item[@"revision"] isEqual:task.taskDescription]) return;
            NSInteger code=[(NSHTTPURLResponse *)task.response statusCode];
            if (error || (code!=200 && code!=409)) {
                unsigned attempts=MIN(5,[state[@"attempts"] unsignedIntValue]+1); state[@"attempts"]=@(attempts);
                state[@"retryAfter"]=@([NSDate.date timeIntervalSince1970]+MIN(900,30*(1u<<attempts)));
                state[@"paused"]=@(code==401 || code==413 || code==422 || code==507); persist();
                setStatus(code==401?@"Offline — pair again":code==507?@"Saved locally — server storage full":@"Saved locally"); return;
            }
            NSDictionary *receipt=get([@"revisions/" stringByAppendingString:item[@"revision"]]);
            NSData *sent=[NSData dataWithContentsOfFile:[statePath stringByAppendingPathComponent:item[@"file"]]];
            if (!sent || ![receipt[@"sha256"] isEqual:dm_save_hash(sent)]) { state[@"paused"]=@YES; persist(); setStatus(@"Saved locally — receipt mismatch"); return; }
            if (![receipt[@"published"] boolValue]) { state[@"blocked"]=@YES; persist(); setStatus(@"Conflict — restart to choose progress"); return; }
            state[@"attempts"]=@0; [state removeObjectForKey:@"retryAfter"]; state[@"paused"]=@NO;
            lastError=nil; state[@"lastConfirmedUpload"]=[NSISO8601DateFormatter.new stringFromDate:NSDate.date];
            state[@"base"]=item[@"revision"]; state[@"baseInventory"]=item[@"inventory"]; NSString *file=item[@"file"]; [q removeObjectAtIndex:0]; persist();
            [NSFileManager.defaultManager removeItemAtPath:[statePath stringByAppendingPathComponent:file] error:nil];
            setStatus(@"Saved locally"); dm_fs_sync_capture(); pump();
        } @catch (NSException *e) { lastError=e.reason; setStatus(e.reason); }
    });
}
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    dispatch_async(worker,^{dispatch_async(dispatch_get_main_queue(),^{if (backgroundDone) { void (^done)(void)=backgroundDone; backgroundDone=nil; done(); }});});
}
@end
static void cancelOutstanding(void) {
    if (!transport) return;
    [transport.session getAllTasksWithCompletionHandler:^(NSArray<NSURLSessionTask *> *tasks) {
        dispatch_async(worker,^{if ([state[@"offlinePaused"] boolValue]) for (NSURLSessionTask *task in tasks) [task cancel];});
    }];
}
static void pump(void) {
    if (!credentials || remoteAdvanced || importing || uploading || [state[@"importNeedsReconciliation"] boolValue] || [state[@"offlinePaused"] boolValue] || [state[@"blocked"] boolValue] || [state[@"paused"] boolValue] || [state[@"retryAfter"] doubleValue]>[NSDate.date timeIntervalSince1970]) return;
    @try { persist(); } @catch(NSException *e) { setStatus(@"Saved locally"); return; }
    if (!transport) transport=[DMSaveTransport new];
    NSDictionary *item=[state[@"queue"] firstObject]; if (!item) return;
    uploading=YES;
    [transport.session getAllTasksWithCompletionHandler:^(NSArray<NSURLSessionTask *> *tasks) {
        dispatch_async(worker,^{ @try {
            if ([state[@"offlinePaused"] boolValue] || importing || [state[@"importNeedsReconciliation"] boolValue]) { uploading=NO; return; }
            if (![[[state[@"queue"] firstObject] objectForKey:@"revision"] isEqual:item[@"revision"]]) { uploading=NO; pump(); return; }
            for (NSURLSessionTask *t in tasks) if ([t.taskDescription isEqual:item[@"revision"]]) { [t resume]; setStatus(@"Uploading"); return; }
            NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:api([@"revisions/" stringByAppendingString:item[@"revision"]])]];
            r.HTTPMethod=@"PUT"; [r setValue:[@"Bearer " stringByAppendingString:credentials[@"token"]] forHTTPHeaderField:@"Authorization"]; [r setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
            NSURLSessionUploadTask *task=[transport.session uploadTaskWithRequest:r fromFile:[NSURL fileURLWithPath:[statePath stringByAppendingPathComponent:item[@"file"]]]]; task.taskDescription=item[@"revision"]; [task resume]; setStatus(@"Uploading");
        } @catch(NSException *e) { uploading=NO; setStatus(@"Saved locally"); } });
    }];
}
void dm_sync_committed(void) {
    if (!atomic_load(&enabled)) return;
    if (atomic_fetch_add(&captures,1)>=2) { atomic_fetch_sub(&captures,1); dispatch_async(worker, ^{ setStatus(@"Saved locally — capture pending"); }); return; }
    @autoreleasepool {
        uint64_t commit = dm_fs_commit_count();
        dispatch_async(worker, ^{ setStatus(@"Saved locally — capture pending"); });
        NSString *snapshot=captureNow();
        if (!snapshot) { atomic_fetch_sub(&captures,1); dispatch_async(worker, ^{ localDirty=YES; lastError=@"Cannot capture committed roots"; setStatus(lastError); }); return; }
        dispatch_async(worker,^{
            @try { enqueue(snapshot,nil); processedCommit=commit; lastError=nil; pump(); }
            @catch (NSException *e) { localDirty=YES; lastError=e.reason; }
            [NSFileManager.defaultManager removeItemAtPath:snapshot error:nil]; atomic_fetch_sub(&captures,1);
            setStatus(lastError ?: @"Committed files captured"); checkHandoff();
        });
    }
}
static void finishHandoff(NSDictionary *head, uint64_t commit, NSString *revision) {
    if (![head[@"revision"] isEqual:revision] || ![state[@"base"] isEqual:revision] || localDirty || uploading || [state[@"queue"] count] || [state[@"blocked"] boolValue] || [state[@"offlinePaused"] boolValue]) { handoffWaiting=NO; handoffRevision=nil; return; }
        state[@"sourceDevice"]=head[@"deviceName"] ?: head[@"manifest"][@"device"] ?: @"unknown";
        if (commit != dm_fs_commit_count() || captures) { setStatus(@"New local save — waiting for its upload"); return; }
        handoffRevision=revision; handoffCommit=commit; handoffWaiting=NO;
        setStatus([NSString stringWithFormat:@"Committed save uploaded — check cloud on the other device\nRevision: %@\nConfirmed: %@",revision,state[@"lastConfirmedUpload"] ?: @"unknown"]);
}
static void checkHandoff(void) {
    if (!handoffWaiting || captures || uploading || [state[@"queue"] count]) return;
    if (localDirty || processedCommit != dm_fs_commit_count() || lastError || [state[@"blocked"] boolValue] || [state[@"paused"] boolValue] || [state[@"offlinePaused"] boolValue] || [state[@"importNeedsReconciliation"] boolValue]) {
        handoffWaiting=NO; setStatus(@"Handoff not confirmed — inspect save status and retry"); return;
    }
    @try {
        uint64_t commit=dm_fs_commit_count(); id revision=state[@"base"];
        id head=get(@"head")[@"head"];
        if (head == NSNull.null || !revision || revision == NSNull.null || ![head[@"revision"] isEqual:revision]) {
            remoteAdvanced=YES; handoffWaiting=NO; setStatus(@"Cloud head changed — restart to reconcile; handoff not confirmed"); return;
        }
        finishHandoff(head,commit,revision);
    } @catch (NSException *e) { handoffWaiting=NO; lastError=e.reason; setStatus(@"Handoff not confirmed — cloud could not be checked"); }
}
static void runSync(BOOL handoff) {
    protectedAction(^{
        resumePublication(); lastError=nil; state[@"paused"]=@NO; [state removeObjectForKey:@"retryAfter"]; persist();
        handoffWaiting=handoff; handoffRevision=nil;
        uint64_t attempt=++handoffAttempt;
        if (handoff) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,90*NSEC_PER_SEC),worker,^{
            if (handoffWaiting && attempt==handoffAttempt) { handoffWaiting=NO; setStatus(@"Cloud check timed out. Saved progress stays queued; you can retry."); }
        });
        setStatus(@"Checking saved progress…");
        dm_fs_sync_capture(); pump();
        if (dashboardActive) dm_sync_menu(NULL);
        else choose(@"Cloud saves",currentStatus(),@[@"Close"],^(NSUInteger n){});
    });
}
static void syncNow(BOOL handoff) {
    if (!credentials) { choose(@"Cloud saves are off",@"Set up cloud saves before starting the game. You can still export a backup file.",@[@"Back"],^(NSUInteger i){dm_sync_menu(NULL);}); return; }
    if ([state[@"importNeedsReconciliation"] boolValue] || remoteAdvanced || [state[@"blocked"] boolValue]) { choose(@"Choose a save before syncing",@"Close and reopen the app to choose the progress to keep. Your local save and existing backups are preserved.",@[@"Back"],^(NSUInteger i){dm_sync_menu(NULL);}); return; }
    // The live screen explains the save-first requirement beside this action.
    // Resume & sync is an explicit request to leave offline mode.
    if (dashboardActive) { runSync(YES); return; }
    choose(handoff ? @"Prepare to switch devices" : @"Sync committed saves",@"Save in-game first. Continue resumes paused uploads and transfers committed files only. Closing the status screen does not discard queued work.",@[@"Continue",@"Cancel"],^(NSUInteger i){ if (!i) runSync(handoff); });
}
static void recoverIfNeeded(void) {
    if (![NSFileManager.defaultManager fileExistsAtPath:[statePath stringByAppendingPathComponent:@"restore.json"]]) return;
    [DMSaveArchive recover:statePath save:savePath];
    state=[jsonFile([statePath stringByAppendingPathComponent:@"state.json"]) mutableCopy] ?: [NSMutableDictionary dictionary];
}
static void installReceipt(NSDictionary *receipt, NSDictionary *head) {
    recoverIfNeeded();
    if (localBytes() > (256u<<20)) problem(@"Local snapshot storage is full. Export retained backups before restoring more history.");
    NSString *revision=receipt[@"revision"]; NSInteger code; NSData *bytes=request(api([NSString stringWithFormat:@"revisions/%@/archive",revision]),@"GET",nil,&code);
    if (code!=200 || ![dm_save_hash(bytes?:NSData.data) isEqual:receipt[@"sha256"]]) problem(@"Archive download failed verification");
    NSString *file=[statePath stringByAppendingPathComponent:@"download.nxsave"], *stage=[statePath stringByAppendingPathComponent:[@"stage-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    dm_save_atomic(file,bytes); NSDictionary *m=[DMSaveArchive read:file into:stage];
    if (![m[@"title"] isEqual:@DM_GAME_ID] || ![m[@"profile"] isEqual:@"default"] || ![m[@"revision"] isEqual:revision]) problem(@"Archive identity mismatch");
    // Preserve pending archives and old trees; local history is intentionally not erased.
    NSMutableDictionary *next=[@{@"base":head[@"revision"]?:NSNull.null,@"baseInventory":head?inventoryID(head[@"manifest"]):@"",@"lastInventory":head?inventoryID(head[@"manifest"]):@"",@"queue":[NSMutableArray array]} mutableCopy];
    [DMSaveArchive restore:stage manifest:m state:statePath save:savePath metadata:next]; state=next;
    if (![revision isEqual:head[@"revision"]] || [receipt[@"resolve"] boolValue]) { NSString *capture=captureNow(); if (!capture) problem(@"Cannot capture rollback"); enqueue(capture,head[@"revision"]?:NSNull.null); [NSFileManager.defaultManager removeItemAtPath:capture error:nil]; pump(); }
    setStatus([state[@"queue"] count]?@"Uploading":@"Uploaded"); ready();
}
static void installWhenIdle(NSDictionary *receipt, NSDictionary *head) {
    importing=YES;
    void (^install)(void)=^{
        protectedAction(^{ if (running || uploading || captures) problem(@"Save operations are outstanding. Retry before launch after they finish."); installReceipt(receipt,head); });
        importing=NO; pump();
    };
    if (!transport) { install(); return; }
    [transport.session getAllTasksWithCompletionHandler:^(NSArray<NSURLSessionTask *> *tasks) {
        dispatch_async(worker,^{
            if (tasks.count) { importing=NO; choose(@"Upload still outstanding",@"Wait for its receipt or restart and check cloud before restoring. Local saves are unchanged.",@[@"Back"],^(NSUInteger i){dm_sync_menu(NULL);}); }
            else install();
        });
    }];
}
static void selectCloud(NSDictionary *receipt, NSDictionary *head) {
    NSDictionary *c=receipt[@"manifest"][@"compatibility"];
    if (![c isEqual:compatibility()] || ![c[@"builds"] count]) {
        choose(@"Different game build",@"This save has different or unknown game version/build/DLC metadata. Loading it may be incompatible. A local backup will be kept.",@[@"Load anyway",@"Back"],^(NSUInteger i){if (!i) installWhenIdle(receipt,head); else reconcile();});
    } else installWhenIdle(receipt,head);
}
static void reconcile(void) {
    @try {
        [DMSaveArchive recover:statePath save:savePath]; state=[jsonFile([statePath stringByAppendingPathComponent:@"state.json"]) mutableCopy]?:[NSMutableDictionary dictionary];
        if (!credentials) { setStatus(@"Local only"); ready(); return; }
        NSDictionary *h=get(@"head"), *head=h[@"head"]==NSNull.null?nil:h[@"head"];
        if (head) state[@"sourceDevice"]=head[@"deviceName"] ?: head[@"manifest"][@"device"] ?: @"unknown";
        NSString *capture=captureNow(); if (!capture) problem(@"Cannot capture local progress");
        NSDictionary *inv=[DMSaveArchive inventory:capture]; NSString *identity=inventoryID(inv);
        BOOL dirty=![identity isEqual:state[@"baseInventory"]], progress=[inv[@"entries"] count]>0;
        id base=state[@"base"]==NSNull.null?nil:state[@"base"];
        if (head && [identity isEqual:inventoryID(head[@"manifest"])] && ![state[@"blocked"] boolValue]) {
            state[@"base"]=head[@"revision"]; state[@"baseInventory"]=identity; state[@"lastInventory"]=identity; state[@"queue"]=[NSMutableArray array]; resumePublication(); setStatus(@"Uploaded"); ready();
        } else if (head && !dirty && base) { selectCloud(head,head); }
        else if ((!head && !base && !progress) || (base && [base isEqual:head[@"revision"]] && ![state[@"blocked"] boolValue])) {
            resumePublication();
            if (!head && !base && !progress) { state[@"baseInventory"]=identity; state[@"lastInventory"]=identity; persist(); }
            else if (dirty && (base || progress)) enqueue(capture,nil); pump(); ready();
        } else {
            setStatus(@"Conflict");
            NSString *message=head ? @"Choose the save to continue with. Loading the cloud save keeps a backup of this device's progress." : @"Start cloud saves with the progress on this device? Existing backups are kept.";
            NSDictionary *context=head ? @{@"kind":@"conflict", @"comparisons":@[
                @{@"title":@"This device", @"device":progress ? @"Local progress" : @"No saved files", @"version":compatibility()[@"version"] ?: @"unknown", @"time":NSNull.null},
                @{@"title":@"Cloud save", @"device":head[@"deviceName"] ?: head[@"manifest"][@"device"] ?: @"Unknown device", @"version":head[@"manifest"][@"compatibility"][@"version"] ?: @"unknown", @"time":head[@"manifest"][@"displayTime"] ?: NSNull.null}
            ]} : nil;
            NSMutableArray *options=[(head ? @[@"Use this device",@"Use cloud save",@"Play offline"] : @[@"Use this device",@"Play offline"]) mutableCopy];
            if (landingActive) [options addObject:@"Back"];
            chooseContext(head ? @"Which save do you want to use?" : @"Start using cloud saves?",message,options,context,^(NSUInteger choice){
                if (landingActive && choice==(head ? 3 : 2)) { dm_sync_menu(NULL); return; }
                protectedAction(^{
                    if ((head && choice==2) || (!head && choice==1)) { pausePublication(); ready(); return; }
                    if (head && choice==1) { NSMutableDictionary *resolution=[head mutableCopy]; resolution[@"resolve"]=@YES; selectCloud(resolution,head); return; }
                    // Keep old archive files for recovery; only replace automatic publication queue.
                    state[@"queue"]=[NSMutableArray array]; state[@"blocked"]=@NO; [state removeObjectForKey:@"importNeedsReconciliation"]; resumePublication();
                    NSString *latest=captureNow(); if (!latest) problem(@"Cannot preserve local progress"); enqueue(latest,head[@"revision"]?:NSNull.null); [NSFileManager.defaultManager removeItemAtPath:latest error:nil]; pump(); ready();
                });
            });
        }
        [NSFileManager.defaultManager removeItemAtPath:capture error:nil];
    } @catch (NSException *e) {
        setStatus(@"Offline");
        // A restore journal is a hard gate, even when the player elects offline play.
        BOOL journal=[NSFileManager.defaultManager fileExistsAtPath:[statePath stringByAppendingPathComponent:@"restore.json"]];
        NSMutableArray *options=[(journal ? @[@"Retry recovery"] : @[@"Retry",@"Play offline"]) mutableCopy];
        if (landingActive) [options addObject:@"Back"];
        choose(journal ? @"Save recovery needed" : @"Couldn't check cloud saves",e.reason,options,^(NSUInteger i){
            if (landingActive && i==(journal ? 1 : 2)) dm_sync_menu(NULL);
            else if (i && !journal) protectedAction(^{pausePublication(); ready();}); else reconcile();
        });
    }
}
static void pairUI(void) {
    dispatch_async(dispatch_get_main_queue(),^{
#if TARGET_OS_IPHONE
        UIAlertController *a=[UIAlertController alertControllerWithTitle:credentials ? @"Cloud connection" : @"Set up cloud saves" message:@"Enter your cloud save server and a one-use pairing code. Each device needs its own code." preferredStyle:UIAlertControllerStyleAlert];
        [a addTextFieldWithConfigurationHandler:^(UITextField *f){f.placeholder=@"https://your-save-host"; f.text=credentials[@"server"]; f.keyboardType=UIKeyboardTypeURL; f.autocapitalizationType=UITextAutocapitalizationTypeNone; f.autocorrectionType=UITextAutocorrectionTypeNo;}];
        [a addTextFieldWithConfigurationHandler:^(UITextField *f){f.placeholder=@"Pairing code"; f.secureTextEntry=YES; f.textContentType=UITextContentTypeOneTimeCode;}];
        [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *v){dm_sync_menu((__bridge void *)presenter);}]];
        [a addAction:[UIAlertAction actionWithTitle:@"Connect" style:UIAlertActionStyleDefault handler:^(UIAlertAction *v){
            NSArray *values=@[a.textFields[0].text?:@"",a.textFields[1].text?:@""];
#else
        NSAlert *a=[NSAlert new]; a.messageText=@"Pair cloud saves"; a.informativeText=@"HTTPS URL and one-use pairing code";
        NSView *view=[[NSView alloc] initWithFrame:NSMakeRect(0,0,360,64)]; NSTextField *url=[[NSTextField alloc] initWithFrame:NSMakeRect(0,36,360,24)]; NSSecureTextField *code=[[NSSecureTextField alloc] initWithFrame:NSMakeRect(0,0,360,24)]; [view addSubview:url]; [view addSubview:code]; a.accessoryView=view; [a addButtonWithTitle:@"Pair"]; [a addButtonWithTitle:@"Cancel"];
        if ([a runModal]!=NSAlertFirstButtonReturn) { dm_sync_menu(NULL); return; } NSArray *values=@[url.stringValue,code.stringValue];
#endif
            dispatch_async(worker,^{ protectedAction(^{
                NSString *server=[values[0] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/ "]]; NSURL *u=[NSURL URLWithString:server];
                if (![u.scheme isEqual:@"https"] || !u.host.length || u.user || u.password || u.query || u.fragment) problem(@"A valid HTTPS URL is required");
                NSInteger status; NSData *body=[NSJSONSerialization dataWithJSONObject:@{@"code":values[1],@"name":NSProcessInfo.processInfo.hostName?:@"Apple device"} options:0 error:nil];
                NSData *data=request([server stringByAppendingString:@"/v1/pair"],@"POST",body,&status); if (status!=200) problem(@"Pairing failed; obtain a fresh code");
                NSMutableDictionary *c=[[NSJSONSerialization JSONObjectWithData:data options:0 error:nil] mutableCopy]; if (!c[@"token"] || !c[@"device"]) problem(@"Invalid pairing response"); c[@"server"]=server; BOOL changed=![credentials[@"server"] isEqual:server]; storeCredentials(c);
                state[@"queue"]=[NSMutableArray array]; state[@"blocked"]=@NO; state[@"paused"]=@NO; [state removeObjectForKey:@"retryAfter"]; [state removeObjectForKey:@"lastInventory"];
                if (changed) { [state removeObjectForKey:@"base"]; [state removeObjectForKey:@"baseInventory"]; }
                persist(); reconcile();
            }); });
#if TARGET_OS_IPHONE
        }]]; dm_host_present((__bridge void *)presenter, (__bridge void *)a);
#endif
    });
}
static void historyPage(NSNumber *after) {
    protectedAction(^{
        NSDictionary *page=get([NSString stringWithFormat:@"revisions?limit=100&after=%@",after?:@0]); NSArray *items=page[@"items"];
        NSMutableArray *labels=[NSMutableArray array];
        for (NSDictionary *r in items) [labels addObject:[NSString stringWithFormat:@"%@ · %@%@",displaySaveTime(r[@"manifest"][@"displayTime"]),r[@"deviceName"] ?: r[@"manifest"][@"device"] ?: @"Unknown device",[r[@"published"] boolValue] ? @"" : @" · Unpublished save"]];
        BOOL more=page[@"next"] && page[@"next"]!=NSNull.null; if (more) [labels addObject:@"Next page"]; [labels addObject:@"Back"];
        choose(@"Cloud backups",@"Choose a save to review before restoring. A backup of this device's progress will be kept.",labels,^(NSUInteger n){
            if (n<items.count) {
                NSDictionary *revision=items[n];
                NSDictionary *build=revision[@"manifest"][@"compatibility"];
                BOOL mismatch=![build isEqual:compatibility()] || ![build[@"builds"] count];
                NSString *message=[NSString stringWithFormat:@"Save from %@\nDevice: %@\nGame version: %@\nThis replaces progress on this device. A local backup is kept first.%@",displaySaveTime(revision[@"manifest"][@"displayTime"]),revision[@"deviceName"] ?: revision[@"manifest"][@"device"] ?: @"unknown",build[@"version"] ?: @"unknown",mismatch ? @"\nDifferent or unknown game build/DLC: this save may be incompatible." : @""];
                choose(@"Restore this cloud backup?",message,@[mismatch ? @"Restore anyway" : @"Restore backup",@"Cancel"],^(NSUInteger choice){
                    if (choice) { dm_sync_menu(NULL); return; }
                    protectedAction(^{id h=get(@"head")[@"head"]; installWhenIdle(revision,h==NSNull.null?nil:h);});
                });
            }
            else if (more && n==items.count) historyPage(page[@"next"]); else dm_sync_menu(NULL);
        });
    });
}
// Explicit capture does not touch credentials, automatic capture counters or the
// upload queue. Only cloning runs under the guest filesystem's root locks.
static void cloneExplicit(void *context) {
    NSString *__strong *result = (NSString *__strong *)context;
    *result = captureNow();
}
static NSString *captureCommitted(void) {
    if ([NSFileManager.defaultManager fileExistsAtPath:[statePath stringByAppendingPathComponent:@"restore.json"]]) problem(@"Restore recovery is required before capturing live roots. Retained recovery copies can still be exported.");
    NSString *capture=nil; dm_fs_capture_with(cloneExplicit, &capture);
    if (!capture) problem(@"Cannot capture committed saves; local progress is unchanged");
    return capture;
}
static NSString *newWorkspace(NSString *prefix) {
    NSString *path=[statePath stringByAppendingPathComponent:[prefix stringByAppendingString:NSUUID.UUID.UUIDString]];
    if (![NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil]) problem(@"Cannot create staging directory; free unrelated storage and retry");
    return path;
}
static NSString *writeBackup(NSString *capture, NSString *directory, BOOL current) {
    NSMutableDictionary *manifest=[[DMSaveArchive inventory:capture] mutableCopy];
    NSString *stamp=[NSISO8601DateFormatter.new stringFromDate:NSDate.date];
    [manifest addEntriesFromDictionary:@{@"format":@1,@"revision":NSUUID.UUID.UUIDString.lowercaseString,@"parent":NSNull.null,@"title":@DM_GAME_ID,@"profile":@"default",@"device":credentials[@"device"] ?: NSUUID.UUID.UUIDString.lowercaseString,@"displayTime":current ? stamp : @"unknown",@"compatibility":current ? compatibility() : @{@"version":@"unknown",@"builds":@[],@"dlc":@[]}}];
    NSString *file=[directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%s-%@.nxsave",DM_GAME_ID,[stamp stringByReplacingOccurrencesOfString:@":" withString:@"-"]]];
    [DMSaveArchive write:manifest capture:capture to:file]; [DMSaveArchive read:file into:nil]; return file;
}
static void copyBounded(NSURL *url, NSString *destination) {
    NSInputStream *input=[NSInputStream inputStreamWithURL:url]; NSOutputStream *output=[NSOutputStream outputStreamToFileAtPath:destination append:NO];
    [input open]; [output open]; NSUInteger total=0;
    @try {
        uint8_t buffer[65536]; NSInteger n;
        while ((n=[input read:buffer maxLength:sizeof buffer])>0) {
            total+=n; if (total>(128u<<20)) problem(@"Archive exceeds the 128 MiB import limit");
            NSInteger offset=0; while (offset<n) { NSInteger written=[output write:buffer+offset maxLength:n-offset]; if (written<=0) problem(@"Cannot stage archive; check free storage"); offset+=written; }
        }
        if (n<0 || !total) problem(@"Cannot read selected archive");
    } @finally { [input close]; [output close]; }
}
static void importFile(NSURL *url);
#if TARGET_OS_IPHONE
@interface DMSavePicker : NSObject <UIDocumentPickerDelegate>
@property NSString *workspace;
@property BOOL importing;
@end
static DMSavePicker *filePicker;
@implementation DMSavePicker
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    NSString *workspace=self.workspace; filePicker=nil;
    dispatch_async(worker,^{ if (workspace) [NSFileManager.defaultManager removeItemAtPath:workspace error:nil]; dm_sync_menu(NULL); });
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSString *workspace=self.workspace; BOOL importing=self.importing; filePicker=nil;
    dispatch_async(worker,^{
        if (importing && urls.count) importFile(urls.firstObject);
        else { if (workspace) [NSFileManager.defaultManager removeItemAtPath:workspace error:nil]; dm_sync_menu(NULL); }
    });
}
@end
#endif
static void exportFile(NSString *file, NSString *workspace) {
    dispatch_async(dispatch_get_main_queue(),^{
#if TARGET_OS_IPHONE
        filePicker=[DMSavePicker new]; filePicker.workspace=workspace;
        UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initForExportingURLs:@[[NSURL fileURLWithPath:file]] asCopy:YES];
        picker.delegate=filePicker; dm_host_present((__bridge void *)presenter, (__bridge void *)picker);
#else
        NSSavePanel *panel=[NSSavePanel savePanel]; panel.nameFieldStringValue=file.lastPathComponent;
        if ([panel runModal]==NSModalResponseOK) {
            NSURL *destination=panel.URL;
            dispatch_async(worker,^{ protectedAction(^{ copyBounded([NSURL fileURLWithPath:file],destination.path); }); [NSFileManager.defaultManager removeItemAtPath:workspace error:nil]; dm_sync_menu(NULL); });
        } else dispatch_async(worker,^{ [NSFileManager.defaultManager removeItemAtPath:workspace error:nil]; dm_sync_menu(NULL); });
#endif
    });
}
static void exportBackup(NSString *retained) {
    protectedAction(^{
        NSString *workspace=newWorkspace(@"export-"), *capture=nil;
        @try {
            NSString *file;
            if ([retained.pathExtension isEqual:@"nxsave"]) {
                file=[workspace stringByAppendingPathComponent:retained.lastPathComponent]; copyBounded([NSURL fileURLWithPath:retained],file); [DMSaveArchive read:file into:nil];
            } else { capture=retained ?: captureCommitted(); file=writeBackup(capture,workspace,retained==nil); }
            NSDictionary *m=[DMSaveArchive read:file into:nil];
            if (landingActive || dashboardActive) { exportFile(file,workspace); }
            else choose(@"Export committed save",[NSString stringWithFormat:@"Game: %@\nVersion: %@\nArchive time: %@\nThis does not force an in-game save. Retained copies keep their original contents.",m[@"title"],m[@"compatibility"][@"version"] ?: @"unknown",m[@"displayTime"] ?: @"unknown"],@[@"Save file",@"Cancel"],^(NSUInteger i){
                if (!i) exportFile(file,workspace); else { [NSFileManager.defaultManager removeItemAtPath:workspace error:nil]; dm_sync_menu(NULL); }
            });
        } @catch (NSException *e) { [NSFileManager.defaultManager removeItemAtPath:workspace error:nil]; @throw; }
        @finally { if (capture && !retained) [NSFileManager.defaultManager removeItemAtPath:capture error:nil]; }
    });
}
static void recoveryExports(void) {
    NSMutableArray *paths=[NSMutableArray array], *labels=[NSMutableArray array];
    for (NSString *name in [[NSFileManager.defaultManager contentsOfDirectoryAtPath:statePath error:nil] sortedArrayUsingSelector:@selector(compare:)]) {
        if ([name hasPrefix:@"backup-"] || [name.pathExtension isEqual:@"nxsave"]) { [paths addObject:[statePath stringByAppendingPathComponent:name]]; [labels addObject:name]; }
    }
    [labels addObject:@"Back"];
    choose(@"Recovery copies",@"Export a preserved save to Files. Nothing is deleted. Some older copies have no recorded game version or save time.",labels,^(NSUInteger i){ if (i<paths.count) exportBackup(paths[i]); else dm_sync_menu(NULL); });
}
static NSMutableDictionary *importState(void) {
    NSMutableDictionary *next=[state mutableCopy];
    // Keep old queue entries and ancestry as evidence until an explicit prelaunch
    // reconciliation. Neither foreign metadata nor a late upload may replace it.
    next[@"importNeedsReconciliation"]=@YES; next[@"blocked"]=@YES;
    return next;
}
static void installImport(NSString *file, NSString *workspace) {
    protectedAction(^{
        if (running || uploading || captures) problem(@"Wait for save operations to finish, then import before launch");
        recoverIfNeeded();
        NSString *stage=[workspace stringByAppendingPathComponent:@"roots"];
        NSDictionary *m=[DMSaveArchive read:file into:stage];
        if (![m[@"title"] isEqual:@DM_GAME_ID] || ![m[@"profile"] isEqual:@"default"]) problem(@"Archive identity mismatch");
        NSMutableDictionary *next=credentials ? importState() : [state mutableCopy];
        [DMSaveArchive restore:stage manifest:m state:statePath save:savePath metadata:next]; state=next;
        handoffRevision=nil; localDirty=YES; lastError=nil;
        setStatus(credentials ? @"Imported locally — check cloud and choose a branch before publication" : @"Local backup imported");
        [NSFileManager.defaultManager removeItemAtPath:workspace error:nil]; dm_sync_menu(NULL);
    });
    importing=NO;
}
static void importFile(NSURL *url) {
    protectedAction(^{
        if (running) problem(@"Restart to import before the game mounts its saves");
        recoverIfNeeded();
        NSString *workspace=newWorkspace(@"import-"), *file=[workspace stringByAppendingPathComponent:@"selected.nxsave"];
        BOOL scoped=[url startAccessingSecurityScopedResource];
        @try {
            copyBounded(url,file); NSDictionary *m=[DMSaveArchive read:file into:nil];
            if (![m[@"title"] isEqual:@DM_GAME_ID] || ![m[@"profile"] isEqual:@"default"]) problem(@"This archive belongs to a different title or profile");
            NSDictionary *c=m[@"compatibility"]; if (![c isKindOfClass:NSDictionary.class]) c=@{}; BOOL mismatch=![c isEqual:compatibility()] || ![c[@"builds"] count];
            NSString *message=[NSString stringWithFormat:@"Game version: %@\nSaved: %@\nThis replaces progress on this device. A verified backup is kept first.%@%@",c[@"version"] ?: @"unknown",displaySaveTime(m[@"displayTime"]),credentials ? @"\nCloud progress will be checked before this save can be uploaded." : @"",mismatch ? @"\nDifferent or unknown game build/DLC: this save may be incompatible." : @""];
            choose(@"Import local backup",message,@[mismatch ? @"Import anyway" : @"Import",@"Cancel"],^(NSUInteger i){
                if (i) { [NSFileManager.defaultManager removeItemAtPath:workspace error:nil]; dm_sync_menu(NULL); return; }
                importing=YES;
                // No ancestry changes while a background task has an unknown
                // outcome. Let the normal receipt path finish, then retry import.
                if (transport) [transport.session getAllTasksWithCompletionHandler:^(NSArray<NSURLSessionTask *> *tasks){ dispatch_async(worker,^{
                    if (tasks.count || uploading || captures) { importing=NO; [NSFileManager.defaultManager removeItemAtPath:workspace error:nil]; choose(@"Upload still outstanding",@"Let the upload finish or restart and reconcile its receipt before importing. Local saves are unchanged.",@[@"Back"],^(NSUInteger n){dm_sync_menu(NULL);}); }
                    else installImport(file,workspace);
                }); }]; else installImport(file,workspace);
            });
        } @catch(NSException *e) { [NSFileManager.defaultManager removeItemAtPath:workspace error:nil]; @throw; }
        @finally { if (scoped) [url stopAccessingSecurityScopedResource]; }
    });
}
static void importPicker(void) {
    if (running) { choose(@"Restart required",@"Import and history restore are available before launch only.",@[@"OK"],^(NSUInteger i){}); return; }
    dispatch_async(dispatch_get_main_queue(),^{
#if TARGET_OS_IPHONE
        filePicker=[DMSavePicker new]; filePicker.importing=YES;
        UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeOpen];
        picker.delegate=filePicker; picker.allowsMultipleSelection=NO; dm_host_present((__bridge void *)presenter, (__bridge void *)picker);
#else
        NSOpenPanel *panel=[NSOpenPanel openPanel]; panel.allowsMultipleSelection=NO; panel.canChooseDirectories=NO;
        if ([panel runModal]==NSModalResponseOK) { NSURL *url=panel.URL; dispatch_async(worker,^{ importFile(url); }); }
        else dm_sync_menu(NULL);
#endif
    });
}
static NSDictionary *saveAction(NSString *identifier, NSString *title, NSString *group, NSString *icon, BOOL primary) {
    return @{@"id":identifier, @"title":title, @"group":group, @"icon":icon, @"primary":@(primary)};
}
static void playOffline(void) {
    protectedAction(^{
        launchRequested=YES;
        [DMSaveArchive recover:statePath save:savePath];
        state=[jsonFile([statePath stringByAppendingPathComponent:@"state.json"]) mutableCopy] ?: [NSMutableDictionary dictionary];
        pausePublication(); ready();
    });
}
static void inlineMenu(void) {
    if (landingActive) launchRequested=NO;
    NSMutableArray *actions=[NSMutableArray array];
    if (!running) {
        if (credentials) {
            [actions addObject:saveAction(@"history",@"Restore cloud backup",@"Cloud saves",@"clock.arrow.circlepath",NO)];
            [actions addObject:saveAction(@"offline",@"Play offline",@"Cloud saves",@"icloud.slash",NO)];
        }
        [actions addObject:saveAction(@"connect",credentials ? @"Cloud connection" : @"Set up cloud saves",@"Connection",@"icloud",!credentials)];
    } else if (credentials && !remoteAdvanced && ![state[@"blocked"] boolValue] && ![state[@"importNeedsReconciliation"] boolValue]) {
        [actions addObject:saveAction(@"sync",[state[@"offlinePaused"] boolValue] ? @"Resume & sync" : @"Sync now",@"Cloud saves",@"arrow.triangle.2.circlepath",YES)];
    }
    [actions addObject:saveAction(@"export",@"Export backup file",@"Backup files",@"square.and.arrow.up",NO)];
    if (!running) [actions addObject:saveAction(@"import",@"Import backup file",@"Backup files",@"square.and.arrow.down",NO)];
    [actions addObject:saveAction(@"recovery",@"Recovery copies",@"Backup files",@"externaldrive",NO)];
    landingChooseContext(@"Saves",currentStatus(),[actions valueForKey:@"title"],YES,@{@"actions":actions},^(NSUInteger index){
        NSString *identifier=actions[index][@"id"];
        if ([identifier isEqual:@"sync"]) syncNow(YES);
        else if ([identifier isEqual:@"connect"]) pairUI();
        else if ([identifier isEqual:@"history"]) historyPage(@0);
        else if ([identifier isEqual:@"offline"]) playOffline();
        else if ([identifier isEqual:@"export"]) exportBackup(nil);
        else if ([identifier isEqual:@"import"]) importPicker();
        else if ([identifier isEqual:@"recovery"]) recoveryExports();
    });
}
void dm_sync_menu(void *p) {
    if (!dispatch_get_specific(&workerKey)) { id owner=p ? (__bridge id)p : nil; dispatch_async(worker,^{dm_sync_menu((__bridge void *)owner);}); return; }
    if (p) presenter=(__bridge id)p;
    if (landingActive || dashboardActive) { inlineMenu(); return; }
#if TARGET_OS_IPHONE
    // Completion of a picker/network operation must not reopen UI after the
    // player has left the live save screen.
    if (running) return;
#endif
    if (running) {
        choose(@"Cloud saves",currentStatus(),@[@"Sync now",@"Prepare to switch devices",@"Export backup",@"Retained recovery copies",@"Import / restore",@"Close"],^(NSUInteger i){
            if (i<2) syncNow(i==1); else if (i==2) exportBackup(nil); else if (i==3) recoveryExports(); else if (i==4) importPicker();
        }); return;
    }
    NSArray *options=credentials ? @[@"Check cloud and play",@"History / restore",@"Pair again",@"Play offline",@"Export backup",@"Import backup",@"Retained recovery copies"] : @[@"Play locally",@"Pair",@"Export backup",@"Import backup",@"Retained recovery copies"];
    void (^selected)(NSUInteger)=^(NSUInteger i){
        NSUInteger backupIndex=credentials ? 4 : 2;
        if (i==backupIndex) { exportBackup(nil); return; }
        if (i==backupIndex+1) { importPicker(); return; }
        if (i==backupIndex+2) { recoveryExports(); return; }
        if (!credentials) { if (!i) reconcile(); else pairUI(); return; }
        if (!i) reconcile();
        else if (i==2) pairUI();
        else if (i==3) playOffline();
        else historyPage(@0);
    };
    choose(@"Cloud saves",currentStatus(),options,selected);
}

static void landingAction(NSDictionary *action) {
    if ((!landingActive && !dashboardActive) || ![action[@"token"] isEqual:@(landingToken)]) return;
    BOOL play=[action[@"action"] isEqual:@"play"];
    if (play && (!landingActive || !landingAtMenu)) return;
    void (^selected)(NSUInteger)=landingSelection;
    NSUInteger index=NSNotFound;
    if (!play) {
        if ([action[@"action"] isEqual:@"select"] && [action[@"index"] isKindOfClass:NSNumber.class]) index=[action[@"index"] unsignedIntegerValue];
        else index=[inlinePage[@"actions"] indexOfObjectPassingTest:^BOOL(NSDictionary *item,NSUInteger i,BOOL *stop){return [item[@"id"] isEqual:action[@"action"]];}];
        if (!selected || index>=landingOptionCount) return;
    }
    landingChoose(@"Saves",play ? @"Checking saves before launch…" : @"Please wait…",@[],NO,nil);
    if (play) { launchRequested=YES; reconcile(); }
    else selected(index);
}
static void dashboardOpened(id owner) {
    if (!running) return;
    presenter=owner; dashboardActive=YES;
    setStatus(statusText); dm_sync_menu(NULL);
}
static void dashboardClosed(id owner) {
    if (!dashboardActive || presenter!=owner) return;
    dashboardActive=NO; landingSelection=nil; inlinePage=nil; ++landingToken;
}
void dm_sync_landing(void *p, void (*callback)(void)) {
    dm_sync_prepare();
    id owner=p ? (__bridge id)p : nil;
    dispatch_async(worker,^{
        presenter=owner; launchReady=callback; landingActive=YES; launchRequested=NO;
        if (!transport) transport=[DMSaveTransport new];
        setStatus(credentials ? @"Cloud will be checked when you play" : @"Saves stay on this device until paired");
        dm_sync_menu(NULL);
    });
}
void dm_sync_prepare(void) {
    static dispatch_once_t once; dispatch_once(&once,^{
        const char *path=getenv("DM_SAVE"); if (!path) return; savePath=[@(path) stringByStandardizingPath];
        statePath=[savePath stringByAppendingString:@".cloud-sync"];
        [NSFileManager.defaultManager createDirectoryAtPath:statePath withIntermediateDirectories:YES attributes:nil error:nil];
        NSURL *url=[NSURL fileURLWithPath:statePath]; [url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
#if TARGET_OS_IPHONE
        [NSFileManager.defaultManager setAttributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} ofItemAtPath:statePath error:nil];
#endif
        // Only captures/staging that never became durable queue entries are disposable.
        if (![NSFileManager.defaultManager fileExistsAtPath:[statePath stringByAppendingPathComponent:@"restore.json"]])
            for (NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:statePath error:nil])
                if ([name hasPrefix:@"capture-"] || [name hasPrefix:@"stage-"] || [name hasPrefix:@"export-"] || [name hasPrefix:@"import-"]) [NSFileManager.defaultManager removeItemAtPath:[statePath stringByAppendingPathComponent:name] error:nil];
        worker=dispatch_queue_create("org.nxnative.cloud-save",DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(worker,&workerKey,&workerKey,NULL);
        [NSNotificationCenter.defaultCenter addObserverForName:@"DMSaveScreenReady" object:nil queue:nil usingBlock:^(NSNotification *note){
            id owner=note.object; dispatch_async(worker,^{dashboardOpened(owner);});
        }];
        [NSNotificationCenter.defaultCenter addObserverForName:@"DMSaveScreenClosed" object:nil queue:nil usingBlock:^(NSNotification *note){
            id owner=note.object; dispatch_async(worker,^{dashboardClosed(owner);});
        }];
        [NSNotificationCenter.defaultCenter addObserverForName:@"DMSaveLauncherAction" object:nil queue:nil usingBlock:^(NSNotification *note){
            NSDictionary *action=[note.userInfo copy]; dispatch_async(worker,^{landingAction(action);});
        }];
        credentials=readCredentials(); atomic_store(&enabled,credentials!=nil);
        dm_fs_set_sync_callback(dm_sync_committed);
        state=[jsonFile([statePath stringByAppendingPathComponent:@"state.json"]) mutableCopy]?:[NSMutableDictionary dictionary];
        retryTimer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,worker);
        dispatch_source_set_timer(retryTimer,dispatch_time(DISPATCH_TIME_NOW,30*NSEC_PER_SEC),30*NSEC_PER_SEC,NSEC_PER_SEC);
        dispatch_source_set_event_handler(retryTimer,^{
            @try { if (running && credentials) { dm_fs_sync_capture();
                if ([state[@"offlinePaused"] boolValue]) { setStatus(@"Offline — uploads paused"); return; }
                pump();
                NSDictionary *h=get(@"head")[@"head"];
                if (h && (id)h!=NSNull.null) state[@"sourceDevice"]=h[@"deviceName"] ?: h[@"manifest"][@"device"] ?: @"unknown";
                if ((id)h!=NSNull.null && ![state[@"queue"] count] && ![h[@"revision"] isEqual:state[@"base"]]) { remoteAdvanced=YES; setStatus(@"Another device has newer progress — restart to load it"); }
            } } @catch (NSException *e) { handoffRevision=nil; lastError=e.reason; setStatus(@"Cloud status unknown — committed saves remain local"); }
        }); dispatch_resume(retryTimer);
    });
}
void dm_sync_tick(void) { if (worker) dispatch_async(worker,^{ dm_fs_sync_capture(); pump(); }); }
void dm_sync_prelaunch(void *p, void (*callback)(void)) { dm_sync_prepare(); launchReady=callback; if (p) presenter=(__bridge id)p; dispatch_async(worker,^{if (!transport) transport=[DMSaveTransport new]; dm_sync_menu(p);}); }
void dm_sync_background_handler(void (^completion)(void)) {
    backgroundDone=[completion copy]; dm_sync_prepare();
    dispatch_async(worker,^{
        if (!transport) transport=[DMSaveTransport new];
        @try {
            if (!running) { [DMSaveArchive recover:statePath save:savePath]; state=[jsonFile([statePath stringByAppendingPathComponent:@"state.json"]) mutableCopy]?:[NSMutableDictionary dictionary]; }
            pump();
        } @catch(NSException *e) { setStatus(@"Saved locally — recovery required"); }
    });
}
#if !TARGET_OS_IPHONE
static BOOL macReady;
static void macContinue(void) { macReady=YES; }
int dm_sync_mac_gate(void) {
    if (!getenv("DM_SAVE")) return 1;
    [NSApplication sharedApplication]; dm_sync_prelaunch(NULL,macContinue);
    while (!macReady) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    return 1;
}
#endif
