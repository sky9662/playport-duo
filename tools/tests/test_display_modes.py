# SPDX-License-Identifier: GPL-3.0-or-later
"""Compile and exercise the actual shipped virtual-monitor enumerator."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT = Path(__file__).resolve().parents[2]
class DisplayModesTests(unittest.TestCase):
    def test_shipped_four_three_modes(self):
        scratch = Path(os.environ.get('PLAYPORT_BUILD', str(ROOT / '.work'))) / 'tmp'
        scratch.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=scratch) as td:
            directory=Path(td)
            subprocess.run(['git','init','-q',str(directory)],check=True)
            subprocess.run(['git','apply','--include=build/win32u-unix/pp_display_modes.h',str(ROOT/'patches/madeira-unix/0290-win32u-include-four-three-resolution-levels.patch')],cwd=directory,check=True)
            subprocess.run(['git','apply','--include=build/win32u-unix/pp_display_modes.h',str(ROOT/'patches/madeira-unix/0291-win32u-refresh-scene-mode-capacity.patch')],cwd=directory,check=True)
            binary=directory/('test.exe' if os.name=='nt' else 'test')
            subprocess.run([os.environ.get('CC','cc'),'-std=c11','-Wall','-Wextra','-Werror','-UNDEBUG','-I',str(directory/'build/win32u-unix'),str(ROOT/'tools/tests/display_modes_case.c'),'-o',str(binary)],check=True,timeout=120)
            subprocess.run([str(binary)],check=True,timeout=30)
