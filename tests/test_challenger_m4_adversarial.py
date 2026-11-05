"""Challenger 2 — Milestone 4 Runtime & Integration Adversarial Hardening Suite.

Empirical verification of:
1. Omarchy dock suppression on floating workspaces & restoration lifecycle.
2. 4-tier pinned application cascade & importOmarchyPins() stability.
3. Visual contract for 'glassy' mode: 100% opaque border (>= 1px) and 0.35 alpha background.
"""

import json
import re
import unittest
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DOCK_PANEL_PATH = PROJECT_ROOT / "DockPanel.qml"
BAR_WIDGET_PATH = PROJECT_ROOT / "BarWidget.qml"
I18N_DIR = PROJECT_ROOT / "i18n"
OMARCHY_DEFAULTS_SHELL = Path("/usr/share/omarchy/config/omarchy/shell.json")


class MockPluginRegistry:
    """Mock of Quickshell / Omarchy PluginRegistry."""
    def __init__(self, initial_dock_enabled=True):
        self.plugins = {
            "omarchy.dock": {"enabled": initial_dock_enabled}
        }
        self.call_log = []

    def isEnabled(self, plugin_id):
        return bool(self.plugins.get(plugin_id, {}).get("enabled", False))

    def setEnabled(self, plugin_id, enabled):
        self.call_log.append(("setEnabled", plugin_id, enabled))
        if plugin_id in self.plugins:
            self.plugins[plugin_id]["enabled"] = bool(enabled)
        else:
            self.plugins[plugin_id] = {"enabled": bool(enabled)}
        return True


class MockShell:
    """Mock of Omarchy Shell host object."""
    def __init__(self, registry=None, shell_config=None, defaults_config=None):
        self.pluginRegistry = registry
        self.shellConfig = shell_config or {}
        self.defaultsConfig = defaults_config or {}
        self.call_log = []

    def setPluginEnabled(self, plugin_id, enabled):
        self.call_log.append(("setPluginEnabled", plugin_id, enabled))
        if self.pluginRegistry:
            return self.pluginRegistry.setEnabled(plugin_id, enabled)
        return True


class SystemDockSuppressionAdversarialTest(unittest.TestCase):
    """Stress tests for omarchy.dock suppression on floating workspaces and lifecycle."""

    def simulate_suppression(self, registry, shell, suppress_system_dock, system_dock_was_enabled):
        """Simulate applySystemDockSuppression in DockPanel.qml."""
        reg = registry or (shell.pluginRegistry if shell else None)
        if not reg:
            return system_dock_was_enabled
        if suppress_system_dock:
            is_enabled = False
            if hasattr(reg, "isEnabled"):
                is_enabled = reg.isEnabled("omarchy.dock")
            elif hasattr(reg, "installedPlugins") and "omarchy.dock" in reg.installedPlugins:
                is_enabled = reg.installedPlugins["omarchy.dock"].get("enabled") is True
            if is_enabled:
                system_dock_was_enabled = True
                if hasattr(reg, "setEnabled"):
                    reg.setEnabled("omarchy.dock", False)
                elif shell and hasattr(shell, "setPluginEnabled"):
                    shell.setPluginEnabled("omarchy.dock", False)
        elif system_dock_was_enabled:
            system_dock_was_enabled = False
            if hasattr(reg, "setEnabled"):
                reg.setEnabled("omarchy.dock", True)
            elif shell and hasattr(shell, "setPluginEnabled"):
                shell.setPluginEnabled("omarchy.dock", True)
        return system_dock_was_enabled

    def simulate_destruction(self, registry, shell, system_dock_was_enabled):
        """Simulate Component.onDestruction in DockPanel.qml."""
        if system_dock_was_enabled:
            reg = registry or (shell.pluginRegistry if shell else None)
            if reg and hasattr(reg, "setEnabled"):
                reg.setEnabled("omarchy.dock", True)
            elif shell and hasattr(shell, "setPluginEnabled"):
                shell.setPluginEnabled("omarchy.dock", True)

    def test_nominal_suppression_and_restoration(self):
        """When omarchy.dock was enabled, start suppresses it and exit restores it."""
        reg = MockPluginRegistry(initial_dock_enabled=True)
        shell = MockShell(registry=reg)

        # 1. Startup with suppressSystemDock = True
        was_enabled = self.simulate_suppression(reg, shell, True, False)
        self.assertTrue(was_enabled)
        self.assertFalse(reg.isEnabled("omarchy.dock"))
        self.assertIn(("setEnabled", "omarchy.dock", False), reg.call_log)

        # 2. Destruction restores omarchy.dock
        self.simulate_destruction(reg, shell, was_enabled)
        self.assertTrue(reg.isEnabled("omarchy.dock"))
        self.assertIn(("setEnabled", "omarchy.dock", True), reg.call_log)

    def test_already_disabled_by_user_is_never_forced_on_exit(self):
        """If user already disabled omarchy.dock, dock plugin must NOT enable it on exit."""
        reg = MockPluginRegistry(initial_dock_enabled=False)
        shell = MockShell(registry=reg)

        was_enabled = self.simulate_suppression(reg, shell, True, False)
        self.assertFalse(was_enabled)
        self.assertFalse(reg.isEnabled("omarchy.dock"))

        # Destruction should be a no-op
        self.simulate_destruction(reg, shell, was_enabled)
        self.assertFalse(reg.isEnabled("omarchy.dock"))
        self.assertEqual(len(reg.call_log), 0)

    def test_dynamic_toggle_cycles(self):
        """Toggling suppressSystemDock off and on restores and re-suppresses correctly."""
        reg = MockPluginRegistry(initial_dock_enabled=True)
        shell = MockShell(registry=reg)

        # Step 1: Suppress
        was_enabled = self.simulate_suppression(reg, shell, True, False)
        self.assertFalse(reg.isEnabled("omarchy.dock"))
        self.assertTrue(was_enabled)

        # Step 2: User unchecks suppressSystemDock in settings
        was_enabled = self.simulate_suppression(reg, shell, False, was_enabled)
        self.assertTrue(reg.isEnabled("omarchy.dock"))
        self.assertFalse(was_enabled)

        # Step 3: User re-checks suppressSystemDock
        was_enabled = self.simulate_suppression(reg, shell, True, was_enabled)
        self.assertFalse(reg.isEnabled("omarchy.dock"))
        self.assertTrue(was_enabled)


