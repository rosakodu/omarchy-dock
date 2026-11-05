import QtQuick
import QtTest
import "../DockSettings.js" as DockSettings
import "/usr/share/omarchy/shell/Commons/Plural.js" as Plural

TestCase {
    name: "ChallengerM3_LocalizationAdversarial"

    function test_cldrPluralResolutionAcrossFamilies() {
        // Russian: 1 (one), 2 (few), 5 (many), 21 (one), 12 (many)
        compare(Plural.category("ru", 1), "one");
        compare(Plural.category("ru", 2), "few");
        compare(Plural.category("ru", 4), "few");
        compare(Plural.category("ru", 5), "many");
        compare(Plural.category("ru", 11), "many");
        compare(Plural.category("ru", 12), "many");
        compare(Plural.category("ru", 21), "one");
        compare(Plural.category("ru", 22), "few");

        // Arabic: 0 (zero), 1 (one), 2 (two), 3 (few), 15 (many), 100 (other)
        compare(Plural.category("ar", 0), "zero");
        compare(Plural.category("ar", 1), "one");
        compare(Plural.category("ar", 2), "two");
        compare(Plural.category("ar", 3), "few");
        compare(Plural.category("ar", 10), "few");
        compare(Plural.category("ar", 15), "many");
        compare(Plural.category("ar", 100), "other");

        // Japanese / Chinese: only other
        compare(Plural.category("ja", 1), "other");
        compare(Plural.category("ja", 42), "other");
        compare(Plural.category("zh-CN", 1), "other");

        // English / German: 1 (one), others (other)
        compare(Plural.category("en", 1), "one");
        compare(Plural.category("en", 0), "other");
        compare(Plural.category("en", 2), "other");
    }

    function test_pluralPickAndFallback() {
        var catalogEntry = {
            "one": "%1 файл",
            "few": "%1 файла",
            "many": "%1 файлов",
            "other": "%1 файлов"
        };
        compare(Plural.pick(catalogEntry, "ru", 1), "%1 файл");
        compare(Plural.pick(catalogEntry, "ru", 3), "%1 файла");
        compare(Plural.pick(catalogEntry, "ru", 7), "%1 файлов");

        // Fallback to "other" if specific category missing in entry
        var incompleteEntry = { "other": "%1 items" };
        compare(Plural.pick(incompleteEntry, "ru", 1), "%1 items");
        compare(Plural.pick(incompleteEntry, "ar", 2), "%1 items");
    }

    function test_dockSettingsSuppressSystemDockNormalization() {
        compare(DockSettings.normalizeSuppressSystemDock(true), true);
        compare(DockSettings.normalizeSuppressSystemDock(false), false);
        compare(DockSettings.normalizeSuppressSystemDock("true"), true);
        compare(DockSettings.normalizeSuppressSystemDock("false"), false);
        compare(DockSettings.normalizeSuppressSystemDock("1"), true);
        compare(DockSettings.normalizeSuppressSystemDock("0"), false);
        compare(DockSettings.normalizeSuppressSystemDock(undefined), true);
        compare(DockSettings.normalizeSuppressSystemDock(null), true);
    }

    function test_corruptedCatalogParsingResilience() {
        function safeParseCatalog(raw) {
            try {
                var parsed = JSON.parse(raw || "{}");
                return (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : ({});
            } catch (e) {
                return ({});
            }
        }

        // Malformed JSON strings must not crash, must return empty object
        compare(Object.keys(safeParseCatalog("{bad_json}")).length, 0);
        compare(Object.keys(safeParseCatalog("")).length, 0);
        compare(Object.keys(safeParseCatalog("null")).length, 0);
        compare(Object.keys(safeParseCatalog("[1, 2, 3]")).length, 0);
        compare(safeParseCatalog('{"dock.title": "Dock"}')["dock.title"], "Dock");
    }

    function test_rtlMirroringPropertyContract() {
        var item = Qt.createQmlObject('import QtQuick; Item { property bool isRtl: false; LayoutMirroring.enabled: isRtl; LayoutMirroring.childrenInherit: true }', Qt.application);
        verify(item !== null);
        compare(item.LayoutMirroring.enabled, false);
        item.isRtl = true;
        compare(item.LayoutMirroring.enabled, true);
        compare(item.LayoutMirroring.childrenInherit, true);
        item.destroy();
    }
}
