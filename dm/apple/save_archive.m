#import "save_sync.h"
#import <CommonCrypto/CommonDigest.h>
#include <sys/xattr.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <zlib.h>

static void checkpoint(const char *name) {
#ifdef DM_SYNC_TESTING
    const char *point=getenv("DM_SYNC_CRASH_AT"); if (point && !strcmp(point,name)) _exit(88);
#else
    (void)name;
#endif
}
static const NSUInteger limit = 64u << 20; // client memory budget; server accepts larger desktop clients
static NSFileManager *fm(void) { return NSFileManager.defaultManager; }
static void fail(NSString *message) { @throw [NSException exceptionWithName:@"SaveSync" reason:message userInfo:nil]; }
static void check(BOOL ok, NSString *message) { if (!ok) fail(message); }
static void flush(NSString *path) {
    int fd = open(path.fileSystemRepresentation, O_RDONLY);
    check(fd >= 0, @"Cannot open durable save state");
    int rc = fsync(fd); close(fd); check(rc == 0, @"Cannot flush save state");
}
void dm_save_atomic(NSString *path, NSData *data) {
    NSString *tmp = [path stringByAppendingString:@".next"];
    check([data writeToFile:tmp options:0 error:nil], @"Cannot write save state");
    flush(tmp);
    check(rename(tmp.fileSystemRepresentation, path.fileSystemRepresentation) == 0, @"Cannot publish save state");
    flush(path.stringByDeletingLastPathComponent);
}
void dm_save_json(NSString *path, id value) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingSortedKeys error:nil];
    check(data != nil, @"Invalid save metadata"); dm_save_atomic(path, data);
}
NSString *dm_save_hash(NSData *data) {
    unsigned char bytes[CC_SHA256_DIGEST_LENGTH]; CC_SHA256(data.bytes, (CC_LONG)data.length, bytes);
    NSMutableString *s = [NSMutableString string]; for (unsigned i=0;i<sizeof bytes;i++) [s appendFormat:@"%02x", bytes[i]]; return s;
}
static NSString *guestName(NSString *path) {
    ssize_t size = getxattr(path.fileSystemRepresentation, "org.d2rmobile.guest-name", NULL, 0, 0, XATTR_NOFOLLOW);
    if (size < 0) { check(errno == ENOATTR, @"Cannot read guest-name metadata"); return nil; }
    check(size > 0 && size <= 255, @"Invalid guest-name metadata");
    char value[256]; check(getxattr(path.fileSystemRepresentation, "org.d2rmobile.guest-name", value, size, 0, XATTR_NOFOLLOW) == size, @"Cannot read guest-name metadata");
    NSString *s = [[NSString alloc] initWithBytes:value length:size encoding:NSUTF8StringEncoding]; check(s != nil, @"Non-UTF8 guest name"); return s;
}
static BOOL safeName(NSString *s) {
    return [s isKindOfClass:NSString.class] && s.length && ![s isEqual:@"."] && ![s isEqual:@".."] && [s rangeOfString:@"/"].location == NSNotFound && [s rangeOfString:@"\\"].location == NSNotFound && [s rangeOfString:[NSString stringWithFormat:@"%C",(unichar)0]].location == NSNotFound && [s lengthOfBytesUsingEncoding:NSUTF8StringEncoding] <= 255;
}
static void inventoryTree(NSString *base, NSString *relative, NSString *root, NSMutableArray *entries, NSUInteger *total) {
    NSString *dir = relative.length ? [base stringByAppendingPathComponent:relative] : base;
    NSArray *names = [fm() contentsOfDirectoryAtPath:dir error:nil]; check(names != nil, @"Cannot read save directory");
    for (NSString *name in [names sortedArrayUsingSelector:@selector(compare:)]) {
        check(safeName(name), @"Unsupported save filename");
        NSString *rel = relative.length ? [relative stringByAppendingPathComponent:name] : name;
        NSString *path = [base stringByAppendingPathComponent:rel]; struct stat st;
        check(lstat(path.fileSystemRepresentation, &st) == 0 && (S_ISREG(st.st_mode) || S_ISDIR(st.st_mode)), @"Unsupported save entry");
        NSMutableDictionary *e = [@{@"root":root,@"path":rel,@"type":S_ISDIR(st.st_mode)?@"directory":@"file"} mutableCopy];
        NSString *guest = guestName(path); if (guest) { check(safeName(guest), @"Invalid guest name"); e[@"guestName"] = guest; }
        if (S_ISREG(st.st_mode)) {
            check(st.st_size >= 0 && (uint64_t)st.st_size <= limit-*total, @"Save exceeds local snapshot budget"); *total += st.st_size;
            NSData *bytes = [NSData dataWithContentsOfFile:path]; check(bytes != nil, @"Cannot read save"); e[@"size"] = @(bytes.length); e[@"sha256"] = dm_save_hash(bytes);
        }
        [entries addObject:e]; check(entries.count <= 50000, @"Too many save entries");
        if (S_ISDIR(st.st_mode)) inventoryTree(base, rel, root, entries, total);
    }
}
static void durableTree(NSString *dir) {
    for (NSString *name in [fm() contentsOfDirectoryAtPath:dir error:nil]) {
        NSString *p = [dir stringByAppendingPathComponent:name]; BOOL isDir=NO;
        [fm() fileExistsAtPath:p isDirectory:&isDir]; if (isDir) durableTree(p); else flush(p);
    }
    flush(dir);
}
@implementation DMSaveArchive
+ (NSDictionary *)inventory:(NSString *)capture {
    NSMutableDictionary *roots=[NSMutableDictionary dictionary]; NSMutableArray *entries=[NSMutableArray array]; NSUInteger total=0;
    for (NSString *root in @[@"account",@"device"]) {
        NSString *base=[capture stringByAppendingPathComponent:root]; BOOL isDir=NO; BOOL exists=[fm() fileExistsAtPath:base isDirectory:&isDir];
        check(!exists || isDir, @"Invalid save root"); roots[root]=@(exists); if (exists) inventoryTree(base,@"",root,entries,&total);
    }
    return @{@"roots":roots,@"entries":entries};
}
+ (void)write:(NSDictionary *)manifest capture:(NSString *)capture to:(NSString *)path {
    NSData *json=[NSJSONSerialization dataWithJSONObject:manifest options:NSJSONWritingSortedKeys error:nil]; check(json && json.length <= (8<<20),@"Manifest too large");
    NSMutableData *plain=[NSMutableData data];
    for (NSDictionary *e in manifest[@"entries"]) if ([e[@"type"] isEqual:@"file"]) {
        NSData *data=[NSData dataWithContentsOfFile:[[capture stringByAppendingPathComponent:e[@"root"]] stringByAppendingPathComponent:e[@"path"]]];
        check(data && [dm_save_hash(data) isEqual:e[@"sha256"]] && plain.length+data.length<=limit,@"Snapshot changed"); [plain appendData:data];
    }
    uLongf n=compressBound(plain.length); NSMutableData *compressed=[NSMutableData dataWithLength:n];
    check(compress2(compressed.mutableBytes,&n,plain.bytes,plain.length,Z_DEFAULT_COMPRESSION)==Z_OK,@"Compression failed"); compressed.length=n;
    NSMutableData *out=[NSMutableData dataWithBytes:"NXSV0001" length:8]; uint32_t length=htonl((uint32_t)json.length); [out appendBytes:&length length:4]; [out appendData:json]; [out appendData:compressed]; dm_save_atomic(path,out);
}
+ (NSDictionary *)read:(NSString *)archive into:(NSString *)stage {
    NSDictionary *attr=[fm() attributesOfItemAtPath:archive error:nil]; check([attr fileSize]<=128u<<20,@"Archive too large");
    NSData *data=[NSData dataWithContentsOfFile:archive]; check(data.length>=12 && !memcmp(data.bytes,"NXSV0001",8),@"Invalid archive header");
    uint32_t length; memcpy(&length,(const char *)data.bytes+8,4); length=ntohl(length); check(length<=8u<<20 && 12+(NSUInteger)length<data.length,@"Invalid manifest length");
    NSDictionary *m=[NSJSONSerialization JSONObjectWithData:[data subdataWithRange:NSMakeRange(12,length)] options:0 error:nil];
    check([m isKindOfClass:NSDictionary.class] && [m[@"format"] isEqual:@1] && CFGetTypeID((__bridge CFTypeRef)m[@"format"])!=CFBooleanGetTypeID(),@"Invalid manifest");
    check([m[@"revision"] isKindOfClass:NSString.class] && [[NSUUID alloc] initWithUUIDString:m[@"revision"]] && [m[@"device"] isKindOfClass:NSString.class] && [[NSUUID alloc] initWithUUIDString:m[@"device"]],@"Invalid revision identity");
    check(m[@"parent"]==NSNull.null || ([m[@"parent"] isKindOfClass:NSString.class] && [[NSUUID alloc] initWithUUIDString:m[@"parent"]]),@"Invalid parent");
    NSDictionary *roots=m[@"roots"]; NSArray *entries=m[@"entries"];
    check([roots isKindOfClass:NSDictionary.class] && roots.count==2 && roots[@"account"] && roots[@"device"] && CFGetTypeID((__bridge CFTypeRef)roots[@"account"])==CFBooleanGetTypeID() && CFGetTypeID((__bridge CFTypeRef)roots[@"device"])==CFBooleanGetTypeID(),@"Invalid root inventory");
    check([entries isKindOfClass:NSArray.class] && entries.count<=50000,@"Invalid entries");
    NSMutableDictionary *seen=[NSMutableDictionary dictionary]; NSUInteger total=0;
    for (NSDictionary *e in entries) {
        check([e isKindOfClass:NSDictionary.class],@"Invalid entry"); NSString *root=e[@"root"], *path=e[@"path"], *type=e[@"type"];
        check([root isKindOfClass:NSString.class] && roots[root] && [roots[root] boolValue] && [path isKindOfClass:NSString.class] && path.length<=4096,@"Invalid root/path");
        for (NSString *part in [path componentsSeparatedByString:@"/"]) check(safeName(part),@"Unsafe path");
        NSString *key=[[root stringByAppendingPathComponent:path] lowercaseString]; check(!seen[key],@"Duplicate path");
        if ([path containsString:@"/"]) check([seen[key.stringByDeletingLastPathComponent] isEqual:@"directory"],@"Missing parent directory");
        check([type isEqual:@"file"] || [type isEqual:@"directory"],@"Unsupported entry type"); seen[key]=type;
        if (e[@"guestName"]) check(safeName(e[@"guestName"]),@"Invalid guest name");
        if ([type isEqual:@"file"]) {
            check([e[@"size"] isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)e[@"size"])!=CFBooleanGetTypeID() && [e[@"size"] doubleValue]==(double)[e[@"size"] unsignedLongLongValue] && [e[@"size"] longLongValue]>=0 && [e[@"size"] unsignedLongLongValue]<=limit-total,@"Invalid expanded length"); total += [e[@"size"] unsignedLongLongValue];
            check([e[@"sha256"] isKindOfClass:NSString.class] && [e[@"sha256"] length]==64,@"Invalid file hash");
        }
    }
    NSMutableData *plain=[NSMutableData dataWithLength:total+1]; z_stream z={0}; check(inflateInit(&z)==Z_OK,@"Inflater failed");
    z.next_in=(Bytef *)data.bytes+12+length; z.avail_in=(uInt)(data.length-12-length); z.next_out=plain.mutableBytes; z.avail_out=(uInt)plain.length;
    int rc=inflate(&z,Z_FINISH); BOOL valid=rc==Z_STREAM_END && z.total_out==total && z.avail_in==0; inflateEnd(&z); check(valid,@"Invalid compressed payload"); plain.length=total;
    NSUInteger offset=0;
    for (NSDictionary *e in entries) if ([e[@"type"] isEqual:@"file"]) {
        NSUInteger n=[e[@"size"] unsignedIntegerValue]; check([dm_save_hash([plain subdataWithRange:NSMakeRange(offset,n)]) isEqual:e[@"sha256"]],@"Hash mismatch"); offset+=n;
    }
    if (stage) {
        check(![fm() fileExistsAtPath:stage],@"Stage already exists"); check([fm() createDirectoryAtPath:stage withIntermediateDirectories:YES attributes:nil error:nil],@"Cannot stage restore");
        for (NSString *root in roots) if ([roots[root] boolValue]) check([fm() createDirectoryAtPath:[stage stringByAppendingPathComponent:root] withIntermediateDirectories:NO attributes:nil error:nil],@"Cannot stage root");
        offset=0;
        for (NSDictionary *e in entries) {
            NSString *p=[[stage stringByAppendingPathComponent:e[@"root"]] stringByAppendingPathComponent:e[@"path"]];
            if ([e[@"type"] isEqual:@"directory"]) check([fm() createDirectoryAtPath:p withIntermediateDirectories:NO attributes:nil error:nil],@"Cannot stage directory");
            else { NSUInteger n=[e[@"size"] unsignedIntegerValue]; check([[plain subdataWithRange:NSMakeRange(offset,n)] writeToFile:p options:0 error:nil],@"Cannot stage file"); offset+=n; }
            if (e[@"guestName"]) { NSData *v=[e[@"guestName"] dataUsingEncoding:NSUTF8StringEncoding]; check(setxattr(p.fileSystemRepresentation,"org.d2rmobile.guest-name",v.bytes,v.length,0,XATTR_NOFOLLOW)==0,@"Cannot restore guest name"); }
        }
        for (NSString *root in roots) if ([roots[root] boolValue]) {
            NSString *p=[stage stringByAppendingPathComponent:root]; unsigned char yes=1;
            check(setxattr(p.fileSystemRepresentation,"org.nxnative.restored",&yes,1,0,0)==0,@"Cannot mark restored save");
        }
        durableTree(stage);
    }
    return m;
}
+ (void)recover:(NSString *)state save:(NSString *)save {
    NSString *journal=[state stringByAppendingPathComponent:@"restore.json"];
    if (![fm() fileExistsAtPath:journal]) return;
    NSDictionary *j=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:journal] options:0 error:nil]; check(j != nil,@"Restore journal unreadable; game remains stopped");
    NSString *backup=[state stringByAppendingPathComponent:j[@"backup"]];
    for (NSString *root in @[@"account",@"device"]) {
        NSString *target=[root isEqual:@"account"]?save:[save stringByAppendingString:@"_device"];
        NSString *old=[backup stringByAppendingPathComponent:root]; NSString *tmp=[target stringByAppendingString:@".sync-recover"];
        [fm() removeItemAtPath:tmp error:nil];
        if ([j[@"roots"][root] boolValue]) { check([fm() copyItemAtPath:old toPath:tmp error:nil],@"Cannot recover backup"); durableTree(tmp); }
        if ([fm() fileExistsAtPath:target]) check([fm() removeItemAtPath:target error:nil],@"Cannot recover live save");
        if ([j[@"roots"][root] boolValue]) check([fm() moveItemAtPath:tmp toPath:target error:nil],@"Cannot install recovered save");
        flush(target.stringByDeletingLastPathComponent);
    }
    dm_save_json([state stringByAppendingPathComponent:@"state.json"], j[@"metadata"]);
    check([fm() removeItemAtPath:journal error:nil],@"Cannot finish recovery"); flush(state);
}
+ (void)restore:(NSString *)stage manifest:(NSDictionary *)m state:(NSString *)state save:(NSString *)save metadata:(NSDictionary *)metadata {
    NSString *backupName=[@"backup-" stringByAppendingString:NSUUID.UUID.UUIDString]; NSString *backup=[state stringByAppendingPathComponent:backupName];
    check([fm() createDirectoryAtPath:backup withIntermediateDirectories:NO attributes:nil error:nil],@"Cannot create backup"); NSMutableDictionary *roots=[NSMutableDictionary dictionary];
    for (NSString *root in @[@"account",@"device"]) {
        NSString *target=[root isEqual:@"account"]?save:[save stringByAppendingString:@"_device"]; BOOL exists=[fm() fileExistsAtPath:target]; roots[root]=@(exists);
        if (exists) check([fm() copyItemAtPath:target toPath:[backup stringByAppendingPathComponent:root] error:nil],@"Cannot preserve local save");
    }
    durableTree(backup);
    NSString *stateFile=[state stringByAppendingPathComponent:@"state.json"];
    NSDictionary *old=[NSJSONSerialization JSONObjectWithData:([NSData dataWithContentsOfFile:stateFile]?:[NSData dataWithBytes:"{}" length:2]) options:0 error:nil];
    NSString *journal=[state stringByAppendingPathComponent:@"restore.json"];
    dm_save_json(journal,@{@"backup":backupName,@"roots":roots,@"metadata":old?:@{}}); checkpoint("journal");
    for (NSString *root in @[@"account",@"device"]) {
        NSString *target=[root isEqual:@"account"]?save:[save stringByAppendingString:@"_device"];
        if ([fm() fileExistsAtPath:target]) check([fm() removeItemAtPath:target error:nil],@"Cannot replace save");
        if ([m[@"roots"][root] boolValue]) check([fm() moveItemAtPath:[stage stringByAppendingPathComponent:root] toPath:target error:nil],@"Cannot install save");
        flush(target.stringByDeletingLastPathComponent); checkpoint(root.UTF8String);
    }
        checkpoint("installed");
    dm_save_json(stateFile,metadata); checkpoint("metadata");
    check([fm() removeItemAtPath:journal error:nil],@"Cannot complete restore"); flush(state);
    [fm() removeItemAtPath:stage error:nil];
}
@end
