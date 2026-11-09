/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <assert.h>
#include "../Sources/HostIO/include/hio_display.h"
int main(void) {
    int w,h;
    assert(!host_game_display_capacity_get(&w,&h));
    host_game_display_capacity_set(2034,1398);
    assert(host_game_display_capacity_get(&w,&h) && w==2034 && h==1398);
    host_game_display_capacity_set(2670,1878);
    assert(host_game_display_capacity_get(&w,&h) && w==2670 && h==1878);
    host_game_display_capacity_set(0,0);
    assert(host_game_display_capacity_get(&w,&h) && w==2670 && h==1878);
    assert(!host_game_display_capacity_get(0,&h));
    return 0;
}
