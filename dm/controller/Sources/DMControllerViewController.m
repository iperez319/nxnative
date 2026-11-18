#import <UIKit/UIKit.h>
#import "DMControllerSession.h"
#import "DmGamepadOutput.h"
#import "DmGameMenu.h"
#import "DmLayout.h"
#import "DMControllerPairing.h"
#import "DMQRScanner.h"
#import "DMControllerBluetooth.h"

@interface DMConnectionViewController : UITableViewController
@property(nonatomic, copy) void (^connect)(nw_endpoint_t, NSString *, BOOL, NSString *, DMControllerDiscovery *);
@property(nonatomic, copy) void (^closed)(void);
@property(nonatomic, copy) void (^connectBluetooth)(DMControllerPairing *);
@end
@implementation DMConnectionViewController {
    DMControllerDiscovery *_discovery;
    NSArray *_endpoints;
    UITextField *_invitation;
    UISwitch *_peerToPeer;
    UILabel *_status;
    NSString *_scannedReceiver;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"Connect to iPad or Mac";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    _invitation = [UITextField new]; _invitation.placeholder = @"Paste receiver's 64-character invitation";
    _invitation.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _invitation.autocorrectionType = UITextAutocorrectionTypeNo; _invitation.spellCheckingType = UITextSpellCheckingTypeNo;
    _invitation.secureTextEntry = YES; _invitation.clearButtonMode = UITextFieldViewModeWhileEditing;
    _invitation.accessibilityLabel = @"Receiver invitation";
    _peerToPeer = [UISwitch new]; _status = [UILabel new]; _status.numberOfLines = 0;
    _peerToPeer.on = [NSUserDefaults.standardUserDefaults boolForKey:@"ControllerPeerToPeerExperiment"];
    [_peerToPeer addTarget:self action:@selector(modeChanged) forControlEvents:UIControlEventValueChanged];
    _status.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    _status.text = @"Enable pairing in your iPad or Mac game's Controllers menu, then scan its QR here. nx Input Test also works. The QR selects the connection mode. Manual invitation paste is available for Wi-Fi.";
    _discovery = [DMControllerDiscovery new]; _endpoints = @[];
    __weak DMConnectionViewController *weak = self;
    _discovery.changed = ^(NSArray *items) {
        DMConnectionViewController *s = weak; if (!s) return; s->_endpoints = items; [s.tableView reloadData];
        for (nw_endpoint_t endpoint in items) {
            if (s->_scannedReceiver && [s->_scannedReceiver isEqual:@(nw_endpoint_get_bonjour_service_name(endpoint))]) {
                s->_scannedReceiver = nil; [s connectEndpoint:endpoint]; break;
            }
        }
    };
    _discovery.statusChanged = ^(NSString *text) { DMConnectionViewController *s = weak; if (!s) return; s->_status.text = text; [s.tableView reloadData]; };
}
- (void)done { [_discovery stop]; [self dismissViewControllerAnimated:YES completion:self.closed]; }
- (void)modeChanged {
    [NSUserDefaults.standardUserDefaults setBool:_peerToPeer.on forKey:@"ControllerPeerToPeerExperiment"];
    [_discovery stop]; _status.text = @"Connection mode changed. Search again to apply it."; [self.tableView reloadData];
}
- (void)viewDidDisappear:(BOOL)animated { [super viewDidDisappear:animated]; [_discovery stop]; _invitation.text = @""; _scannedReceiver = nil; }
- (void)scan {
    [self.view endEditing:YES]; [_discovery stop];
    DMQRScanner *scanner = [DMQRScanner new]; __weak DMConnectionViewController *weak = self;
    scanner.scanned = ^(DMControllerPairing *pairing) {
        DMConnectionViewController *s = weak; if (!s) return;
        if (pairing.bluetooth) {
            void (^connect)(DMControllerPairing *) = s.connectBluetooth;
            [s dismissViewControllerAnimated:YES completion:^{ if (connect) connect(pairing); }];
            return;
        }
        s->_invitation.text = pairing.invitation; s->_peerToPeer.on = pairing.peerToPeer;
        [NSUserDefaults.standardUserDefaults setBool:pairing.peerToPeer forKey:@"ControllerPeerToPeerExperiment"];
        s->_scannedReceiver = pairing.receiverName;
        s->_status.text = @"QR scanned. Finding your receiver… If its name changed, select it below.";
        [s->_discovery startWithPeerToPeer:pairing.peerToPeer]; [s.tableView reloadData];
    };
    [self.navigationController pushViewController:scanner animated:YES];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return section ? (NSInteger)_endpoints.count : 6; }
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section { return section ? @"Receivers" : @"Local connection"; }
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {
    return section ? @"The invitation authenticates the receiver. Device names alone do not prove identity. Transfer the invitation privately; it expires when the receiver stops." :
        @"Peer-to-peer is an experiment, not verified airplane support. Enable it on both devices for no-router testing. Wi-Fi must be on.";
}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    if (path.section) {
        nw_endpoint_t endpoint = _endpoints[path.row]; cell.textLabel.text = @(nw_endpoint_get_bonjour_service_name(endpoint)); cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (path.row == 0) { cell.textLabel.text = @"Scan receiver QR code"; cell.imageView.image = [UIImage systemImageNamed:@"qrcode.viewfinder"]; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (path.row == 1) {
        [cell.contentView addSubview:_invitation]; _invitation.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[[_invitation.leadingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.leadingAnchor],
            [_invitation.trailingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.trailingAnchor],
            [_invitation.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:12], [_invitation.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12]]];
    } else if (path.row == 2) { cell.textLabel.text = @"Test peer-to-peer (unverified)"; cell.accessoryView = _peerToPeer;
    } else if (path.row == 3) { cell.textLabel.text = @"Search for receivers"; cell.textLabel.textColor = self.view.tintColor;
    } else if (path.row == 5) { cell.textLabel.text = @"Allow Bluetooth for testing"; cell.textLabel.textColor = self.view.tintColor;
    } else {
        cell.textLabel.text = _status.text; cell.textLabel.numberOfLines = 0; cell.textLabel.font = _status.font;
    }
    return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (!path.section) {
        if (path.row == 0) [self scan];
        if (path.row == 5) [DMControllerBluetooth requestAccess];
        if (path.row == 3) { [self.view endEditing:YES]; _scannedReceiver = nil; _status.text = @"Searching for 30 seconds…"; [_discovery startWithPeerToPeer:_peerToPeer.on]; [table reloadData]; }
        return;
    }
    [self connectEndpoint:_endpoints[path.row]];
}
- (void)connectEndpoint:(nw_endpoint_t)endpoint {
    NSString *invitation = [_invitation.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSCharacterSet *bad = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"] invertedSet];
    if (invitation.length != 64 || [invitation rangeOfCharacterFromSet:bad].location != NSNotFound) {
        _status.text = @"Scan the iPad QR code or paste the complete invitation, then select the receiver again."; [self.tableView reloadData]; return;
    }
    BOOL p2p = _peerToPeer.on;
    NSString *name = @(nw_endpoint_get_bonjour_service_name(endpoint));
    void (^connect)(nw_endpoint_t, NSString *, BOOL, NSString *, DMControllerDiscovery *) = self.connect;
    // Experimental handoff: test whether keeping discovery during setup helps
    // the unresolved no-router failure. The session bounds and cancels it.
    DMControllerDiscovery *discovery = _discovery; _discovery = nil;
    discovery.changed = nil; discovery.statusChanged = nil;
    [self dismissViewControllerAnimated:YES completion:^{
        if (connect) connect(endpoint, invitation, p2p, name, discovery); else [discovery stop];
    }];
}
@end

@interface DMControllerViewController : UIViewController <UIAdaptivePresentationControllerDelegate> @end
@implementation DMControllerViewController {
    DMControllerSession *_session;
    UIView *_pad;
    UILabel *_status, *_readout;
    NSString *_connectionStatus, *_hostName;
    dm_control_state _state;
    NSTimer *_timer;
    DMControllerBluetooth *_bluetoothSetup;
    BOOL _usingBluetooth;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor = [UIColor colorWithRed:0.035 green:0.07 blue:0.12 alpha:1];
    DMControllerSetDiagnosticFile([NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"controller-network.log"]);
    _session = [DMControllerSession new]; _session.diagnoseInputStalls = YES;
    _connectionStatus = @"Controller test — open the gear to connect";
    __weak DMControllerViewController *weak = self;
    _session.statusChanged = ^(NSString *text) {
        DMControllerViewController *s = weak; if (!s) return;
        s->_connectionStatus = text;
        UIApplication.sharedApplication.idleTimerDisabled = s->_session.connected;
        if (!s->_session.connected) { s->_state = (dm_control_state){0}; dm_gamepad_reset(); }
        [s refresh];
    };
    dm_gamepad_set_output(^(uint64_t buttons, int32_t lx, int32_t ly, int32_t rx, int32_t ry) {
        DMControllerViewController *s = weak; if (!s) return;
        s->_state = (dm_control_state){(uint32_t)buttons, {lx, ly, rx, ry}};
        [s->_session publish:s->_state];
    });
    dm_gamepad_set_menu([UIMenu menuWithTitle:@"Phone controller" children:@[
        [UIAction actionWithTitle:@"Connection" image:[UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"] identifier:nil handler:^(UIAction *action) { [weak connection]; }],
        [UIAction actionWithTitle:@"Controls" image:[UIImage systemImageNamed:@"gamecontroller"] identifier:nil handler:^(UIAction *action) { [weak settings]; }],
        [UIAction actionWithTitle:@"Disconnect" image:[UIImage systemImageNamed:@"xmark.circle"] identifier:nil handler:^(UIAction *action) { [weak disconnect]; }]
    ]]);
    _pad = dm_gamepad_view(self.view.bounds); _pad.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; [self.view addSubview:_pad];
    _status = [UILabel new]; _readout = [UILabel new];
    for (UILabel *label in @[_status, _readout]) {
        label.textColor = UIColor.whiteColor; label.textAlignment = NSTextAlignmentCenter; label.numberOfLines = 0;
        label.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular]; label.userInteractionEnabled = NO;
        label.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:label];
        [label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
        [label.widthAnchor constraintLessThanOrEqualToAnchor:self.view.widthAnchor multiplier:0.5].active = YES;
    }
    [_status.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-30].active = YES;
    [_readout.topAnchor constraintEqualToAnchor:_status.bottomAnchor constant:12].active = YES;
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) { [weak refresh]; }];
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    [nc addObserver:self selector:@selector(inactive) name:UISceneWillDeactivateNotification object:nil];
    [nc addObserver:self selector:@selector(inactive) name:UISceneDidDisconnectNotification object:nil];
    [nc addObserver:self selector:@selector(background) name:UISceneDidEnterBackgroundNotification object:nil];
    [nc addObserver:self selector:@selector(active) name:UISceneDidActivateNotification object:nil];
    [self refresh];
}
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; dm_gamepad_arrange(_pad, dm_layout_pad_only(_pad.bounds)); }
- (void)refresh {
    _status.text = _session.connected ? [NSString stringWithFormat:@"Connected to %@", _hostName ?: @"receiver"] : _connectionStatus;
    _readout.text = [NSString stringWithFormat:@"Buttons %04x\nL %d, %d  R %d, %d\nACK round trip %.1f ms\n%@", _state.buttons,
        _state.axes[0], _state.axes[1], _state.axes[2], _state.axes[3], _session.lastRoundTripNS / 1e6,
        _usingBluetooth ? @"Bluetooth LE L2CAP experiment; end-to-end TLS" : _session.pathSummary];
}
- (void)connection {
    DMConnectionViewController *vc = [[DMConnectionViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    vc.closed = ^{ dm_gamepad_host_ui(NO); };
    __weak DMControllerViewController *weak = self;
    vc.connect = ^(nw_endpoint_t endpoint, NSString *invitation, BOOL p2p, NSString *name, DMControllerDiscovery *discovery) {
        DMControllerViewController *s = weak; if (!s) { [discovery stop]; return; }
        [s->_bluetoothSetup stop]; s->_bluetoothSetup = nil; s->_usingBluetooth = NO;
        s->_hostName = name; dm_gamepad_host_ui(NO); dm_gamepad_reset();
        [s->_session connectTo:endpoint invitation:invitation peerToPeer:p2p discovery:discovery];
    };
    vc.connectBluetooth = ^(DMControllerPairing *pairing) { [weak connectBluetooth:pairing]; };
    [self show:vc];
}
- (void)connectBluetooth:(DMControllerPairing *)pairing {
    [self disconnect]; _usingBluetooth = YES; _hostName = @"Bluetooth receiver";
    _connectionStatus = @"Finding Bluetooth receiver…"; dm_gamepad_host_ui(NO); [self refresh];
    DMControllerBluetooth *bridge = [DMControllerBluetooth new]; _bluetoothSetup = bridge;
    __weak DMControllerViewController *weak = self; __weak DMControllerBluetooth *weakBridge = bridge;
    bridge.localListenerReady = ^(uint16_t port) {
        DMControllerViewController *s = weak; DMControllerBluetooth *carrier = weakBridge;
        if (!s || !carrier) return;
        if ([s->_session connectTo:nw_endpoint_create_host("127.0.0.1", [NSString stringWithFormat:@"%u", port].UTF8String) invitation:pairing.invitation peerToPeer:NO])
            s->_session.auxiliaryTransport = carrier;
        else [carrier stop];
        s->_bluetoothSetup = nil;
        carrier.localListenerReady = nil;
    };
    bridge.failed = ^(NSString *reason) {
        DMControllerViewController *s = weak; if (!s) return;
        [s->_session stop:reason]; s->_bluetoothSetup = nil;
    };
    [bridge connectToServiceUUID:pairing.receiverName];
}
- (void)settings {
    UIViewController *settings = dm_gamepad_settings();
    settings.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
    [self show:settings];
}
- (void)show:(UIViewController *)vc {
    dm_gamepad_host_ui(YES);
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nav animated:YES completion:nil]; nav.presentationController.delegate = self;
}
- (void)close { [self dismissViewControllerAnimated:YES completion:^{ dm_gamepad_host_ui(NO); }]; }
- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController { dm_gamepad_host_ui(NO); }
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; dm_gamepad_host_ui(NO); }
- (void)disconnect { [_bluetoothSetup stop]; _bluetoothSetup = nil; [_session stop:@"Disconnected — controls below can still be tested"]; dm_gamepad_reset(); }
- (void)inactive {
    [_bluetoothSetup stop]; _bluetoothSetup = nil;
    dm_gamepad_active(NO); [_session stop:@"Phone inactive — start a fresh connection to resume"];
    UIApplication.sharedApplication.idleTimerDisabled = NO;
}
- (void)background { [self dismissViewControllerAnimated:NO completion:nil]; }
- (void)active { dm_gamepad_active(YES); }
- (BOOL)prefersStatusBarHidden { return YES; }
- (void)dealloc { [_timer invalidate]; [NSNotificationCenter.defaultCenter removeObserver:self]; }
@end
