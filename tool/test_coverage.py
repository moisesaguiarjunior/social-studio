"""Exercise report publication without depending on a Flutter coverage run."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class CoverageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        source = Path(__file__).resolve().parent
        (self.root / "tool/hooks").mkdir(parents=True)
        shutil.copy(source / "coverage.sh", self.root / "tool/coverage.sh")
        shutil.copy(source / "hooks/lib.sh", self.root / "tool/hooks/lib.sh")
        self.package = self.root / "flutter/social_studio"
        self.package.mkdir(parents=True)
        self.report = self.root / "coverage/lcov.info"
        self.report.parent.mkdir()
        self.stub = self.root / "stub"
        self.stub.mkdir()
        flutter = self.stub / "flutter"
        flutter.write_text("""#!/usr/bin/env python3
import os, pathlib, sys
if os.environ.get('GIT_DIR'):
    sys.exit(9)
if sys.argv[1] == 'pub':
    sys.exit(0)
assert sys.argv[1:] == ['test', '--coverage']
report = pathlib.Path('coverage/lcov.info')
report.parent.mkdir(exist_ok=True)
if os.environ['REPORT'] != 'missing':
    report.write_text(os.environ['REPORT'])
sys.exit(int(os.environ.get('TEST_EXIT', '0')))
""")
        flutter.chmod(0o755)

    def run_coverage(self, report, test_exit=0):
        return subprocess.run(
            ["bash", str(self.root / "tool/coverage.sh")],
            cwd=self.temp.name,
            env={
                **os.environ,
                "PATH": str(self.stub) + os.pathsep + os.environ["PATH"],
                "REPORT": report,
                "TEST_EXIT": str(test_exit),
                "GIT_DIR": "must-not-reach-the-sdk",
            },
            capture_output=True,
            text=True,
            check=False,
        )

    def test_prefixes_sources_and_preserves_counts(self):
        result = self.run_coverage("SF:lib/story.dart\nDA:1,2\nend_of_record\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.report.read_text(),
            "SF:flutter/social_studio/lib/story.dart\nDA:1,2\nend_of_record\n",
        )

    def test_failed_tests_cannot_publish_stale_coverage(self):
        self.report.write_text("stale report")
        result = self.run_coverage("SF:lib/story.dart\nDA:1,2\n", test_exit=17)
        self.assertEqual(result.returncode, 17, result.stderr)
        self.assertFalse(self.report.exists())

    def test_missing_empty_or_non_library_report_is_rejected(self):
        for report in [
            "missing", "", "SF:lib/story.dart\nend_of_record\n",
            "SF:/private/source.dart\nDA:1,2\n",
            "SF:lib/story.dart\nDA:1,2\nSF:/private/source.dart\nDA:2,1\n",
        ]:
            with self.subTest(report=report):
                self.report.write_text("stale report")
                result = self.run_coverage(report)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn("coverage:", result.stderr)
                self.assertFalse(self.report.exists())


if __name__ == "__main__":
    unittest.main()
