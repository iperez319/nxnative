#import <Cocoa/Cocoa.h>
#import "../apple/controller_host/DMControllerHost.h"
#import "../apple/controller/DMQRCode.h"
#include "dm_input.h"

@interface DMPhonePairingDocument : NSView @end
@implementation DMPhonePairingDocument
- (BOOL)isFlipped { return YES; }
@end

@interface DMPhoneControllerPanel : NSObject <NSWindowDelegate>
@property NSPanel *panel;
@property NSTextField *status;
@property NSTextField *readout;
@property NSTextField *manual;
@property NSImageView *qr;
@property NSSegmentedControl *mode;
@property NSString *renderedCode;
@property (weak) NSWindow *game;
- (void)show:(id)sender;
@end
@implementation DMPhoneControllerPanel
- (void)show:(id)sender {
    if (!self.panel) {
        self.panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 560, 660) styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
        self.panel.minSize = NSMakeSize(480, 420);
        self.panel.title = @"Connect iPhone — player 1"; self.panel.delegate = self; self.panel.releasedWhenClosed = NO;
        NSTextField *hint = [NSTextField wrappingLabelWithString:@"Open nx Controller on your iPhone → Connection → Scan receiver QR code. Wi-Fi uses a shared local network without internet. Bluetooth is experimental. Enabling pairing replaces local player-1 controls after connection; other player slots stay assigned."];
        self.status = [NSTextField wrappingLabelWithString:DMControllerHost.shared.status];
        self.mode = [NSSegmentedControl segmentedControlWithLabels:@[@"Local Wi-Fi", @"Bluetooth (experimental)"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(modeChanged:)];
        self.mode.selectedSegment = [NSUserDefaults.standardUserDefaults boolForKey:@"PhoneControllerBluetooth"] ? 1 : 0;
        NSButton *start = [NSButton buttonWithTitle:@"Enable pairing for player 1" target:self action:@selector(start:)];
        NSButton *stop = [NSButton buttonWithTitle:@"Disconnect / cancel pairing" target:self action:@selector(stop:)];
        self.qr = [NSImageView new]; self.qr.imageScaling = NSImageScaleProportionallyUpOrDown;
        [self.qr.heightAnchor constraintEqualToConstant:260].active = YES;
        self.manual = [NSTextField wrappingLabelWithString:@""]; self.manual.selectable = YES;
        self.readout = [NSTextField wrappingLabelWithString:@""];
        NSTextField *footer = [NSTextField wrappingLabelWithString:@"Keep this private QR visible while pairing (60-second limit). Test buttons here, then close this window to play. Menus suppress gameplay input; they do not pause or save. Losing application focus disconnects the phone. Each new session needs a fresh QR."];
        NSStackView *stack = [NSStackView stackViewWithViews:@[self.status, hint, self.mode, start, stop, self.qr, self.manual, self.readout, footer]];
        stack.orientation = NSUserInterfaceLayoutOrientationVertical; stack.alignment = NSLayoutAttributeLeading; stack.spacing = 12; stack.translatesAutoresizingMaskIntoConstraints = NO;
        NSView *content = self.panel.contentView; if (!content) return;
        NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:content.bounds];
        scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable; scroll.hasVerticalScroller = YES; [content addSubview:scroll];
        NSView *document = [DMPhonePairingDocument new]; document.translatesAutoresizingMaskIntoConstraints = NO;
        scroll.documentView = document; [document addSubview:stack];
        [NSLayoutConstraint activateConstraints:@[[document.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor],
            [stack.leadingAnchor constraintEqualToAnchor:document.leadingAnchor constant:20],
            [stack.trailingAnchor constraintEqualToAnchor:document.trailingAnchor constant:-20],
            [stack.topAnchor constraintEqualToAnchor:document.topAnchor constant:20],
            [stack.bottomAnchor constraintEqualToAnchor:document.bottomAnchor constant:-20],
            [self.qr.widthAnchor constraintEqualToAnchor:stack.widthAnchor]]];
        for (NSView *label in @[self.status, hint, self.manual, self.readout, footer])
            [label.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
        [self.panel center];
    }
    __weak DMPhoneControllerPanel *weak = self;
    DMControllerHost.shared.changed = ^{ [weak refresh]; }; [self refresh];
    [self.panel makeKeyAndOrderFront:nil]; dm_input_remote_block(1);
}
- (void)refresh {
    DMControllerHost *host = DMControllerHost.shared; self.status.stringValue = host.status;
    dm_control_state state = host.state;
    self.readout.stringValue = host.connected ? [NSString stringWithFormat:@"Button test: %04x   Left: %d, %d   Right: %d, %d", state.buttons, state.axes[0], state.axes[1], state.axes[2], state.axes[3]] : @"";
    NSString *code = host.pairingCode;
    if (self.renderedCode != code && ![self.renderedCode isEqual:code]) {
        self.renderedCode = code; CGImageRef image = DMCreatePairingQR(code);
        self.qr.image = image ? [[NSImage alloc] initWithCGImage:image size:NSMakeSize(260, 260)] : nil; if (image) CGImageRelease(image);
    }
    self.manual.stringValue = host.invitation && self.mode.selectedSegment == 0 ? [@"Manual Wi-Fi invitation: " stringByAppendingString:host.invitation] : @"";
    self.qr.hidden = !self.qr.image; self.manual.hidden = !self.manual.stringValue.length;
}
- (void)start:(id)sender { [DMControllerHost.shared startBluetooth:self.mode.selectedSegment == 1]; }
- (void)stop:(id)sender { [DMControllerHost.shared stop:@"iPhone disconnected. Local player-1 controls restored."]; }
- (void)modeChanged:(id)sender { [NSUserDefaults.standardUserDefaults setBool:self.mode.selectedSegment == 1 forKey:@"PhoneControllerBluetooth"]; [self stop:nil]; }
- (void)windowWillClose:(NSNotification *)note { [DMControllerHost.shared endPairing]; DMControllerHost.shared.changed = nil; [self.game makeKeyAndOrderFront:nil]; }
@end
static DMPhoneControllerPanel *phonePanel;
void dm_phone_controller_mac_menu(NSMenu *bar, NSWindow *game) {
    phonePanel = [DMPhoneControllerPanel new]; phonePanel.game = game;
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Controllers"];
    [menu addItemWithTitle:@"Connect iPhone / disconnect…" action:@selector(show:) keyEquivalent:@""].target = phonePanel;
    [[bar addItemWithTitle:@"Controllers" action:nil keyEquivalent:@""] setSubmenu:menu];
    if (getenv("DM_PHONE_PAIR_AT_START") && atoi(getenv("DM_PHONE_PAIR_AT_START")))
        dispatch_async(dispatch_get_main_queue(), ^{ [phonePanel show:nil]; });
    [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidResignActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        [DMControllerHost.shared stop:@"Receiver lost focus. Pair again to resume iPhone control."]; dm_input_remote_block(1);
    }];
    [NSWorkspace.sharedWorkspace.notificationCenter addObserverForName:NSWorkspaceWillSleepNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        [DMControllerHost.shared stop:@"Mac sleeping. Pair again to resume iPhone control."]; dm_input_remote_block(1);
    }];
}
