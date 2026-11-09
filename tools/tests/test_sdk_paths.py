# SPDX-License-Identifier: GPL-3.0-or-later
import json
from pathlib import Path
import tempfile
import unittest
from build.sdk_paths import sdk_root
class SDKPathsTests(unittest.TestCase):
    def test_installed_metadata_selects_actual_sdk_versions(self):
        for ios,macos in [("26.5","26.5"),("27.1","27.0")]:
            with tempfile.TemporaryDirectory() as temp:
                root=Path(temp)
                iospath=f"Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS{ios}.sdk"
                macpath=f"Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX{macos}.sdk"
                for path in [iospath,macpath]: (root/path).mkdir(parents=True)
                (root/'swift-sdk.json').write_text(json.dumps({'targetTriples':{'arm64-apple-ios':{'sdkRootPath':iospath},'arm64-apple-macosx':{'sdkRootPath':macpath}}}))
                self.assertEqual(sdk_root(root,'ios'),root/iospath)
                self.assertEqual(sdk_root(root,'macos'),root/macpath)
                (root/'swift-sdk.json').write_text(json.dumps({'targetTriples':{'arm64-apple-ios':{'sdkRootPath':'../escape'}}}))
                with self.assertRaises(ValueError): sdk_root(root,'ios')
