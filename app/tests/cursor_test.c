/* SPDX-License-Identifier: GPL-3.0-or-later */
#include "hio_cursor.h"
#include <assert.h>
#include <stdio.h>
#define EQ(a,b) assert(fabs((a)-(b)) < 0.000001)
int main(void) {
    host_cursor_rect r, picture = {60, 20, 960, 540};
    host_cursor_position p = {1060, 590, {100, 50, 1920, 1080}};
    assert(host_cursor_map(p, picture, 32, 32, 4, 6, &r));
    EQ(r.x,538); EQ(r.y,287); EQ(r.w,16); EQ(r.h,16);
    /* Absolute guest warp after arbitrarily many relative inputs: no drift. */
    p.x=100; p.y=50;
    assert(host_cursor_map(p,picture,32,32,4,6,&r)); EQ(r.x,58); EQ(r.y,17);
    p.x=2019; p.y=1129;
    assert(host_cursor_map(p,picture,32,32,0,0,&r)); EQ(r.x,1019.5); EQ(r.y,559.5);
    p.x=2020; assert(!host_cursor_map(p,picture,32,32,0,0,&r));
    p.x=99; assert(!host_cursor_map(p,picture,32,32,0,0,&r));
    p.x=100; p.y=49; assert(!host_cursor_map(p,picture,32,32,0,0,&r));
    /* Negative desktop origin, changed resolution and letterboxing. */
    p=(host_cursor_position){-640,360,{-1280,0,1280,720}};
    picture=(host_cursor_rect){0,100,800,450};
    assert(host_cursor_map(p,picture,24,24,0,0,&r)); EQ(r.x,400); EQ(r.y,325); EQ(r.w,15);
    picture.w=0; assert(!host_cursor_map(p,picture,24,24,0,0,&r));
    picture.w=800; p.client.h=0; assert(!host_cursor_map(p,picture,24,24,0,0,&r));
    p.client.h=720; p.x=NAN; assert(!host_cursor_map(p,picture,24,24,0,0,&r));
    p.x=-640; picture.w=INFINITY; assert(!host_cursor_map(p,picture,24,24,0,0,&r));
    puts("cursor mapping: PASS (position, hotspot, scale, warp, edges, invalid geometry)");
}
