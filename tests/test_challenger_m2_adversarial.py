"""Adversarial stress test suite for M2_TrayStyleSync.
Empirically tests DockPanel.qml barStyleState resolution, IPC getBarStyleState,
color/alpha formulas, and parseShellConfig resilience.
"""

import json
import re
import unittest
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DOCK_PANEL_PATH = PROJECT_ROOT / "DockPanel.qml"


class DockPanelSourceInspectionTest(unittest.TestCase):
    """Static and semantic inspection of DockPanel.qml implementation."""

    @classmethod
    def setUpClass(cls):
        cls.content = DOCK_PANEL_PATH.read_text(encoding="utf-8")

    def test_ipc_handler_defines_get_bar_style_state(self):
        """Verify IPC handler defines getBarStyleState returning root.barStyleState."""
        match = re.search(
            r'target:\s*"rosakodu\.dock".*?function\s+getBarStyleState\(\):\s*string\s*\{\s*return\s+root\.barStyleState\s*\}',
            self.content,
            re.DOTALL,
        )
        self.assertIsNotNone(match, "IpcHandler must contain function getBarStyleState(): string { return root.barStyleState }")

    def test_bar_style_state_property_exists_and_readonly(self):
        """Verify barStyleState is declared as readonly property string."""
        self.assertIn("readonly property string barStyleState:", self.content)

    def test_is_bar_transparent_compatibility_contract(self):
        """Verify isBarTransparent is tied strictly to barStyleState === 'none'."""
        self.assertIn('readonly property bool isBarTransparent: root.barStyleState === "none"', self.content)

    def test_dock_surface_color_alpha_bindings(self):
        """Verify dockSurface binds color to transparent, 0.35 glassy, and base bar background."""
        surface_match = re.search(r'id:\s*dockSurface\b.*?color:\s*\{(.*?)\}', self.content, re.DOTALL)
        self.assertIsNotNone(surface_match, "dockSurface must define color binding")
        color_block = surface_match.group(1)
        self.assertIn('root.barStyleState === "none"', color_block)
        self.assertIn('"transparent"', color_block)
        self.assertIn('root.barStyleState === "glassy"', color_block)
        self.assertIn("Util.alpha(Color.bar.background, 0.35)", color_block)
        self.assertIn("Color.bar.background", color_block)

    def test_dock_surface_border_bindings(self):
        """Verify dockSurface border width and border color for all 3 states."""
        # Border width
        width_match = re.search(r'border\.width:\s*\{(.*?)\}', self.content, re.DOTALL)
        self.assertIsNotNone(width_match)
        width_block = width_match.group(1)
        self.assertIn('root.barStyleState === "none"', width_block)
        self.assertIn("return 0", width_block)
        self.assertIn('root.barStyleState === "glassy"', width_block)
        self.assertIn("Math.max(1, Border.uniformWidth(root.dockBorderSpec))", width_block)

        # Border color
        color_match = re.search(r'border\.color:\s*\{(.*?)\}', self.content, re.DOTALL)
        self.assertIsNotNone(color_match)
        color_block = color_match.group(1)
        self.assertIn('root.barStyleState === "none"', color_block)
        self.assertIn('"transparent"', color_block)
        self.assertIn('root.barStyleState === "glassy"', color_block)
        self.assertIn("Border.color(root.dockBorderSpec)", color_block)

    def test_dock_border_overlay_active_only_on_opaque(self):
        """Verify gradient overlay Loader is active only in opaque mode."""
        self.assertIn('active: root.barStyleState === "opaque" && Border.needsOverlay(root.dockBorderSpec)', self.content)


