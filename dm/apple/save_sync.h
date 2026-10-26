#pragma once
/* Commit hook is invoked with filesystem path/mount locks held. It only clones
 * immutable roots; compression and networking are dispatched to a worker. */
void dm_sync_committed(void);
void dm_fs_sync_capture(void);
void dm_fs_set_sync_callback(void (*callback)(void));
void dm_sync_prepare(void);
void dm_sync_prelaunch(void *presenter, void (*ready)(void));
void dm_sync_menu(void *presenter);
void dm_sync_tick(void);
int dm_sync_mac_gate(void);
#ifdef __OBJC__
#import <Foundation/Foundation.h>
@interface DMSaveArchive : NSObject
+ (NSDictionary *)inventory:(NSString *)capture;
+ (NSDictionary *)read:(NSString *)archive into:(NSString *)stage;
+ (void)write:(NSDictionary *)manifest capture:(NSString *)capture to:(NSString *)path;
+ (void)recover:(NSString *)state save:(NSString *)save;
+ (void)restore:(NSString *)stage manifest:(NSDictionary *)manifest state:(NSString *)state save:(NSString *)save metadata:(NSDictionary *)metadata;
@end
void dm_sync_background_handler(void (^completion)(void));
void dm_save_atomic(NSString *path, NSData *data);
void dm_save_json(NSString *path, id value);
NSString *dm_save_hash(NSData *data);
#endif
