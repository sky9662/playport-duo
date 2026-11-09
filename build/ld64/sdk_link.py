#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Give Apple's linker the version of the SDK it actually links against."""
import json
from pathlib import Path
import os
import re
import sys


def sdk_arguments(arguments):
    args = list(arguments)
    positions = [i for i, a in enumerate(args) if a == '-platform_version'
                 and i + 3 < len(args) and args[i + 1] == 'ios']
    legacy = [i for i, a in enumerate(args) if a in ('-iphoneos_version_min', '-ios_version_min')]
    if not positions and not legacy:
        return args
    try:
        root_index = args.index('-syslibroot')
        root = Path(args[root_index + 1])
        version = str(json.loads((root / 'SDKSettings.json').read_text())['Version'])
    except (ValueError, IndexError, OSError, KeyError, json.JSONDecodeError) as error:
        raise ValueError('iOS final link requires SDKSettings.json from its actual -syslibroot') from error
    if not re.fullmatch(r'\d+(?:\.\d+){0,2}', version):
        raise ValueError('invalid SDKSettings.json Version')
    for i in positions:
        args[i + 3] = version
    for i in reversed(legacy):
        if i + 1 >= len(args):
            raise ValueError('missing iOS deployment target')
        args[i:i + 2] = ['-platform_version', 'ios', args[i + 1], version]
    return args


if __name__ == '__main__':
    try:
        args = sdk_arguments(sys.argv[2:])
    except ValueError as error:
        sys.exit(f'ld64 SDK configuration: {error}')
    os.execv(sys.argv[1], [sys.argv[1], *args])
