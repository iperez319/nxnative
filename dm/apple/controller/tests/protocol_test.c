#include "../controller_protocol.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

static dm_control_message hello(void) {
    dm_control_message m = {.kind = DM_CONTROL_HELLO, .capabilities = DM_CONTROL_CAPS}; m.session[0] = 1; return m;
}
static dm_control_message state(uint64_t sequence, uint32_t buttons) {
    dm_control_message m = hello(); m.kind = DM_CONTROL_STATE; m.capabilities = 0;
    m.sequence = sequence; m.state.buttons = buttons; return m;
}
int main(void) {
    uint8_t bytes[DM_CONTROL_WIRE_SIZE], bad[DM_CONTROL_WIRE_SIZE];
    dm_control_message m = hello(), decoded;
    assert(dm_control_encode(&m, bytes)); assert(!memcmp(bytes, "NXCP\x01\x01\0\0", 8));
    assert(dm_control_decode(bytes, sizeof bytes, &decoded)); assert(decoded.session[0] == 1);
    for (unsigned n = 0; n < sizeof bytes; n++) assert(!dm_control_decode(bytes, n, &decoded));
    assert(!dm_control_decode(bytes, sizeof bytes + 1, &decoded));
    const unsigned offsets[] = {0, 4, 5, 6, 7, 24, 32, 44, 47};
    for (unsigned i = 0; i < sizeof offsets / sizeof *offsets; i++) {
        memcpy(bad, bytes, sizeof bad); bad[offsets[i]] ^= 0xff; assert(!dm_control_decode(bad, sizeof bad, &decoded));
    }
    m = state(UINT64_C(0x0102030405060708), 0xffff); m.state.axes[0] = -32767; m.state.axes[1] = 32767;
    assert(dm_control_encode(&m, bytes)); assert(bytes[24] == 1 && bytes[31] == 8 && bytes[36] == 0x80 && bytes[37] == 1);
    assert(dm_control_decode(bytes, sizeof bytes, &decoded)); assert(decoded.state.axes[0] == -32767 && decoded.state.axes[1] == 32767);
    bytes[37] = 0; assert(!dm_control_decode(bytes, sizeof bytes, &decoded)); // -32768 is forbidden
    m.state.axes[0] = -32768; assert(!dm_control_encode(&m, bytes));
    m = state(1, 1u << 16); assert(!dm_control_encode(&m, bytes));
    m = state(0, 0); assert(!dm_control_encode(&m, bytes));
    m = hello(); memset(m.session, 0, 16); assert(!dm_control_encode(&m, bytes));
    // Host receipt times only: no sender timestamps or cross-device clock math.
    dm_control_receiver r = {0}; m = hello();
    assert(dm_control_receiver_begin(&r, &m, 100)); assert(!dm_control_receiver_begin(&r, &m, 101));
    m = state(1, 1); assert(!dm_control_receiver_apply(&r, &m, 102)); assert(!r.active);
    m = hello(); assert(dm_control_receiver_begin(&r, &m, 100));
    m = state(1, 0); assert(dm_control_receiver_apply(&r, &m, 101));
    m = state(2, 1); assert(dm_control_receiver_apply(&r, &m, 102));
    m = state(3, 0); assert(dm_control_receiver_apply(&r, &m, 103));
    assert(dm_control_receiver_sample(&r).buttons == 1); assert(!dm_control_receiver_sample(&r).buttons);
    // A duplicate fails closed and drops latches, rather than refreshing liveness.
    assert(!dm_control_receiver_apply(&r, &m, 104)); assert(!r.active && !r.pressed);
    m = hello(); assert(dm_control_receiver_begin(&r, &m, 100));
    m = state(1, 0); assert(dm_control_receiver_apply(&r, &m, 101));
    m = state(2, 3); m.state.axes[0] = 12345; assert(dm_control_receiver_apply(&r, &m, 102));
    assert(dm_control_receiver_tick(&r, 102 + DM_CONTROL_TIMEOUT_NS - 1));
    assert(!dm_control_receiver_tick(&r, 102 + DM_CONTROL_TIMEOUT_NS));
    assert(dm_control_neutral(dm_control_receiver_sample(&r)));
    // Reconnect changes identity; packets from the old session cannot apply.
    m = hello(); m.session[0] = 2; assert(dm_control_receiver_begin(&r, &m, 200));
    m = state(1, 0); assert(!dm_control_receiver_apply(&r, &m, 201));
    // One source's loss cannot mutate a second source's state or latches.
    dm_control_receiver other = {0}; m = hello(); assert(dm_control_receiver_begin(&other, &m, 10));
    m = state(1, 0); assert(dm_control_receiver_apply(&other, &m, 11));
    m = state(2, 2); assert(dm_control_receiver_apply(&other, &m, 12)); dm_control_receiver_clear(&r);
    assert(dm_control_receiver_sample(&other).buttons == 2);
    // Floods, backwards clocks and sequence gaps fail closed.
    m = hello(); assert(dm_control_receiver_begin(&r, &m, 100));
    for (unsigned i = 1; i <= DM_CONTROL_RATE; i++) { m = state(i, 0); assert(dm_control_receiver_apply(&r, &m, 100 + i)); }
    m = state(DM_CONTROL_RATE + 1, 0); assert(!dm_control_receiver_apply(&r, &m, 1000));
    m = hello(); assert(dm_control_receiver_begin(&r, &m, 100));
    m = state(1, 0); assert(!dm_control_receiver_apply(&r, &m, 99));
    m = hello(); assert(dm_control_receiver_begin(&r, &m, 100));
    m = state(2, 0); assert(!dm_control_receiver_apply(&r, &m, 101));
    dm_control_sender s = {0};
    for (unsigned i = 1; i <= DM_CONTROL_MAX_PENDING; i++) assert(dm_control_sender_push(&s, i, 100 + i));
    assert(!dm_control_sender_push(&s, DM_CONTROL_MAX_PENDING + 1, 200));
    assert(!dm_control_sender_ack(&s, 2)); assert(dm_control_sender_ack(&s, 1)); assert(!dm_control_sender_ack(&s, 1));
    assert(dm_control_sender_push(&s, DM_CONTROL_MAX_PENDING + 1, 200));
    assert(dm_control_sender_alive(&s, 102 + DM_CONTROL_TIMEOUT_NS - 1));
    assert(!dm_control_sender_alive(&s, 102 + DM_CONTROL_TIMEOUT_NS));
    for (unsigned i = 2; i <= DM_CONTROL_MAX_PENDING + 1; i++) assert(dm_control_sender_ack(&s, i));
    assert(!s.count); assert(dm_control_sender_alive(&s, UINT64_MAX));
    // Arbitrary bytes may decode only into canonical, re-encodable messages.
    uint32_t rng = 0x12345678;
    for (unsigned k = 0; k < 10000; k++) {
        for (unsigned i = 0; i < sizeof bytes; i++) { rng = rng * 1664525 + 1013904223; bytes[i] = (uint8_t)(rng >> 24); }
        if (dm_control_decode(bytes, sizeof bytes, &decoded)) { assert(dm_control_encode(&decoded, bad)); assert(!memcmp(bytes, bad, sizeof bytes)); }
    }
    puts("PASS: wire bounds/version/capabilities, ordered taps, liveness, rate limit, session isolation, independent sources, bounded ACK ledger");
}
