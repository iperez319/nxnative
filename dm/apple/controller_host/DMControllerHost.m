#import "DMControllerHost.h"
#import "../controller/DMControllerBluetooth.h"
#import "../controller/DMControllerPairing.h"
#include "dm_input.h"

@implementation DMControllerHost {
    DMControllerSession *_session;
    NSString *_status, *_invitation, *_pairingCode, *_bluetoothService;
    BOOL _bluetooth, _owned;
    dm_control_state _state;
}
+ (instancetype)shared { static DMControllerHost *host; static dispatch_once_t once; dispatch_once(&once, ^{ host = [self new]; }); return host; }
- (instancetype)init {
    if ((self = [super init])) {
        _status = @"Connect an iPhone to use it as player 1. Local player-1 controls are replaced until disconnect.";
        _session = [DMControllerSession new];
        __weak DMControllerHost *weak = self;
        _session.statusChanged = ^(NSString *text) {
            DMControllerHost *s = weak; if (!s) return;
            [s updateOwnership];
            s->_status = s.connected ? @"iPhone controller connected — player 1" : text;
            if (!s->_session.pairingAvailable || s.connected) {
                s->_invitation = s->_pairingCode = s->_bluetoothService = nil;
            } else {
                if (s->_bluetooth && s->_session.port && !s->_session.auxiliaryTransport) [s startBridge];
                [s updateCode];
            }
            if (s.changed) s.changed();
        };
        _session.receivedState = ^(dm_control_state state) {
            DMControllerHost *s = weak; if (!s) return;
            [s updateOwnership];
            s->_state = state;
            if (s.connected) dm_input_remote_set(state.buttons, state.axes[0], state.axes[1], state.axes[2], state.axes[3]);
            if (s.changed) s.changed();
        };
    }
    return self;
}
- (BOOL)connected { return _session.connected; }
- (NSString *)status { return _status; }
- (NSString *)pairingCode { return _pairingCode; }
- (NSString *)invitation { return _invitation; }
- (dm_control_state)state { return _state; }
- (void)updateOwnership {
    BOOL connected = self.connected;
    if (connected == _owned) return;
    _owned = connected; dm_input_remote_owner(connected);
    [NSNotificationCenter.defaultCenter postNotificationName:@"DMPhoneControllerOwnershipChanged" object:self];
}
- (void)updateCode {
    if (!_invitation || !_session.pairingAvailable) return;
    NSString *name = _bluetooth ? _bluetoothService : _session.pairingServiceName;
    if (!name) return;
    _pairingCode = _bluetooth ? [DMControllerPairing bluetoothCodeForInvitation:_invitation serviceUUID:name] :
        [DMControllerPairing codeForInvitation:_invitation receiverName:name peerToPeer:NO];
}
- (void)startBluetooth:(BOOL)bluetooth {
    [self stop:@"Starting a fresh invitation…"];
    _bluetooth = bluetooth;
    NSString *invitation = DMControllerSession.newInvitation;
    if (!invitation) { _status = @"Could not create a private invitation. Try again."; if (self.changed) self.changed(); return; }
    // listen resets synchronously and may send status before returning. Install
    // the invitation afterwards; listener readiness then supplies its QR hint.
    BOOL started = bluetooth ? [_session listenOnLoopbackWithInvitation:invitation] :
        [_session listenWithInvitation:invitation name:NSProcessInfo.processInfo.hostName peerToPeer:NO];
    if (started) { _invitation = invitation; [self updateCode]; }
    if (self.changed) self.changed();
}
- (void)startBridge {
    DMControllerBluetooth *bridge = [DMControllerBluetooth new];
    __weak DMControllerHost *weak = self;
    bridge.advertised = ^(NSString *uuid) {
        DMControllerHost *s = weak; if (!s) return;
        s->_bluetoothService = uuid; s->_status = @"Scan this QR from nx Controller on your iPhone. Bluetooth is experimental.";
        [s updateCode]; if (s.changed) s.changed();
    };
    bridge.failed = ^(NSString *reason) { [weak stop:reason]; };
    _session.auxiliaryTransport = bridge; [bridge listenForTLSPort:_session.port];
}
- (void)stop:(NSString *)reason {
    [_session stop:reason]; [self updateOwnership];
    _invitation = _pairingCode = _bluetoothService = nil; _state = (dm_control_state){0};
}
- (void)endPairing { if (!self.connected) [self stop:@"Pairing closed. Start again to create a fresh invitation."]; }
@end
