/* SPDX-License-Identifier: GPL-3.0-or-later */
#import <QuartzCore/QuartzCore.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <dispatch/dispatch.h>
#include <pthread.h>
#include "hio_cursor.h"

static pthread_mutex_t cursor_lock = PTHREAD_MUTEX_INITIALIZER;
static host_cursor_position position;
static int visible;
static int presentation_allowed;
static host_cursor_clip_state clip_state;
static unsigned long long requested_image;
/* Main thread only, including image creation and layer mutation. */
static CALayer *cursor;
static int image_width, image_height, hot_x, hot_y;
static unsigned long long displayed_image;

void host_game_cursor_position(int x, int y, int left, int top, int width, int height) {
    pthread_mutex_lock(&cursor_lock);
    position = (host_cursor_position){x, y, {left, top, width, height}};
    pthread_mutex_unlock(&cursor_lock);
}

void host_game_cursor_show(int show) {
    pthread_mutex_lock(&cursor_lock);
    visible = !!show;
    pthread_mutex_unlock(&cursor_lock);
}

int host_game_cursor_confine(int active, int left, int top, int right, int bottom,
                             int cl, int ct, int cr, int cb, int *ol, int *ot, int *oright, int *ob) {
    if (!ol || !ot || !oright || !ob) return 0;
    host_cursor_bounds out;
    pthread_mutex_lock(&cursor_lock);
    int changed = host_cursor_clip_plan(&clip_state, (host_cursor_bounds){cl,ct,cr,cb},
        (host_cursor_bounds){left,top,right,bottom}, active && presentation_allowed && visible, &out);
    pthread_mutex_unlock(&cursor_lock);
    if (changed) { *ol=out.left; *ot=out.top; *oright=out.right; *ob=out.bottom; }
    return changed;
}

void host_game_cursor_filter(int smooth) {
    host_game_cursor_layer();
    cursor.magnificationFilter = smooth ? kCAFilterLinear : kCAFilterNearest;
    cursor.minificationFilter = smooth ? kCAFilterLinear : kCAFilterNearest;
}

void *host_game_cursor_layer(void) {
    if (!cursor) {
        cursor = [CALayer layer];
        cursor.anchorPoint = CGPointZero;
        cursor.hidden = YES;
        cursor.magnificationFilter = kCAFilterNearest;
    }
    return (__bridge void *)cursor;
}

void host_game_cursor_image(int w, int h, int hx, int hy, const void *bgra) {
    if (!bgra || w <= 0 || h <= 0 || w > 256 || h > 256) return;
    /* The decoder frees its buffer on return. Copy before publishing. */
    NSData *data = [NSData dataWithBytes:bgra length:(size_t)w * h * 4];
    pthread_mutex_lock(&cursor_lock);
    unsigned long long generation = ++requested_image;
    pthread_mutex_unlock(&cursor_lock);
    dispatch_async(dispatch_get_main_queue(), ^{
        pthread_mutex_lock(&cursor_lock);
        int current = generation == requested_image;
        pthread_mutex_unlock(&cursor_lock);
        if (!current) return;
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
        CGImageRef image = CGImageCreate(w, h, 8, 32, w * 4, cs,
            kCGBitmapByteOrder32Little | kCGImageAlphaFirst, provider, NULL, true,
            kCGRenderingIntentDefault);
        if (image) {
            host_game_cursor_layer();
            cursor.contents = (__bridge id)image;
            image_width = w; image_height = h; hot_x = hx; hot_y = hy;
            displayed_image = generation;
            CGImageRelease(image);
        }
        CGDataProviderRelease(provider);
        CGColorSpaceRelease(cs);
    });
}

void host_game_cursor_present(double x, double y, double w, double h, int allowed) {
    host_game_cursor_present_scaled(x, y, w, h, allowed, 1);
}

void host_game_cursor_present_scaled(double x, double y, double w, double h, int allowed, double scale) {
    host_cursor_position p;
    int show;
    unsigned long long generation;
    pthread_mutex_lock(&cursor_lock);
    presentation_allowed = !!allowed;
    p = position; show = visible; generation = requested_image;
    pthread_mutex_unlock(&cursor_lock);
    host_game_cursor_layer();
    host_cursor_rect r;
    show = allowed && show && displayed_image == generation && cursor.contents && host_cursor_map_scaled(p,
        (host_cursor_rect){x, y, w, h}, image_width, image_height, hot_x, hot_y, scale, &r);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    cursor.hidden = !show;
    if (show) {
        cursor.bounds = CGRectMake(0, 0, r.w, r.h);
        cursor.position = CGPointMake(r.x, r.y);
    }
    [CATransaction commit];
}
