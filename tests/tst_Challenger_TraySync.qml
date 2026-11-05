import QtQuick
import QtTest

TestCase {
    name: "Challenger_TraySync"

    // Component modeling DockPanel's exact reactive tray resolution logic
    Component {
        id: dockSyncHarnessComponent
        Item {
            id: mockDock

            property var shell: null
            property string detectedBarPosition: "top"
            property bool detectedBarTransparent: false
            property string detectedBarBackground: "opaque"
            property bool hasDetectedBarBackground: false

            readonly property string barStyleState: {
                var sbc = (shell && shell.barConfig) ? shell.barConfig : (shell && shell.bar ? shell.bar : null);
                if (sbc && typeof sbc.background === "string") {
                    var bg = sbc.background;
                    if (bg === "opaque" || bg === "glassy" || bg === "none") return bg;
                }
                if (mockDock.hasDetectedBarBackground && (mockDock.detectedBarBackground === "opaque" || mockDock.detectedBarBackground === "glassy" || mockDock.detectedBarBackground === "none")) {
                    return mockDock.detectedBarBackground;
                }
                if (sbc && sbc.transparent !== undefined) {
                    return (sbc.transparent === true) ? "glassy" : "opaque";
                }
                if (mockDock.detectedBarTransparent) {
                    return "glassy";
                }
                if (mockDock.detectedBarBackground === "glassy" || mockDock.detectedBarBackground === "none") {
                    return mockDock.detectedBarBackground;
                }
                return "opaque";
            }

            readonly property bool isBarTransparent: mockDock.barStyleState === "none"

            function parseShellConfig(rawText) {
                if (!rawText || typeof rawText !== "string" || rawText.trim().length === 0) return;
                try {
                    var cfg = JSON.parse(rawText);
                    if (cfg && cfg.bar) {
                        if (cfg.bar.position && mockDock.detectedBarPosition !== cfg.bar.position) {
                            mockDock.detectedBarPosition = cfg.bar.position;
                        }
                        if (cfg.bar.transparent !== undefined && mockDock.detectedBarTransparent !== (cfg.bar.transparent === true)) {
                            mockDock.detectedBarTransparent = (cfg.bar.transparent === true);
                        }
                        if (cfg.bar.background !== undefined) {
                            var bg = cfg.bar.background;
                            if (bg === "opaque" || bg === "glassy" || bg === "none") {
                                mockDock.detectedBarBackground = bg;
                                mockDock.hasDetectedBarBackground = true;
                            }
                        }
                    }
                } catch(e) {}
            }

            function getBarStyleState() {
                return mockDock.barStyleState;
            }
        }
    }

    function test_corruptedAndMalformedJsonInputs() {
        var dock = dockSyncHarnessComponent.createObject(null);
        verify(dock !== null);

        var corrupted = [
            null, undefined, "", "   ", "\n\t", "{", "{\"bar\":",
            "123", "true", "false", "[]", "[{\"bar\":1}]",
            "{\"bar\": null}", "{\"bar\": 42}", "{\"bar\": []}",
            "{\"bar\": {\"background\": \"invalid\"}}",
            "{\"bar\": {\"background\": \"neon\"}}",
            "{\"bar\": {\"background\": 999}}",
            "{\"bar\": {\"background\": null}}",
            "{\"bar\": {\"background\": []}}",
            "{\"bar\": {\"background\": {}}}"
        ];

        for (var i = 0; i < corrupted.length; i++) {
            dock.parseShellConfig(corrupted[i]);
            compare(dock.barStyleState, "opaque");
            compare(dock.isBarTransparent, false);
            compare(dock.getBarStyleState(), "opaque");
        }

        dock.destroy();
    }

    function test_reactiveRuntimeTransitions() {
        var dock = dockSyncHarnessComponent.createObject(null);
        verify(dock !== null);

        // Sequence of valid states
        dock.parseShellConfig(JSON.stringify({ bar: { background: "glassy" } }));
        compare(dock.barStyleState, "glassy");
        compare(dock.isBarTransparent, false);
        compare(dock.getBarStyleState(), "glassy");

        dock.parseShellConfig(JSON.stringify({ bar: { background: "none" } }));
        compare(dock.barStyleState, "none");
        compare(dock.isBarTransparent, true);
        compare(dock.getBarStyleState(), "none");

        dock.parseShellConfig(JSON.stringify({ bar: { background: "opaque" } }));
        compare(dock.barStyleState, "opaque");
        compare(dock.isBarTransparent, false);
        compare(dock.getBarStyleState(), "opaque");

        dock.destroy();
    }

    function test_liveShellPrecedenceOverFileView() {
        var dock = dockSyncHarnessComponent.createObject(null);
        verify(dock !== null);

        // File config specifies "none"
        dock.parseShellConfig(JSON.stringify({ bar: { background: "none" } }));
        compare(dock.barStyleState, "none");

        // Live shell specifies "glassy" -> live shell must win
        dock.shell = { barConfig: { background: "glassy" } };
        compare(dock.barStyleState, "glassy");

        // Live shell specifies "opaque" -> live shell must win
        dock.shell = { barConfig: { background: "opaque" } };
        compare(dock.barStyleState, "opaque");

        // Live shell removed -> falls back to file config ("none")
        dock.shell = null;
        compare(dock.barStyleState, "none");

        dock.destroy();
    }

    function test_legacyBooleanReactivity() {
        var dock = dockSyncHarnessComponent.createObject(null);
        verify(dock !== null);

        dock.parseShellConfig(JSON.stringify({ bar: { transparent: true } }));
        compare(dock.barStyleState, "glassy");
        compare(dock.isBarTransparent, false);

        dock.parseShellConfig(JSON.stringify({ bar: { transparent: false } }));
        compare(dock.barStyleState, "opaque");
        compare(dock.isBarTransparent, false);

        dock.destroy();
    }
}
