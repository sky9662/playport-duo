/* SPDX-License-Identifier: GPL-3.0-or-later */
#include "include/hio_display.h"
#include <stdint.h>
#include <stdatomic.h>
static _Atomic uint64_t capacity;
void host_game_display_capacity_set(int width, int height) {
    if (width <= 0 || height <= 0 || width > 8192 || height > 8192) return;
    atomic_store_explicit(&capacity, ((uint64_t)(unsigned)width << 32) | (unsigned)height, memory_order_release);
}
int host_game_display_capacity_get(int *width, int *height) {
    uint64_t value = atomic_load_explicit(&capacity, memory_order_acquire);
    if (!value || !width || !height) return 0;
    *width = value >> 32; *height = value & 0xffffffff;
    return 1;
}
