#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// Host callbacks return true only after copying the complete readable span.
typedef bool (*DMGuideHeapRead)(uint64_t address, void *out, size_t size);
void dm_shield_guide_configure_live(const char *build, const void *base, size_t size, DMGuideHeapRead read);
