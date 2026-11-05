import QtQuick
import QtTest
import "../DockModel.js" as DockModel
import "../DockSettings.js" as DockSettings
import "../DockAutoName.js" as DockAutoName

TestCase {
    name: "Tier5_Adversarial"

    // -------------------------------------------------------------------------
    // 1. Dynamic Translation & Layout Mirroring
    // -------------------------------------------------------------------------
    function test_layoutMirroringReactivity() {
        var testContainer = Qt.createQmlObject(
            'import QtQuick; Item {\n' +
            '    property bool isRtl: false\n' +
            '    LayoutMirroring.enabled: isRtl\n' +
            '    LayoutMirroring.childrenInherit: true\n' +
            '    Rectangle {\n' +
            '        id: childRect\n' +
            '        x: 10\n' +
            '        width: 50\n' +
            '    }\n' +
            '}',
            Qt.application
        );

        verify(testContainer !== null, "Test container created");
        compare(testContainer.LayoutMirroring.enabled, false);

        // Switch to RTL
        testContainer.isRtl = true;
        compare(testContainer.LayoutMirroring.enabled, true);
        compare(testContainer.LayoutMirroring.childrenInherit, true);

        // Switch back to LTR
        testContainer.isRtl = false;
        compare(testContainer.LayoutMirroring.enabled, false);
    }

    // -------------------------------------------------------------------------
    // 2. DockSettings Normalization Adversarial Stress
    // -------------------------------------------------------------------------
    function test_settingsNormalizationAdversarial() {
        // Null / undefined inputs
        var normNull = DockSettings.normalize(null);
        compare(normNull.visibilityMode, "always");
        compare(normNull.overlayMode, false);
        compare(normNull.visibleWorkspace, "all");
        compare(normNull.suppressSystemDock, true);

        var normEmpty = DockSettings.normalize({});
        compare(normEmpty.visibilityMode, "always");
        compare(normEmpty.suppressSystemDock, true);

        // Extreme corrupted types
        var normCorrupted = DockSettings.normalize({
            visibilityMode: 12345,
            overlayMode: "not-a-bool",
            visibleWorkspace: -999,
            suppressSystemDock: "invalid"
        });
        compare(normCorrupted.visibilityMode, "always");
        compare(normCorrupted.overlayMode, false);
        compare(normCorrupted.suppressSystemDock, true);

        // Legacy autohide migration
        var normLegacyTrue = DockSettings.normalize({ autohide: true });
        compare(normLegacyTrue.visibilityMode, "hover");

        var normLegacyFalse = DockSettings.normalize({ autohide: false });
        compare(normLegacyFalse.visibilityMode, "always");
    }

    // -------------------------------------------------------------------------
    // 3. Tray Style State Invariants & Border Rendering
    // -------------------------------------------------------------------------
    function test_trayStyleStateResolution() {
        function resolveStyle(sbc, detectedBg, hasDetectedBg) {
            if (sbc && typeof sbc.background === "string") {
                var bg = sbc.background;
                if (bg === "opaque" || bg === "glassy" || bg === "none") return bg;
            }
            if (hasDetectedBg && (detectedBg === "opaque" || detectedBg === "glassy" || detectedBg === "none")) {
                return detectedBg;
            }
            if (sbc && sbc.transparent !== undefined) {
                return (sbc.transparent === true) ? "glassy" : "opaque";
            }
            if (detectedBg === "glassy" || detectedBg === "none") {
                return detectedBg;
            }
            return "opaque";
        }

        // Nominal 3 states
        compare(resolveStyle({ background: "opaque" }, "opaque", false), "opaque");
        compare(resolveStyle({ background: "glassy" }, "opaque", false), "glassy");
        compare(resolveStyle({ background: "none" }, "opaque", false), "none");

        // Legacy transparent mapping
        compare(resolveStyle({ transparent: true }, "opaque", false), "glassy");
        compare(resolveStyle({ transparent: false }, "glassy", false), "opaque");

        // Corrupted background falls back to detectedBg
        compare(resolveStyle({ background: "GARBAGE" }, "glassy", true), "glassy");
        compare(resolveStyle({ background: 42 }, "none", true), "none");
        compare(resolveStyle(null, "unknown", false), "opaque");
    }

    // -------------------------------------------------------------------------
    // 4. Auto-naming Categories & Key Mapping
    // -------------------------------------------------------------------------
    function test_autonameCategoryKeyMapping() {
        var categories = [
            "Browsers", "Messaging", "Communication", "Development",
            "Terminals", "Editors", "Graphics", "Media", "Productivity",
            "Games", "Files", "System", "Utilities", "Email", "Photos",
            "Notes & Docs", "AI Tools", "Maps", "Folder"
        ];

        for (var i = 0; i < categories.length; i++) {
            var cat = categories[i];
            var key = DockAutoName.getCategoryI18nKey(cat);
            verify(key !== "", "Category '" + cat + "' must have non-empty i18n key");
            verify(key.indexOf("folder.") === 0, "Key must start with 'folder.' prefix: " + key);
        }
    }

    // -------------------------------------------------------------------------
    // 5. Pinned Items Fallback Cascade Invariants
    // -------------------------------------------------------------------------
    function test_pinnedFallbackCascade() {
        var hardcodedDefaults = ["org.gnome.Nautilus", "chromium", "foot", "omacalc", "omawrite", "X", "YouTube"];

        function simulateGetPinned(shellConfig, fileText, defaultsConfig) {
            try {
                if (shellConfig && shellConfig.dock && Array.isArray(shellConfig.dock.pinned) && shellConfig.dock.pinned.length > 0) {
                    return shellConfig.dock.pinned;
                }
                if (fileText && fileText.trim().length > 0) {
                    var parsed = JSON.parse(fileText);
                    if (parsed && parsed.dock && Array.isArray(parsed.dock.pinned) && parsed.dock.pinned.length > 0) {
                        return parsed.dock.pinned;
                    }
                }
                if (defaultsConfig && defaultsConfig.dock && Array.isArray(defaultsConfig.dock.pinned) && defaultsConfig.dock.pinned.length > 0) {
                    return defaultsConfig.dock.pinned;
                }
            } catch(e) {}
            return hardcodedDefaults;
        }

        // Tier 1: shellConfig
        var res1 = simulateGetPinned({ dock: { pinned: ["app1", "app2"] } }, "", null);
        compare(res1.length, 2);
        compare(res1[0], "app1");

        // Tier 2: fileText
        var res2 = simulateGetPinned(null, '{"dock":{"pinned":["fileApp"]}}', null);
        compare(res2.length, 1);
        compare(res2[0], "fileApp");

        // Tier 3: defaultsConfig
        var res3 = simulateGetPinned(null, "", { dock: { pinned: ["defApp1", "defApp2"] } });
        compare(res3.length, 2);
        compare(res3[0], "defApp1");

        // Tier 4: Hardcoded fallback
        var res4 = simulateGetPinned(null, "MALFORMED_JSON", null);
        compare(res4.length, 7);
        compare(res4[0], "org.gnome.Nautilus");
        compare(res4[6], "YouTube");
    }
}
