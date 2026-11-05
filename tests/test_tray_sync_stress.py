"""Challenger Stress & Empirical Verification Test Suite for M2_TrayStyleSync."""

import json
import unittest


class QmlDockLogicHarness:
    """Accurate Python simulation of DockPanel.qml logic for TrayStyleSync."""

    def __init__(self):
        self.detected_bar_position = "top"
        self.detected_bar_transparent = False
        self.detected_bar_background = "opaque"
        self.has_detected_bar_background = False

    def parse_shell_config(self, raw_text):
        """Replicates parseShellConfig(rawText) from DockPanel.qml:334-354."""
        if not raw_text or not isinstance(raw_text, str) or len(raw_text.strip()) == 0:
            return
        try:
            cfg = json.loads(raw_text)
            if cfg and isinstance(cfg, dict) and "bar" in cfg and isinstance(cfg["bar"], dict):
                bar = cfg["bar"]
                if "position" in bar and bar["position"] and self.detected_bar_position != bar["position"]:
                    self.detected_bar_position = bar["position"]
                if "transparent" in bar and bar["transparent"] is not None:
                    transparent_bool = (bar["transparent"] is True)
                    if self.detected_bar_transparent != transparent_bool:
                        self.detected_bar_transparent = transparent_bool
                if "background" in bar and bar["background"] is not None:
                    bg = bar["background"]
                    if bg in ("opaque", "glassy", "none"):
                        self.detected_bar_background = bg
                        self.has_detected_bar_background = True
        except Exception:
            pass

    def get_bar_style_state(self, shell=None):
        """Replicates readonly property string barStyleState from DockPanel.qml:51-70."""
        sbc = None
        if shell and isinstance(shell, dict):
            sbc = shell.get("barConfig") if "barConfig" in shell else shell.get("bar")

        if sbc and isinstance(sbc, dict) and isinstance(sbc.get("background"), str):
            bg = sbc["background"]
            if bg in ("opaque", "glassy", "none"):
                return bg

        if self.has_detected_bar_background and self.detected_bar_background in ("opaque", "glassy", "none"):
            return self.detected_bar_background

        if sbc and isinstance(sbc, dict) and "transparent" in sbc and sbc["transparent"] is not None:
            return "glassy" if sbc["transparent"] is True else "opaque"

        if self.detected_bar_transparent:
            return "glassy"

        if self.detected_bar_background in ("glassy", "none"):
            return self.detected_bar_background

        return "opaque"

    def is_bar_transparent(self, shell=None):
        """Replicates readonly property bool isBarTransparent: root.barStyleState === 'none'."""
        return self.get_bar_style_state(shell) == "none"

    def compute_surface_style(self, shell=None, system_border_size=2, needs_overlay=True):
        """Replicates dockSurface styling bindings in DockPanel.qml:2642-2673."""
        state = self.get_bar_style_state(shell)
        if state == "none":
            color_alpha = 0.0
            border_width = 0
            border_alpha = 0.0
            overlay_active = False
        elif state == "glassy":
            color_alpha = 0.35
            border_width = max(1, system_border_size)
            border_alpha = 0.30
            overlay_active = False
        else:  # opaque
            color_alpha = 1.0
            border_width = system_border_size
            border_alpha = 1.0
            overlay_active = needs_overlay

        return {
            "state": state,
            "color_alpha": color_alpha,
            "border_width": border_width,
            "border_alpha": border_alpha,
            "overlay_active": overlay_active,
        }


