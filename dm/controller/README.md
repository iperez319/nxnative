# Offline phone controller

`NxController` is a separate, lightweight iPhone app. It launches without a
game, game profile, shader preparation, account or cloud service. It reuses the
host's touch controls (2D stick, 2D D-pad and 3D), response math and preferences,
with a replaceable state destination and its own connection/settings menu.
Plus and Minus remain controller buttons. Tap, motion, game touch forwarding
and physical-controller forwarding are excluded from the phone target.

The shared iPad and Mac game hosts now accept this controller as player 1.
Rebuild each game to include the receiver; existing installed games do not gain
it automatically. The separate iPad and command-line input-test receivers remain
available for transport diagnosis. Physical gameplay acceptance is still open;
Bluetooth remains experimental, especially on Mac.

## Connect to a game

1. On iPad, choose **Controllers → Connect iPhone / disconnect** from the gear
   menu, **Controllers → Connect iPhone** from the game menu, or **Connect iPhone**
   before launch. On Mac, use **Controllers → Connect iPhone / disconnect…**.
   The Mac start screen also offers **Connect iPhone and play**, which starts
   the host and opens pairing there (the launcher is a separate process).
2. Choose **Local Wi-Fi** or **Bluetooth (experimental)**, then **Enable pairing
   for player 1**. Nothing listens until explicitly enabled. Pairing expires in
   60 seconds. Local Wi-Fi requires a shared network, with no WAN requirement;
   Bluetooth requires Bluetooth permission and the radio enabled. Direct
   peer-to-peer Wi-Fi remains confined to the diagnostic apps.
3. On the phone, open **Connection → Scan receiver QR code** and scan the host.
   Build 10 calls this **Scan iPad QR code** and uses the same compatible
   protocol. For Wi-Fi, the manual invitation also works. Keep both apps open
   and the QR private; each session gets a fresh invitation.
4. Test buttons/sticks on the pairing screen, then close all host UI to play.
   The phone owns player 1 exclusively. The host hides its touch pad and keeps
   Menu available. Physical controller assignments for other players are kept;
   player-1 physical/keyboard/touch/script input is suppressed while the phone
   owns it. Plus and Minus remain game buttons. Use the phone's **Controls**
   menu to choose 2D/3D and stick settings.
5. Disconnect from either device, lock the phone, or leave the receiver app.
   Input clears and local controls return. Open pairing again for a fresh
   session. Closing an unconnected pairing screen cancels its invitation;
   closing it after connection keeps gameplay connected.

Host menus suppress remote game input while still allowing the button test to
update. A HID-side 200 ms arrival watchdog also releases input when the main
queue cannot service the transport timer. Neither menus nor disconnection pause
or save the game. The phone sends buttons and sticks only: motion, game screen
touches, saved trust and automatic reconnect are not part of this slice.

## Build

From the repository root, with Xcode, the iPhoneOS SDK and XcodeGen installed:

```sh
python3 scripts/build_controller.py --output /scratch/new-controller-build
```

The output directory must be new. It contains `NxController.ipa`,
`NxControllerReceiver.ipa` and an Xcode project under
`source/dm/controller/NxController.xcodeproj`. Use `--only controller` or
`--only receiver` to build one target. Signing is disabled; the user signs,
sideloads and tests the IPAs. This command never signs or installs anything.
All generated project files and build products stay in the specified output.

Both app targets use a single `UIWindowScene` and scene focus notifications.
This is required for startup on iOS 27; the first physical iPhone deployment
caught a trap from the older app-delegate-only window lifecycle. Corrected
device-test builds use version 0.1; build 3 adds QR pairing. Signing and installation remain
opt-in actions under explicit user authorization; the build command above
continues to produce unsigned output.

