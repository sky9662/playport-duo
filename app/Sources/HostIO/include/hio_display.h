/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef HIO_DISPLAY_H
#define HIO_DISPLAY_H
/* Atomic pair: UIKit publishes available logical pixels; Wine reads without UIKit calls. */
void host_game_display_capacity_set(int width, int height);
int host_game_display_capacity_get(int *width, int *height);
#endif
