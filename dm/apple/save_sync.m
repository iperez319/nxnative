#import "save_sync.h"
#import <Security/Security.h>
#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif
#include <sys/clonefile.h>
#include <stdatomic.h>
#include "game_profile.h"

static NSString *savePath, *statePath;
static dispatch_queue_t worker;
static NSMutableDictionary *state;
static NSDictionary *credentials;
static NSString *statusText=@"Saved locally";
static _Atomic int enabled, captures;
static _Atomic int running;
static BOOL uploading;
static char workerKey;
static _Atomic int remoteAdvanced;
static dispatch_source_t retryTimer;
static void (^backgroundDone)(void);
static void (*launchReady)(void);
static __weak id presenter;
static __weak id activeStatusAlert;
static void pump(void);
static void reconcile(void);
static void cancelOutstanding(void);
static void setStatus(NSString *s) {
    if (remoteAdvanced && [s isEqual:@"Uploaded"]) s=@"Newer cloud save — restart to load";
    @synchronized(DMSaveArchive.class) { statusText=s; }
    dispatch_async(dispatch_get_main_queue(),^{
        [NSNotificationCenter.defaultCenter postNotificationName:@"DMSaveSyncStatus" object:s];
#if TARGET_OS_IPHONE
        [activeStatusAlert setMessage:s];
#else
        [activeStatusAlert setInformativeText:s];
#endif
    });
}
static NSString *currentStatus(void) { @synchronized(DMSaveArchive.class) { return statusText; } }
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
        if (access(source.fileSystemRepresentation,F_OK)==0 && clonefile(source.fileSystemRepresentation,[path stringByAppendingPathComponent:root].fileSystemRepresentation,0)) {
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
    if (!parentOverride && [state[@"lastInventory"] isEqual:identity]) { if (!queue.count && ![state[@"blocked"] boolValue]) setStatus(state[@"base"] && state[@"base"]!=NSNull.null?@"Uploaded":@"Saved locally"); return; }
    if (localBytes() > (256u<<20)) problem(@"Saved locally — snapshot storage full");
    if (queue.count>=3 || [state[@"blocked"] boolValue]) { setStatus([state[@"blocked"] boolValue]?@"Conflict":@"Saved locally — queue full"); return; }
    NSString *revision=NSUUID.UUID.UUIDString.lowercaseString;
    id parent=parentOverride?:([queue.lastObject objectForKey:@"revision"]?:state[@"base"]?:NSNull.null);
    NSMutableDictionary *m=[inventory mutableCopy]; [m addEntriesFromDictionary:@{@"format":@1,@"revision":revision,@"parent":parent,@"title":@DM_GAME_ID,@"profile":@"default",@"device":credentials[@"device"],@"displayTime":[NSISO8601DateFormatter.new stringFromDate:NSDate.date],@"compatibility":compatibility()}];
    NSString *filename=[revision stringByAppendingString:@".nxsave"], *path=[statePath stringByAppendingPathComponent:filename];
    [DMSaveArchive write:m capture:capture to:path];
    [queue addObject:[@{@"revision":revision,@"file":filename,@"inventory":identity} mutableCopy]]; state[@"lastInventory"]=identity; persist();
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
static void ready(void) {
    running=YES;
    dispatch_async(dispatch_get_main_queue(),^{ if (launchReady) { void (*fn)(void)=launchReady; launchReady=NULL; fn(); } });
}
static void choose(NSString *title, NSString *message, NSArray<NSString *> *options, void (^selected)(NSUInteger)) {
    dispatch_async(dispatch_get_main_queue(),^{
#if TARGET_OS_IPHONE
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        for (NSUInteger i=0;i<options.count;i++) [alert addAction:[UIAlertAction actionWithTitle:options[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ dispatch_async(worker,^{selected(i);}); }]];
        if (running && [title isEqual:@"Cloud saves"]) activeStatusAlert=alert;
        [presenter presentViewController:alert animated:YES completion:nil];
#else
        NSAlert *alert=[NSAlert new]; alert.messageText=title; alert.informativeText=message;
        if (running && [title isEqual:@"Cloud saves"]) activeStatusAlert=alert;
        for (NSString *s in options) [alert addButtonWithTitle:s]; NSUInteger i=[alert runModal]-NSAlertFirstButtonReturn; dispatch_async(worker,^{selected(i);});
#endif
    });
}
static void protectedAction(void (^action)(void)) {
    @try { action(); } @catch (NSException *e) { setStatus(@"Saved locally"); choose(@"Cloud save paused",e.reason,@[@"Back"],^(NSUInteger i){ if (!running) reconcile(); }); }
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
        uploading=NO;
        @try {
            if ([state[@"offlinePaused"] boolValue]) { setStatus(@"Offline — uploads paused"); return; }
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
            state[@"base"]=item[@"revision"]; state[@"baseInventory"]=item[@"inventory"]; NSString *file=item[@"file"]; [q removeObjectAtIndex:0]; persist();
            [NSFileManager.defaultManager removeItemAtPath:[statePath stringByAppendingPathComponent:file] error:nil];
            setStatus(@"Saved locally"); dm_fs_sync_capture(); pump();
        } @catch (NSException *e) { setStatus(@"Saved locally"); }
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
    if (!credentials || uploading || [state[@"offlinePaused"] boolValue] || [state[@"blocked"] boolValue] || [state[@"paused"] boolValue] || [state[@"retryAfter"] doubleValue]>[NSDate.date timeIntervalSince1970]) return;
    @try { persist(); } @catch(NSException *e) { setStatus(@"Saved locally"); return; }
    if (!transport) transport=[DMSaveTransport new];
    NSDictionary *item=[state[@"queue"] firstObject]; if (!item) return;
    uploading=YES;
    [transport.session getAllTasksWithCompletionHandler:^(NSArray<NSURLSessionTask *> *tasks) {
        dispatch_async(worker,^{ @try {
            if ([state[@"offlinePaused"] boolValue]) { uploading=NO; return; }
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
    if (atomic_fetch_add(&captures,1)>=2) { atomic_fetch_sub(&captures,1); setStatus(@"Saved locally"); return; }
    @autoreleasepool {
        setStatus(@"Saved locally"); NSString *snapshot=captureNow();
        if (!snapshot) { atomic_fetch_sub(&captures,1); setStatus(@"Saved locally"); return; }
        dispatch_async(worker,^{ @try { enqueue(snapshot,nil); pump(); } @catch (NSException *e) { setStatus(@"Saved locally"); }
            [NSFileManager.defaultManager removeItemAtPath:snapshot error:nil]; atomic_fetch_sub(&captures,1);
        });
    }
}
static void installReceipt(NSDictionary *receipt, NSDictionary *head) {
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
static void selectCloud(NSDictionary *receipt, NSDictionary *head) {
    NSDictionary *c=receipt[@"manifest"][@"compatibility"];
    if (![c isEqual:compatibility()] || ![c[@"builds"] count]) {
        choose(@"Different game build",@"This save has different or unknown game version/build/DLC metadata. Loading it may be incompatible. A local backup will be kept.",@[@"Load anyway",@"Back"],^(NSUInteger i){if (!i) protectedAction(^{installReceipt(receipt,head);}); else reconcile();});
    } else protectedAction(^{installReceipt(receipt,head);});
}
static void reconcile(void) {
    @try {
        [DMSaveArchive recover:statePath save:savePath]; state=[jsonFile([statePath stringByAppendingPathComponent:@"state.json"]) mutableCopy]?:[NSMutableDictionary dictionary];
        if (!credentials) { ready(); return; }
        NSDictionary *h=get(@"head"), *head=h[@"head"]==NSNull.null?nil:h[@"head"];
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
            setStatus(@"Conflict"); NSString *message=head?[NSString stringWithFormat:@"Cloud device: %@\nGame version: %@\nSaved: %@\nLocal game version: %@\nChoose the progress to continue. Existing snapshots and a local backup are preserved.",head[@"deviceName"]?:head[@"manifest"][@"device"],head[@"manifest"][@"compatibility"][@"version"],head[@"manifest"][@"displayTime"],compatibility()[@"version"]]:@"Use the existing local save as the first cloud revision?";
            choose(@"Choose save progress",message,head?@[@"Continue local",@"Load cloud",@"Play offline"]:@[@"Upload local",@"Play offline"],^(NSUInteger choice){
                protectedAction(^{
                    if ((head && choice==2) || (!head && choice==1)) { pausePublication(); ready(); return; }
                    if (head && choice==1) { NSMutableDictionary *resolution=[head mutableCopy]; resolution[@"resolve"]=@YES; selectCloud(resolution,head); return; }
                    // Keep old archive files for recovery; only replace automatic publication queue.
                    state[@"queue"]=[NSMutableArray array]; state[@"blocked"]=@NO; resumePublication();
                    NSString *latest=captureNow(); if (!latest) problem(@"Cannot preserve local progress"); enqueue(latest,head[@"revision"]?:NSNull.null); [NSFileManager.defaultManager removeItemAtPath:latest error:nil]; pump(); ready();
                });
            });
        }
        [NSFileManager.defaultManager removeItemAtPath:capture error:nil];
    } @catch (NSException *e) {
        setStatus(@"Offline");
        // A restore journal is a hard gate, even when the player elects offline play.
        BOOL journal=[NSFileManager.defaultManager fileExistsAtPath:[statePath stringByAppendingPathComponent:@"restore.json"]];
        choose(@"Cloud save",e.reason,journal?@[@"Retry recovery"]:@[@"Retry",@"Play offline"],^(NSUInteger i){if (i && !journal) protectedAction(^{pausePublication(); ready();}); else reconcile();});
    }
}
static void pairUI(void) {
    dispatch_async(dispatch_get_main_queue(),^{
#if TARGET_OS_IPHONE
        UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Pair cloud saves" message:@"Enter your Whatbox HTTPS URL and a one-use code from the service's pair command. Tokens stay in Keychain." preferredStyle:UIAlertControllerStyleAlert];
        [a addTextFieldWithConfigurationHandler:^(UITextField *f){f.placeholder=@"https://your-save-host"; f.autocapitalizationType=UITextAutocapitalizationTypeNone;}];
        [a addTextFieldWithConfigurationHandler:^(UITextField *f){f.placeholder=@"Pairing code"; f.secureTextEntry=YES;}];
        [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *v){dm_sync_menu((__bridge void *)presenter);}]];
        [a addAction:[UIAlertAction actionWithTitle:@"Pair" style:UIAlertActionStyleDefault handler:^(UIAlertAction *v){
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
        }]]; [presenter presentViewController:a animated:YES completion:nil];
#endif
    });
}
static void historyPage(NSNumber *after) {
    protectedAction(^{
        NSDictionary *page=get([NSString stringWithFormat:@"revisions?limit=100&after=%@",after?:@0]); NSArray *items=page[@"items"];
        NSMutableArray *labels=[NSMutableArray array];
        for (NSDictionary *r in items) [labels addObject:[NSString stringWithFormat:@"%@ · %@ · %@%@",r[@"manifest"][@"displayTime"],r[@"deviceName"]?:r[@"manifest"][@"device"],r[@"manifest"][@"compatibility"][@"version"],[r[@"published"] boolValue]?@"":@" (conflict)"]];
        BOOL more=page[@"next"] && page[@"next"]!=NSNull.null; if (more) [labels addObject:@"Next page"]; [labels addObject:@"Back"];
        choose(@"Restore revision",@"Restoring history keeps local backups and publishes a new revision.",labels,^(NSUInteger n){
            if (n<items.count) protectedAction(^{id h=get(@"head")[@"head"]; selectCloud(items[n],h==NSNull.null?nil:h);});
            else if (more && n==items.count) historyPage(page[@"next"]); else dm_sync_menu(NULL);
        });
    });
}
void dm_sync_menu(void *p) {
    if (!dispatch_get_specific(&workerKey)) { dispatch_async(worker,^{dm_sync_menu(p);}); return; }
    if (p) presenter=(__bridge id)p;
    if (running) {
        choose(@"Cloud saves",currentStatus(),@[@"Sync now",@"Close"],^(NSUInteger i){if (!i) { resumePublication(); state[@"paused"]=@NO; [state removeObjectForKey:@"retryAfter"]; dm_fs_sync_capture(); pump(); }}); return;
    }
    choose(@"Cloud saves",credentials?currentStatus():@"Sync is disabled until paired. Sync uploads committed saves; save in-game first.",credentials?@[@"Check cloud and play",@"History / restore",@"Pair again",@"Play offline"]:@[@"Play locally",@"Pair"],^(NSUInteger i){
        if (!credentials) { if (!i) reconcile(); else pairUI(); return; }
        if (!i) reconcile();
        else if (i==2) pairUI();
        else if (i==3) {
            protectedAction(^{[DMSaveArchive recover:statePath save:savePath]; state=[jsonFile([statePath stringByAppendingPathComponent:@"state.json"]) mutableCopy]?:[NSMutableDictionary dictionary]; pausePublication(); ready();});
        } else historyPage(@0);
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
                if ([name hasPrefix:@"capture-"] || [name hasPrefix:@"stage-"]) [NSFileManager.defaultManager removeItemAtPath:[statePath stringByAppendingPathComponent:name] error:nil];
        worker=dispatch_queue_create("org.nxnative.cloud-save",DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(worker,&workerKey,&workerKey,NULL);
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
                if ((id)h!=NSNull.null && ![state[@"queue"] count] && ![h[@"revision"] isEqual:state[@"base"]]) { remoteAdvanced=YES; setStatus(@"Another device has newer progress — restart to load it"); }
            } } @catch (NSException *e) { setStatus(@"Offline"); }
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
