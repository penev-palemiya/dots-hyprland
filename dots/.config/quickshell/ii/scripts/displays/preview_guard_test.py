#!/usr/bin/env python3
"""Filesystem-only tests for preview_guard persistence; no Hyprland needed."""
import importlib.util
import pathlib
import tempfile
import unittest

SOURCE = pathlib.Path(__file__).with_name("preview_guard.py")
SPEC = importlib.util.spec_from_file_location("preview_guard", SOURCE)
guard = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(guard)


def rule(output, enabled=True):
    return {"output": output, "enabled": enabled, "mode": {"width": 1920, "height": 1080, "refreshRate": 60}, "x": 0, "y": 0, "scale": 1, "transform": 0, "mirrorOf": ""}


class PersistenceTests(unittest.TestCase):
    def test_create_replace_preserve_and_noop(self):
        manual = "-- manual content\nlocal x = 1\n"
        first = guard.merged_persistent_text(manual, [rule("eDP-1")])
        self.assertTrue(first.startswith(manual))
        self.assertEqual(first, guard.merged_persistent_text(first, [rule("eDP-1")]))
        second = guard.merged_persistent_text(first, [rule("DP-1")])
        self.assertTrue(second.startswith(manual))
        self.assertIn('output = "eDP-1"', second)
        self.assertIn('output = "DP-1"', second)

    def test_disabled_mirror_escape_and_remove(self):
        text = guard.merged_persistent_text("", [rule('DP-"quoted'), rule("HDMI-A-1", False), {**rule("DP-2"), "mirrorOf": "DP-1"}])
        self.assertIn('output = "DP-\\"quoted"', text)
        self.assertIn("disabled = true", text)
        self.assertIn('mirror = "DP-1"', text)
        self.assertNotIn("HDMI-A-1", guard.merged_persistent_text(text, [], "HDMI-A-1"))

    def test_atomic_write_keeps_old_file_on_prepare_failure(self):
        with tempfile.TemporaryDirectory() as temp:
            path = pathlib.Path(temp) / "monitors.lua"
            guard.write_atomic(path, "old\n")
            self.assertEqual(path.read_text(), "old\n")
            guard.write_atomic(path, "new\n")
            self.assertEqual(path.read_text(), "new\n")


if __name__ == "__main__":
    unittest.main()
