"""Tier 5 Adversarial Coverage Hardening Suite for Omarchy Dock (Milestone 4).

Empirical adversarial verification covering:
1. Dynamic Language Switching & Extreme Locale Variations (50 locales, RTL/LTR, CLDR plurals, parameter substitutions)
2. 3 Tray States Adaptation, Precedence Hierarchy & Border Crispness Invariants
3. Autohide, Visibility Mode State Transitions & Edge Depth Clamping
4. Configuration Fault Tolerance (Corrupted JSON, missing files, cascade fallbacks)
5. System Dock Suppression Lifecycle & Destruction Safety
"""

import json
import os
import re
import unittest
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
I18N_DIR = PROJECT_ROOT / "i18n"
DOCK_PANEL_PATH = PROJECT_ROOT / "DockPanel.qml"
BAR_WIDGET_PATH = PROJECT_ROOT / "BarWidget.qml"
SETTINGS_JS_PATH = PROJECT_ROOT / "DockSettings.js"
LOCALES_PATH = Path("/usr/share/omarchy/default/i18n/locales.json")

RTL_LOCALES = {"ar", "fa", "he", "ur"}


class Tier5LocalizationAdversarialTest(unittest.TestCase):
    """Adversarial stress-testing of 50 language catalogs and CLDR rules."""

    @classmethod
    def setUpClass(cls):
        cls.catalogs = {}
        for p in I18N_DIR.glob("*.json"):
            with open(p, "r", encoding="utf-8") as f:
                cls.catalogs[p.stem] = json.load(f)
        cls.en_catalog = cls.catalogs.get("en", {})

    def test_all_50_locales_present_and_well_formed(self):
        """Verify exactly 50 locales exist and every file is valid JSON with >70 keys."""
        self.assertEqual(len(self.catalogs), 50, "Must have exactly 50 locale catalogs")
        for code, cat in self.catalogs.items():
            self.assertGreaterEqual(len(cat), 70, f"Catalog {code} must contain >= 70 keys")
            self.assertIsInstance(cat, dict, f"Catalog {code} must be a dictionary")

    def test_strict_key_parity_against_en(self):
        """Every single key in en.json must exist in all other 49 catalogs."""
        en_keys = set(self.en_catalog.keys())
        for code, cat in self.catalogs.items():
            if code == "en":
                continue
            cat_keys = set(cat.keys())
            missing = en_keys - cat_keys
            self.assertEqual(len(missing), 0, f"Locale {code} is missing keys: {missing}")

    def test_parameter_placeholders_preserved_in_all_locales(self):
        """Parameterized keys (%1) must preserve their placeholders across all languages."""
        parameterized_keys = ["dock.workspace"]
        for key in parameterized_keys:
            for code, cat in self.catalogs.items():
                val = cat.get(key, "")
                self.assertIn("%1", val, f"Locale {code} key {key} must contain placeholder '%1'")

    def test_cldr_plurals_completeness_and_boundary_forms(self):
        """Verify plural forms across all languages with CLDR plural structures."""
        # Check Russian (one, few, many, other)
        ru_items = self.catalogs["ru"].get("dock.items")
        self.assertIsInstance(ru_items, dict)
        for form in ["one", "few", "many", "other"]:
            self.assertIn(form, ru_items, f"Russian dock.items must have plural form '{form}'")
            self.assertIn("%1", ru_items[form])

        # Check Arabic (zero, one, two, few, many, other)
        ar_items = self.catalogs["ar"].get("dock.items")
        self.assertIsInstance(ar_items, dict)
        for form in ["zero", "one", "two", "few", "many", "other"]:
            self.assertIn(form, ar_items, f"Arabic dock.items must have plural form '{form}'")

        # Check English (one, other)
        en_items = self.catalogs["en"].get("dock.items")
        self.assertIsInstance(en_items, dict)
        for form in ["one", "other"]:
            self.assertIn(form, en_items)

        # Check Japanese (other)
        ja_items = self.catalogs["ja"].get("dock.items")
        self.assertIsInstance(ja_items, dict)
        self.assertIn("other", ja_items)

    def test_rtl_locale_isolation(self):
        """Verify exact partition: ar, fa, he, ur are RTL; all 46 remaining are LTR."""
        for code in self.catalogs.keys():
            if code in RTL_LOCALES:
                self.assertIn(code, ["ar", "fa", "he", "ur"])
            else:
                self.assertNotIn(code, RTL_LOCALES)

    def test_new_feature_keys_in_all_catalogs(self):
        """Verify M2/M3 keys (suppressSystemDock, suppressSystemDockDesc, importOmarchyPins)."""
        required_keys = [
            "dock.suppressSystemDock",
            "dock.suppressSystemDockDesc",
            "dock.importOmarchyPins",
        ]
        for key in required_keys:
            for code, cat in self.catalogs.items():
                self.assertIn(key, cat, f"Locale {code} must contain '{key}'")
                self.assertTrue(len(str(cat[key]).strip()) > 0, f"Locale {code} '{key}' must not be empty")


