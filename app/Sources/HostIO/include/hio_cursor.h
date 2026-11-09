/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef HIO_CURSOR_H
#define HIO_CURSOR_H
#include <math.h>

typedef struct { double x, y, w, h; } host_cursor_rect;
/* Raw Wine desktop pixels, never accumulated touch deltas. */
typedef struct {
    double x, y;
    host_cursor_rect client;
} host_cursor_position;

/* The picture is the aspect-fitted presented client image in view points.
 * Hide outside the client instead of clamping an inaccurate arrow to an edge.
 * Safe-area insets belong to touch controls, not the game's picture. */
static inline int host_cursor_map(host_cursor_position p, host_cursor_rect picture,
                                  int iw, int ih, int hx, int hy,
                                  host_cursor_rect *out) {
    if (!out || iw <= 0 || ih <= 0 || p.client.w <= 0 || p.client.h <= 0 ||
        picture.w <= 0 || picture.h <= 0 || !isfinite(p.x) || !isfinite(p.y) ||
        !isfinite(p.client.x) || !isfinite(p.client.y) ||
        !isfinite(p.client.w) || !isfinite(p.client.h) ||
        !isfinite(picture.x) || !isfinite(picture.y) ||
        !isfinite(picture.w) || !isfinite(picture.h)) return 0;
    double x = p.x - p.client.x, y = p.y - p.client.y;
    if (x < 0 || y < 0 || x >= p.client.w || y >= p.client.h) return 0;
    double sx = picture.w / p.client.w, sy = picture.h / p.client.h;
    *out = (host_cursor_rect){picture.x + (x - hx) * sx,
                             picture.y + (y - hy) * sy, iw * sx, ih * sy};
    return 1;
}

/* Wine threads publish; the main thread owns the layer and refreshes once per
 * display tick. No Wine API is called from UIKit's thread. */
void host_game_cursor_position(int x, int y, int left, int top, int width, int height);
void host_game_cursor_image(int w, int h, int hx, int hy, const void *bgra);
void host_game_cursor_show(int show);
void *host_game_cursor_layer(void);
void host_game_cursor_present(double x, double y, double w, double h, int allowed);
/* Enlarge around the hotspot, keeping its screen position unchanged. */
static inline int host_cursor_map_scaled(host_cursor_position p, host_cursor_rect picture,
                                         int iw, int ih, int hx, int hy, double scale,
                                         host_cursor_rect *out) {
    if (!isfinite(scale) || scale < 1 || scale > 4) scale = 1;
    if (!host_cursor_map(p, picture, iw, ih, hx, hy, out)) return 0;
    out->x -= hx * picture.w / p.client.w * (scale - 1);
    out->y -= hy * picture.h / p.client.h * (scale - 1);
    out->w *= scale; out->h *= scale;
    return 1;
}
void host_game_cursor_present_scaled(double x, double y, double w, double h, int allowed, double scale);
#endif
