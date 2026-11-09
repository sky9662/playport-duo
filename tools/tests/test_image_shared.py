# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise the shipped small-image shared-section patch using real VM aliases.

The C fixture uses the host's mapping API for Mach operations and a stopped CPU
context seam. It is not a replacement for the iOS full-build and phone gates.
"""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / 'patches/madeira-unix/0288-virtual-service-small-image-shared-pages-through-aliases.patch'


class ImageSharedTests(unittest.TestCase):
    def test_shipped_shared_mapping(self):
        compiler = shlex.split(os.environ.get('CC', 'cc'))
        self.assertTrue(compiler and shutil.which(compiler[0]), 'A host C compiler is required')
        scratch = Path(os.environ.get('PLAYPORT_BUILD', str(ROOT / '.work'))) / 'tmp'
        scratch.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=scratch) as td:
            directory = Path(td)
            subprocess.run(['git', 'init', '-q', str(directory)], check=True)
            subprocess.run(['git', 'apply', '--include=build/ntdll-unix/pp_image_shared*.h', str(PATCH)],
                           cwd=directory, check=True)
            subprocess.run(['git', 'apply', str(ROOT / 'patches/madeira-unix/0289-virtual-make-small-shared-image-compatibility-adjustable.patch')], cwd=directory, check=True)
            binary = directory / ('test.exe' if os.name == 'nt' else 'test')
            command = [*compiler, '-std=gnu11', '-O2', '-UNDEBUG', '-Wall', '-Wextra', '-Werror',
                       '-I', str(directory / 'build/ntdll-unix'),
                       str(ROOT / 'tools/tests/image_shared_case.c'), '-o', str(binary)]
            if os.name != 'nt':
                command.append('-pthread')
            subprocess.run(command, check=True, timeout=120)
            subprocess.run([str(binary)], check=True, timeout=30)


if __name__ == '__main__':
    unittest.main()
