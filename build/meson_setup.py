# SPDX-License-Identifier: GPL-3.0-or-later
"""Retry only Meson's transient clock-skew error, without changing timestamps."""
import subprocess
import sys
import time


def configure(arguments, *, runner=subprocess.run, pause=time.sleep, output=None):
    output = output or sys.stdout
    arguments = list(arguments)
    for attempt in range(3):
        result = runner(["meson", "setup", *arguments], stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT, text=True)
        output.write(result.stdout)
        output.flush()
        if result.returncode == 0:
            return 0
        if "ERROR: Clock skew detected." not in result.stdout or attempt == 2:
            return result.returncode
        print("Meson clock-skew check failed; retrying configuration in 2 seconds.", file=output, flush=True)
        pause(2)
        if "--reconfigure" not in arguments:
            arguments.insert(0, "--reconfigure")
    raise AssertionError("unreachable")


if __name__ == "__main__":
    sys.exit(configure(sys.argv[1:]))
