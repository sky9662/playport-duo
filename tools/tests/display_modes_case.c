/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <assert.h>
#include "pp_display_modes.h"
static int has(struct pp_display_size *m, unsigned count, int w, int h) {
    for (unsigned i=0; i<count; i++) if (m[i].width==w && m[i].height==h) return 1;
    return 0;
}
int main(void) {
    struct pp_display_size m[32];
    const int panels[][2] = {{2670,1878},{2034,1398},{960,720},{720,540},{1280,960}};
    for (unsigned p=0;p<sizeof(panels)/sizeof(panels[0]);p++) {
        int w=panels[p][0],h=panels[p][1];
        unsigned n=pp_display_modes(m,32,w,h);
        assert(n>0 && has(m,n,w,h));
        assert(has(m,n,720,540));
        if (h>=720 && w>=960) assert(has(m,n,960,720));
        if (h>=768 && w>=1024) assert(has(m,n,1024,768));
        if (h>=960 && w>=1280) assert(has(m,n,1280,960));
        for (unsigned i=0;i<n;i++) {
            assert((m[i].width<=w && m[i].height<=h) ||
                   (m[i].width==640 && m[i].height==480) || (m[i].width==800 && m[i].height==600));
            if (i) assert(m[i-1].width<m[i].width ||
                          (m[i-1].width==m[i].width && m[i-1].height<m[i].height));
        }
    }
    unsigned n=pp_display_with_current(m,32,2670,1878,2034,1398);
    assert(has(m,n,2670,1878) && has(m,n,2034,1398) && has(m,n,1280,960));
    n=pp_display_with_current(m,32,2034,1398,2670,1878);
    assert(has(m,n,2034,1398) && has(m,n,2670,1878));
    n=pp_display_with_current(m,32,2034,1398,1280,960);
    assert(has(m,n,1280,960));
    assert(pp_display_with_current(m,0,2670,1878,2034,1398)==0);
    assert(pp_display_modes(m,0,2670,1878)==0);
    assert(pp_display_modes(m,1,2670,1878)==1);
    assert(pp_display_modes(m,32,0,0)==0);
    return 0;
}
