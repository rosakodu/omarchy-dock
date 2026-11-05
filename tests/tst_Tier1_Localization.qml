import QtQuick
import QtTest
import "../DockAutoName.js" as DockAutoName

TestCase {
    name: "Tier1_Localization"

    function resolveTranslation(catalogs, langCode, key) {
        if (catalogs[langCode] && catalogs[langCode][key] !== undefined) {
            return catalogs[langCode][key];
        }
        if (langCode.indexOf("-") !== -1) {
            var base = langCode.split("-")[0];
            if (catalogs[base] && catalogs[base][key] !== undefined) {
                return catalogs[base][key];
            }
        }
        if (catalogs["en"] && catalogs["en"][key] !== undefined) {
            return catalogs["en"][key];
        }
        return key;
    }

    function isRtl(langCode) {
        var rtlSet = { "ar": true, "fa": true, "he": true, "ur": true };
        return rtlSet[langCode] === true;
    }

    function test_dialectFallback() {
        var catalogs = {
            "en": { "dock.title": "Dock", "dock.items": "%1 items" },
            "pt": { "dock.title": "Doca" },
            "pt-BR": { "dock.launch": "Iniciar" }
        };

        // 1. Exact match in pt-BR
        compare(resolveTranslation(catalogs, "pt-BR", "dock.launch"), "Iniciar");

        // 2. Base fallback to pt
        compare(resolveTranslation(catalogs, "pt-BR", "dock.title"), "Doca");

        // 3. Fallback to en
        compare(resolveTranslation(catalogs, "pt-BR", "dock.items"), "%1 items");

        // 4. Missing key returns key itself
        compare(resolveTranslation(catalogs, "pt-BR", "dock.missing"), "dock.missing");
    }

    function test_rtlDetection() {
        compare(isRtl("ar"), true);
        compare(isRtl("fa"), true);
        compare(isRtl("he"), true);
        compare(isRtl("ur"), true);
        compare(isRtl("en"), false);
        compare(isRtl("ru"), false);
        compare(isRtl("ja"), false);
    }

    function test_dynamicTextArgSubstitution() {
        var template = "%1 items selected";
        var result = template.arg(42);
        compare(result, "42 items selected");
    }

    function test_autonameKeyMapping() {
        var categoryMap = DockAutoName.CATEGORY_I18N_MAP;
        compare(categoryMap["Browsers"], "folder.browsers");
        compare(categoryMap["Media"], "folder.media");
        compare(categoryMap["Games"], "folder.games");
        compare(categoryMap["Development"], "folder.dev");
        compare(categoryMap["Folder"], "folder.default");
    }

    function test_omarchyPinnedFallback() {
        var hardcoded = ["org.gnome.Nautilus", "chromium", "foot", "omacalc", "omawrite", "X", "YouTube"];
        function getPinned(txt, shellCfg, defaultsCfg) {
            if (txt && txt.trim().length > 0) {
                try {
                    var parsed = JSON.parse(txt);
                    if (Array.isArray(parsed) && parsed.length > 0) return parsed;
                } catch(e) {}
            }
            if (shellCfg && shellCfg.dock && Array.isArray(shellCfg.dock.pinned) && shellCfg.dock.pinned.length > 0) {
                return shellCfg.dock.pinned;
            }
            if (defaultsCfg && defaultsCfg.dock && Array.isArray(defaultsCfg.dock.pinned) && defaultsCfg.dock.pinned.length > 0) {
                return defaultsCfg.dock.pinned;
            }
            return hardcoded;
        }

        compare(getPinned('["custom"]', null, null)[0], "custom");
        compare(getPinned("", { dock: { pinned: ["shell"] } }, null)[0], "shell");
        compare(getPinned("", { dock: { pinned: [] } }, { dock: { pinned: ["default"] } })[0], "default");
        compare(getPinned("", null, null).length, 7);
    }
}
