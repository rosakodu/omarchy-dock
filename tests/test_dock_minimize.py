"""Unit tests for scripts/dock-minimize.py.

Run with:  python3 -m unittest discover -s tests
"""

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


def _client(addr, workspace="1"):
    return {"address": addr, "workspace": {"name": workspace}}


class SplitQueriesTest(unittest.TestCase):
    def test_an_address_is_a_selector_and_leaves_the_app_identifiers_alone(self):
        # A dock click sends the app's identifiers *and* which window to act on.
        # Narrowing the match down to the address hides the app's siblings.
        identifiers, index, addr = dm.split_queries(
            ["firefox", "firefox.desktop", "/usr/bin/firefox", "0xDEADBEEF"])
        self.assertEqual(identifiers, ["firefox", "firefox.desktop", "/usr/bin/firefox"])
        self.assertEqual(index, -1)
        self.assertEqual(addr, "0xdeadbeef")

    def test_the_legacy_index_selector_still_works(self):
        self.assertEqual(dm.split_queries(["firefox", "--index=2"]), (["firefox"], 2, ""))
        self.assertEqual(dm.split_queries(["firefox", "2"]), (["firefox"], 2, ""))

    def test_no_selector_at_all(self):
        self.assertEqual(dm.split_queries(["firefox"]), (["firefox"], -1, ""))

    def test_an_app_identifier_that_merely_looks_like_hex_is_kept(self):
        identifiers, _, addr = dm.split_queries(["deface", "facade"])
        self.assertEqual(identifiers, ["deface", "facade"])
        self.assertEqual(addr, "")


class PickTargetTest(unittest.TestCase):
    def setUp(self):
        self.first = _client("0xAAA")
        self.second = _client("0xBBB")
        self.hidden = _client("0xCCC", "special:minimized")
        self.matching = [self.first, self.second, self.hidden]
        self.visible = [self.first, self.second]
        self.minimized = [self.hidden]

    def _pick(self, addr="", index=-1, active=""):
        return dm.pick_target(self.matching, self.visible, self.minimized, addr, index, active)

    def test_an_address_names_the_window_outright(self):
        self.assertIs(self._pick(addr="0xbbb"), self.second)

    def test_an_address_wins_over_an_index(self):
        self.assertIs(self._pick(addr="0xbbb", index=0), self.second)

    def test_an_index_is_used_when_no_address_was_given(self):
        self.assertIs(self._pick(index=1), self.second)

    def test_an_address_that_is_gone_falls_through_to_the_heuristics(self):
        self.assertIs(self._pick(addr="0xffff", active="0xbbb"), self.second)

    def test_the_active_window_comes_before_the_first_visible_one(self):
        self.assertIs(self._pick(active="0xbbb"), self.second)

    def test_the_first_visible_window_is_the_default(self):
        self.assertIs(self._pick(), self.first)

    def test_a_minimized_window_is_the_last_resort(self):
        self.assertIs(
            dm.pick_target(self.matching, [], self.minimized, "", -1, ""), self.hidden)

    def test_nothing_matched_at_all(self):
        self.assertIsNone(dm.pick_target([], [], [], "", -1, ""))


class FindDesktopFileTest(unittest.TestCase):
    def test_desktop_file_with_spaces_is_found(self):
        # Issue #23: Desktop files like "Google Maps.desktop" or "Disk Usage.desktop"
        # have spaces in their filename and must not be rejected by find_desktop_file.
        # Test finding an existing entry on disk or via custom search directory.
        import tempfile
        with tempfile.TemporaryDirectory() as tmpdir:
            test_app = os.path.join(tmpdir, "My Custom App.desktop")
            with open(test_app, "w") as f:
                f.write("[Desktop Entry]\nName=My Custom App\nType=Application\nExec=true\n")

            old_xdg = os.environ.get("XDG_DATA_DIRS", "")
            try:
                # Set XDG_DATA_DIRS so tmpdir is searched as <tmpdir>/applications
                app_dir = os.path.join(tmpdir, "applications")
                os.makedirs(app_dir, exist_ok=True)
                os.rename(test_app, os.path.join(app_dir, "My Custom App.desktop"))
                os.environ["XDG_DATA_DIRS"] = tmpdir

                found = dm.find_desktop_file("My Custom App")
                self.assertEqual(found, "My Custom App.desktop")

                found_ext = dm.find_desktop_file("My Custom App.desktop")
                self.assertEqual(found_ext, "My Custom App.desktop")
            finally:
                if old_xdg:
                    os.environ["XDG_DATA_DIRS"] = old_xdg
                else:
                    os.environ.pop("XDG_DATA_DIRS", None)

    def test_path_traversal_and_null_bytes_rejected(self):
        self.assertEqual(dm.find_desktop_file("/etc/passwd"), "")
        self.assertEqual(dm.find_desktop_file("../app.desktop"), "")
        self.assertEqual(dm.find_desktop_file("app\x00name"), "")
        self.assertEqual(dm.find_desktop_file(""), "")
        self.assertEqual(dm.find_desktop_file(None), "")


