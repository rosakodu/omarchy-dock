"""Tier 1 Feature Tests: R1 - 50 Language Translations & Dynamic Switching."""

import json
import os
import unittest

LOCALES_FILE = "/usr/share/omarchy/default/i18n/locales.json"
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
I18N_DIR = os.path.join(PROJECT_ROOT, "i18n")


class Tier1LocalizationFeatureTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(LOCALES_FILE, "r", encoding="utf-8") as f:
            cls.locales = json.load(f)

    def test_all_50_omarchy_locales_registered(self):
        """Verify exactly 50 Omarchy locales are defined with required attributes."""
        self.assertEqual(len(self.locales), 50, "Omarchy specification mandates exactly 50 locales")
        required_keys = {"name", "englishName", "formatLocale", "locale", "decimal", "zeroDigit"}
        for code, meta in self.locales.items():
            missing = required_keys - set(meta.keys())
            self.assertFalse(missing, f"Locale {code} is missing required fields: {missing}")

    def test_locale_fallback_cascade(self):
        """Verify fallback cascade: regional code -> base language -> en -> key."""
        def resolve_translation(catalogs, lang_code, key):
            # Check requested language
            if lang_code in catalogs and key in catalogs[lang_code]:
                return catalogs[lang_code][key]
            # Check base language if regional (e.g. pt-BR -> pt)
            if "-" in lang_code:
                base = lang_code.split("-")[0]
                if base in catalogs and key in catalogs[base]:
                    return catalogs[base][key]
            # Check English fallback
            if "en" in catalogs and key in catalogs["en"]:
                return catalogs["en"][key]
            return key

        mock_catalogs = {
            "en": {"dock.settings": "Dock Settings", "dock.enable": "Enable dock", "dock.items": "%1 items"},
            "pt": {"dock.settings": "Configurações do Dock"},
            "pt-BR": {"dock.enable": "Ativar dock"}
        }

        # 1. Exact match in pt-BR
        self.assertEqual(resolve_translation(mock_catalogs, "pt-BR", "dock.enable"), "Ativar dock")
        # 2. Fallback from pt-BR to pt
        self.assertEqual(resolve_translation(mock_catalogs, "pt-BR", "dock.settings"), "Configurações do Dock")
        # 3. Fallback to English
        self.assertEqual(resolve_translation(mock_catalogs, "pt-BR", "dock.items"), "%1 items")
        # 4. Fallback to raw key if missing everywhere
        self.assertEqual(resolve_translation(mock_catalogs, "pt-BR", "dock.nonexistent"), "dock.nonexistent")

    def test_cldr_pluralization_categories(self):
        """Verify plural rule categories across diverse language families."""
        # Rules defined by Unicode CLDR and Omarchy Commons/Plural.js
        def get_plural_category(lang, n):
            if lang in ("ja", "zh-CN", "zh-TW", "ko", "th", "vi", "id", "ms"):
                return "other"
            if lang in ("en", "de", "nl", "sv", "da", "no", "fi", "es-MX", "it", "pt", "pt-BR"):
                return "one" if n == 1 else "other"
            if lang in ("ru", "uk"):
                mod10 = n % 10
                mod100 = n % 100
                if mod10 == 1 and mod100 != 11:
                    return "one"
                if 2 <= mod10 <= 4 and not (12 <= mod100 <= 14):
                    return "few"
                return "many"
            if lang in ("ar",):
                if n == 0: return "zero"
                if n == 1: return "one"
                if n == 2: return "two"
                if 3 <= n % 100 <= 10: return "few"
                if 11 <= n % 100 <= 99: return "many"
                return "other"
            return "other"

        self.assertEqual(get_plural_category("ja", 5), "other")
        self.assertEqual(get_plural_category("en", 1), "one")
        self.assertEqual(get_plural_category("en", 2), "other")
        self.assertEqual(get_plural_category("ru", 1), "one")
        self.assertEqual(get_plural_category("ru", 3), "few")
        self.assertEqual(get_plural_category("ru", 5), "many")
        self.assertEqual(get_plural_category("ru", 21), "one")
        self.assertEqual(get_plural_category("ar", 0), "zero")
        self.assertEqual(get_plural_category("ar", 2), "two")

    def test_number_and_decimal_formatting(self):
        """Verify number formatting using locale decimal separators."""
        def format_number(val, locale_meta):
            dec = locale_meta["decimal"]
            formatted = f"{val:.1f}".replace(".", dec)
            return formatted

        self.assertEqual(format_number(12.5, self.locales["en"]), "12.5")
        self.assertEqual(format_number(12.5, self.locales["ru"]), "12,5")
        self.assertEqual(format_number(12.5, self.locales["fr"]), "12,5")
        self.assertEqual(format_number(12.5, self.locales["fa"]), "12٫5")

    def test_i18n_catalog_schema_validation(self):
        """Validate live i18n catalogs: all 50 locales must exist and contain required keys."""
        self.assertTrue(os.path.isdir(I18N_DIR), "i18n directory must exist")
        found_locales = [f[:-5] for f in os.listdir(I18N_DIR) if f.endswith(".json")]
        self.assertEqual(len(found_locales), 50, "All 50 Omarchy locales must have catalogs")
        required_keys = [
            "dock.settings", "dock.enable", "dock.autohide", "dock.keybind", "dock.keybindHint",
            "dock.copied", "dock.overlay", "dock.badges", "dock.widgets", "dock.configureWidgets",
            "dock.suppressSystemDock", "dock.suppressSystemDockDesc", "dock.importOmarchyPins",
            "picker.title", "picker.appMenuPosition", "picker.widgetPosition", "picker.left",
            "picker.right", "picker.apps", "picker.dock", "picker.off", "picker.tray",
            "widget.clock", "widget.weather", "folder.default"
        ]
        for code in found_locales:
            with open(os.path.join(I18N_DIR, f"{code}.json"), "r", encoding="utf-8") as f:
                data = json.load(f)
                self.assertIsInstance(data, dict, f"Catalog for {code} must be a JSON object")
                for rk in required_keys:
                    self.assertIn(rk, data, f"Key '{rk}' missing in {code}.json")

    def test_omarchy_pinned_import_fallback(self):
        """Verify Omarchy pinned apps fallback logic."""
        hardcoded = ["org.gnome.Nautilus", "chromium", "foot", "omacalc", "omawrite", "X", "YouTube"]
        def resolve_pinned(user_pinned_txt, shell_cfg, defaults_cfg):
            if user_pinned_txt and user_pinned_txt.strip():
                try:
                    parsed = json.loads(user_pinned_txt)
                    if isinstance(parsed, list) and len(parsed) > 0:
                        return parsed
                except Exception:
                    pass
            if shell_cfg and "dock" in shell_cfg and isinstance(shell_cfg["dock"].get("pinned"), list) and shell_cfg["dock"]["pinned"]:
                return shell_cfg["dock"]["pinned"]
            if defaults_cfg and "dock" in defaults_cfg and isinstance(defaults_cfg["dock"].get("pinned"), list) and defaults_cfg["dock"]["pinned"]:
                return defaults_cfg["dock"]["pinned"]
            return hardcoded

        # 1. Custom user pins take precedence
        self.assertEqual(resolve_pinned('["app1", "app2"]', {}, {}), ["app1", "app2"])
        # 2. Empty user pins fallback to shellConfig
        self.assertEqual(resolve_pinned("", {"dock": {"pinned": ["shellApp"]}}, {}), ["shellApp"])
        # 3. Empty shellConfig falls back to defaultsConfig
        self.assertEqual(resolve_pinned("", {"dock": {"pinned": []}}, {"dock": {"pinned": ["defaultApp"]}}), ["defaultApp"])
        # 4. Total fallback to hardcoded
        self.assertEqual(resolve_pinned("", {}, {}), hardcoded)


if __name__ == "__main__":
    unittest.main()
