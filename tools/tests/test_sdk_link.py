# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('sdk_link', Path(__file__).resolve().parents[2] / 'build/ld64/sdk_link.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SDKLinkTests(unittest.TestCase):
    def test_uses_actual_sdk_metadata_and_preserves_deployment_target(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for version in ('26.5', '27.1'):
                (root / 'SDKSettings.json').write_text(json.dumps({'Version': version}))
                args = ['-syslibroot', directory, '-platform_version', 'ios', '26.0', '26.0', '-o', 'app']
                result = module.sdk_arguments(args)
                self.assertEqual(result, [*args[:5], version, *args[6:]])
                self.assertEqual(args[5], '26.0')

    def test_legacy_flag_becomes_explicit_platform_version(self):
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / 'SDKSettings.json').write_text('{"Version":"27.1"}')
            result = module.sdk_arguments(['-iphoneos_version_min', '26.0', '-syslibroot', directory])
            self.assertEqual(result, ['-platform_version', 'ios', '26.0', '27.1', '-syslibroot', directory])

    def test_missing_or_invalid_sdk_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            args = ['-syslibroot', directory, '-platform_version', 'ios', '26.0', '26.0']
            with self.assertRaises(ValueError):
                module.sdk_arguments(args)
            (Path(directory) / 'SDKSettings.json').write_text('{"Version":"pretend-27"}')
            with self.assertRaises(ValueError):
                module.sdk_arguments(args)

    def test_host_link_is_unchanged(self):
        args = ['-platform_version', 'macos', '15.0', '27.0']
        self.assertEqual(module.sdk_arguments(args), args)