class ChromePWAMatchingTest(unittest.TestCase):
    def test_real_world_chrome_pwa_classes(self):
        # Issue #28 real-world examples:
        # 1. Teams
        q_teams = 'google-chrome-stable --profile-directory="Profile 1" --app="https://teams.microsoft.com/"'
        self.assertTrue(dm.match_chrome_pwa("chrome-teams.microsoft.com__-Profile_1", q_teams))

        # 2. Outlook
        q_outlook = 'google-chrome-stable --profile-directory="Profile 1" --app="https://outlook.office.com/mail/"'
        self.assertTrue(dm.match_chrome_pwa("chrome-outlook.office.com__mail_-Profile_1", q_outlook))

        # 3. Excel
        q_excel = 'google-chrome-stable --profile-directory="Profile 1" --app="https://excel.cloud.microsoft/"'
        self.assertTrue(dm.match_chrome_pwa("chrome-excel.cloud.microsoft__-Profile_1", q_excel))

    def test_profile_isolation(self):
        # Profile 2 should not match a window from Profile 1
        q_prof2 = 'google-chrome-stable --profile-directory="Profile 2" --app="https://outlook.office.com/mail/"'
        self.assertFalse(dm.match_chrome_pwa("chrome-outlook.office.com__mail_-Profile_1", q_prof2))
        self.assertTrue(dm.match_chrome_pwa("chrome-outlook.office.com__mail_-Profile_2", q_prof2))

    def test_fallback_when_no_profile_specified(self):
        q_no_prof = 'google-chrome-stable --app="https://outlook.office.com/mail/"'
        self.assertTrue(dm.match_chrome_pwa("chrome-outlook.office.com__mail_-Profile_1", q_no_prof))
        self.assertTrue(dm.match_chrome_pwa("chrome-outlook.office.com__mail_-Default", q_no_prof))

    def test_browser_variants(self):
        q = 'brave-browser --app="https://teams.microsoft.com/"'
        self.assertTrue(dm.match_chrome_pwa("brave-teams.microsoft.com__-Default", q))
        q_edge = 'microsoft-edge --app="https://teams.microsoft.com/"'
        self.assertTrue(dm.match_chrome_pwa("msedge-teams.microsoft.com__-Default", q_edge))
        self.assertTrue(dm.match_chrome_pwa("edge-teams.microsoft.com__-Default", q_edge))

    def test_app_id_pwa(self):
        q = 'google-chrome-stable --profile-directory="Default" --app-id="appgkjomdnhhdolojlpkjafpklojikld"'
        self.assertTrue(dm.match_chrome_pwa("chrome-appgkjomdnhhdolojlpkjafpklojikld-Default", q))
        self.assertFalse(dm.match_chrome_pwa("chrome-appgkjomdnhhdolojlpkjafpklojikld-Profile_1", q))

    def test_non_pwa_does_not_match(self):
        self.assertFalse(dm.match_chrome_pwa("foot", 'foot -e nvim'))
        self.assertFalse(dm.match_chrome_pwa("google-chrome", 'google-chrome-stable'))


class PickTargetExplicitAddressTest(unittest.TestCase):
    def test_address_resolved_from_all_clients_even_if_not_in_matching(self):
        target_win = _client("0xTARGET")
        other_win = _client("0xOTHER")
        all_clients = [other_win, target_win]
        # matching list is empty because class heuristic missed it
        picked = dm.pick_target([], [], [], "0xtarget", -1, "", all_clients=all_clients)
        self.assertIs(picked, target_win)


if __name__ == "__main__":
    unittest.main()