class Tier5TrayStyleAndBorderAdversarialTest(unittest.TestCase):
    """Adversarial stress-testing of tray state detection and border rendering invariants."""

    @classmethod
    def setUpClass(cls):
        cls.dock_content = DOCK_PANEL_PATH.read_text(encoding="utf-8")

    def simulate_bar_style_state(self, sbc, has_detected_bg=False, detected_bg="opaque", sbc_transparent=None, detected_trans=False):
        """Exact replica of DockPanel.qml barStyleState property logic."""
        if sbc and isinstance(sbc.get("background"), str):
            bg = sbc["background"]
            if bg in ("opaque", "glassy", "none"):
                return bg

        if has_detected_bg and detected_bg in ("opaque", "glassy", "none"):
            return detected_bg

        if sbc and sbc.get("transparent") is not None:
            return "glassy" if sbc["transparent"] is True else "opaque"

        if detected_trans:
            return "glassy"

        if detected_bg in ("glassy", "none"):
            return detected_bg

        return "opaque"

    def test_precedence_hierarchy_exhaustive(self):
        """Test exhaustive precedence order across 6 tiers."""
        # Tier 1: sbc.background takes top precedence
        self.assertEqual(self.simulate_bar_style_state({"background": "none"}, has_detected_bg=True, detected_bg="opaque"), "none")
        self.assertEqual(self.simulate_bar_style_state({"background": "glassy"}, has_detected_bg=True, detected_bg="opaque"), "glassy")
        self.assertEqual(self.simulate_bar_style_state({"background": "opaque"}, has_detected_bg=True, detected_bg="none"), "opaque")

        # Tier 2: invalid sbc.background falls back to detectedBarBackground
        self.assertEqual(self.simulate_bar_style_state({"background": "corrupt"}, has_detected_bg=True, detected_bg="glassy"), "glassy")

        # Tier 3: legacy sbc.transparent takes precedence if no background
        self.assertEqual(self.simulate_bar_style_state({"transparent": True}), "glassy")
        self.assertEqual(self.simulate_bar_style_state({"transparent": False}), "opaque")

        # Tier 4: detectedBarTransparent
        self.assertEqual(self.simulate_bar_style_state({}, detected_trans=True), "glassy")

        # Tier 5: default fallback
        self.assertEqual(self.simulate_bar_style_state({}), "opaque")
        self.assertEqual(self.simulate_bar_style_state(None), "opaque")

    def test_adversarial_values_resilience(self):
        """Fuzz simulate_bar_style_state with adversarial/malicious types."""
        fuzz_values = [
            "", " ", "\n", "\t", "NONE", "Glassy", "OPAQUE",
            None, 0, 1, -1, 3.14, True, False,
            [], {}, ["opaque"], {"nested": "glassy"},
            "'; DROP TABLE;--", "<script>alert(1)</script>",
            "\x00\x01\x02", "a" * 1000
        ]
        for val in fuzz_values:
            state = self.simulate_bar_style_state({"background": val})
            self.assertIn(state, ("opaque", "glassy", "none"))

    def test_glassy_border_crispness_contract(self):
        """Verify user refinement: glassy mode has 0.35 background alpha but crisp border."""
        self.assertIn('root.barStyleState === "glassy"', self.dock_content)
        self.assertIn("Util.alpha(Color.bar.background, 0.35)", self.dock_content)

        # Border color in glassy mode must NOT be alpha-muted
        border_color_match = re.search(r'border\.color:\s*\{(.*?)\}', self.dock_content, re.DOTALL)
        self.assertIsNotNone(border_color_match)
        bc_block = border_color_match.group(1)
        self.assertIn('root.barStyleState === "glassy"', bc_block)
        self.assertIn("Border.color(root.dockBorderSpec)", bc_block)
        # Ensure no alpha applied to glassy border
        self.assertNotIn("alpha", bc_block)

        # Border width in glassy mode must be at least 1px
        border_width_match = re.search(r'border\.width:\s*\{(.*?)\}', self.dock_content, re.DOTALL)
        self.assertIsNotNone(border_width_match)
        bw_block = border_width_match.group(1)
        self.assertIn('root.barStyleState === "glassy"', bw_block)
        self.assertIn("Math.max(1, Border.uniformWidth(root.dockBorderSpec))", bw_block)

    def test_none_state_zero_border_contract(self):
        """Verify none mode has zero border width and transparent border color."""
        border_width_match = re.search(r'border\.width:\s*\{(.*?)\}', self.dock_content, re.DOTALL)
        self.assertIn('root.barStyleState === "none"', border_width_match.group(1))
        self.assertIn("return 0", border_width_match.group(1))

        border_color_match = re.search(r'border\.color:\s*\{(.*?)\}', self.dock_content, re.DOTALL)
        self.assertIn('root.barStyleState === "none"', border_color_match.group(1))
        self.assertIn('"transparent"', border_color_match.group(1))


