#!/usr/bin/env python3
"""Unit tests for Ambxst[+] Python scripts."""

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock

# Add scripts directory to path
SCRIPTS_DIR = Path(__file__).parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))


class TestKeystore(unittest.TestCase):
    """Tests for keystore.py encryption/decryption."""

    @classmethod
    def setUpClass(cls):
        """Import keystore module."""
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "keystore", SCRIPTS_DIR / "keystore.py"
        )
        cls.keystore = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.keystore)

    def test_encrypt_decrypt_roundtrip(self):
        """Encrypted text should decrypt back to original."""
        machine_key = b"test-machine-id-1234"
        original = "sk-test-1234567890abcdef"

        encrypted = self.keystore.encrypt(original, machine_key)
        decrypted = self.keystore.decrypt(encrypted, machine_key)

        self.assertEqual(decrypted, original)

    def test_encrypt_produces_different_output(self):
        """Each encryption should produce different output (random salt)."""
        machine_key = b"test-machine-id-1234"
        original = "sk-test-1234567890abcdef"

        enc1 = self.keystore.encrypt(original, machine_key)
        enc2 = self.keystore.encrypt(original, machine_key)

        self.assertNotEqual(enc1, enc2)

    def test_decrypt_invalid_returns_empty(self):
        """Decryption of invalid data should return empty string."""
        machine_key = b"test-machine-id-1234"
        result = self.keystore.decrypt("invalid-base64-data", machine_key)
        self.assertEqual(result, "")

    def test_get_machine_id_fallback(self):
        """get_machine_id should return bytes."""
        result = self.keystore.get_machine_id()
        self.assertIsInstance(result, bytes)
        self.assertTrue(len(result) > 0)


class TestSystemMonitor(unittest.TestCase):
    """Tests for system_monitor.py."""

    @classmethod
    def setUpClass(cls):
        """Import system_monitor module."""
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "system_monitor", SCRIPTS_DIR / "system_monitor.py"
        )
        cls.monitor = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.monitor)

    def test_system_monitor_initialization(self):
        """SystemMonitor should initialize with default values."""
        monitor = self.monitor.SystemMonitor(disks=["/"])
        self.assertEqual(monitor.prev_cpu_total, 0)
        self.assertEqual(monitor.prev_cpu_idle, 0)
        self.assertEqual(monitor.monitored_disks, ["/"])

    def test_cpu_usage_in_range(self):
        """CPU usage should be between 0 and 100."""
        monitor = self.monitor.SystemMonitor(disks=["/"])
        # First call returns 0 (no previous data)
        usage = monitor.get_cpu()
        self.assertGreaterEqual(usage, 0.0)
        self.assertLessEqual(usage, 100.0)

    def test_memory_in_range(self):
        """Memory usage should be between 0 and 100."""
        monitor = self.monitor.SystemMonitor(disks=["/"])
        usage, total, used, available = monitor.get_mem()
        self.assertGreaterEqual(usage, 0.0)
        self.assertLessEqual(usage, 100.0)

    def test_disk_usage_returns_dict(self):
        """Disk usage should return a dictionary."""
        monitor = self.monitor.SystemMonitor(disks=["/"])
        usage = monitor.get_disk_usage(["/"])
        self.assertIsInstance(usage, dict)
        self.assertIn("/", usage)


class TestColorpicker(unittest.TestCase):
    """Tests for colorpicker.py."""

    @classmethod
    def setUpClass(cls):
        """Import colorpicker module."""
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "colorpicker", SCRIPTS_DIR / "colorpicker.py"
        )
        cls.colorpicker = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.colorpicker)

    def test_cmd_function_exists(self):
        """cmd function should be callable."""
        self.assertTrue(callable(self.colorpicker.cmd))

    def test_main_function_exists(self):
        """main function should be callable."""
        self.assertTrue(callable(self.colorpicker.main))


if __name__ == "__main__":
    unittest.main(verbosity=2)
