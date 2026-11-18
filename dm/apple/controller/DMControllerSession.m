#import "DMControllerSession.h"
#import <Security/Security.h>
#include <time.h>
#include <netinet/in.h>

NSString *const DMControllerServiceType = @"_nxcontrol._tcp";
uint64_t DMControllerNow(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return (uint64_t)t.tv_sec * 1000000000 + t.tv_nsec; }
static NSString *diagnosticFile;
static void recordDiagnostic(NSString *event) {
    if (!diagnosticFile) return;
    NSMutableData *data = [[NSData dataWithContentsOfFile:diagnosticFile] mutableCopy] ?: [NSMutableData data];
    if (data.length > 32768) {
        // Retain the newest complete lines, without growing across relaunches.
        const uint8_t *bytes = data.bytes; NSUInteger start = data.length - 32768;
        while (start < data.length && bytes[start] != '\n') start++;
        if (start < data.length) start++;
        data = [[data subdataWithRange:NSMakeRange(start, data.length - start)] mutableCopy];
    }
    NSString *line = [NSString stringWithFormat:@"%.3f %@\n", DMControllerNow() / 1e9, event];
    [data appendData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [data writeToFile:diagnosticFile atomically:YES];
}
void DMControllerSetDiagnosticFile(NSString *path) { diagnosticFile = [path copy]; recordDiagnostic(@"Diagnostics started"); }
void DMControllerRecordDiagnostic(NSString *event) { recordDiagnostic(event); }

static NSString *networkError(nw_error_t error) {
    if (!error) return @"no error detail";
    nw_error_domain_t domain = nw_error_get_error_domain(error);
    NSString *name = domain == nw_error_domain_posix ? @"POSIX" : domain == nw_error_domain_dns ? @"DNS" :
        domain == nw_error_domain_tls ? @"TLS" : @"Network";
    return [NSString stringWithFormat:@"%@ %d", name, nw_error_get_error_code(error)];
}
static NSString *pathDescription(nw_path_t path) {
    if (!path) return @"Path not available yet";
    NSMutableArray *names = [NSMutableArray array];
    nw_path_enumerate_interfaces(path, ^bool(nw_interface_t interface) {
        const char *name = nw_interface_get_name(interface);
        if (name) [names addObject:@(name)]; return true;
    });
    return [NSString stringWithFormat:@"Path status %d; available interfaces %@; direct path unverified",
        nw_path_get_status(path), names.count ? [names componentsJoinedByString:@", "] : @"none"];
}

static NSData *secret(NSString *text) {
    if (text.length != 64) return nil;
    uint8_t bytes[32];
    for (NSUInteger i = 0; i < 64; i++) {
        unichar c = [text characterAtIndex:i]; int n = c >= '0' && c <= '9' ? c - '0' :
            c >= 'a' && c <= 'f' ? c - 'a' + 10 : c >= 'A' && c <= 'F' ? c - 'A' + 10 : -1;
        if (n < 0) return nil;
        if (!(i & 1)) bytes[i / 2] = (uint8_t)(n << 4); else bytes[i / 2] |= n;
    }
    return [NSData dataWithBytes:bytes length:sizeof bytes];
}
static dispatch_data_t dispatchBytes(NSData *data) {
    // Copy: the Network/Security objects can outlive the caller's NSData.
    void *p = malloc(data.length); memcpy(p, data.bytes, data.length);
    return dispatch_data_create(p, data.length, dispatch_get_main_queue(), ^{ free(p); });
}
static nw_parameters_t parameters(NSData *key, BOOL p2p) {
    nw_parameters_t p = nw_parameters_create_secure_tcp(^(nw_protocol_options_t tls) {
        sec_protocol_options_t options = nw_tls_copy_sec_protocol_options(tls);
        sec_protocol_options_set_min_tls_protocol_version(options, tls_protocol_version_TLSv12);
        sec_protocol_options_set_max_tls_protocol_version(options, tls_protocol_version_TLSv12);
        // Only PSK authentication is offered. Never install an accept-all
        // certificate verifier, and never use a guessable PIN as this key.
        sec_protocol_options_append_tls_ciphersuite(options, TLS_PSK_WITH_AES_128_GCM_SHA256);
        sec_protocol_options_add_pre_shared_key(options, dispatchBytes(key),
            dispatchBytes([@"nxnative-controller-spike-v1" dataUsingEncoding:NSUTF8StringEncoding]));
        sec_protocol_options_set_tls_tickets_enabled(options, false);
    }, ^(nw_protocol_options_t tcp) { nw_tcp_options_set_no_delay(tcp, true); });
    nw_parameters_set_include_peer_to_peer(p, p2p);
    // Tiny controller updates are interactive user data, rather than bulk or
    // best-effort transfers. Physical no-router tests delivered a queued burst
    // after a ~0.5 s arrival gap. Request this scheduling class; it is not a
    // latency guarantee and must not extend the 200 ms input release deadline.
    nw_parameters_set_service_class(p, nw_service_class_responsive_data);
    nw_parameters_prohibit_interface_type(p, nw_interface_type_cellular);
    return p;
}
static nw_advertise_descriptor_t advertisement(NSString *name) {
    nw_advertise_descriptor_t descriptor = nw_advertise_descriptor_create_bonjour_service(name.UTF8String, DMControllerServiceType.UTF8String, "local.");
    // DNS-SD advertisements include a TXT record (RFC 6763 section 6), even
    // when all addressing comes from SRV. Publish only the metadata version;
    // authentication remains inside TLS and no invitation is advertised.
    static const uint8_t txt[] = {9, 't', 'x', 't', 'v', 'e', 'r', 's', '=', '1'};
    nw_advertise_descriptor_set_txt_record(descriptor, txt, sizeof txt);
    return descriptor;
}

@interface DMControllerSession () <NSNetServiceDelegate> @end
@implementation DMControllerSession {
    nw_listener_t _listener;
    nw_connection_t _connection;
    dispatch_source_t _timer;
    BOOL _receiver, _connected, _stopped, _transportReady, _peerToPeer;
    NSString *_pathSummary;
    NSString *_pairingServiceName;
    uint16_t _port;
    NSUInteger _generation, _pendingWrites;
    uint64_t _started, _lastSend, _lastRoundTripNS;
    dm_control_message _out;
    dm_control_state _latest, _sent;
    dm_control_receiver _input;
    dm_control_sender _ledger;
    nw_endpoint_t _serviceEndpoint;
    NSNetService *_resolutionProbe;
    DMControllerDiscovery *_peerDiscovery;
    uint64_t _previousTick, _largestTickGap;
    uint64_t _stallStarted;
    NSString *_stallReason;
    unsigned _stallFrames;
}
- (BOOL)connected { return _connected; }
- (uint16_t)port { return _port; }
- (BOOL)pairingAvailable { return !_stopped && _receiver && _listener && !_connection; }
- (NSString *)pairingServiceName { return _pairingServiceName; }
- (uint64_t)lastRoundTripNS { return _lastRoundTripNS; }
- (NSString *)pathSummary { return [NSString stringWithFormat:@"%@; peer-to-peer %@", _pathSummary ?: @"Path not available yet", _peerToPeer ? @"enabled" : @"disabled"]; }
+ (NSString *)newInvitation {
    uint8_t key[32]; if (SecRandomCopyBytes(kSecRandomDefault, sizeof key, key) != errSecSuccess) return nil;
    NSMutableString *text = [NSMutableString string];
    for (unsigned i = 0; i < sizeof key; i++) [text appendFormat:@"%02x", key[i]];
    return text;
}
- (void)status:(NSString *)text { recordDiagnostic(text); if (self.statusChanged) self.statusChanged(text); }
- (void)prepareReceiver:(BOOL)receiver {
    [self stop:@"Stopped"]; _stopped = NO; _receiver = receiver; _transportReady = NO; _started = DMControllerNow();
    _out = (dm_control_message){0}; _latest = _sent = (dm_control_state){0}; _ledger = (dm_control_sender){0};
    _pendingWrites = 0; _lastSend = _lastRoundTripNS = 0;
    _previousTick = DMControllerNow(); _largestTickGap = 0;
    __weak DMControllerSession *weak = self;
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, 10000000), 10000000, 1000000);
    dispatch_source_set_event_handler(_timer, ^{ [weak tick]; }); dispatch_resume(_timer);
}
- (BOOL)listenWithInvitation:(NSString *)invitation name:(NSString *)name peerToPeer:(BOOL)p2p {
    return [self listenWithInvitation:invitation name:name peerToPeer:p2p loopback:NO];
}
- (BOOL)listenOnLoopbackWithInvitation:(NSString *)invitation {
    return [self listenWithInvitation:invitation name:@"nxnative" peerToPeer:NO loopback:YES];
}
- (BOOL)listenWithInvitation:(NSString *)invitation name:(NSString *)name peerToPeer:(BOOL)p2p loopback:(BOOL)loopback {
    NSAssert(NSThread.isMainThread, @"Main queue only");
    NSData *key = secret(invitation); if (!key) return NO;
    [self prepareReceiver:YES]; _peerToPeer = p2p;
    recordDiagnostic(loopback ? @"Receiver start: loopback TLS endpoint for byte carrier" : p2p ? @"Receiver start: LAN + peer-to-peer allowed; interactive data priority requested" : @"Receiver start: LAN only; interactive data priority requested");
    nw_parameters_t p = parameters(key, p2p);
    if (loopback) nw_parameters_set_local_endpoint(p, nw_endpoint_create_host("127.0.0.1", "0"));
    _listener = nw_listener_create(p);
    if (!_listener) { [self stop:@"Could not open receiver"]; return NO; }
    NSUInteger generation = _generation; __weak DMControllerSession *weak = self;
    nw_listener_set_queue(_listener, dispatch_get_main_queue());
    // A fresh instance name prevents a new invitation/port from selecting a
    // cached service belonging to an earlier listener. Use the registration
    // callback's actual name for QR generation, including any auto-rename.
    NSString *base = name.length && [name lengthOfBytesUsingEncoding:NSUTF8StringEncoding] <= 24 &&
        [name rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location == NSNotFound ? name : @"nxnative";
    NSString *registrationName = [base stringByAppendingFormat:@"-%@", [NSUUID.UUID.UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""]];
    if (!loopback) nw_listener_set_advertise_descriptor(_listener, advertisement(registrationName));
    nw_listener_set_advertised_endpoint_changed_handler(_listener, ^(nw_endpoint_t endpoint, bool added) {
        DMControllerSession *s = weak; if (!s || s->_generation != generation) return;
        const char *serviceName = nw_endpoint_get_bonjour_service_name(endpoint); if (!serviceName) return;
        if (added) {
            if (!s.pairingAvailable) return;
            s->_pairingServiceName = @(serviceName);
            recordDiagnostic(@"Bonjour registration confirmed; fresh session name assigned (name omitted)");
            [s status:@"Ready to pair. Scan this session's QR on your iPhone."];
        } else if ([s->_pairingServiceName isEqual:@(serviceName)]) {
            s->_pairingServiceName = nil;
            recordDiagnostic(@"Bonjour registration withdrawn");
            if (s->_connection && !s->_connected) [s status:@"Receiver selected; establishing encrypted connection…"];
        }
    });
    nw_listener_set_state_changed_handler(_listener, ^(nw_listener_state_t state, nw_error_t error) {
        DMControllerSession *s = weak; if (!s || s->_generation != generation) return;
        if (state == nw_listener_state_ready) { s->_port = nw_listener_get_port(s->_listener); recordDiagnostic([NSString stringWithFormat:@"Listener ready on port %u", s->_port]); [s status:[NSString stringWithFormat:@"Registering %@ receiver…", p2p ? @"LAN + peer-to-peer" : @"LAN"]]; }
        if (state == nw_listener_state_failed) [s stop:[NSString stringWithFormat:@"Listener failed (%@). Check Wi-Fi and Local Network access in Settings.", networkError(error)]];
    });
    nw_listener_set_new_connection_handler(_listener, ^(nw_connection_t connection) {
        DMControllerSession *s = weak;
        if (!s || s->_generation != generation || s->_connection) { nw_connection_cancel(connection); return; }
        recordDiagnostic(@"Listener delivered incoming connection candidate");
        s->_started = DMControllerNow(); [s attach:connection];
        // Stop advertising as soon as a candidate owns this invitation. A failed
        // authentication requires a new explicit start with a new invitation.
        nw_listener_cancel(s->_listener); s->_listener = nil;
    });
    nw_listener_start(_listener); [self status:@"Opening controller receiver…"]; return YES;
}
- (BOOL)connectTo:(nw_endpoint_t)endpoint invitation:(NSString *)invitation peerToPeer:(BOOL)p2p {
    return [self connectTo:endpoint invitation:invitation peerToPeer:p2p discovery:nil];
}
- (BOOL)connectTo:(nw_endpoint_t)endpoint invitation:(NSString *)invitation peerToPeer:(BOOL)p2p discovery:(DMControllerDiscovery *)discovery {
    NSAssert(NSThread.isMainThread, @"Main queue only");
    NSData *key = secret(invitation); if (!key || !endpoint) { [discovery stop]; return NO; }
    [self prepareReceiver:NO]; _peerToPeer = p2p;
    if (p2p) { _peerDiscovery = discovery; [_peerDiscovery handoffForConnectionSetup]; }
    else [discovery stop];
    _serviceEndpoint = endpoint;
    recordDiagnostic(p2p ? @"Connection start: LAN + peer-to-peer allowed; interactive data priority requested" : @"Connection start: LAN only; interactive data priority requested");
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof _out.session, _out.session) != errSecSuccess) {
        [self stop:@"Could not create a fresh session"]; return NO;
    }
    [self status:@"Connecting to receiver…"];
    [self attach:nw_connection_create(endpoint, parameters(key, p2p))]; return YES;
}
- (void)attach:(nw_connection_t)connection {
    _connection = connection; NSUInteger generation = _generation;
    __weak DMControllerSession *weak = self;
    nw_connection_set_queue(connection, dispatch_get_main_queue());
    nw_connection_set_state_changed_handler(connection, ^(nw_connection_state_t state, nw_error_t error) {
        DMControllerSession *s = weak; if (!s || s->_generation != generation) return;
        [s connectionChanged:state error:error];
    });
    nw_connection_set_path_changed_handler(connection, ^(nw_path_t path) {
        DMControllerSession *s = weak; if (!s || s->_generation != generation) return;
        NSString *description = pathDescription(path);
        if (![s->_pathSummary isEqual:description]) recordDiagnostic(description);
        s->_pathSummary = description;
    });
    nw_connection_start(connection);
}
- (void)connectionChanged:(nw_connection_state_t)state error:(nw_error_t)error {
    if (_stopped) return;
    recordDiagnostic([NSString stringWithFormat:@"Connection state %d (%@)", state, networkError(error)]);
    if (state == nw_connection_state_ready) {
        [_peerDiscovery connectionEstablished];
        _transportReady = YES;
        _pathSummary = pathDescription(nw_connection_copy_current_path(_connection));
        [self status:@"Encrypted connection ready; confirming controller session…"];
        if (!_receiver) { _out.kind = DM_CONTROL_HELLO; _out.capabilities = DM_CONTROL_CAPS; [self send:_out]; }
        [self receive];
    } else if (state == nw_connection_state_waiting && !_transportReady && !_connected &&
               (!error || nw_error_get_error_domain(error) != nw_error_domain_tls)) {
        // Waiting is recoverable: Network.framework retries when the path
        // changes. Preserve only this fresh setup attempt, within its existing
        // 10-second deadline. TLS errors (including a wrong invitation) are not
        // path establishment and still fail immediately. No old input resumes.
        [self status:[NSString stringWithFormat:@"Waiting for a local path (%@); setup still active. Check Wi-Fi, Bluetooth and Local Network access.", networkError(error)]];
    } else if (state == nw_connection_state_failed || state == nw_connection_state_waiting) {
        [self stop:[NSString stringWithFormat:@"Connection lost or authentication failed (%@). Check invitation and local connectivity, then start again.", networkError(error)]];
    }
}
- (void)send:(dm_control_message)message {
    if (!_connection || _stopped) return;
    uint8_t bytes[DM_CONTROL_WIRE_SIZE];
    if (!dm_control_encode(&message, bytes) || _pendingWrites >= DM_CONTROL_MAX_PENDING) { [self stop:@"Invalid message or send queue fell behind"]; return; }
    _pendingWrites++; NSUInteger generation = _generation; __weak DMControllerSession *weak = self;
    nw_connection_send(_connection, dispatchBytes([NSData dataWithBytes:bytes length:sizeof bytes]),
        NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t error) {
            DMControllerSession *s = weak; if (!s || s->_generation != generation) return;
            s->_pendingWrites--; if (error) [s stop:@"Connection could not send input. Start a new session."];
        });
}
- (void)receive {
    if (!_connection || _stopped) return;
    NSUInteger generation = _generation; __weak DMControllerSession *weak = self;
    nw_connection_receive(_connection, DM_CONTROL_WIRE_SIZE, DM_CONTROL_WIRE_SIZE,
        ^(dispatch_data_t content, nw_content_context_t context, bool complete, nw_error_t error) {
            DMControllerSession *s = weak; if (!s || s->_generation != generation) return;
            const void *bytes = NULL; size_t n = 0;
            dispatch_data_t mapped = content ? dispatch_data_create_map(content, &bytes, &n) : nil;
            dm_control_message message;
            if (s->_stallStarted) {
                // The input session has already been invalidated. Read only to
                // distinguish delayed delivery from a dead link; never apply
                // input, negotiate, ACK or restart heartbeats in this phase.
                if (mapped && dm_control_decode(bytes, n, &message)) {
                    recordDiagnostic([NSString stringWithFormat:@"Discarded post-stall frame: kind %u, sequence %llu, %.1f ms after input release",
                        message.kind, (unsigned long long)message.sequence, (DMControllerNow() - s->_stallStarted) / 1e6]);
                }
                if (++s->_stallFrames >= 64 || error || complete || !mapped) [s stop:s->_stallReason];
                else [s receive];
                return;
            }
            if (!mapped || !dm_control_decode(bytes, n, &message) || error) { [s stop:@"Connection closed or incompatible controller protocol"]; return; }
            [s handle:message];
            if (complete) [s stop:@"Peer disconnected"]; else [s receive];
        });
}
- (void)handle:(dm_control_message)m {
    if (_stallStarted) return;
    uint64_t now = DMControllerNow();
    if (_receiver) {
        if (!_connected) {
            if (!dm_control_receiver_begin(&_input, &m, now)) { [self stop:@"Incompatible controller capabilities"]; return; }
            _out = m; _out.kind = DM_CONTROL_ACCEPT; [self send:_out];
            _connected = YES; [self status:@"iPhone controller connected"];
        } else {
            if (!dm_control_receiver_apply(&_input, &m, now)) { [self stop:@"Invalid, stale or excessive controller input"]; return; }
            if (m.sequence <= 3) recordDiagnostic([NSString stringWithFormat:@"Input frame accepted: sequence %llu", (unsigned long long)m.sequence]);
            if (self.receivedState) self.receivedState(m.state);
            dm_control_message ack = { .kind = DM_CONTROL_ACK, .sequence = m.sequence };
            memcpy(ack.session, m.session, 16); [self send:ack];
        }
    } else {
        if (memcmp(m.session, _out.session, 16)) { [self stop:@"Incorrect session identity"]; return; }
        if (!_connected) {
            if (m.kind != DM_CONTROL_ACCEPT || m.capabilities != DM_CONTROL_CAPS) { [self stop:@"Incompatible receiver capabilities"]; return; }
            _connected = YES; _out.kind = DM_CONTROL_STATE; _out.capabilities = 0;
            _latest = (dm_control_state){0}; [self sendState];
            [self status:@"Connected to receiver"];
        } else {
            if (m.kind != DM_CONTROL_ACK || !dm_control_sender_alive(&_ledger, now) || !_ledger.count ||
                m.sequence != _ledger.sequence[_ledger.head]) { [self stop:@"Receiver acknowledgment invalid or late"]; return; }
            _lastRoundTripNS = now - _ledger.sent_ns[_ledger.head];
            if (m.sequence <= 3) recordDiagnostic([NSString stringWithFormat:@"Input ACK received: sequence %llu", (unsigned long long)m.sequence]);
            if (!dm_control_sender_ack(&_ledger, m.sequence)) [self stop:@"Receiver acknowledgment invalid"];
        }
    }
}
- (void)sendState {
    uint64_t now = DMControllerNow();
    if (_out.sequence == UINT64_MAX || !dm_control_sender_push(&_ledger, _out.sequence + 1, now)) { [self stop:@"Receiver fell behind; input discarded"]; return; }
    _out.sequence++; _out.state = _latest; _sent = _latest; _lastSend = now; [self send:_out];
}
- (void)publish:(dm_control_state)state {
    NSAssert(NSThread.isMainThread, @"Main queue only");
    if (_receiver || !_connected) return;
    if (!dm_control_valid_state(state)) { [self stop:@"Invalid local controller state"]; return; }
    BOOL buttonEdge = state.buttons != _latest.buttons; _latest = state;
    // Preserve both edges even if a tap begins and ends between two ticks.
    if (buttonEdge) [self sendState];
}
- (void)tick {
    uint64_t now = DMControllerNow();
    uint64_t gap = now - _previousTick; _previousTick = now; _largestTickGap = MAX(_largestTickGap, gap);
    if (gap >= UINT64_C(100000000)) recordDiagnostic([NSString stringWithFormat:@"Transport callback scheduling gap %.1f ms", gap / 1e6]);
    if (_stallStarted) {
        if (now - _stallStarted >= UINT64_C(5000000000)) {
            recordDiagnostic(@"Post-stall diagnostic finished (5-second cap); transport cancelled");
            [self stop:_stallReason];
        }
        return;
    }
    if (!_connected) {
        if (now - _started >= (_connection ? UINT64_C(10000000000) : UINT64_C(60000000000))) {
            nw_endpoint_t endpoint = _serviceEndpoint; BOOL p2p = _peerToPeer;
            BOOL probe = !_receiver && !_transportReady && endpoint && nw_endpoint_get_type(endpoint) == nw_endpoint_type_bonjour_service;
            [self stop:_connection ? (_transportReady ? @"Controller session confirmation expired. Start again on both devices." : @"Local connection setup expired. Start again on both devices.") : @"Pairing invitation expired. Tap Start on the receiver."];
            // A bounded, service-specific diagnostic runs only AFTER the failed
            // connection is invalidated. It does not revive or replace input.
            if (probe) [self probeService:endpoint peerToPeer:p2p];
        }
    } else if (_receiver) {
        uint64_t age = now - _input.arrival_ns, sequence = _input.sequence;
        if (!dm_control_receiver_tick(&_input, now)) {
            recordDiagnostic([NSString stringWithFormat:@"Receive watchdog: last sequence %llu, age %.1f ms, largest scheduling gap %.1f ms", (unsigned long long)sequence, age / 1e6, _largestTickGap / 1e6]);
            [self endForInputStall:@"Controller timed out; all input released"];
        }
    } else {
        if (!dm_control_sender_alive(&_ledger, now)) {
            recordDiagnostic([NSString stringWithFormat:@"ACK watchdog: sent %llu, ACKed %llu, pending %u, largest scheduling gap %.1f ms", (unsigned long long)_ledger.last_sent, (unsigned long long)_ledger.last_ack, _ledger.count, _largestTickGap / 1e6]);
            [self endForInputStall:@"Receiver stopped acknowledging; all input discarded"]; return;
        }
        if ((memcmp(_latest.axes, _sent.axes, sizeof _latest.axes) && now - _lastSend >= UINT64_C(16666667)) ||
            now - _lastSend >= UINT64_C(50000000)) [self sendState];
    }
}
- (void)endForInputStall:(NSString *)reason {
    if (!self.diagnoseInputStalls) { [self stop:reason]; return; }
    _connected = NO; _stallStarted = DMControllerNow(); _stallReason = [reason copy]; _stallFrames = 0;
    dm_control_receiver_clear(&_input); _latest = _sent = (dm_control_state){0};
    _out = (dm_control_message){0}; _ledger = (dm_control_sender){0};
    if (self.receivedState) self.receivedState((dm_control_state){0});
    recordDiagnostic(@"Input session invalidated; post-stall frames will be discarded for up to 5 seconds (no sends or input recovery)");
    [self status:[reason stringByAppendingString:@". Collecting late-arrival diagnostics for 5 seconds…"]];
}
- (void)probeService:(nw_endpoint_t)endpoint peerToPeer:(BOOL)p2p {
    _resolutionProbe = [[NSNetService alloc] initWithDomain:@(nw_endpoint_get_bonjour_service_domain(endpoint))
        type:@(nw_endpoint_get_bonjour_service_type(endpoint)) name:@(nw_endpoint_get_bonjour_service_name(endpoint))];
    _resolutionProbe.includesPeerToPeer = p2p; _resolutionProbe.delegate = self;
    recordDiagnostic(@"Post-timeout Bonjour address lookup started (5-second diagnostic only)");
    [_resolutionProbe resolveWithTimeout:5];
    NSNetService *probe = _resolutionProbe; __weak DMControllerSession *weak = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5000000000), dispatch_get_main_queue(), ^{
        DMControllerSession *s = weak; if (!s || s->_resolutionProbe != probe) return;
        recordDiagnostic(@"Post-timeout Bonjour diagnostic finished");
        probe.delegate = nil; [probe stop]; s->_resolutionProbe = nil;
    });
}
- (void)netServiceDidResolveAddress:(NSNetService *)service {
    if (service != _resolutionProbe) return;
    unsigned ipv4 = 0, ipv6 = 0, scoped = 0;
    for (NSData *data in service.addresses) {
        if (data.length < sizeof(struct sockaddr)) continue;
        const struct sockaddr *address = data.bytes;
        if (address->sa_family == AF_INET && data.length >= sizeof(struct sockaddr_in)) ipv4++;
        if (address->sa_family == AF_INET6 && data.length >= sizeof(struct sockaddr_in6)) {
            ipv6++; if (((const struct sockaddr_in6 *)address)->sin6_scope_id) scoped++;
        }
    }
    recordDiagnostic([NSString stringWithFormat:@"Post-timeout Bonjour resolved port %ld: IPv4 %u, IPv6 %u, scoped IPv6 %u (addresses omitted)", (long)service.port, ipv4, ipv6, scoped]);
}
- (void)netService:(NSNetService *)service didNotResolve:(NSDictionary<NSString *, NSNumber *> *)error {
    if (service != _resolutionProbe) return;
    recordDiagnostic([NSString stringWithFormat:@"Post-timeout Bonjour lookup failed: domain %@ code %@", error[NSNetServicesErrorDomain], error[NSNetServicesErrorCode]]);
    service.delegate = nil; [service stop]; _resolutionProbe = nil;
}
- (void)stop:(NSString *)reason {
    NSAssert(NSThread.isMainThread, @"Main queue only");
    NSString *finalReason = [reason copy];
    _generation++; _stopped = YES; _connected = NO; _transportReady = NO; _port = 0; _pathSummary = nil;
    _stallStarted = 0; _stallReason = nil; _stallFrames = 0;
    [_auxiliaryTransport stop]; _auxiliaryTransport = nil;
    if (_resolutionProbe) { _resolutionProbe.delegate = nil; [_resolutionProbe stop]; _resolutionProbe = nil; }
    _serviceEndpoint = nil;
    [_peerDiscovery stop]; _peerDiscovery = nil;
    _pairingServiceName = nil;
    if (_listener) { nw_listener_cancel(_listener); _listener = nil; }
    if (_connection) { nw_connection_cancel(_connection); _connection = nil; }
    if (_timer) { dispatch_source_cancel(_timer); _timer = nil; }
    dm_control_receiver_clear(&_input); _latest = _sent = (dm_control_state){0};
    _out = (dm_control_message){0}; _ledger = (dm_control_sender){0};
    if (self.receivedState) self.receivedState((dm_control_state){0});
    [self status:finalReason];
}
- (void)dealloc {
    [_auxiliaryTransport stop];
    [_peerDiscovery stop];
    _resolutionProbe.delegate = nil; [_resolutionProbe stop];
    if (_listener) nw_listener_cancel(_listener);
    if (_connection) nw_connection_cancel(_connection);
    if (_timer) dispatch_source_cancel(_timer);
}
@end

