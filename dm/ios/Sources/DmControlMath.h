// Shared touch response math: no UIKit dependency, exercised by host tests.
#pragma once
#include <math.h>
#include <stdint.h>
static inline double dm_control_bound(double value, double fallback, double lo, double hi) {
    return isfinite(value) ? fmin(hi, fmax(lo, value)) : fallback;
}
static inline void dm_control_stick(double x, double y, double radius, double dead,
                                    double sensitivity, int32_t *outX, int32_t *outY) {
    *outX = *outY = 0;
    if (!(radius > 0) || !isfinite(x) || !isfinite(y)) return;
    dead = dm_control_bound(dead, 0.1, 0, 0.4);
    sensitivity = dm_control_bound(sensitivity, 1, 0.25, 2);
    double length = hypot(x, y), dz = radius * dead;
    if (length <= dz) return;
    double gain = fmin((fmin(length, radius) - dz) / (radius * 0.8 - dz) * sensitivity, 1) / length;
    *outX = (int32_t)lrint(x * gain * 32767);
    *outY = (int32_t)lrint(-y * gain * 32767);
}
static inline uint64_t dm_control_dpad(double dx, double dy, double radius) {
    if (hypot(dx, dy) < radius * 0.25) return 0;
    double angle = atan2(-dy, dx) * 180 / M_PI;
    uint64_t bits = 0;
    if (angle > -67.5 && angle < 67.5) bits |= 1ull << 14;
    if (angle > 22.5 && angle < 157.5) bits |= 1ull << 13;
    if (angle > 112.5 || angle < -112.5) bits |= 1ull << 12;
    if (angle < -22.5 && angle > -157.5) bits |= 1ull << 15;
    return bits;
}
