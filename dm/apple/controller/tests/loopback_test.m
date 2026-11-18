// Include the implementation to let adversarial test peers use exactly the
// production TLS parameters while deliberately violating the application flow.
#import "../DMControllerSession.m"
#include <assert.h>

static DMControllerSession *host, *phone;
static nw_connection_t raw;
static nw_listener_t rawListener;
static BOOL finished, receivedPress, receivedRelease, started;
static NSString *mode;
static NSString *key;
static uint64_t connectedAt;
static DMControllerDiscovery *setupDiscovery;
static NSString *diagnosticPath;
static unsigned presses;

static void pass(void) { if (!finished) printf("PASS: encrypted loopback %s\n", mode.UTF8String); finished = YES; }
static void sendRaw(dm_control_message message) {
    uint8_t bytes[DM_CONTROL_WIRE_SIZE]; assert(dm_control_encode(&message, bytes));
    nw_connection_send(raw, dispatchBytes([NSData dataWithBytes:bytes length:sizeof bytes]), NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t error) { assert(!error); });
}
static void receiveWithoutAck(void) {
    nw_connection_receive(raw, DM_CONTROL_WIRE_SIZE, DM_CONTROL_WIRE_SIZE, ^(dispatch_data_t data, nw_content_context_t context, bool done, nw_error_t error) {
        if (!data || error) return;
        const void *bytes; size_t length; dispatch_data_t mapped = dispatch_data_create_map(data, &bytes, &length);
        dm_control_message m; assert(mapped && dm_control_decode(bytes, length, &m));
        if (m.kind == DM_CONTROL_HELLO) { m.kind = DM_CONTROL_ACCEPT; sendRaw(m); }
        if (!done) receiveWithoutAck();
    });
}
static void startRawSilent(uint16_t port) {
    raw = nw_connection_create(nw_endpoint_create_host("127.0.0.1", [NSString stringWithFormat:@"%u", port].UTF8String), parameters(secret(key), NO));
    nw_connection_set_queue(raw, dispatch_get_main_queue());
    nw_connection_set_state_changed_handler(raw, ^(nw_connection_state_t state, nw_error_t error) {
        if (state != nw_connection_state_ready) return;
        dm_control_message m = {.kind = DM_CONTROL_HELLO, .capabilities = DM_CONTROL_CAPS}; m.session[0] = 42;
        sendRaw(m);
        m.kind = DM_CONTROL_STATE; m.capabilities = 0; m.sequence = 1; sendRaw(m);
        m.sequence = 2; m.state.buttons = 1; sendRaw(m);
        // No further messages: host must time out and release held A.
        if ([mode isEqual:@"stall-diagnostic"]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 400000000), dispatch_get_main_queue(), ^{
                dm_control_message late = {.kind = DM_CONTROL_STATE, .sequence = 3, .state.buttons = 1};
                late.session[0] = 42; sendRaw(late);
            });
        }
    });
    nw_connection_start(raw);
}
int main(int argc, char **argv) {
    @autoreleasepool {
        assert(argc == 2); mode = @(argv[1]); key = DMControllerSession.newInvitation; assert(key);
        if ([mode isEqual:@"browser-waiting"]) {
            assert(nw_parameters_get_include_peer_to_peer(parameters(secret(key), YES)));
            assert(!nw_parameters_get_include_peer_to_peer(parameters(secret(key), NO)));
            DMControllerDiscovery *discovery = [DMControllerDiscovery new];
            [discovery startWithPeerToPeer:YES];
            [discovery browserChanged:nw_browser_state_waiting error:nil];
            assert(discovery.searching); // Recoverable waiting must not cancel the search.
            [discovery browserChanged:nw_browser_state_ready error:nil];
            assert(discovery.searching);
            [discovery browserChanged:nw_browser_state_failed error:nil];
            assert(!discovery.searching);
            puts("PASS: browser waiting preserves search; fatal failure cancels; peer-to-peer parameter applied");
            return 0;
        }
        host = [DMControllerSession new]; phone = [DMControllerSession new];
        if ([mode isEqual:@"stall-diagnostic"]) {
            host.diagnoseInputStalls = YES;
            diagnosticPath = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
            DMControllerSetDiagnosticFile(diagnosticPath);
        }
        phone.statusChanged = ^(NSString *text) {
            fprintf(stderr, "phone: %s\n", text.UTF8String);
            if (([mode isEqual:@"wrong-key"] || [mode isEqual:@"handoff-wrong-key"]) && [text containsString:@"authentication failed"]) {
                assert(!host.connected && !receivedPress);
                if (setupDiscovery) assert(!setupDiscovery.searching);
                pass();
            }
            if ([mode isEqual:@"no-ack"] && [text containsString:@"stopped acknowledging"]) { assert(DMControllerNow() - connectedAt < UINT64_C(500000000)); pass(); }
        };
        host.receivedState = ^(dm_control_state state) {
            if (state.buttons == 1) { receivedPress = YES; presses++; }
            if (!state.buttons && receivedPress) {
                receivedRelease = YES;
                if ([mode isEqual:@"silent"]) { assert(!host.connected); pass(); }
            }
        };
        host.statusChanged = ^(NSString *text) {
            fprintf(stderr, "host: %s\n", text.UTF8String);
            if (!host.port || started) return;
            started = YES;
            if ([mode isEqual:@"silent"] || [mode isEqual:@"stall-diagnostic"]) { startRawSilent(host.port); return; }
            NSString *invitation = ([mode isEqual:@"wrong-key"] || [mode isEqual:@"handoff-wrong-key"]) ? DMControllerSession.newInvitation : key;
            if ([mode hasPrefix:@"handoff"]) {
                setupDiscovery = [DMControllerDiscovery new]; [setupDiscovery startWithPeerToPeer:YES];
            }
            assert([phone connectTo:nw_endpoint_create_host("127.0.0.1", [NSString stringWithFormat:@"%u", host.port].UTF8String) invitation:invitation peerToPeer:setupDiscovery != nil discovery:setupDiscovery]);
            if (setupDiscovery) assert(setupDiscovery.searching);
            if ([mode isEqual:@"waiting"]) [phone connectionChanged:nw_connection_state_waiting error:nil];
        };
        if ([mode isEqual:@"no-ack"]) {
            // Server authenticates and negotiates, then reads but never ACKs.
            rawListener = nw_listener_create(parameters(secret(key), NO)); assert(rawListener);
            nw_listener_set_queue(rawListener, dispatch_get_main_queue());
            nw_listener_set_state_changed_handler(rawListener, ^(nw_listener_state_t state, nw_error_t error) {
                if (state == nw_listener_state_ready) assert([phone connectTo:nw_endpoint_create_host("127.0.0.1", [NSString stringWithFormat:@"%u", nw_listener_get_port(rawListener)].UTF8String) invitation:key peerToPeer:NO]);
            });
            nw_listener_set_new_connection_handler(rawListener, ^(nw_connection_t connection) {
                raw = connection; nw_connection_set_queue(raw, dispatch_get_main_queue());
                nw_connection_set_state_changed_handler(raw, ^(nw_connection_state_t state, nw_error_t error) { if (state == nw_connection_state_ready) receiveWithoutAck(); });
                nw_connection_start(raw);
            });
            nw_listener_start(rawListener);
        } else assert([host listenWithInvitation:key name:@"nxnative automated loopback" peerToPeer:NO]);
        uint64_t start = DMControllerNow(); BOOL tapped = NO, stopped = NO;
        while (!finished && DMControllerNow() - start < UINT64_C(6500000000)) {
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];
            if ([mode isEqual:@"stall-diagnostic"]) {
                NSString *log = [NSString stringWithContentsOfFile:diagnosticPath encoding:NSUTF8StringEncoding error:nil];
                if ([log containsString:@"Post-stall diagnostic finished"]) {
                    assert(receivedRelease && presses == 1 && !host.connected);
                    assert([log containsString:@"Discarded post-stall frame: kind 3, sequence 3"]);
                    [host publish:(dm_control_state){.buttons = 1}]; assert(!host.connected);
                    pass();
                }
            }
            if (phone.connected && !connectedAt) connectedAt = DMControllerNow();
            if (([mode isEqual:@"normal"] || [mode isEqual:@"waiting"] || [mode isEqual:@"handoff"]) && phone.connected && !tapped) {
                if (setupDiscovery) assert(setupDiscovery.searching);
                tapped = YES;
                [phone publish:(dm_control_state){1, {1234, -1234, 0, 0}}];
                [phone publish:(dm_control_state){0}]; // same run-loop turn
            }
            if (([mode isEqual:@"normal"] || [mode isEqual:@"waiting"] || [mode isEqual:@"handoff"]) && receivedPress && receivedRelease && !stopped && DMControllerNow() - connectedAt > UINT64_C(300000000)) {
                assert(phone.connected && host.connected && phone.lastRoundTripNS);
                stopped = YES; [phone publish:(dm_control_state){.buttons = 1}];
            }
            if (stopped && host.connected && receivedPress && DMControllerNow() - connectedAt > UINT64_C(400000000)) {
                if ([mode isEqual:@"waiting"]) {
                    // Waiting after authentication must never resume old input.
                    [phone connectionChanged:nw_connection_state_waiting error:nil]; assert(!phone.connected);
                } else { [host stop:@"Receiver focus lost"]; assert(!host.connected); }
                if (setupDiscovery) { [phone stop:@"Phone focus lost"]; assert(!setupDiscovery.searching); }
                pass();
            }
        }
        if (!finished) fprintf(stderr, "FAIL: loopback %s timed out (host=%d phone=%d)\n", mode.UTF8String, host.connected, phone.connected);
        [host stop:@"Test ended"]; [phone stop:@"Test ended"];
        if (raw) nw_connection_cancel(raw); if (rawListener) nw_listener_cancel(rawListener);
        DMControllerSetDiagnosticFile(nil);
        if (diagnosticPath) [NSFileManager.defaultManager removeItemAtPath:diagnosticPath error:nil];
        return finished ? 0 : 1;
    }
}