During build-3 deployment, the phone accepted installation but denied launch
with a development-profile verification error while offline. Its signature
verified on the Mac, and the same installed app launched once the user gave the
phone internet access. Verify a freshly installed development build before
travel; Apple documents first-launch PPQ checks for affected developer teams in
[provisioning profile updates](https://developer.apple.com/help/account/provisioning-profiles/provisioning-profile-updates/).
This OS-level development verification is an acceptance consideration alongside
the app's local transport.

Provisional compile targets are iOS/iPadOS 17 and macOS 14. These are not a
validated device support range. The separate phone app does not require the
game host's iOS 26 / Metal 4 runtime.

Build the Mac diagnostic receiver:

```sh
sh dm/controller/tools/build_receiver_mac.sh /scratch/receiver-test
/scratch/receiver-test
```

The Mac receiver runs in the foreground until Ctrl-C. Restart it to create a
new invitation. The listener expires after 60 seconds without a candidate;
authentication/negotiation has a 10-second deadline.

## Test a local connection

1. On iPad, open **nx Input Test** and select **Start test receiver**. On Mac,
   run the command above. This explicitly enables the diagnostic listener.
2. For iPad pairing, open **nx Controller → gear → Connection → Scan receiver QR
   code**. Allow Camera access and point at the QR in **nx Input Test**. Scanning
   transfers the receiver's selected connection mode and searches for its name;
   a matching receiver connects automatically. If Bonjour renamed it, select
   the receiver from the results. No invitation needs to be typed or copied.
3. For the Mac test receiver, or when the camera is unavailable, use the manual
   invitation. On iPad it is hidden behind **Show manual invitation**. Paste it
   into the phone's manual field, search, and select the receiver. The invitation
   is still a fresh random 256-bit credential; QR pairing transports that same
   key. Keep the QR/manual invitation private. Neither is advertised or saved.
   Search stops after 30 seconds or on dismissal. In the peer-to-peer
   experiment, selection transfers the search to connection setup for at most
   10 seconds. Build 7 retains it through an established foreground session,
   stopping on disconnect, watchdog or focus loss. LAN selection stops
   searching immediately.
4. Exercise buttons and sticks and compare the receiver's readout. The phone's
   readout is useful without a connection, too. Its ACK round trip uses only
   the phone's monotonic clock; it is not one-way or visible-response latency.
5. Stop the receiver, lock the phone or switch apps while holding a button.
   Both ends must disconnect/release input. Resume requires an explicit new
   connection; input is never queued for replay across sessions.

No WAN, DNS outside local Bonjour, account, cellular plan or reachability probe
is used. For LAN acceptance, disconnect the router's WAN and repeat the test.
Local Network permission and Wi-Fi are required. If discovery fails, allow
Local Network access in system Settings and search again. Some shared networks
isolate clients; joining the same network does not establish reachability.

For the **unverified no-router experiment**, enable **Test peer-to-peer** on
both mobile targets, or start the Mac receiver with `--peer-to-peer`. This sets
Network.framework's peer-to-peer parameters for browsing, listening and
connecting. It does not prove which path Apple selected. No ordinary
**Nearby connection** option or airplane-mode compatibility claim is exposed.
Test with no access point and no cellular data, then with airplane mode and
Wi-Fi re-enabled; record Bluetooth requirements on each device combination.
**Keep Wi-Fi enabled in Settings; disconnect from joined networks for a
no-router test. Turning the Wi-Fi radio off prevents this discovery path.**
Set radios before starting pairing and keep both apps open. Changing the mode
stops the current attempt; start again on iPad or search again on phone. QR
scanning automatically uses the mode selected on the iPad.

Physical no-router attempts on this iPhone/iPad pair discover the receiver on
`awdl0`, but connection setup expires before an incoming receiver candidate.
AirDrop succeeds with the same radio/network settings (user-reported). Thus
direct Wi-Fi is available, but this app's no-router transport remains unreliable.
Build 5 uses a fresh, confirmed Bonjour registration name and explicit
version-only TXT metadata; it did not resolve the physical failure. Build 6
tests retaining discovery during bounded connection setup. Two physical
build-6 attempts then completed TLS/negotiation on `awdl0` and exchanged the
first input/ACK. After discovery stopped at TLS readiness, further frames did
not arrive and both watchdogs fired after about 200 ms. Build 7 tests retaining
discovery for the active foreground session as well. Its physical retry still
stalled: three frames/ACKs arrived before the watchdog, with no large phone
scheduling gap. Browser retention alone is insufficient. Build 8 adds the
bounded late-arrival diagnostic described below. The system-level cause
and production suitability remain unconfirmed; Apple's current
[migration guidance](https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework)
recommends stopping discovery before connecting for performance.

Build 8 showed that the direct link remained able to deliver data: after input
release, the iPad discarded queued states 2–5 arriving in a burst roughly
490–520 ms after state 1. This is an arrival gap on one device's clock, not a
one-way latency measurement. Build 9 requests the supported `responsiveData`
service class for interactive controller traffic instead of default best
effort. This is a scheduling request, not a latency guarantee. Input release
still uses the same 200 ms deadline. Physical acceptance remains open; see
[Apple's peer-to-peer latency discussion](https://developer.apple.com/forums/thread/751839)
and [service-class documentation](https://developer.apple.com/documentation/network/nwparameters/serviceclass-swift.property).

Temporary Network.framework `waiting` states during initial discovery or path
setup now remain active within the existing 30-second search / 10-second
connection deadline. TLS errors still fail immediately. An established session
that loses its path still disconnects and clears input. Status includes numeric
error domains/codes. Connected readouts show raw available interface names,
without treating those names or the peer-to-peer flag as proof of a direct path.
Each mobile app keeps a bounded `Documents/controller-network.log` of setup,
state/error and interface events. After a connection timeout, a separate
five-second Bonjour resolution probe logs only port/address-family counts and
errors; it cannot reconnect or send input. Logs omit invitations, QR contents,
peer names, addresses and input packets. The camera runs only while its scan screen is open and does
not save photos or video. The camera permission alert retains the pairing
screen; actual backgrounding clears/dismisses it and stops control.

## Bluetooth carrier experiment (build 10)

The iPhone/iPad diagnostic apps also offer a Bluetooth LE L2CAP byte carrier.
This is an alternative feasibility test after peer-to-peer Wi-Fi repeatedly
delayed input beyond the release deadline. The first physical iPhone/iPad run
stayed connected for 30 seconds with Wi-Fi on but neither device joined to a
network (user-reported). The reported ACK round trip was 50–100 ms. The iPad
log confirms L2CAP, TLS authentication and input; no subsequent watchdog failure
appears before phone lock in the captured log. The held-button phone-lock check
also passed: buttons cleared and the receiver disconnected. The receiver's log
spans about 236 seconds from session negotiation to stream closure. This is not
a calibrated latency distribution, a measured release-time bound or
long-session travel acceptance. The Mac command-line UI currently exposes
LAN/peer-to-peer Wi-Fi only.

1. On the phone's **Connection** screen, tap **Allow Bluetooth for testing**
   and accept the Bluetooth permission prompt.
2. On iPad, enable **Test Bluetooth LE**, accept permission, then tap **Start
   test receiver**. This mode takes precedence over the peer-to-peer Wi-Fi switch.
3. Scan the new QR from the phone. It selects Bluetooth automatically. Keep
   both apps open, test buttons/sticks for 30 seconds, and record the ACK round
   trip. Bluetooth must be on; no joined network is used. Wi-Fi may be off for
   this test. If a permission prompt interrupted setup, start a fresh session.

The QR carries a fresh service UUID discovery hint and the same 256-bit TLS
invitation, using a strict version-2 `transport=ble` payload. The phone scans
only for that UUID. The iPad advertises only the public UUID and publishes a
read-only dynamic L2CAP PSM characteristic; no invitation is advertised.
Scanning/advertising has a 30/60-second setup limit. One candidate consumes
the invitation; there is no automatic reconnect or saved Bluetooth identity.

The carrier never sees a key or decoded input. It forwards the existing TLS
records over ordered L2CAP streams, with small TCP bridges bound exclusively
to `127.0.0.1` on each device. The TLS server is not advertised over Bonjour
in this mode. Link-layer bonding is optional; authentication/encryption is
always the existing TLS-PSK session end to end. There is no plaintext input
fallback and no new cipher or key-exchange design.

The byte pump handles partial reads/writes and backpressure, caps its write
queues, and closes on stream errors. Session stop/focus loss also stops the
carrier and all discovery/listeners. Input retains the same framing, ordered
edges, ACK ledger and watchdog. A radio-free test connects real TLS endpoints
through the production pump using deliberately fragmented streams, checking
short taps, heartbeats, wrong-invitation rejection and lifetime cleanup. This
does not establish physical Bluetooth latency or reliability by itself.

## Shared protocol and security boundary

`dm/apple/controller` is independent of both UIKit and host HID storage (the
protocol core itself is plain C). The transport uses Network.framework with
ordered TCP, TCP_NODELAY, and TLS 1.2 PSK with AES-128-GCM-SHA256. Only the PSK
cipher suite is configured; there is no accept-all certificate verifier,
plaintext fallback, cloud signaling, saved invitation or automatic reconnect.
One candidate consumes the listener; other candidates cannot take it over.

This is an invitation-authenticated transport spike, **not the plan's final
cryptographic device-identity pairing implementation**. A device possessing
the invitation can authenticate. QR assistance is implemented; persistent host
identity, confirmation on both devices, Keychain trust and Forget Device remain pending.
Do not silently promote this invitation flow to remembered-device trust.

Every frame is 48 bytes, explicitly encoded in network byte order: magic,
version, type, reserved fields, a random 128-bit session ID, a 64-bit sequence,
16 button bits, four signed axes and capabilities. Invalid version, lengths,
reserved bits, masks, axes, capabilities, ordering or session fail closed.
The first state is neutral. A receiver accepts at most 240 states per second.

Button transitions send immediately, including a press and release in the same
run-loop turn. Stick changes coalesce to approximately 60 Hz; unchanged full
states heartbeat every 50 ms. The receiver ACKs each applied state. Local send
completions and unacknowledged frames are separately bounded to 32. The oldest
unacknowledged frame and receiver arrival silence have 200 ms deadlines, with
a 10 ms timer; device scheduling can add delay and must be measured. A failed
session clears buttons, axes, sequence history and pending edges. The portable
receiver model latches short presses until sampled; production integration
must still feed the host's existing latching and ownership arbiter.

Build-8 diagnostic apps opt into a five-second read-only phase after an input
watchdog. Input is released immediately, the session becomes disconnected and
no new frames or ACKs are sent. Incoming frames are discarded and only their
kind, sequence and arrival time after release are logged (at most 64 frames).
The transport then closes, or closes sooner on focus loss, explicit stop or
network failure. This distinguishes late delivery from transport failure
without allowing stale input to resume. This diagnostic is disabled by default
in the shared session and does not relax the input watchdog.

The phone stays awake only during a connected foreground session. Opening a
phone settings/connection sheet neutralizes output. Losing focus on either
mobile target closes the session; menu actions do not promise game pause/save.

## Verification

```sh
python3 dm/apple/controller/tests/run_tests.py
```

This compiles the protocol tests with AddressSanitizer and UndefinedBehaviorSanitizer,
then runs actual encrypted localhost connections: ordered short taps and
heartbeats, wrong invitation, held-button silence, and a receiver that reads
input without acknowledging it. It also verifies initial waiting-state recovery,
loss of an active path, browser waiting versus fatal failure, and discovery
ownership through an encrypted session, with cleanup on focus loss and wrong
invitation. A real Bonjour test checks fresh
confirmed registration, SRV/TXT resolution, version-only metadata and encrypted
service-name connection/heartbeat ACKs. QR tests decode
the actual iPad renderer and reject invalid/oversized/version-mismatched payloads.
It needs permission to open local sockets.
An adversarial late-frame test verifies input stays released during the
read-only diagnostic and the transport closes at its five-second limit.
Tests use synthetic data and do not establish device gameplay or radio latency.
CI also builds both unsigned app targets without game assets.

Apple API basis:
[Network.framework peer-to-peer support](https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api),
[C peer-to-peer parameter](https://developer.apple.com/documentation/network/nw_parameters_set_include_peer_to_peer(_:_:)),
[TLS/PSK Network sample](https://developer.apple.com/documentation/network/implementing-netcat-with-network-framework),
[local network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy).

## Host integration checks

```sh
python3 dm/apple/controller_host/tests/run_tests.py
make -C dm/host/tests GAME=01008DB008C2C000 build/t_hid
./dm/host/tests/build/t_hid
```

The first check connects real TLS sessions to the production host receiver and
reads the actual SDK HID entry point with synthetic guest stubs. It covers short
taps, axes, menu discard, other-player preservation, focus cleanup, fresh pairing
and wrong-invitation rejection under ASan/UBSan. No game files or radios are
needed. The HID suite also covers handheld/docked routing, physical fallback
arbitration, independent applet latches and main-queue-stall neutralization.
These local checks do not replace 2D/3D gameplay or physical Bluetooth acceptance.
