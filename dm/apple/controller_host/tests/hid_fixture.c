// Reuse existing guest stubs while exposing the actual SDK input entry point.
#define main dm_hid_suite_main
#include "../../../host/tests/t_hid.c"
#undef main
void dm_test_hid_read(void *out, uint32_t player) { h_hid_StateFullKey(out, &player); }
