#pragma once
#import <UIKit/UIKit.h>
@class DMControllerPairing;
@interface DMQRScanner : UIViewController
@property(nonatomic, copy) void (^scanned)(DMControllerPairing *pairing);
@end