@implementation DMControllerDiscovery {
    nw_browser_t _browser;
    NSUInteger _generation;
    NSMutableDictionary *_endpoints;
    BOOL _peerToPeer;
}
- (BOOL)searching { return _browser != nil; }
- (void)handoffForConnectionSetup {
    NSAssert(NSThread.isMainThread, @"Main queue only");
    if (!_browser) return;
    // Experimental AWDL lifetime test. Physical build 6 connected but stopped
    // exchanging frames immediately after browser cancellation at TLS ready.
    // Keep setup bounded; an established session explicitly takes ownership.
    self.changed = nil; self.statusChanged = nil; _endpoints = nil;
    NSUInteger generation = ++_generation; __weak DMControllerDiscovery *weak = self;
    recordDiagnostic(@"Peer-to-peer discovery handed to connection setup (10-second cap)");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10000000000), dispatch_get_main_queue(), ^{
        DMControllerDiscovery *s = weak; if (s && s->_generation == generation) [s stop];
    });
}
- (void)connectionEstablished {
    NSAssert(NSThread.isMainThread, @"Main queue only");
    if (!_browser) return;
    // Invalidate the setup lease. The session now stops this browser on input
    // watchdog expiry, connection failure, explicit stop, focus loss or dealloc.
    // Root cause inside the system's AWDL lifetime remains unconfirmed; this
    // foreground-only experiment must pass real-device and power acceptance.
    _generation++;
    recordDiagnostic(@"Peer-to-peer discovery retained for active session");
}
- (void)startWithPeerToPeer:(BOOL)p2p {
    [self stop]; _peerToPeer = p2p; _endpoints = [NSMutableDictionary dictionary]; NSUInteger generation = _generation; __weak DMControllerDiscovery *weak = self;
    recordDiagnostic(p2p ? @"Search start: LAN + peer-to-peer allowed" : @"Search start: LAN only");
    nw_parameters_t p = nw_parameters_create(); nw_parameters_set_include_peer_to_peer(p, p2p);
    _browser = nw_browser_create(nw_browse_descriptor_create_bonjour_service(DMControllerServiceType.UTF8String, "local."), p);
    nw_browser_set_queue(_browser, dispatch_get_main_queue());
    nw_browser_set_browse_results_changed_handler(_browser, ^(nw_browse_result_t old, nw_browse_result_t result, bool complete) {
        DMControllerDiscovery *s = weak; if (!s || s->_generation != generation) return;
        if (old) {
            nw_endpoint_t endpoint = nw_browse_result_copy_endpoint(old);
            [s->_endpoints removeObjectForKey:@(nw_endpoint_get_bonjour_service_name(endpoint))];
        }
        if (result && s->_endpoints.count < 32) {
            nw_endpoint_t endpoint = nw_browse_result_copy_endpoint(result);
            s->_endpoints[@(nw_endpoint_get_bonjour_service_name(endpoint))] = endpoint;
            NSMutableArray *interfaces = [NSMutableArray array];
            nw_browse_result_enumerate_interfaces(result, ^bool(nw_interface_t interface) {
                const char *name = nw_interface_get_name(interface); if (name) [interfaces addObject:@(name)]; return true;
            });
            recordDiagnostic([NSString stringWithFormat:@"Discovery result: available interfaces %@ (peer name omitted)", [interfaces componentsJoinedByString:@", "]]);
        }
        if (complete && s.changed) s.changed(s->_endpoints.allValues);
    });
    nw_browser_set_state_changed_handler(_browser, ^(nw_browser_state_t state, nw_error_t error) {
        DMControllerDiscovery *s = weak; if (!s || s->_generation != generation) return;
        [s browserChanged:state error:error];
    });
    nw_browser_start(_browser);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30000000000), dispatch_get_main_queue(), ^{
        DMControllerDiscovery *s = weak; if (s && s->_generation == generation) {
            [s stop]; if (s.statusChanged) s.statusChanged(@"Search ended. If no receiver appeared, check Wi-Fi and Local Network access, then search again.");
        }
    });
}
- (void)browserChanged:(nw_browser_state_t)state error:(nw_error_t)error {
    recordDiagnostic([NSString stringWithFormat:@"Search state %d (%@)", state, networkError(error)]);
    if (state == nw_browser_state_waiting) {
        // Keep the existing 30-second search alive during path establishment.
        if (self.statusChanged) self.statusChanged([NSString stringWithFormat:@"Search waiting for connectivity (%@); still searching. Check Wi-Fi, Bluetooth and Local Network access.", networkError(error)]);
    } else if (state == nw_browser_state_ready) {
        if (self.statusChanged) self.statusChanged(_peerToPeer ? @"Searching: LAN + peer-to-peer experiment (30-second limit). No direct path verified yet." : @"Searching: LAN only (30-second limit).");
    } else if (state == nw_browser_state_failed) {
        [self stop]; if (self.statusChanged) self.statusChanged([NSString stringWithFormat:@"Search failed (%@). Check Wi-Fi and Local Network permission in Settings.", networkError(error)]);
    }
}
- (void)stop { _generation++; if (_browser) { recordDiagnostic(@"Discovery stopped"); nw_browser_cancel(_browser); _browser = nil; } _endpoints = nil; if (self.changed) self.changed(@[]); }
- (void)dealloc { if (_browser) nw_browser_cancel(_browser); }
@end
