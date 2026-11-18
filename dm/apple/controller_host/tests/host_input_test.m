// Real encrypted loopback -> production receiver owner -> real nn::hid reads.
// t_hid supplies the guest/platform stubs only; no input publication is mocked.
#import "../DMControllerHost.h"
#include "dm_input.h"
#include <assert.h>

typedef struct { int64_t sampling; uint64_t buttons; int32_t lx, ly, rx, ry; uint32_t attributes, pad; } TestNpadState;
extern void dm_test_hid_read(void *, uint32_t);
static TestNpadState sample(uint32_t player) { TestNpadState s; dm_test_hid_read(&s, player); return s; }
static void delay(double seconds, dispatch_block_t block) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), block); }

int main(int argc, const char **argv) {
    @autoreleasepool {
        BOOL wrongKey = argc > 1 && !strcmp(argv[1], "wrong-key");
        DMControllerHost *host = DMControllerHost.shared;
        DMControllerSession *phone = [DMControllerSession new];
        dm_pad_players(3); dm_pad_set_player(1, DM_BTN_B, 2345, 0, 0, 0);
        dm_input_set(DM_BTN_Y, 999, 0, 0, 0);
        __block BOOL connecting = NO, tapped = NO, pressed = NO;
        __block int stage = 0;
        __weak DMControllerHost *weakHost = host;
        __weak DMControllerSession *weakPhone = phone;
        host.changed = ^{
            DMControllerHost *host = weakHost; DMControllerSession *phone = weakPhone;
            if (!host || !phone) return;
            if (!connecting && host.pairingCode) {
                connecting = YES;
                // Inspect the test listener's bound port to avoid requiring any
                // radios or other peers. All traffic still crosses the real TLS
                // session and production host receiver callbacks.
                DMControllerSession *listener = [host valueForKey:@"session"];
                assert(listener.port && host.invitation);
                NSString *key = wrongKey ? DMControllerSession.newInvitation : host.invitation;
                nw_endpoint_t endpoint = nw_endpoint_create_host("127.0.0.1", [NSString stringWithFormat:@"%u", listener.port].UTF8String);
                assert([phone connectTo:endpoint invitation:key peerToPeer:NO]);
            }
            if (!host.connected) return;
            assert(!wrongKey && dm_input_remote_owned());
            dm_input_set(DM_BTN_Y, 999, 0, 0, 0); dm_pad_set(DM_BTN_Y, 999, 0, 0, 0);
            if (stage == 0 && host.state.buttons == DM_BTN_A) { pressed = YES; return; }
            if (stage == 0 && pressed && !host.state.buttons) {
                stage = 1;
                TestNpadState s = sample(0);
                assert((s.buttons & 0xffff) == DM_BTN_A && !((sample(0).buttons) & 0xffff));
                assert(sample(1).buttons == DM_BTN_B && sample(1).lx == 2345);
                dm_input_remote_block(1);
                [phone publish:(dm_control_state){.buttons = DM_BTN_X, .axes = {-1234, 0, 0, 0}}];
            } else if (stage == 1 && host.state.buttons == DM_BTN_X) {
                stage = 2;
                assert(!(sample(0).buttons & 0xffff) && !sample(0).lx);
                dm_input_remote_block(0); assert(!(sample(0).buttons & 0xffff));
                [phone publish:(dm_control_state){.buttons = DM_BTN_PLUS, .axes = {4567, 0, 0, 0}}];
            } else if (stage == 2 && host.state.buttons == DM_BTN_PLUS) {
                stage = 3;
                TestNpadState s = sample(0); assert((s.buttons & 0xffff) == DM_BTN_PLUS && s.lx == 4567);
                [host endPairing]; assert(host.connected); // closing pairing UI preserves established play
                [host stop:@"Receiver focus lost"];
                assert(!dm_input_remote_owned() && !(sample(0).buttons & 0xffff) && !sample(0).lx);
                assert(sample(1).buttons == DM_BTN_B && sample(1).lx == 2345);
                dm_input_set(DM_BTN_Y, 678, 0, 0, 0); assert((sample(0).buttons & 0xffff) == DM_BTN_Y);
                [phone stop:@"Done"];
                // Fresh session, no automatic replay; dismissing an unused
                // pairing invitation closes the new listener as well.
                [host startBluetooth:NO]; assert(!dm_input_remote_owned());
                [host endPairing]; assert(!host.invitation && !host.pairingCode);
                puts("PASS: TLS -> host ownership -> game HID; ordered tap, menu discard, player isolation, focus cleanup and reconnect");
                exit(0);
            }
        };
        phone.statusChanged = ^(NSString *status) {
            DMControllerSession *phone = weakPhone; if (!phone) return;
            if (phone.connected && !tapped) {
                tapped = YES;
                [phone publish:(dm_control_state){.buttons = DM_BTN_A}];
                [phone publish:(dm_control_state){0}];
            }
        };
        [host startBluetooth:NO];
        delay(wrongKey ? 2 : 6, ^{
            if (wrongKey) {
                assert(connecting && !host.connected && !phone.connected && !dm_input_remote_owned());
                assert((sample(0).buttons & 0xffff) == DM_BTN_Y);
                [host stop:@"Done"]; [phone stop:@"Done"];
                puts("PASS: wrong invitation never claims player 1 or clears local input"); exit(0);
            }
            fprintf(stderr, "FAIL: host integration timeout, stage %d\n", stage); exit(1);
        });
        CFRunLoopRun();
    }
}
