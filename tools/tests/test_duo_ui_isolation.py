# SPDX-License-Identifier: GPL-3.0-or-later
"""Preserve standard layouts and Duo adaptations independently.

Source golden regions complement executable hardware-policy tests; these
checks do not substitute for UIKit screenshots or real-device validation.
"""
import hashlib
import json
from pathlib import Path
import re
import unittest

REPO = Path(__file__).resolve().parents[2]


def body_at(source, start):
    begin = source.index("{", start)
    depth, end = 1, begin + 1
    while depth:
        if source[end] == "{": depth += 1
        elif source[end] == "}": depth -= 1
        end += 1
    return source[begin + 1:end - 1], end


def digest(source):
    canonical = re.sub(r"\s+", "", re.sub(r"//[^\n]*", "", source))
    return hashlib.sha256(canonical.encode()).hexdigest()


class DuoUIIsolation(unittest.TestCase):
    def test_standard_and_duo_layout_regions_remain_separate_and_unchanged(self):
        regions = json.loads((REPO / "tools/tests/fixtures/duo-ui-layout-regions.json").read_text())
        for name, region in regions.items():
            with self.subTest(region=name):
                source = (REPO / region["path"]).read_text()
                start = source.index("if SceneDisplay.usesDuoLayout {", source.index(region["after"]))
                duo, end = body_at(source, start)
                self.assertRegex(source[end:], r"^\s*else\s*\{")
                standard, _ = body_at(source, end)
                self.assertEqual(digest(standard), region["standard_sha256"])
                self.assertEqual(digest(duo), region["duo_sha256"])

    def test_shell_grid_and_safe_area_changes_are_gated(self):
        shell = (REPO / "app/Sources/S1Probe/UI/AppShell.swift").read_text()
        library = (REPO / "app/Sources/S1Probe/UI/LibraryView.swift").read_text()
        self.assertEqual(shell.count(".padding(.horizontal, SceneDisplay.usesDuoLayout ? 24 : 0)"), 2)
        self.assertIn(".padding(.horizontal, SceneDisplay.usesDuoLayout ? 24 : 0)", library)
        self.assertIn("SceneDisplay.uiProfile.libraryColumns", library)
        safe = (REPO / "app/Sources/S1Probe/UI/Pad/PadTheme.swift").read_text()
        self.assertIn("SceneDisplay.usesDuoLayout ? window?.gameSafeInsets : window?.safeAreaInsets", safe)
        controls = (REPO / "app/Sources/S1Probe/UI/TouchControlsView.swift").read_text()
        self.assertIn("if #available(iOS 27.1, *), SceneDisplay.usesDuoLayout", controls)
