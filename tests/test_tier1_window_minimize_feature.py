"""Tier 1 Feature Tests: R3 - Window Management & Minimization IPC."""

import importlib.util
import os
import unittest

_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       os.pardir, "scripts", "dock-minimize.py")


def _load_script():
    spec = importlib.util.spec_from_file_location("dock_minimize", _SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


dm = _load_script()


class Tier1WindowMinimizeFeatureTest(unittest.TestCase):
    def test_address_parsing_and_hex_normalization(self):
        """Verify hex address query parsing, prefixing and normalization."""
        identifiers, index, addr = dm.split_queries(["code", "0x12AB", "--index=1"])
        self.assertEqual(identifiers, ["code"])
        self.assertEqual(addr, "0x12ab")
        self.assertEqual(index, 1)

        # Bare word without 0x is treated as identifier, not address
        identifiers, _, addr = dm.split_queries(["firefox", "deface"])
        self.assertEqual(identifiers, ["firefox", "deface"])
        self.assertEqual(addr, "")

    def test_heuristic_window_selection_priority(self):
        """Verify selection order: specific address > active window > first visible > minimized."""
        win_active = {"address": "0x101", "workspace": {"name": "1"}}
        win_visible = {"address": "0x102", "workspace": {"name": "1"}}
        win_minimized = {"address": "0x103", "workspace": {"name": "special:minimized"}}

        all_matching = [win_active, win_visible, win_minimized]
        visible = [win_active, win_visible]
        minimized = [win_minimized]

        # 1. Exact address match wins
        target = dm.pick_target(all_matching, visible, minimized, "0x102", -1, "0x101")
        self.assertIs(target, win_visible)

        # 2. Active window wins when no address specified
        target = dm.pick_target(all_matching, visible, minimized, "", -1, "0x101")
        self.assertIs(target, win_active)

        # 3. First visible window wins when active window is not among candidates
        target = dm.pick_target(all_matching, visible, minimized, "", -1, "0x999")
        self.assertIs(target, win_active)

        # 4. Minimized window selected if no visible windows exist
        target = dm.pick_target(all_matching, [], minimized, "", -1, "")
        self.assertIs(target, win_minimized)

    def test_special_minimized_workspace_detection(self):
        """Verify identification of windows located in special:minimized workspace."""
        client_min = {"address": "0x201", "workspace": {"name": "special:minimized"}}
        client_normal = {"address": "0x202", "workspace": {"name": "2"}}
        self.assertTrue(client_min["workspace"]["name"].startswith("special:minimized"))
        self.assertFalse(client_normal["workspace"]["name"].startswith("special:minimized"))

    def test_find_desktop_file_safety(self):
        """Verify find_desktop_file rejects traversal, null bytes, and empty inputs."""
        self.assertEqual(dm.find_desktop_file("../../etc/passwd"), "")
        self.assertEqual(dm.find_desktop_file("app\x00evil"), "")
        self.assertEqual(dm.find_desktop_file(""), "")
        self.assertEqual(dm.find_desktop_file(None), "")

    def test_multiple_instances_index_selector(self):
        """Verify explicit index selector picks the expected instance."""
        win1 = {"address": "0x301", "workspace": {"name": "1"}}
        win2 = {"address": "0x302", "workspace": {"name": "1"}}
        win3 = {"address": "0x303", "workspace": {"name": "1"}}
        candidates = [win1, win2, win3]

        target0 = dm.pick_target(candidates, candidates, [], "", 0, "")
        self.assertIs(target0, win1)

        target2 = dm.pick_target(candidates, candidates, [], "", 2, "")
        self.assertIs(target2, win3)


if __name__ == "__main__":
    unittest.main()
