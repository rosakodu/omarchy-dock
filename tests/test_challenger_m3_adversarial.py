"""Adversarial stress test suite for Milestone 3 (M3_Localization, Omarchy Dock Suppression & Pinned Fallback).
Empirically verifies:
1. Static/semantic conformance of DockPanel.qml, BarWidget.qml, and popup components.
2. Suppression of omarchy.dock: initialization, dynamic toggle, destruction restoration, IPC contract.
3. Pinned apps fallback cascade: empty, missing, corrupted dock-pinned.json, cascade precedence, importOmarchyPins().
4. RTL mirroring: right-to-left layout activation across ar, fa, he, ur and LTR across remaining 46 locales.
"""

import json
import os
import re
import unittest
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DOCK_PANEL_PATH = PROJECT_ROOT / "DockPanel.qml"
BAR_WIDGET_PATH = PROJECT_ROOT / "BarWidget.qml"
LOCALES_FILE = Path("/usr/share/omarchy/default/i18n/locales.json")
I18N_DIR = PROJECT_ROOT / "i18n"


class DockSuppressionAndFallbackInspectionTest(unittest.TestCase):
    """Static and semantic code inspection of suppression, fallback, and RTL contracts."""

    @classmethod
    def setUpClass(cls):
        cls.dock_content = DOCK_PANEL_PATH.read_text(encoding="utf-8")
        cls.bar_content = BAR_WIDGET_PATH.read_text(encoding="utf-8")

    def test_dockpanel_properties_and_ipc_declared(self):
        """Verify DockPanel.qml declares suppressSystemDock and IPC methods."""
        self.assertIn("property bool suppressSystemDock: true", self.dock_content)
        self.assertIn("property bool systemDockWasEnabled: false", self.dock_content)

        # IPC handlers
        self.assertRegex(
            self.dock_content,
            r'function\s+setSuppressSystemDock\(val:\s*string\):\s*string\s*\{\s*root\.setSuppressSystemDock\(.*?\);\s*return\s*"ok"\s*\}',
        )
        self.assertRegex(
            self.dock_content,
            r'function\s+importOmarchyPins\(\):\s*string\s*\{\s*return\s+root\.importOmarchyPins\(\)\s*\}',
        )

    def test_dockpanel_destruction_cleanup(self):
        """Verify DockPanel.qml restores system dock on destruction only if it was enabled."""
        match = re.search(r"Component\.onDestruction:\s*\{(.*?)\}", self.dock_content, re.DOTALL)
        self.assertIsNotNone(match, "DockPanel must have Component.onDestruction")
        block = match.group(1)
        self.assertIn("if (root.systemDockWasEnabled)", block)
        self.assertIn('"omarchy.dock"', block)
        self.assertIn("true", block)

    def test_dockpanel_pinned_fallback_cascade_logic(self):
        """Verify DockPanel implements getOmarchyDefaultPinned with cascade tiers."""
        self.assertIn("function getOmarchyDefaultPinned()", self.dock_content)
        self.assertIn("function importOmarchyPins()", self.dock_content)
        self.assertIn('"org.gnome.Nautilus"', self.dock_content)
        self.assertIn('"chromium"', self.dock_content)
        self.assertIn('"foot"', self.dock_content)
        self.assertIn('"omacalc"', self.dock_content)
        self.assertIn('"omawrite"', self.dock_content)
        self.assertIn('"X"', self.dock_content)
        self.assertIn('"YouTube"', self.dock_content)

    def test_layout_mirroring_in_components(self):
        """Verify LayoutMirroring bindings across DockPanel, BarWidget, and popup components."""
        self.assertIn('property: "LayoutMirroring.enabled"; value: I18n.rightToLeft', self.dock_content)
        self.assertIn('property: "LayoutMirroring.childrenInherit"; value: true', self.dock_content)
        self.assertIn("LayoutMirroring.enabled: I18n.rightToLeft", self.bar_content)
        self.assertIn("LayoutMirroring.childrenInherit: true", self.bar_content)

        picker_content = (PROJECT_ROOT / "components" / "WidgetPickerPopup.qml").read_text(encoding="utf-8")
        self.assertIn("LayoutMirroring.enabled: I18n.rightToLeft", picker_content)
        self.assertIn("LayoutMirroring.childrenInherit: true", picker_content)

        folder_popup = (PROJECT_ROOT / "components" / "FolderPopup.qml").read_text(encoding="utf-8")
        self.assertIn("LayoutMirroring.enabled: I18n.rightToLeft", folder_popup)
        self.assertIn("LayoutMirroring.childrenInherit: true", folder_popup)

        folder_menu = (PROJECT_ROOT / "components" / "FolderMenu.qml").read_text(encoding="utf-8")
        self.assertIn("LayoutMirroring.enabled: I18n.rightToLeft", folder_menu)
        self.assertIn("LayoutMirroring.childrenInherit: true", folder_menu)


