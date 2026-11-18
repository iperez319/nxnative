#import <UIKit/UIKit.h>
#import "../../apple/controller_host/DMControllerHost.h"
#import "../../apple/controller/DMQRCode.h"

@interface DMPhoneControllerUI : UIViewController @end
@implementation DMPhoneControllerUI {
    UILabel *_status, *_readout;
    UIImageView *_qr;
    UITextView *_manual;
    UISegmentedControl *_mode;
    NSString *_renderedCode;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"Connect iPhone"; self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleProminent target:self action:@selector(close)];
    _status = [UILabel new]; _status.numberOfLines = 0;
    UILabel *help = [UILabel new]; help.numberOfLines = 0;
    help.text = @"Open nx Controller on your iPhone, then Connection → Scan receiver QR code. Choose Wi-Fi for a shared local network, or Bluetooth for experimental offline play. Pairing lasts 60 seconds. Keep this QR private. Close host UI to play; other player slots stay assigned.";
    _mode = [[UISegmentedControl alloc] initWithItems:@[@"Local Wi-Fi", @"Bluetooth (experimental)"]];
    _mode.selectedSegmentIndex = [NSUserDefaults.standardUserDefaults boolForKey:@"PhoneControllerBluetooth"] ? 1 : 0;
    [_mode addTarget:self action:@selector(modeChanged) forControlEvents:UIControlEventValueChanged];
    UIButton *start = [UIButton buttonWithType:UIButtonTypeSystem]; [start setTitle:@"Enable pairing for player 1" forState:UIControlStateNormal];
    [start addTarget:self action:@selector(start) forControlEvents:UIControlEventTouchUpInside];
    UIButton *stop = [UIButton buttonWithType:UIButtonTypeSystem]; [stop setTitle:@"Disconnect / cancel pairing" forState:UIControlStateNormal];
    [stop addTarget:self action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
    _qr = [UIImageView new]; _qr.contentMode = UIViewContentModeScaleAspectFit; _qr.backgroundColor = UIColor.whiteColor;
    _qr.layer.magnificationFilter = kCAFilterNearest; _qr.layer.minificationFilter = kCAFilterNearest;
    _qr.isAccessibilityElement = YES; _qr.accessibilityLabel = @"Private iPhone pairing QR";
    [_qr.heightAnchor constraintEqualToConstant:260].active = YES;
    _manual = [UITextView new]; _manual.editable = NO; _manual.selectable = YES;
    _manual.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    [_manual.heightAnchor constraintEqualToConstant:80].active = YES;
    _readout = [UILabel new]; _readout.numberOfLines = 0;
    UILabel *footer = [UILabel new]; footer.numberOfLines = 0;
    footer.text = @"Buttons and sticks can be tested here while gameplay input is suppressed. Plus and Minus remain game buttons. Opening menus or disconnecting does not pause or save the game. On connection loss local controls return. New pairing requires a fresh QR; remembered-device pairing is not available yet.";
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_status, help, _mode, start, stop, _qr, _manual, _readout, footer]];
    stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 16; stack.translatesAutoresizingMaskIntoConstraints = NO;
    UIScrollView *scroll = [UIScrollView new]; scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll]; [scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[scroll.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-20],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:20],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-20],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-40]]];
    __weak DMPhoneControllerUI *weak = self;
    DMControllerHost.shared.changed = ^{ [weak refresh]; }; [self refresh];
}
- (void)refresh {
    DMControllerHost *host = DMControllerHost.shared; _status.text = host.status;
    dm_control_state state = host.state;
    _readout.text = host.connected ? [NSString stringWithFormat:@"Button test: %04x\nLeft: %d, %d   Right: %d, %d", state.buttons, state.axes[0], state.axes[1], state.axes[2], state.axes[3]] : @"";
    NSString *code = host.pairingCode;
    if (_renderedCode != code && ![_renderedCode isEqual:code]) {
        _renderedCode = code; CGImageRef image = DMCreatePairingQR(code);
        _qr.image = image ? [UIImage imageWithCGImage:image] : nil; if (image) CGImageRelease(image);
    }
    _qr.hidden = !_qr.image;
    _manual.text = host.invitation && _mode.selectedSegmentIndex == 0 ? [@"Manual invitation (Wi-Fi):\n" stringByAppendingString:host.invitation] : @"";
    _manual.hidden = !_manual.text.length;
}
- (void)start { [DMControllerHost.shared startBluetooth:_mode.selectedSegmentIndex == 1]; }
- (void)stop { [DMControllerHost.shared stop:@"iPhone disconnected. Local player-1 controls restored."]; }
- (void)modeChanged {
    [NSUserDefaults.standardUserDefaults setBool:_mode.selectedSegmentIndex == 1 forKey:@"PhoneControllerBluetooth"];
    [self stop];
}
- (void)close { [DMControllerHost.shared endPairing]; [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.isBeingDismissed || self.navigationController.isBeingDismissed || self.isMovingFromParentViewController) [DMControllerHost.shared endPairing];
}
- (void)dealloc { DMControllerHost.shared.changed = nil; }
@end
UIViewController *dm_phone_controller_view(void) { return [DMPhoneControllerUI new]; }
