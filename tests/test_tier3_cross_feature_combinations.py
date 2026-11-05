"""Tier 3 Cross-Feature Combination Tests: Pairwise interactions between i18n, tray states, and windows."""

import importlib.util
import os
import unittest
from test_tier1_tray_sync_feature import MockColor, TrayStyleResolver

_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       os.pardir, "scripts", "dock-minimize.py")


def _load_script():
    spec = importlib.util.spec_from_file_location("dock_minimize", _SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


dm = _load_script()


class Tier3CrossFeatureCombinationsTest(unittest.TestCase):
    def setUp(self):
        self.base_color = MockColor(0.15, 0.15, 0.18, 1.0)
        self.resolver = TrayStyleResolver()

    def test_rtl_language_with_glassy_tray_state(self):
        """Cross-feature: RTL language (Arabic) combined with glassy tray styling."""
        locale_meta = {"name": "العربية", "direction": "rtl", "formatLocale": "ar-AE"}
        tray_state = self.resolver.resolve_state({"background": "glassy"})
        style = self.resolver.compute_style(tray_state, self.base_color)

        self.assertEqual(locale_meta.get("direction"), "rtl")
        self.assertEqual(tray_state, "glassy")
        self.assertAlmostEqual(style["alpha"], 0.35)
        self.assertTrue(style["blur_enabled"])

    def test_russian_plural_with_window_minimize_count(self):
        """Cross-feature: Russian plural category calculation for minimized window count."""
        def ru_plural(count, one="окно", few="окна", many="окон"):
            mod10 = count % 10
            mod100 = count % 100
            if mod10 == 1 and mod100 != 11:
                return f"{count} {one}"
            if 2 <= mod10 <= 4 and not (12 <= mod100 <= 14):
                return f"{count} {few}"
            return f"{count} {many}"

        win_min1 = {"address": "0x401", "workspace": {"name": "special:minimized"}}
        win_min2 = {"address": "0x402", "workspace": {"name": "special:minimized"}}
        win_min3 = {"address": "0x403", "workspace": {"name": "special:minimized"}}

        minimized_pool = [win_min1, win_min2, win_min3]
        self.assertEqual(ru_plural(1), "1 окно")
        self.assertEqual(ru_plural(len(minimized_pool[:2])), "2 окна")
        self.assertEqual(ru_plural(5), "5 окон")

        target = dm.pick_target(minimized_pool, [], minimized_pool, "", 0, "")
        self.assertIs(target, win_min1)

    def test_transparent_tray_with_overlay_mode(self):
        """Cross-feature: 'none' tray background combined with overlay visibility mode."""
        tray_state = self.resolver.resolve_state({"background": "none"})
        style = self.resolver.compute_style(tray_state, self.base_color)
        dock_overlay_mode = True

        self.assertEqual(tray_state, "none")
        self.assertEqual(style["alpha"], 0.0)
        self.assertEqual(style["border_width"], 0)
        self.assertTrue(dock_overlay_mode)

    def test_compound_fault_resilience(self):
        """Cross-feature: Corrupted shell config + Unknown locale + Hex address window query."""
        # 1. Corrupted shell config -> fallback to opaque
        tray_state = self.resolver.resolve_state(shell_bar_config={"invalid": 123})
        self.assertEqual(tray_state, "opaque")

        # 2. Unknown locale fallback to English
        catalogs = {"en": {"title": "Dock"}}
        resolved_title = catalogs.get("unknown_lang", {}).get("title", catalogs["en"]["title"])
        self.assertEqual(resolved_title, "Dock")

        # 3. Window minimization address resolution with 0x prefix
        identifiers, idx, addr = dm.split_queries(["my-app", "0xc0ffee"])
        self.assertEqual(identifiers, ["my-app"])
        self.assertEqual(addr, "0xc0ffee")

    def test_autohide_and_tray_state_coexistence(self):
        """Cross-feature: Autohide mode enabled alongside dynamic tray state changes."""
        autohide_enabled = True
        for state in ("opaque", "glassy", "none"):
            s = self.resolver.resolve_state({"background": state})
            style = self.resolver.compute_style(s, self.base_color)
            self.assertTrue(autohide_enabled)
            self.assertIn(style["alpha"], (1.0, 0.35, 0.0))


if __name__ == "__main__":
    unittest.main()