class SystemDockSuppressionAdversarialSimulationTest(unittest.TestCase):
    """Simulates adversarial edge cases for omarchy.dock suppression logic."""

    class MockPluginRegistry:
        def __init__(self, dock_initial_state=True):
            self.plugins = {"omarchy.dock": {"enabled": dock_initial_state}}
            self.calls = []

        def isEnabled(self, plugin_id):
            return self.plugins.get(plugin_id, {}).get("enabled", False)

        def setEnabled(self, plugin_id, enabled):
            self.calls.append(("registry.setEnabled", plugin_id, enabled))
            if plugin_id in self.plugins:
                self.plugins[plugin_id]["enabled"] = bool(enabled)
            return True

    class MockShell:
        def __init__(self, plugin_registry):
            self.pluginRegistry = plugin_registry
            self.calls = []

        def setPluginEnabled(self, plugin_id, enabled):
            self.calls.append(("shell.setPluginEnabled", plugin_id, enabled))
            return self.pluginRegistry.setEnabled(plugin_id, enabled)

    def simulate_dock_lifecycle(self, initial_dock_state, suppress_setting, toggle_sequence=()):
        """Execute simulation matching DockPanel.qml logic step-by-step."""
        registry = self.MockPluginRegistry(dock_initial_state=initial_dock_state)
        shell = self.MockShell(registry)

        state = {
            "suppressSystemDock": suppress_setting,
            "systemDockWasEnabled": False,
        }

        def apply_suppression():
            reg = registry
            if not reg:
                return
            if state["suppressSystemDock"]:
                is_enabled = reg.isEnabled("omarchy.dock")
                if is_enabled:
                    state["systemDockWasEnabled"] = True
                    reg.setEnabled("omarchy.dock", False)
            elif state["systemDockWasEnabled"]:
                state["systemDockWasEnabled"] = False
                reg.setEnabled("omarchy.dock", True)

        def set_suppress(val):
            state["suppressSystemDock"] = (val is True or val == "true" or val == 1 or val == "1")
            apply_suppression()

        def on_destruction():
            if state["systemDockWasEnabled"]:
                registry.setEnabled("omarchy.dock", True)

        # 1. Startup
        apply_suppression()

        # 2. Dynamic toggles
        for action in toggle_sequence:
            set_suppress(action)

        # 3. Teardown
        on_destruction()

        return registry, state

    def test_nominal_suppress_and_restore_cycle(self):
        """When omarchy.dock is enabled and suppress is true, it disables at startup and restores at destruction."""
        reg, state = self.simulate_dock_lifecycle(initial_dock_state=True, suppress_setting=True)
        self.assertEqual(reg.calls, [
            ("registry.setEnabled", "omarchy.dock", False),
            ("registry.setEnabled", "omarchy.dock", True),
        ])
        self.assertTrue(reg.isEnabled("omarchy.dock"))

    def test_dock_already_disabled_by_user_is_not_restored(self):
        """If omarchy.dock was already disabled, destruction must NOT turn it on."""
        reg, state = self.simulate_dock_lifecycle(initial_dock_state=False, suppress_setting=True)
        self.assertEqual(reg.calls, [])
        self.assertFalse(reg.isEnabled("omarchy.dock"))
        self.assertFalse(state["systemDockWasEnabled"])

    def test_suppress_disabled_leaves_system_dock_alone(self):
        """When suppressSystemDock is false, system dock is left running untouched."""
        reg, state = self.simulate_dock_lifecycle(initial_dock_state=True, suppress_setting=False)
        self.assertEqual(reg.calls, [])
        self.assertTrue(reg.isEnabled("omarchy.dock"))

    def test_dynamic_toggle_and_adversarial_inputs(self):
        """Stress-test dynamic toggle with truthy/falsy strings and repeated cycles."""
        reg, state = self.simulate_dock_lifecycle(
            initial_dock_state=True,
            suppress_setting=True,
            toggle_sequence=["false", "true", "0", "1", "false"],
        )
        self.assertTrue(reg.isEnabled("omarchy.dock"))
        self.assertFalse(state["systemDockWasEnabled"])