class ChallengerTraySyncStressTest(unittest.TestCase):
    def setUp(self):
        self.harness = QmlDockLogicHarness()

    def test_corrupted_and_boundary_json_inputs(self):
        """Stress test malformed, empty, and malicious raw inputs to parseShellConfig."""
        corrupted_inputs = [
            None,
            "",
            "   ",
            "\n\t\r",
            "{",
            "{bar:",
            "{\"bar\":",
            "{\"bar\": {",
            "{\"bar\": {\"background\":",
            "12345",
            "\"raw string\"",
            "true",
            "false",
            "null",
            "[]",
            "[{\"bar\": {\"background\": \"glassy\"}}]",
            "{\"bar\": null}",
            "{\"bar\": 123}",
            "{\"bar\": \"string_not_dict\"}",
            "{\"bar\": []}",
            "{\"bar\": false}",
            "{\"bar\": {}}",
            "{\"bar\": {\"background\": null}}",
            "{\"bar\": {\"background\": 123}}",
            "{\"bar\": {\"background\": true}}",
            "{\"bar\": {\"background\": []}}",
            "{\"bar\": {\"background\": {}}}",
            "{\"bar\": {\"background\": \"\"}}",
            "{\"bar\": {\"background\": \"OPAQUE\"}}",
            "{\"bar\": {\"background\": \" glassy \"}}",
            "{\"bar\": {\"background\": \"invalid\"}}",
            "{\"bar\": {\"background\": \"neon\"}}",
            "{\"bar\": {\"background\": \"\\u0000none\"}}",
        ]

        for idx, bad_input in enumerate(corrupted_inputs):
            # Must never raise exception
            try:
                self.harness.parse_shell_config(bad_input)
            except Exception as e:
                self.fail(f"Input #{idx} ({bad_input!r}) caused unexpected exception: {e}")

            # State must remain valid "opaque" fallback
            state = self.harness.get_bar_style_state()
            self.assertIn(state, ("opaque", "glassy", "none"),
                          f"Input #{idx} produced invalid state: {state}")
            self.assertEqual(state, "opaque",
                             f"Input #{idx} should default to opaque, got {state}")

    def test_unknown_tray_background_fallbacks(self):
        """Ensure all unapproved strings fall back to opaque."""
        odd_values = ["translucent", "blur", "clear", "glass", "solid", "vivid", "dark"]
        for val in odd_values:
            h = QmlDockLogicHarness()
            h.parse_shell_config(json.dumps({"bar": {"background": val}}))
            self.assertEqual(h.get_bar_style_state(), "opaque", f"Value '{val}' must fall back to opaque")

    def test_runtime_state_transitions(self):
        """Simulate rapid and dynamic state transitions."""
        transitions = ["opaque", "glassy", "none", "opaque", "none", "glassy", "opaque"]
        for target in transitions:
            self.harness.parse_shell_config(json.dumps({"bar": {"background": target}}))
            self.assertEqual(self.harness.get_bar_style_state(), target)

    def test_legacy_transparent_fallback(self):
        """Ensure legacy transparent boolean functions correctly when background is omitted."""
        h1 = QmlDockLogicHarness()
        h1.parse_shell_config(json.dumps({"bar": {"transparent": True}}))
        self.assertEqual(h1.get_bar_style_state(), "glassy")
        self.assertFalse(h1.is_bar_transparent())

        h2 = QmlDockLogicHarness()
        h2.parse_shell_config(json.dumps({"bar": {"transparent": False}}))
        self.assertEqual(h2.get_bar_style_state(), "opaque")
        self.assertFalse(h2.is_bar_transparent())

    def test_precedence_shell_bar_config_over_detected(self):
        """Live shell.barConfig must strictly override shell.json file detection."""
        self.harness.parse_shell_config(json.dumps({"bar": {"background": "opaque"}}))
        self.assertEqual(self.harness.get_bar_style_state(), "opaque")

        # shell.barConfig overrides to "glassy"
        live_shell = {"barConfig": {"background": "glassy"}}
        self.assertEqual(self.harness.get_bar_style_state(live_shell), "glassy")

        # shell.barConfig overrides to "none"
        live_shell["barConfig"]["background"] = "none"
        self.assertEqual(self.harness.get_bar_style_state(live_shell), "none")
        self.assertTrue(self.harness.is_bar_transparent(live_shell))

        # shell.barConfig removed: falls back to detected "opaque"
        self.assertEqual(self.harness.get_bar_style_state(None), "opaque")

    def test_dock_surface_style_metrics(self):
        """Verify surface metrics: alpha, border width, border alpha, overlay."""
        for state, expected in [
            ("opaque", {"color_alpha": 1.0, "border_width": 2, "border_alpha": 1.0, "overlay_active": True}),
            ("glassy", {"color_alpha": 0.35, "border_width": 2, "border_alpha": 0.30, "overlay_active": False}),
            ("none", {"color_alpha": 0.0, "border_width": 0, "border_alpha": 0.0, "overlay_active": False}),
        ]:
            self.harness.parse_shell_config(json.dumps({"bar": {"background": state}}))
            metrics = self.harness.compute_surface_style(system_border_size=2, needs_overlay=True)
            self.assertEqual(metrics["state"], state)
            self.assertAlmostEqual(metrics["color_alpha"], expected["color_alpha"])
            self.assertEqual(metrics["border_width"], expected["border_width"])
            self.assertAlmostEqual(metrics["border_alpha"], expected["border_alpha"])
            self.assertEqual(metrics["overlay_active"], expected["overlay_active"])


if __name__ == "__main__":
    unittest.main()
