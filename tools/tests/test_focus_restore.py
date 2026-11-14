# SPDX-License-Identifier: GPL-3.0-or-later
"""Execute the shipped focus recovery functions with delayed guest-thread replies."""
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]


def function(source, signature):
    start = source.index(signature)
    brace = source.index("{", start)
    depth = 1
    end = brace + 1
    while depth:
        if source[end] == "{":
            depth += 1
        elif source[end] == "}":
            depth -= 1
        end += 1
    return source[start:end] + "\n"


class FocusRestore(unittest.TestCase):
    def test_delayed_restore_timeout_modal_destruction_and_reentry(self):
        work = REPO / ".work"
        work.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="focus-restore-", dir=work) as tmp:
            root = Path(tmp)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            path = root / "app/Madeira/Winios/Winios.m"
            path.parent.mkdir(parents=True)
            path.write_bytes(subprocess.check_output([
                "git", "-C", str(REPO / "upstream/madeira"), "show",
                "HEAD:app/Madeira/Winios/Winios.m"]))
            for name in (REPO / "patches/madeira-winios/series").read_text().splitlines():
                if name and not name.startswith("#"):
                    subprocess.run(["git", "apply", str(REPO / "patches/madeira-winios" / name)],
                                   cwd=root, check=True)
            source = path.read_text()
            functions = "\n".join(function(source, sig) for sig in [
                "static int winios_fg_none(", "static int winios_focus_restore(",
                "static int winios_focus_ready(", "static void winios_drain_focus("])
            harness = r'''
#include <assert.h>
#include <pthread.h>
#include <stdio.h>
typedef void *HWND;
typedef int BOOL;
typedef struct { int type, x; } winios_input_event_t;
#define WINIOS_EV_FOCUS 3
#define GAME ((HWND)1)
#define DESKTOP ((HWND)2)
static pthread_mutex_t g_focus_lock = PTHREAD_MUTEX_INITIALIZER;
static int g_app_away;
static HWND g_focus_saved, g_focus_child, g_restore_target, g_restore_show_pending;
static unsigned int g_focus_pid;
static double g_restore_since, g_restore_retry_at, g_child_until, g_focus_wait_since;
static double clock_now;
static unsigned int style, exstyle;
static int alive, activations, shows, reenter;
static int pads_released, minimize_on_loss;
static HWND foreground;
static int winios_focus_ready(const winios_input_event_t *e);
static HWND get_desktop_window(void) { return DESKTOP; }
static unsigned int get_window_long(HWND hwnd, int offset) {
    return hwnd == GAME ? (offset == -16 ? style : exstyle) : 0;
}
static HWND NtUserGetForegroundWindow(void) { return foreground; }
static HWND get_active_window(void) { return foreground; }
static HWND get_focus(void) { return foreground; }
static unsigned int get_window_thread(HWND hwnd, unsigned int *pid) {
    (void)hwnd; *pid = 10; return 1;
}
static int set_active_window(HWND hwnd, HWND *prev, int mouse, int focus, unsigned int thread) {
    (void)mouse; (void)focus; (void)thread;
    *prev = foreground; foreground = hwnd;
    if (!hwnd && minimize_on_loss) style |= 0x20000000u;
    return 1;
}
static int host_pads_release_all(void) { return ++pads_released; }
static int is_window(HWND hwnd) { return hwnd == GAME && alive; }
static double CACurrentMediaTime(void) { return clock_now; }
static int set_foreground_window(HWND hwnd, int mouse, int internal) {
    assert(!mouse && internal && !(style & 0x20000000u));
    activations++; foreground = hwnd; return 1;
}
static HWND winios_focus_target(HWND saved, unsigned int pid) {
    (void)pid; return alive ? saved : NULL;
}
static BOOL NtUserShowWindowAsync(HWND hwnd, int cmd) {
    assert(hwnd == GAME && cmd == 9);
    shows++;
    if (reenter) {
        winios_input_event_t input = {0, 0};
        assert(!winios_focus_ready(&input));
    }
    return 1; /* queued, but the guest thread has not restored it yet */
}
'''
            cases = r'''
static void reset(void) {
    alive = 1; style = 0x30000000u; exstyle = 0;
    foreground = GAME; clock_now = 1;
    activations = shows = reenter = g_app_away = 0;
    pads_released = minimize_on_loss = 0; g_focus_child = NULL;
    g_focus_saved = g_restore_target = GAME;
    g_focus_pid = 10; g_restore_since = 1;
    g_restore_show_pending = NULL;
    g_restore_retry_at = g_child_until = g_focus_wait_since = 0;
}
int main(void) {
    winios_input_event_t input = {0, 0};
    reset(); reenter = 1;
    assert(winios_focus_restore(GAME, "test"));
    assert(shows == 1 && activations == 0);
    clock_now = 1.2;
    assert(!winios_focus_ready(&input));
    assert(activations == 0); /* a minimized foreground is not ready */
    style &= ~0x20000000u;
    assert(!winios_focus_ready(&input));
    assert(activations == 1 && !g_restore_show_pending);
    assert(winios_focus_ready(&input));
    assert(!g_restore_since);

    reset(); winios_focus_restore(GAME, "timeout");
    clock_now = 1.6;
    assert(winios_focus_ready(&input));
    assert(!g_restore_since && !g_restore_show_pending && activations == 0);
    assert(g_restore_retry_at > clock_now);
    assert(winios_focus_ready(&input)); assert(shows == 1);

    reset(); winios_focus_restore(GAME, "destroyed");
    alive = 0; style = 0; foreground = NULL; clock_now = 1.1;
    assert(!winios_focus_ready(&input)); assert(!activations);
    clock_now = 1.6; assert(winios_focus_ready(&input));
    assert(!activations && !g_restore_show_pending);

    reset(); winios_focus_restore(GAME, "modal");
    style = 0x18000000u; foreground = NULL;
    assert(!winios_focus_ready(&input)); assert(!activations);
    clock_now = 1.6; assert(winios_focus_ready(&input));
    assert(!activations);

    reset(); style = 0x20000000u; /* hidden */
    assert(!winios_focus_restore(GAME, "hidden")); assert(!shows && !activations);
    reset(); exstyle = 0x08000000u;
    assert(!winios_focus_restore(GAME, "noactivate")); assert(!shows && !activations);

    /* The actual loss/back path: the game minimizes inside its loss callback.
     * Key releases must still drain while away; a second loss cancels recovery. */
    reset(); style = 0x10000000u; minimize_on_loss = 1;
    winios_drain_focus(0);
    assert(g_app_away && g_focus_saved == GAME && pads_released == 1);
    assert(style & 0x20000000u);
    assert(winios_focus_ready(&input)); assert(!shows);
    winios_drain_focus(1);
    assert(!g_app_away && shows == 1 && !activations);
    assert(g_restore_show_pending == GAME);
    winios_drain_focus(0);
    assert(!g_restore_show_pending && !g_restore_since && pads_released == 2);
    assert(winios_focus_ready(&input)); assert(!activations);
    return 0;
}
'''
            probe = root / "test.c"
            probe.write_text(harness + functions + cases)
            exe = root / "test"
            subprocess.run(["cc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-pthread",
                            str(probe), "-o", str(exe)], check=True)
            subprocess.run([str(exe)], check=True, timeout=10)