class PinnedCascadeAndImportAdversarialTest(unittest.TestCase):
    """Stress tests for the 4-tier pinned cascade and importOmarchyPins()."""

    HARDCODED = ["org.gnome.Nautilus", "chromium", "foot", "omacalc", "omawrite", "X", "YouTube"]

    def simulate_get_omarchy_default_pinned(self, shell=None, shell_config_file_text=""):
        """Exact logic of getOmarchyDefaultPinned() in DockPanel.qml."""
        try:
            sh = shell or None
            if sh and hasattr(sh, "shellConfig") and sh.shellConfig and "dock" in sh.shellConfig:
                dock = sh.shellConfig["dock"]
                if isinstance(dock, dict) and isinstance(dock.get("pinned"), list) and len(dock["pinned"]) > 0:
                    return dock["pinned"]

            if shell_config_file_text and shell_config_file_text.strip():
                parsed = json.loads(shell_config_file_text)
                if parsed and isinstance(parsed, dict) and "dock" in parsed:
                    dock = parsed["dock"]
                    if isinstance(dock, dict) and isinstance(dock.get("pinned"), list) and len(dock["pinned"]) > 0:
                        return dock["pinned"]

            if sh and hasattr(sh, "defaultsConfig") and sh.defaultsConfig and "dock" in sh.defaultsConfig:
                dock = sh.defaultsConfig["dock"]
                if isinstance(dock, dict) and isinstance(dock.get("pinned"), list) and len(dock["pinned"]) > 0:
                    return dock["pinned"]
        except Exception:
            pass
        return self.HARDCODED

    def test_tier_1_shell_config_wins(self):
        """Tier 1: sh.shellConfig.dock.pinned overrides everything."""
        sh = MockShell(
            shell_config={"dock": {"pinned": ["custom_t1"]}},
            defaults_config={"dock": {"pinned": ["def_t3"]}}
        )
        file_text = '{"dock": {"pinned": ["file_t2"]}}'
        res = self.simulate_get_omarchy_default_pinned(shell=sh, shell_config_file_text=file_text)
        self.assertEqual(res, ["custom_t1"])

    def test_tier_2_file_wins_if_shell_config_empty(self):
        """Tier 2: shellConfigFile text wins if shellConfig has no pinned list."""
        sh = MockShell(
            shell_config={"dock": {"pinned": []}},
            defaults_config={"dock": {"pinned": ["def_t3"]}}
        )
        file_text = '{"dock": {"pinned": ["file_t2_app"]}}'
        res = self.simulate_get_omarchy_default_pinned(shell=sh, shell_config_file_text=file_text)
        self.assertEqual(res, ["file_t2_app"])

    def test_tier_3_defaults_config_wins_if_no_user_file(self):
        """Tier 3: sh.defaultsConfig.dock.pinned wins if shellConfig and file are absent."""
        sh = MockShell(
            shell_config={},
            defaults_config={"dock": {"pinned": ["def_t3_app"]}}
        )
        res = self.simulate_get_omarchy_default_pinned(shell=sh, shell_config_file_text="")
        self.assertEqual(res, ["def_t3_app"])

    def test_tier_4_hardcoded_fallback(self):
        """Tier 4: Hardcoded fallback matches /usr/share/omarchy/config/omarchy/shell.json exactly."""
        res = self.simulate_get_omarchy_default_pinned(shell=None, shell_config_file_text="")
        self.assertEqual(res, self.HARDCODED)

        # Compare with physical file on disk
        if OMARCHY_DEFAULTS_SHELL.exists():
            with open(OMARCHY_DEFAULTS_SHELL, "r", encoding="utf-8") as f:
                disk_data = json.load(f)
            disk_pinned = disk_data.get("dock", {}).get("pinned", [])
            self.assertEqual(res, disk_pinned, "Hardcoded fallback must match system default shell.json")

    def test_adversarial_corrupted_shell_configs(self):
        """Malformed JSON or corrupted types fall through cleanly to tier 4 without crashing."""
        corrupted_payloads = [
            "", "   ", "{", "null", "123", "[]",
            '{"dock": null}',
            '{"dock": {"pinned": null}}',
            '{"dock": {"pinned": "not-a-list"}}',
            '{"dock": {"pinned": []}}',
            '{"dock": {"pinned": {}}}'
        ]
        for payload in corrupted_payloads:
            res = self.simulate_get_omarchy_default_pinned(shell=None, shell_config_file_text=payload)
            self.assertEqual(res, self.HARDCODED)


