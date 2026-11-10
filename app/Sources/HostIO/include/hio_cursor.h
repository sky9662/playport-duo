/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef HIO_CURSOR_H
#define HIO_CURSOR_H
#include <math.h>

typedef struct { double x, y, w, h; } host_cursor_rect;
typedef struct { int left, top, right, bottom; } host_cursor_bounds;
typedef struct { int active; host_cursor_bounds previous, applied; } host_cursor_clip_state;

static inline int host_cursor_bounds_equal(host_cursor_bounds a, host_cursor_bounds b) {
    return a.left == b.left && a.top == b.top && a.right == b.right && a.bottom == b.bottom;
}

/* Preserve a game's narrower clip and restore only a clip we still own.
 * Wine supplies raw desktop coordinates and applies the result itself. */
static inline int host_cursor_clip_plan(host_cursor_clip_state *state, host_cursor_bounds current,
                                        host_cursor_bounds target, int enabled, host_cursor_bounds *out) {
    if (!state || !out) return 0;
    if (state->active && !host_cursor_bounds_equal(current, state->applied)) state->active = 0;
    host_cursor_bounds base = state->active ? state->previous : current;
    host_cursor_bounds next = {base.left > target.left ? base.left : target.left,
        base.top > target.top ? base.top : target.top,
        base.right < target.right ? base.right : target.right,
        base.bottom < target.bottom ? base.bottom : target.bottom};
    if (!enabled || next.right <= next.left || next.bottom <= next.top) {
        if (!state->active) return 0;
        *out = state->previous;
        state->active = 0;
        return !host_cursor_bounds_equal(current, *out);
    }
    if (host_cursor_bounds_equal(current, next)) return 0;
    state->previous = base;
    state->applied = next;
    state->active = 1;
    *out = next;
    return 1;
}
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
/* Wine-thread bridge: plan a real server clip, not a visual-only clamp. */
int host_game_cursor_confine(int active, int left, int top, int right, int bottom,
                             int cl, int ct, int cr, int cb, int *ol, int *ot, int *oright, int *ob);
void host_game_cursor_filter(int smooth);
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