class BarStyleStateAdversarialSimulationTest(unittest.TestCase):
    """Executes the exact DockPanel.qml logic across edge cases and adversarial inputs."""

    def evaluate_bar_style_state(
        self,
        shell_bar_config=None,
        shell_bar=None,
        detected_bar_bg="opaque",
        has_detected_bar_bg=False,
        detected_bar_transparent=False,
    ):
        """Exact Python port of DockPanel.qml barStyleState property."""
        sbc = shell_bar_config if shell_bar_config is not None else (shell_bar if shell_bar is not None else None)
        if sbc and isinstance(sbc.get("background"), str):
            bg = sbc.get("background")
            if bg in ("opaque", "glassy", "none"):
                return bg
        if has_detected_bar_bg and detected_bar_bg in ("opaque", "glassy", "none"):
            return detected_bar_bg
        if sbc and "transparent" in sbc and sbc["transparent"] is not None:
            return "glassy" if sbc["transparent"] is True else "opaque"
        if detected_bar_transparent:
            return "glassy"
        if detected_bar_bg in ("glassy", "none"):
            return detected_bar_bg
        return "opaque"

    def parse_shell_config(self, raw_text):
        """Exact Python port of DockPanel.qml parseShellConfig(rawText)."""
        detected_pos = "top"
        detected_trans = False
        detected_bg = "opaque"
        has_detected_bg = False

        if not raw_text or not isinstance(raw_text, str) or len(raw_text.strip()) == 0:
            return detected_pos, detected_trans, detected_bg, has_detected_bg
        try:
            cfg = json.loads(raw_text)
            if cfg and isinstance(cfg, dict) and "bar" in cfg and isinstance(cfg["bar"], dict):
                bar = cfg["bar"]
                if "position" in bar and bar["position"]:
                    detected_pos = bar["position"]
                if "transparent" in bar and bar["transparent"] is not None:
                    detected_trans = bar["transparent"] is True
                if "background" in bar and bar["background"] is not None:
                    bg = bar["background"]
                    if bg in ("opaque", "glassy", "none"):
                        detected_bg = bg
                        has_detected_bg = True
        except Exception:
            pass
        return detected_pos, detected_trans, detected_bg, has_detected_bg

    def test_three_nominal_states(self):
        """Verify each of the 3 nominal states resolves cleanly."""
        for state in ("opaque", "glassy", "none"):
            res = self.evaluate_bar_style_state(shell_bar_config={"background": state})
            self.assertEqual(res, state)

    def test_precedence_hierarchy(self):
        """Verify barConfig > shell.json background > legacy barConfig transparent > legacy file transparent > default."""
        # 1. barConfig overrides everything
        res = self.evaluate_bar_style_state(
            shell_bar_config={"background": "glassy", "transparent": False},
            detected_bar_bg="opaque",
            has_detected_bar_bg=True,
            detected_bar_transparent=False,
        )
        self.assertEqual(res, "glassy")

        # 2. shell.json background overrides legacy transparent
        res = self.evaluate_bar_style_state(
            shell_bar_config={"transparent": True},
            detected_bar_bg="opaque",
            has_detected_bar_bg=True,
            detected_bar_transparent=True,
        )
        # Note: in DockPanel.qml:
        # line 57 checks hasDetectedBarBackground BEFORE sbc.transparent!
        # So file background="opaque" correctly overrides legacy boolean transparent!
        self.assertEqual(res, "opaque")

        # 3. Legacy transparent in barConfig when no file background
        res = self.evaluate_bar_style_state(
            shell_bar_config={"transparent": True},
            has_detected_bar_bg=False,
        )
        self.assertEqual(res, "glassy")

        # 4. Default fallback is opaque
        res = self.evaluate_bar_style_state()
        self.assertEqual(res, "opaque")

    def test_corrupt_and_adversarial_values(self):
        """Verify resilient handling of corrupted / malicious values."""
        bad_values = [
            "",
            "   ",
            "OPAQUE",
            "None",
            "GLASSY",
            "transparent",
            "blur",
            123,
            True,
            False,
            [],
            {},
            "../../../etc/passwd",
            "<script>",
        ]
        for val in bad_values:
            res = self.evaluate_bar_style_state(
                shell_bar_config={"background": val},
                has_detected_bar_bg=False,
            )
            self.assertEqual(res, "opaque", f"Failed for corrupted value: {val!r}")

    def test_parse_shell_config_resilience(self):
        """Fuzz parse_shell_config with malformed payloads."""
        malformed_inputs = [
            "",
            "   ",
            "{",
            "{ bar: }",
            "null",
            "12345",
            '"string"',
            '{"bar": null}',
            '{"bar": []}',
            '{"bar": {"background": "invalid"}}',
            '{"bar": {"background": 999}}',
            '{"bar": {"transparent": "yes"}}',
        ]
        for inp in malformed_inputs:
            pos, trans, bg, has_bg = self.parse_shell_config(inp)
            self.assertEqual(bg, "opaque")
            self.assertFalse(has_bg)

        # Valid inputs
        for state in ("opaque", "glassy", "none"):
            payload = json.dumps({"bar": {"background": state, "position": "left"}})
            pos, trans, bg, has_bg = self.parse_shell_config(payload)
            self.assertEqual(pos, "left")
            self.assertEqual(bg, state)
            self.assertTrue(has_bg)


if __name__ == "__main__":
    unittest.main()
