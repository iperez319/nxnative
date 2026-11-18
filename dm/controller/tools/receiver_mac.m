// Diagnostic receiver only: no game runtime or HID publication is linked.
#import "DMControllerSession.h"

int main(int argc, const char **argv) {
    @autoreleasepool {
        BOOL p2p = argc == 2 && !strcmp(argv[1], "--peer-to-peer");
        if (argc > 2 || (argc == 2 && !p2p)) { fprintf(stderr, "Usage: receiver-test [--peer-to-peer]\n"); return 2; }
        DMControllerSession *session = [DMControllerSession new];
        NSString *invitation = DMControllerSession.newInvitation;
        if (!invitation) return 2;
        session.statusChanged = ^(NSString *status) { puts(status.UTF8String); fflush(stdout); };
        session.receivedState = ^(dm_control_state s) {
            printf("buttons=%04x L=(%d,%d) R=(%d,%d)\n", s.buttons, s.axes[0], s.axes[1], s.axes[2], s.axes[3]); fflush(stdout);
        };
        if (![session listenWithInvitation:invitation name:NSProcessInfo.processInfo.hostName peerToPeer:p2p]) return 2;
        // This fresh test credential is deliberately shown for private transfer,
        // never put in Bonjour TXT records, persisted, or written to diagnostics.
        printf("Private, single-session invitation (paste on phone):\n%s\n", invitation.UTF8String);
        puts(p2p ? "Peer-to-peer experiment enabled; actual path and airplane support UNVERIFIED." : "LAN test; no internet required.");
        fflush(stdout);
        // Keep the Objective-C owner alive for callbacks on the main queue.
        [[NSRunLoop mainRunLoop] run];
        [session stop:@"Stopped"];
    }
    return 0;
}
