#import <UIKit/UIKit.h>

#ifdef DM_CONTROLLER_RECEIVER
@interface DMReceiverViewController : UIViewController @end
#else
@interface DMControllerViewController : UIViewController @end
#endif
@interface DMControllerAppDelegate : UIResponder <UIApplicationDelegate>
@end
@implementation DMControllerAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    return YES;
}
@end

// Both targets use the scene lifecycle. iOS 27 traps apps linked with the new
// SDK that still create their only window from UIApplicationDelegate.
@interface DMControllerSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation DMControllerSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    if (![scene isKindOfClass:UIWindowScene.class]) return;
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
#ifdef DM_CONTROLLER_RECEIVER
    self.window.rootViewController = [DMReceiverViewController new];
#else
    self.window.rootViewController = [DMControllerViewController new];
#endif
    [self.window makeKeyAndVisible];
}
- (void)sceneDidDisconnect:(UIScene *)scene { self.window = nil; }
@end
int main(int argc, char **argv) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(DMControllerAppDelegate.class)); }
}