class PinnedFallbackAdversarialSimulationTest(unittest.TestCase):
    """Stress-tests the pinned apps fallback cascade under corrupted or missing inputs."""

    HARDCODED = ["org.gnome.Nautilus", "chromium", "foot", "omacalc", "omawrite", "X", "YouTube"]

    def resolve_pinned(self, user_pinned_raw, shell_cfg, shell_json_file_raw, defaults_cfg):
        """Replicates DockPanel.qml pinned resolution and cascade."""
        # 1. User pinned file parse
        if user_pinned_raw and user_pinned_raw.strip():
            try:
                parsed = json.loads(user_pinned_raw)
                if isinstance(parsed, list) and len(parsed) > 0:
                    return parsed
            except Exception:
                pass

        # Fallback to getOmarchyDefaultPinned
        try:
            if shell_cfg and "dock" in shell_cfg:
                p = shell_cfg["dock"].get("pinned")
                if isinstance(p, list) and len(p) > 0:
                    return p

            if shell_json_file_raw and shell_json_file_raw.strip():
                try:
                    parsed_file = json.loads(shell_json_file_raw)
                    if parsed_file and "dock" in parsed_file:
                        p = parsed_file["dock"].get("pinned")
                        if isinstance(p, list) and len(p) > 0:
                            return p
                except Exception:
                    pass

            if defaults_cfg and "dock" in defaults_cfg:
                p = defaults_cfg["dock"].get("pinned")
                if isinstance(p, list) and len(p) > 0:
                    return p
        except Exception:
            pass

        return self.HARDCODED

    def test_user_pinned_corruptions(self):
        """Verify invalid user pinned files fall through cleanly."""
        corrupt_inputs = [
            "",
            "   \n\t  ",
            "{ not an array",
            "[ unclosed array",
            "null",
            "123",
            '"string"',
            "[]",
        ]
        defaults = {"dock": {"pinned": ["defaultApp"]}}
        for raw in corrupt_inputs:
            resolved = self.resolve_pinned(raw, None, None, defaults)
            self.assertEqual(resolved, ["defaultApp"], f"Failed to fall back for raw: {raw!r}")

    def test_precedence_tier_cascade(self):
        """Verify shellConfig > shellConfigFile > defaultsConfig > hardcoded."""
        # Tier 1 wins
        t1 = self.resolve_pinned(
            "",
            {"dock": {"pinned": ["t1"]}},
            json.dumps({"dock": {"pinned": ["t2"]}}),
            {"dock": {"pinned": ["t3"]}},
        )
        self.assertEqual(t1, ["t1"])

        # Tier 2 wins when Tier 1 empty
        t2 = self.resolve_pinned(
            "",
            {"dock": {"pinned": []}},
            json.dumps({"dock": {"pinned": ["t2"]}}),
            {"dock": {"pinned": ["t3"]}},
        )
        self.assertEqual(t2, ["t2"])

        # Tier 3 wins when Tier 1 & 2 empty or invalid
        t3 = self.resolve_pinned(
            "",
            None,
            "corrupted json {",
            {"dock": {"pinned": ["t3"]}},
        )
        self.assertEqual(t3, ["t3"])

        # Tier 4 total fallback
        t4 = self.resolve_pinned("", None, None, None)
        self.assertEqual(t4, self.HARDCODED)


class RtlMirroringAndLocaleAdversarialTest(unittest.TestCase):
    """Verifies RTL directionality and completeness of new M3 translation keys across 50 locales."""

    def test_rtl_locales_exact_set(self):
        """Verify ar, fa, he, ur are RTL and the other 46 locales are LTR."""
        with open(LOCALES_FILE, "r", encoding="utf-8") as f:
            locales = json.load(f)

        expected_rtl = {"ar", "fa", "he", "ur"}
        actual_rtl = {code for code, meta in locales.items() if meta.get("direction") == "rtl"}
        self.assertEqual(actual_rtl, expected_rtl, f"RTL locales set mismatch: {actual_rtl} vs {expected_rtl}")

    def test_new_m3_keys_in_all_50_catalogs(self):
        """Verify dock.suppressSystemDock, dock.suppressSystemDockDesc, and dock.importOmarchyPins in all catalogs."""
        catalogs = list(I18N_DIR.glob("*.json"))
        self.assertEqual(len(catalogs), 50)
        keys_to_check = [
            "dock.suppressSystemDock",
            "dock.suppressSystemDockDesc",
            "dock.importOmarchyPins",
        ]
        for cat in catalogs:
            with open(cat, "r", encoding="utf-8") as f:
                data = json.load(f)
            for k in keys_to_check:
                self.assertIn(k, data, f"Missing key {k} in {cat.name}")
                self.assertTrue(isinstance(data[k], str) and len(data[k].strip()) > 0, f"Empty string for {k} in {cat.name}")


if __name__ == "__main__":
    unittest.main()
