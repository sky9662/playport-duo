# SPDX-License-Identifier: GPL-3.0-or-later
import io
import subprocess
import unittest
from build.meson_setup import configure


class MesonSetupTests(unittest.TestCase):
    def run_results(self, results):
        calls, pauses, output = [], [], io.StringIO()
        responses = iter(results)

        def runner(args, **kwargs):
            calls.append(args)
            code, body = next(responses)
            return subprocess.CompletedProcess(args, code, stdout=body)

        code = configure(["--cross-file", "cross.txt", "build"], runner=runner,
                         pause=pauses.append, output=output)
        return code, calls, pauses, output.getvalue()

    def test_clock_skew_reconfigures_and_preserves_original_diagnostic(self):
        code, calls, pauses, output = self.run_results([
            (1, "ERROR: Clock skew detected. File coredata.dat is in the future.\n"),
            (0, "Configuration completed.\n")])
        self.assertEqual(code, 0)
        self.assertEqual(calls[1], ["meson", "setup", "--reconfigure", "--cross-file", "cross.txt", "build"])
        self.assertEqual(pauses, [2])
        self.assertIn("ERROR: Clock skew detected.", output)
        self.assertIn("Configuration completed.", output)

    def test_a_compiler_failure_after_clock_skew_stops_immediately(self):
        code, calls, pauses, _ = self.run_results([
            (1, "ERROR: Clock skew detected.\n"), (7, "ERROR: Compiler cannot compile programs.\n")])
        self.assertEqual(code, 7)
        self.assertEqual(len(calls), 2)
        self.assertEqual(pauses, [2])

    def test_persistent_clock_skew_is_bounded_and_reported_as_failure(self):
        code, calls, pauses, _ = self.run_results([(1, "ERROR: Clock skew detected.\n")] * 3)
        self.assertEqual(code, 1)
        self.assertEqual(len(calls), 3)
        self.assertEqual(pauses, [2, 2])
        self.assertEqual(calls[-1].count("--reconfigure"), 1)

    def test_success_is_not_repeated(self):
        code, calls, pauses, _ = self.run_results([(0, "Configured.\n")])
        self.assertEqual((code, len(calls), pauses), (0, 1, []))