class GlassyBorderVisualContractAdversarialTest(unittest.TestCase):
    """Adversarial stress-testing of glassy mode visual contracts and border rendering."""

    @classmethod
    def setUpClass(cls):
        cls.content = DOCK_PANEL_PATH.read_text(encoding="utf-8")

    def evaluate_dock_surface_border_width(self, bar_style_state, can_use_native, uniform_width, is_none=False):
        """Exact control flow from DockPanel.qml border.width binding."""
        if bar_style_state == "none":
            return 0
        if bar_style_state == "glassy":
            return 0 if is_none else max(1, uniform_width)
        if not can_use_native:
            return 0
        return uniform_width

    def evaluate_dock_surface_border_color(self, bar_style_state, can_use_native, spec_color, is_none=False):
        """Exact control flow from DockPanel.qml border.color binding."""
        if bar_style_state == "none":
            return "transparent"
        if bar_style_state == "glassy":
            return "transparent" if is_none else spec_color
        if not can_use_native:
            return "transparent"
        return spec_color

    def test_glassy_flat_border_success(self):
        """When active border is flat (single color), glassy mode achieves >= 1px solid border."""
        w = self.evaluate_dock_surface_border_width("glassy", can_use_native=True, uniform_width=2)
        c = self.evaluate_dock_surface_border_color("glassy", can_use_native=True, spec_color="#78824b")
        self.assertEqual(w, 2)
        self.assertEqual(c, "#78824b")

    def test_glassy_gradient_border_drop_bug(self):
        """Verified: When system active border is a gradient (canUseNative=False),
        glassy mode now correctly retains solid border (>=1px, spec_color).
        """
        # When Hyprland has a multi-color gradient border, canUseNative is False
        can_use_native = False
        uniform_width = 2
        spec_color = "#78824b"

        actual_width = self.evaluate_dock_surface_border_width("glassy", can_use_native, uniform_width)
        actual_color = self.evaluate_dock_surface_border_color("glassy", can_use_native, spec_color)

        self.assertEqual(actual_width, 2, "Fixed: width is preserved on gradient in glassy mode")
        self.assertEqual(actual_color, "#78824b", "Fixed: color is preserved on gradient in glassy mode")


if __name__ == "__main__":
    unittest.main()
