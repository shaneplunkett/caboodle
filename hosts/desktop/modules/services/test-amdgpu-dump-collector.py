"""Fixture tests: no real GPU, root access, or sysfs writes required."""

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

source, executable = sys.argv[1:3]
spec = importlib.util.spec_from_file_location("collector", source)
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)
sys.argv = sys.argv[:1]


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.device = self.root / "devcd7"
        self.device.mkdir()
        failing = self.root / "pci-gpu"
        failing.mkdir()
        driver = self.root / "amdgpu"
        driver.mkdir()
        (failing / "driver").symlink_to(driver)
        (self.device / "failing_device").symlink_to(failing)
        self.payload = b"AMD GPU fixture\x00\xff\n" * 100000
        (self.device / "data").write_bytes(self.payload)
        self.output = self.root / "saved"

    def test_packaged_cli_preserves_bytes_and_permissions(self):
        result = subprocess.run(
            [executable, str(self.device), str(self.output), "--journal-delay", "0"],
            capture_output=True, text=True, check=True,
        )
        saved, = self.output.iterdir()
        self.assertEqual((saved / "amdgpu-devcoredump.data").read_bytes(), self.payload)
        self.assertEqual((self.device / "data").read_bytes(), self.payload)
        self.assertFalse((saved / "amdgpu-devcoredump.partial").exists())
        self.assertEqual(saved.stat().st_mode & 0o777, 0o750)
        self.assertEqual((saved / "amdgpu-devcoredump.data").stat().st_mode & 0o777, 0o640)
        self.assertEqual(json.loads((saved / "metadata.json").read_text())["device"], str(self.device))
        self.assertIn("Saved GPU dump:", result.stdout)

    def test_other_driver_ignored(self):
        link = self.device / "failing_device" / "driver"
        link.unlink()
        other = self.root / "iwlwifi"
        other.mkdir()
        link.symlink_to(other)
        self.assertIsNone(collector.capture(self.device, self.output))
        self.assertFalse(self.output.exists())

    def test_empty_dump_is_not_marked_complete(self):
        (self.device / "data").write_bytes(b"")
        with self.assertRaisesRegex(OSError, "Empty device dump"):
            collector.capture(self.device, self.output)
        saved, = self.output.iterdir()
        self.assertTrue((saved / "amdgpu-devcoredump.partial").exists())
        self.assertFalse((saved / "amdgpu-devcoredump.data").exists())

    def test_failed_read_retains_partial(self):
        def broken_copy(source, target, **kwargs):
            target.write(b"partial evidence")
            raise OSError("device expired")

        with patch.object(collector.shutil, "copyfileobj", side_effect=broken_copy):
            with self.assertRaisesRegex(OSError, "device expired"):
                collector.capture(self.device, self.output)
        saved, = self.output.iterdir()
        self.assertEqual((saved / "amdgpu-devcoredump.partial").read_bytes(), b"partial evidence")
        self.assertFalse((saved / "amdgpu-devcoredump.data").exists())

    def test_repeat_capture_never_overwrites(self):
        first = collector.capture(self.device, self.output)
        second = collector.capture(self.device, self.output)
        self.assertNotEqual(first, second)
        self.assertEqual((first / "amdgpu-devcoredump.data").read_bytes(), self.payload)

    def test_journal_timeout_keeps_completed_dump(self):
        saved = collector.capture(self.device, self.output)
        with patch.object(collector.subprocess, "run", side_effect=subprocess.TimeoutExpired("journalctl", 15)):
            collector.capture_journal(saved, 0)
        self.assertEqual((saved / "amdgpu-devcoredump.data").read_bytes(), self.payload)

    def test_invalid_device_name_rejected(self):
        with self.assertRaises(ValueError):
            collector.capture(self.root / "not-a-device", self.output)
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    os.umask(0o027)
    unittest.main()
