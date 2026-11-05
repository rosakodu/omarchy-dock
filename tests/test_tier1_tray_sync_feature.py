"""Tier 1 Feature Tests: R2 - 3 Tray States Adaptation & Synchronization."""

import unittest


class MockColor:
    def __init__(self, r=0.1, g=0.1, b=0.1, a=1.0):
        self.r = r
        self.g = g
        self.b = b
        self.a = a


class TrayStyleResolver:
    @staticmethod
    def resolve_state(shell_bar_config=None, shell_json_bar=None):
        """Resolves tray state adhering to M2 precedence contract."""
        if shell_bar_config and "background" in shell_bar_config:
            val = shell_bar_config["background"]
            if val in ("opaque", "glassy", "none"):
                return val
        if shell_json_bar and "background" in shell_json_bar:
            val = shell_json_bar["background"]
            if val in ("opaque", "glassy", "none"):
                return val
        # Legacy fallback
        if shell_bar_config and "transparent" in shell_bar_config:
            return "glassy" if shell_bar_config["transparent"] else "opaque"
        if shell_json_bar and "transparent" in shell_json_bar:
            return "glassy" if shell_json_bar["transparent"] else "opaque"
        return "opaque"

    @staticmethod
    def compute_style(state, base_color, system_border_size=2):
        """Calculates background alpha, color, border width and blur."""
        if state == "opaque":
            return {
                "alpha": 1.0,
                "color_rgba": (base_color.r, base_color.g, base_color.b, 1.0),
                "border_width": system_border_size,
                "blur_enabled": False
            }
        elif state == "glassy":
            return {
                "alpha": 0.35,
                "color_rgba": (base_color.r, base_color.g, base_color.b, 0.35),
                "border_width": max(1, system_border_size),
                "blur_enabled": True
            }
        elif state == "none":
            return {
                "alpha": 0.0,
                "color_rgba": (0.0, 0.0, 0.0, 0.0),
                "border_width": 0,
                "blur_enabled": False
            }
        return TrayStyleResolver.compute_style("opaque", base_color, system_border_size)


class Tier1TraySyncFeatureTest(unittest.TestCase):
    def setUp(self):
        self.base_color = MockColor(0.12, 0.12, 0.15, 1.0)
        self.resolver = TrayStyleResolver()

    def test_tray_state_resolution_priority(self):
        """Verify priority: shell.barConfig > shell.json > legacy transparent > fallback."""
        # shell.barConfig takes precedence
        state = self.resolver.resolve_state(
            shell_bar_config={"background": "glassy"},
            shell_json_bar={"background": "opaque"}
        )
        self.assertEqual(state, "glassy")

        # Fallback to shell_json_bar
        state = self.resolver.resolve_state(
            shell_bar_config=None,
            shell_json_bar={"background": "none"}
        )
        self.assertEqual(state, "none")

        # Fallback to legacy boolean
        state = self.resolver.resolve_state(
            shell_bar_config={"transparent": True},
            shell_json_bar=None
        )
        self.assertEqual(state, "glassy")

        # Default fallback
        state = self.resolver.resolve_state(None, None)
        self.assertEqual(state, "opaque")

    def test_opaque_state_styling_properties(self):
        """Verify opaque state: 100% alpha, full border, blur disabled."""
        style = self.resolver.compute_style("opaque", self.base_color, system_border_size=2)
        self.assertEqual(style["alpha"], 1.0)
        self.assertEqual(style["color_rgba"][-1], 1.0)
        self.assertEqual(style["border_width"], 2)
        self.assertFalse(style["blur_enabled"])

    def test_glassy_state_styling_properties(self):
        """Verify glassy state: 0.35 alpha, blur active, border preserved."""
        style = self.resolver.compute_style("glassy", self.base_color, system_border_size=2)
        self.assertAlmostEqual(style["alpha"], 0.35)
        self.assertAlmostEqual(style["color_rgba"][-1], 0.35)
        self.assertGreaterEqual(style["border_width"], 1)
        self.assertTrue(style["blur_enabled"])

    def test_none_state_styling_properties(self):
        """Verify none state: 0.0 alpha, zero border, blur disabled."""
        style = self.resolver.compute_style("none", self.base_color, system_border_size=2)
        self.assertEqual(style["alpha"], 0.0)
        self.assertEqual(style["color_rgba"], (0.0, 0.0, 0.0, 0.0))
        self.assertEqual(style["border_width"], 0)
        self.assertFalse(style["blur_enabled"])

    def test_dynamic_tray_state_transition(self):
        """Simulate dynamic transitions: opaque -> glassy -> none -> opaque."""
        states = ["opaque", "glassy", "none", "opaque"]
        expected_alphas = [1.0, 0.35, 0.0, 1.0]
        for state, expected_alpha in zip(states, expected_alphas):
            style = self.resolver.compute_style(state, self.base_color)
            self.assertAlmostEqual(style["alpha"], expected_alpha)


if __name__ == "__main__":
    unittest.main()
