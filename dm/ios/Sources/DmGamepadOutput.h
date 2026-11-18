// Reusable touch controls. DM_CONTROLLER_APP excludes game runtime, physical
// pads, motion and applets; the standalone app supplies its own menu and sink.
#pragma once
#import <UIKit/UIKit.h>
#include <stdbool.h>
#include <stdint.h>
typedef void (^DmGamepadOutput)(uint64_t buttons, int32_t lx, int32_t ly, int32_t rx, int32_t ry);
// Install before creating the view. The sink runs synchronously outside the
// input lock (main thread in the standalone app). NULL restores the host destination.
void dm_gamepad_set_output(DmGamepadOutput _Nullable output);
void dm_gamepad_set_menu(UIMenu * _Nonnull menu);
UIViewController * _Nonnull dm_gamepad_settings(void);
void dm_gamepad_host_ui(BOOL open);
void dm_gamepad_active(BOOL active);
