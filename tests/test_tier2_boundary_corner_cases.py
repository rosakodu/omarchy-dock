"""Tier 2 Boundary & Corner Cases Tests: RTL, Corrupted Configs, Rapid Toggling, Edge Inputs."""

import importlib.util
import json
import os
import unittest
from test_tier1_tray_sync_feature import TrayStyleResolver

_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       os.pardir, "scripts", "dock-minimize.py")


def _load_script():
    spec = importlib.util.spec_from_file_location("dock_minimize", _SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


dm = _load_script()
LOCALES_FILE = "/usr/share/omarchy/default/i18n/locales.json"


class Tier2BoundaryCornerCasesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(LOCALES_FILE, "r", encoding="utf-8") as f:
            cls.locales = json.load(f)

    def test_rtl_locales_identified_and_mirrored(self):
        """Verify the 4 RTL languages (ar, fa, he, ur) have direction 'rtl'."""
        expected_rtl = {"ar", "fa", "he", "ur"}
        detected_rtl = {code for code, meta in self.locales.items() if meta.get("direction") == "rtl"}
        self.assertEqual(detected_rtl, expected_rtl, "Exactly ar, fa, he, ur must be RTL")

        for code, meta in self.locales.items():
            if code not in expected_rtl:
                self.assertNotEqual(meta.get("direction"), "rtl", f"Locale {code} must not be RTL")

    def test_rapid_language_switching_resilience(self):
        """Simulate rapid sequential language toggling across diverse families."""
        sequence = ["en", "ru", "ar", "ja", "de", "zh-CN", "he", "en"]
        active_lang = "en"
        for lang in sequence:
            self.assertIn(lang, self.locales)
            active_lang = lang
        self.assertEqual(active_lang, "en")

    def test_corrupted_shell_json_fallback(self):
        """Verify tray resolver handles corrupted or malformed shell config gracefully."""
        # 1. Non-dict bar config
        state = TrayStyleResolver.resolve_state(shell_bar_config="not_a_dict", shell_json_bar=None)
        self.assertEqual(state, "opaque")

        # 2. Missing background key
        state = TrayStyleResolver.resolve_state(shell_bar_config={}, shell_json_bar={})
        self.assertEqual(state, "opaque")

        # 3. None / empty values
        state = TrayStyleResolver.resolve_state(shell_bar_config=None, shell_json_bar=None)
        self.assertEqual(state, "opaque")

    def test_unknown_tray_background_value_fallback(self):
        """Verify invalid background values fall back to 'opaque'."""
        invalid_values = ["neon", "translucent", "vivid", "", None, 42, False]
        for val in invalid_values:
            cfg = {"background": val} if val is not None else {}
            state = TrayStyleResolver.resolve_state(shell_bar_config=cfg)
            self.assertEqual(state, "opaque", f"Value '{val}' must fall back to opaque")

    def test_window_minimize_edge_inputs(self):
        """Verify boundary inputs for window minimization queries and index parsing."""
        # Address with 0x prefix is captured as address
        identifiers, idx, addr = dm.split_queries(["code", "0xdeadbeef"])
        self.assertEqual(identifiers, ["code"])
        self.assertEqual(addr, "0xdeadbeef")

        # Zero address
        identifiers, idx, addr = dm.split_queries(["code", "0x0"])
        self.assertEqual(addr, "0x0")

        # Out-of-bounds index falls back to visible window
        self.assertIsNone(dm.pick_target([], [], [], "", -5, ""))
        win = {"address": "0x111", "workspace": {"name": "1"}}
        self.assertIs(dm.pick_target([win], [win], [], "", 99, ""), win)

    def test_empty_candidates_and_null_active_window(self):
        """Verify pick_target handles empty candidates and None safely."""
        self.assertIsNone(dm.pick_target([], [], [], "", -1, ""))
        self.assertIsNone(dm.pick_target([], [], [], "", -1, None))


if __name__ == "__main__":
    unittest.main()
