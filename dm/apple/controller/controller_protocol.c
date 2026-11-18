#include "controller_protocol.h"
#include <string.h>

static uint64_t read_be(const uint8_t *p, unsigned n) {
    uint64_t v = 0; for (unsigned i = 0; i < n; i++) v = (v << 8) | p[i]; return v;
}
static void write_be(uint8_t *p, uint64_t v, unsigned n) {
    for (unsigned i = n; i; i--) { p[i - 1] = (uint8_t)v; v >>= 8; }
}
bool dm_control_valid_state(dm_control_state s) {
    if (s.buttons & ~UINT32_C(0xffff)) return false;
    for (unsigned i = 0; i < 4; i++) if (s.axes[i] < -32767 || s.axes[i] > 32767) return false;
    return true;
}
bool dm_control_neutral(dm_control_state s) {
    return !s.buttons && !s.axes[0] && !s.axes[1] && !s.axes[2] && !s.axes[3];
}
static bool valid(const dm_control_message *m) {
    unsigned nonzero = 0; for (unsigned i = 0; i < 16; i++) nonzero |= m->session[i];
    if (!nonzero || !dm_control_valid_state(m->state)) return false;
    switch (m->kind) {
        case DM_CONTROL_HELLO: case DM_CONTROL_ACCEPT:
            return !m->sequence && dm_control_neutral(m->state) && m->capabilities == DM_CONTROL_CAPS;
        case DM_CONTROL_STATE: return m->sequence && !m->capabilities;
        case DM_CONTROL_ACK: return m->sequence && !m->capabilities && dm_control_neutral(m->state);
        default: return false;
    }
}
bool dm_control_encode(const dm_control_message *m, uint8_t out[DM_CONTROL_WIRE_SIZE]) {
    if (!m || !out || !valid(m)) return false;
    memset(out, 0, DM_CONTROL_WIRE_SIZE); memcpy(out, "NXCP", 4);
    out[4] = DM_CONTROL_VERSION; out[5] = m->kind;
    memcpy(out + 8, m->session, 16); write_be(out + 24, m->sequence, 8);
    write_be(out + 32, m->state.buttons, 4);
    for (unsigned i = 0; i < 4; i++) write_be(out + 36 + 2 * i, (uint16_t)m->state.axes[i], 2);
    write_be(out + 44, m->capabilities, 4); return true;
}
bool dm_control_decode(const void *bytes, size_t n, dm_control_message *out) {
    if (!bytes || !out || n != DM_CONTROL_WIRE_SIZE) return false;
    const uint8_t *p = bytes;
    if (memcmp(p, "NXCP", 4) || p[4] != DM_CONTROL_VERSION || p[6] || p[7]) return false;
    dm_control_message m = { .kind = p[5] };
    memcpy(m.session, p + 8, 16); m.sequence = read_be(p + 24, 8);
    m.state.buttons = (uint32_t)read_be(p + 32, 4);
    for (unsigned i = 0; i < 4; i++) {
        int v = (int)read_be(p + 36 + 2 * i, 2); m.state.axes[i] = v >= 32768 ? v - 65536 : v;
    }
    m.capabilities = (uint32_t)read_be(p + 44, 4);
    if (!valid(&m)) return false;
    *out = m; return true;
}
void dm_control_receiver_clear(dm_control_receiver *r) { memset(r, 0, sizeof *r); }
bool dm_control_receiver_begin(dm_control_receiver *r, const dm_control_message *m, uint64_t now) {
    if (r->active || !valid(m) || m->kind != DM_CONTROL_HELLO) return false;
    dm_control_receiver_clear(r); r->active = true; memcpy(r->session, m->session, 16);
    r->arrival_ns = r->rate_start_ns = now; return true;
}
bool dm_control_receiver_apply(dm_control_receiver *r, const dm_control_message *m, uint64_t now) {
    if (!r->active) return false;
    if (!valid(m) || m->kind != DM_CONTROL_STATE || memcmp(m->session, r->session, 16) ||
        r->sequence == UINT64_MAX || m->sequence != r->sequence + 1 || now < r->arrival_ns ||
        now - r->arrival_ns >= DM_CONTROL_TIMEOUT_NS ||
        (!r->sequence && !dm_control_neutral(m->state))) goto reject;
    if (now - r->rate_start_ns >= UINT64_C(1000000000)) { r->rate_start_ns = now; r->rate_count = 0; }
    if (++r->rate_count > DM_CONTROL_RATE) goto reject;
    r->pressed |= m->state.buttons & ~r->state.buttons;
    r->state = m->state; r->sequence = m->sequence; r->arrival_ns = now; return true;
reject:
    dm_control_receiver_clear(r); return false;
}
bool dm_control_receiver_tick(dm_control_receiver *r, uint64_t now) {
    if (!r->active) return false;
    if (now < r->arrival_ns || now - r->arrival_ns >= DM_CONTROL_TIMEOUT_NS) {
        dm_control_receiver_clear(r); return false;
    }
    return true;
}
dm_control_state dm_control_receiver_sample(dm_control_receiver *r) {
    dm_control_state s = r->state; s.buttons |= r->pressed; r->pressed = 0; return s;
}
bool dm_control_sender_push(dm_control_sender *s, uint64_t sequence, uint64_t now) {
    if (s->count == DM_CONTROL_MAX_PENDING || s->last_sent == UINT64_MAX || sequence != s->last_sent + 1 ||
        !dm_control_sender_alive(s, now)) return false;
    unsigned at = (s->head + s->count) % DM_CONTROL_MAX_PENDING;
    s->sequence[at] = sequence; s->sent_ns[at] = now; s->count++; s->last_sent = sequence; return true;
}
bool dm_control_sender_ack(dm_control_sender *s, uint64_t sequence) {
    if (!s->count || sequence != s->sequence[s->head]) return false;
    s->head = (s->head + 1) % DM_CONTROL_MAX_PENDING; s->count--; s->last_ack = sequence; return true;
}
bool dm_control_sender_alive(const dm_control_sender *s, uint64_t now) {
    return !s->count || (now >= s->sent_ns[s->head] && now - s->sent_ns[s->head] < DM_CONTROL_TIMEOUT_NS);
}
