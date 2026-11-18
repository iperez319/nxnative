// Separate iPad test receiver target. Never links or publishes into the host.
#import <UIKit/UIKit.h>
#import "DMControllerSession.h"
#import "DMControllerPairing.h"
#import "DMQRCode.h"
#import "DMControllerBluetooth.h"

@interface DMReceiverViewController : UIViewController @end
@implementation DMReceiverViewController {
    DMControllerSession *_session;
    UILabel *_status, *_readout, *_path;
    UITextView *_invitation;
    UIImageView *_qr;
    UIButton *_manual;
    NSString *_pairingInvitation, *_renderedServiceName;
    UISwitch *_peerToPeer;
    UISwitch *_bluetooth;
    NSString *_bluetoothService;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor = UIColor.systemBackgroundColor;
    DMControllerSetDiagnosticFile([NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"controller-network.log"]);
    _session = [DMControllerSession new]; _session.diagnoseInputStalls = YES;
    _status = [UILabel new]; _readout = [UILabel new];
    _status.text = @"Input test receiver. No game is running. Tap Start to enable pairing for 60 seconds.";
    _status.numberOfLines = _readout.numberOfLines = 0;
    _invitation = [UITextView new]; _invitation.editable = NO; _invitation.selectable = YES;
    _invitation.font = [UIFont monospacedSystemFontOfSize:18 weight:UIFontWeightRegular];
    [_invitation.heightAnchor constraintEqualToConstant:100].active = YES;
    UILabel *hint = [UILabel new]; hint.numberOfLines = 0;
    hint.text = @"Select a test mode, tap Start, then scan from nx Controller on your iPhone. Bluetooth mode needs Bluetooth on; Wi-Fi modes need Wi-Fi on. Keep both apps open.";
    UILabel *experiment = [UILabel new]; experiment.text = @"Test peer-to-peer (airplane support unverified)"; experiment.numberOfLines = 0;
    _peerToPeer = [UISwitch new];
    _peerToPeer.on = [NSUserDefaults.standardUserDefaults boolForKey:@"ControllerPeerToPeerExperiment"];
    [_peerToPeer addTarget:self action:@selector(modeChanged) forControlEvents:UIControlEventValueChanged];
    _path = [UILabel new]; _path.numberOfLines = 0; _path.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    _qr = [UIImageView new]; _qr.contentMode = UIViewContentModeScaleAspectFit; _qr.backgroundColor = UIColor.whiteColor;
    _qr.layer.magnificationFilter = kCAFilterNearest; _qr.layer.minificationFilter = kCAFilterNearest;
    _qr.accessibilityLabel = @"Private pairing QR. Scan using nx Controller on your iPhone."; _qr.isAccessibilityElement = YES;
    [_qr.heightAnchor constraintEqualToConstant:260].active = YES; _qr.hidden = YES;
    _manual = [UIButton buttonWithType:UIButtonTypeSystem]; [_manual setTitle:@"Show manual invitation" forState:UIControlStateNormal];
    [_manual addTarget:self action:@selector(manual) forControlEvents:UIControlEventTouchUpInside]; _manual.hidden = YES; _invitation.hidden = YES;
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[experiment, _peerToPeer]]; row.spacing = 16;
    UILabel *bluetoothLabel = [UILabel new]; bluetoothLabel.text = @"Test Bluetooth LE (offline experiment)"; bluetoothLabel.numberOfLines = 0;
    _bluetooth = [UISwitch new];
    _bluetooth.on = [NSUserDefaults.standardUserDefaults boolForKey:@"ControllerBluetoothExperiment"];
    _peerToPeer.enabled = !_bluetooth.on;
    [_bluetooth addTarget:self action:@selector(bluetoothChanged) forControlEvents:UIControlEventValueChanged];
    UIStackView *bluetoothRow = [[UIStackView alloc] initWithArrangedSubviews:@[bluetoothLabel, _bluetooth]]; bluetoothRow.spacing = 16;
    UIButton *start = [UIButton buttonWithType:UIButtonTypeSystem]; [start setTitle:@"Start test receiver" forState:UIControlStateNormal];
    [start addTarget:self action:@selector(start) forControlEvents:UIControlEventTouchUpInside];
    UIButton *stop = [UIButton buttonWithType:UIButtonTypeSystem]; [stop setTitle:@"Stop and forget invitation" forState:UIControlStateNormal];
    [stop addTarget:self action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_status, hint, row, bluetoothRow, start, stop, _qr, _manual, _invitation, _readout, _path]];
    stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 12; stack.translatesAutoresizingMaskIntoConstraints = NO;
    UIScrollView *scroll = [UIScrollView new]; scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll]; [scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[scroll.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-24],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:24],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-48]]];
    __weak DMReceiverViewController *weak = self;
    _session.statusChanged = ^(NSString *text) {
        DMReceiverViewController *s = weak; if (!s) return; s->_status.text = text;
        UIApplication.sharedApplication.idleTimerDisabled = s->_session.connected;
        if (!s->_session.pairingAvailable || s->_session.connected) [s clearInvitation];
        else {
            if (s->_bluetooth.on && s->_session.port && !s->_session.auxiliaryTransport) [s startBluetoothBridge];
            [s refreshPairingQR];
        }
    };
    _session.receivedState = ^(dm_control_state state) {
        DMReceiverViewController *s = weak; if (!s) return;
        s->_readout.text = [NSString stringWithFormat:@"Buttons: %04x\nL: %d, %d\nR: %d, %d", state.buttons, state.axes[0], state.axes[1], state.axes[2], state.axes[3]];
        s->_path.text = s->_bluetooth.on ? @"Bluetooth LE L2CAP experiment; end-to-end TLS" : s->_session.pathSummary;
    };
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(inactive) name:UISceneWillDeactivateNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(inactive) name:UISceneDidDisconnectNotification object:nil];
}
- (void)start {
    NSString *invitation = DMControllerSession.newInvitation;
    if (!invitation || !(_bluetooth.on ? [_session listenOnLoopbackWithInvitation:invitation] : [_session listenWithInvitation:invitation name:UIDevice.currentDevice.name peerToPeer:_peerToPeer.on])) {
        _status.text = @"Could not start test receiver"; return;
    }
    _pairingInvitation = invitation; [self refreshPairingQR];
}
- (void)refreshPairingQR {
    NSString *name = _bluetooth.on ? _bluetoothService : _session.pairingServiceName;
    if (!_pairingInvitation || !name || [_renderedServiceName isEqual:name]) return;
    _renderedServiceName = name; _invitation.text = _pairingInvitation;
    NSString *code = _bluetooth.on ? [DMControllerPairing bluetoothCodeForInvitation:_pairingInvitation serviceUUID:name] : [DMControllerPairing codeForInvitation:_pairingInvitation receiverName:name peerToPeer:_peerToPeer.on];
    CGImageRef image = DMCreatePairingQR(code);
    _qr.image = image ? [UIImage imageWithCGImage:image] : nil; if (image) CGImageRelease(image);
    _qr.hidden = !_qr.image; _manual.hidden = _bluetooth.on;
    if (!_qr.image) {
        _status.text = _bluetooth.on ? @"Bluetooth QR could not be generated. Stop and start again." : @"QR could not be generated. Use Show manual invitation.";
        _invitation.hidden = _bluetooth.on;
    }
}
- (void)clearInvitation { _pairingInvitation = _renderedServiceName = _bluetoothService = nil; _invitation.text = @""; _invitation.hidden = YES; _manual.hidden = YES; _qr.image = nil; _qr.hidden = YES; [_manual setTitle:@"Show manual invitation" forState:UIControlStateNormal]; }
- (void)startBluetoothBridge {
    DMControllerBluetooth *bridge = [DMControllerBluetooth new];
    __weak DMReceiverViewController *weak = self;
    bridge.advertised = ^(NSString *uuid) {
        DMReceiverViewController *s = weak; if (!s) return;
        s->_bluetoothService = uuid; s->_status.text = @"Bluetooth receiver ready. Scan this QR on the iPhone."; [s refreshPairingQR];
    };
    bridge.failed = ^(NSString *reason) { DMReceiverViewController *s = weak; if (s) [s->_session stop:reason]; };
    _session.auxiliaryTransport = bridge; [bridge listenForTLSPort:_session.port];
}
- (void)manual { _invitation.hidden = !_invitation.hidden; [_manual setTitle:_invitation.hidden ? @"Show manual invitation" : @"Hide manual invitation" forState:UIControlStateNormal]; }
- (void)stop { [_session stop:@"Test receiver stopped; all input released"]; [self clearInvitation]; UIApplication.sharedApplication.idleTimerDisabled = NO; }
- (void)inactive { [_session stop:@"Receiver inactive; pairing stopped and input released. Tap Start again."]; [self clearInvitation]; UIApplication.sharedApplication.idleTimerDisabled = NO; }
- (void)modeChanged {
    [NSUserDefaults.standardUserDefaults setBool:_peerToPeer.on forKey:@"ControllerPeerToPeerExperiment"];
    [self stop]; _status.text = @"Connection mode changed. Tap Start to apply it and create a fresh invitation.";
}
- (void)bluetoothChanged {
    [NSUserDefaults.standardUserDefaults setBool:_bluetooth.on forKey:@"ControllerBluetoothExperiment"];
    _peerToPeer.enabled = !_bluetooth.on;
    [self stop];
    if (_bluetooth.on) [DMControllerBluetooth requestAccess];
    _status.text = @"Mode changed. Allow Bluetooth if prompted, then tap Start for a fresh QR.";
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
@end
