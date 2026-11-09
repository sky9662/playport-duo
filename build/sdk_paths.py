# SPDX-License-Identifier: GPL-3.0-or-later
"""Read actual platform SDK roots from xtool metadata without assuming a version."""
import json
from pathlib import Path
import sys
TRIPLES = {"ios": "arm64-apple-ios", "macos": "arm64-apple-macosx"}
def sdk_root(bundle, platform):
    bundle = Path(bundle)
    metadata = json.loads((bundle / "swift-sdk.json").read_text())
    relative = Path(metadata["targetTriples"][TRIPLES[platform]]["sdkRootPath"])
    root = bundle / relative
    if relative.is_absolute() or ".." in relative.parts or not root.is_dir():
        raise ValueError("invalid or absent SDK root in swift-sdk.json")
    return root
if __name__ == "__main__":
    if sys.argv[1]:
        root = sdk_root(sys.argv[1], sys.argv[2])
        print(json.loads((root / "SDKSettings.json").read_text())["Version"] if len(sys.argv) > 3 and sys.argv[3] == "version" else root)
