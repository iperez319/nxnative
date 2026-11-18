// Game-independent, fixed-size wire format. No native structs go on the wire.
#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

enum { DM_CONTROL_WIRE_SIZE = 48, DM_CONTROL_VERSION = 1,
       DM_CONTROL_HELLO = 1, DM_CONTROL_ACCEPT = 2, DM_CONTROL_STATE = 3, DM_CONTROL_ACK = 4,
       DM_CONTROL_CAP_FULL_STATE = 1, DM_CONTROL_CAPS = DM_CONTROL_CAP_FULL_STATE,
       DM_CONTROL_MAX_PENDING = 32, DM_CONTROL_RATE = 240 };
// 200 ms leaves scheduling headroom for the proposed 250 ms device target.
// Real-device measurements must still establish the actual release bound.
#define DM_CONTROL_TIMEOUT_NS UINT64_C(200000000)
typedef struct { uint32_t buttons; int32_t axes[4]; } dm_control_state;
typedef struct {
    uint8_t kind, session[16];
    uint64_t sequence;
    dm_control_state state;
    uint32_t capabilities;
} dm_control_message;

bool dm_control_valid_state(dm_control_state state);
bool dm_control_neutral(dm_control_state state);
bool dm_control_encode(const dm_control_message *message, uint8_t out[DM_CONTROL_WIRE_SIZE]);
bool dm_control_decode(const void *bytes, size_t length, dm_control_message *message);

// One receiver session, owned by one serial executor. Latches preserve a short
// press/release until the consumer samples it. Invalidation drops pending edges.
typedef struct {
    bool active;
    uint8_t session[16];
    uint64_t sequence, arrival_ns, rate_start_ns;
    unsigned rate_count;
    dm_control_state state;
    uint32_t pressed;
} dm_control_receiver;
bool dm_control_receiver_begin(dm_control_receiver *receiver, const dm_control_message *hello, uint64_t now);
bool dm_control_receiver_apply(dm_control_receiver *receiver, const dm_control_message *message, uint64_t now);
bool dm_control_receiver_tick(dm_control_receiver *receiver, uint64_t now);
void dm_control_receiver_clear(dm_control_receiver *receiver);
dm_control_state dm_control_receiver_sample(dm_control_receiver *receiver);

// ACK ledger also bounds data that Network.framework has accepted locally but
// the peer has not processed. A successful send completion is not a peer ACK.
typedef struct {
    uint64_t sequence[DM_CONTROL_MAX_PENDING], sent_ns[DM_CONTROL_MAX_PENDING];
    unsigned head, count;
    uint64_t last_sent, last_ack;
} dm_control_sender;
bool dm_control_sender_push(dm_control_sender *sender, uint64_t sequence, uint64_t now);
bool dm_control_sender_ack(dm_control_sender *sender, uint64_t sequence);
bool dm_control_sender_alive(const dm_control_sender *sender, uint64_t now);