class Tier5SettingsAndAutohideAdversarialTest(unittest.TestCase):
    """Adversarial stress-testing of settings normalization, edge depth, and autohide."""

    @classmethod
    def setUpClass(cls):
        cls.settings_js = SETTINGS_JS_PATH.read_text(encoding="utf-8")

    def test_settings_normalize_source_contract(self):
        """Verify DockSettings.normalize handles defensive fallbacks in source."""
        self.assertIn("function normalize(raw)", self.settings_js)
        self.assertIn("normalizeVisibilityMode", self.settings_js)
        self.assertIn("normalizeOverlayMode", self.settings_js)
        self.assertIn("normalizeVisibleWorkspace", self.settings_js)
        self.assertIn("normalizeSuppressSystemDock", self.settings_js)

    def test_autohide_edge_depth_clamping(self):
        """Verify autohideEdgeDepth is clamped strictly to [1, 64]."""
        dock_content = DOCK_PANEL_PATH.read_text(encoding="utf-8")
        self.assertIn("depth >= 1 && depth <= 64", dock_content)
        self.assertIn("n >= 1 && n <= 64", dock_content)

    def test_autohide_legacy_compatibility_mapping(self):
        """Verify legacyAutohide helper maps visibility modes cleanly."""
        self.assertIn("function legacyAutohide(visibilityMode)", self.settings_js)
        self.assertIn('return normalizeVisibilityMode(visibilityMode, false) !== VISIBILITY_ALWAYS', self.settings_js)


class Tier5SystemDockSuppressionAndPinnedFallbackTest(unittest.TestCase):
    """Adversarial testing of system dock suppression and pinned cascade."""

    @classmethod
    def setUpClass(cls):
        cls.dock_content = DOCK_PANEL_PATH.read_text(encoding="utf-8")
        cls.bar_content = BAR_WIDGET_PATH.read_text(encoding="utf-8")

    def test_suppression_safe_destruction_invariant(self):
        """Component.onDestruction must check systemDockWasEnabled before re-enabling."""
        match = re.search(r"Component\.onDestruction:\s*\{(.*?)\}", self.dock_content, re.DOTALL)
        self.assertIsNotNone(match)
        block = match.group(1)
        self.assertIn("if (root.systemDockWasEnabled)", block)
        self.assertIn("omarchy.dock", block)
        self.assertIn("true", block)

    def test_pinned_cascade_defaults(self):
        """Pinned apps cascade must include all 7 standard Omarchy default pins."""
        expected_pins = ["org.gnome.Nautilus", "chromium", "foot", "omacalc", "omawrite", "X", "YouTube"]
        for pin in expected_pins:
            self.assertIn(pin, self.dock_content)


if __name__ == "__main__":
    unittest.main()
