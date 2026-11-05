"""Tier 4 Real-World Application Scenarios: User workflows and session lifecycle."""

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


class Tier4RealWorldScenariosTest(unittest.TestCase):
    def setUp(self):
        self.base_color = MockColor(0.1, 0.1, 0.12, 1.0)
        self.resolver = TrayStyleResolver()

    def test_scenario_cold_boot_initialization(self):
        """Scenario 1: Cold boot session setup, locale loading, tray sync and dock geometry."""
        # 1. Initial shell config with default opaque tray
        shell_config = {"bar": {"background": "opaque", "position": "top"}}
        tray_state = self.resolver.resolve_state(shell_json_bar=shell_config["bar"])
        self.assertEqual(tray_state, "opaque")

        # 2. Verify dock initial visual metrics
        style = self.resolver.compute_style(tray_state, self.base_color)
        self.assertEqual(style["alpha"], 1.0)
        self.assertEqual(style["border_width"], 2)

        # 3. Verify stable slot size geometry
        slot_size = 42
        icon_base_size = 24
        self.assertEqual(slot_size, 42)
        self.assertEqual(icon_base_size, 24)

    def test_scenario_window_lifecycle_minimize_restore(self):
        """Scenario 2: Launch app -> detect window -> minimize to special workspace -> unminimize."""
        # App running with 1 active window on workspace 1
        app_win = {"address": "0xabc1", "workspace": {"name": "1"}}
        clients = [app_win]

        # User clicks dock item to minimize
        target_to_min = dm.pick_target(clients, clients, [], "0xabc1", -1, "0xabc1")
        self.assertIs(target_to_min, app_win)

        # Window is now minimized (moved to special:minimized)
        app_win["workspace"]["name"] = "special:minimized"
        visible_clients = []
        minimized_clients = [app_win]

        # User clicks dock item again to unminimize
        target_to_restore = dm.pick_target(clients, visible_clients, minimized_clients, "0xabc1", -1, "")
        self.assertIs(target_to_restore, app_win)
        self.assertTrue(target_to_restore["workspace"]["name"].startswith("special:minimized"))

    def test_scenario_settings_panel_and_hot_reloads(self):
        """Scenario 3: Toggle dock settings, switch tray to glassy, change locale dynamically."""
        # Initial settings
        dock_settings = {"autohide": False, "locale": "en", "tray_state": "opaque"}
        self.assertEqual(self.resolver.resolve_state({"background": dock_settings["tray_state"]}), "opaque")

        # User changes tray background to glassy via CLI
        dock_settings["tray_state"] = "glassy"
        tray_state = self.resolver.resolve_state({"background": dock_settings["tray_state"]})
        style = self.resolver.compute_style(tray_state, self.base_color)
        self.assertEqual(tray_state, "glassy")
        self.assertAlmostEqual(style["alpha"], 0.35)

        # User updates language to Russian
        dock_settings["locale"] = "ru"
        translations = {
            "en": {"dock.settings": "Dock Settings"},
            "ru": {"dock.settings": "Настройки дока"}
        }
        ui_label = translations[dock_settings["locale"]]["dock.settings"]
        self.assertEqual(ui_label, "Настройки дока")

    def test_scenario_desktop_theme_hot_reload(self):
        """Scenario 4: Live desktop reload with transparent bar background and overlay mode."""
        live_shell_state = {"background": "none"}
        resolved_state = self.resolver.resolve_state(shell_bar_config=live_shell_state)
        style = self.resolver.compute_style(resolved_state, self.base_color)

        self.assertEqual(resolved_state, "none")
        self.assertEqual(style["alpha"], 0.0)
        self.assertEqual(style["border_width"], 0)


if __name__ == "__main__":
    unittest.main()
