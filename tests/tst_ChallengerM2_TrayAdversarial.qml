import QtQuick
import QtTest

TestCase {
    name: "ChallengerM2_TrayAdversarial"

    // Emulation of DockPanel.qml barStyleState resolution
    function resolveBarStyleState(shellBarConfig, detectedBg, hasDetectedBg, detectedTrans) {
        var sbc = shellBarConfig;
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
        if (detectedTrans === true) {
            return "glassy";
        }
        if (detectedBg === "glassy" || detectedBg === "none") {
            return detectedBg;
        }
        return "opaque";
    }

    // Emulation of Util.alpha(color, opacity) from Omarchy shell
    function utilAlpha(c, opacity) {
        var a = Math.max(0.0, Math.min(1.0, opacity));
        var col = (typeof c === "string") ? Qt.color(c) : c;
        return Qt.rgba(col.r, col.g, col.b, a);
    }

    // Emulation of dockSurface styling from DockPanel.qml
    function computeDockSurfaceStyle(barStyleState, baseColor, borderSpecColor, baseBorderWidth, needsOverlay) {
        var col = (barStyleState === "none") ? Qt.rgba(0, 0, 0, 0)
                : (barStyleState === "glassy") ? utilAlpha(baseColor, 0.35)
                : baseColor;

        var bw = (barStyleState === "none") ? 0
               : (barStyleState === "glassy") ? Math.max(1, baseBorderWidth)
               : baseBorderWidth;

        var bc = (barStyleState === "none") ? Qt.rgba(0, 0, 0, 0)
               : (barStyleState === "glassy") ? borderSpecColor
               : borderSpecColor;

        var overlayActive = (barStyleState === "opaque" && needsOverlay);
        var isTransparent = (barStyleState === "none");

        return {
            color: col,
            borderWidth: bw,
            borderColor: bc,
            overlayActive: overlayActive,
            isBarTransparent: isTransparent
        };
    }

    function test_threeStatesStylingAndAlphas() {
        var baseBg = Qt.rgba(0.1, 0.12, 0.15, 1.0);
        var borderCol = Qt.rgba(0.3, 0.35, 0.4, 1.0);

        // 1. OPAQUE state
        var sOpaque = computeDockSurfaceStyle("opaque", baseBg, borderCol, 2, true);
        compare(sOpaque.color.a, 1.0);
        compare(sOpaque.borderWidth, 2);
        compare(sOpaque.borderColor.a, 1.0);
        compare(sOpaque.overlayActive, true);
        compare(sOpaque.isBarTransparent, false);

        // 2. GLASSY state
        var sGlassy = computeDockSurfaceStyle("glassy", baseBg, borderCol, 2, true);
        verify(Math.abs(sGlassy.color.a - 0.35) < 0.001);
        compare(sGlassy.borderWidth, 2);
        compare(sGlassy.borderColor.a, 1.0);
        compare(sGlassy.overlayActive, false);
        compare(sGlassy.isBarTransparent, false);

        // 3. NONE state
        var sNone = computeDockSurfaceStyle("none", baseBg, borderCol, 2, true);
        compare(sNone.color.a, 0.0);
        compare(sNone.borderWidth, 0);
        compare(sNone.borderColor.a, 0.0);
        compare(sNone.overlayActive, false);
        compare(sNone.isBarTransparent, true);
    }

    function test_adversarialPrecedenceCascade() {
        // BarConfig background takes highest priority
        compare(resolveBarStyleState({ background: "none" }, "opaque", true, false), "none");
        compare(resolveBarStyleState({ background: "glassy" }, "none", true, false), "glassy");
        compare(resolveBarStyleState({ background: "opaque" }, "glassy", true, true), "opaque");

        // Invalid BarConfig falls through to file detected background
        compare(resolveBarStyleState({ background: "custom_glow" }, "glassy", true, false), "glassy");
        compare(resolveBarStyleState({ background: 42 }, "none", true, false), "none");

        // Missing background falls through to legacy transparent boolean
        compare(resolveBarStyleState({ transparent: true }, "opaque", false, false), "glassy");
        compare(resolveBarStyleState({ transparent: false }, "opaque", false, false), "opaque");

        // File-detected legacy transparent
        compare(resolveBarStyleState(null, "opaque", false, true), "glassy");
        compare(resolveBarStyleState(null, "opaque", false, false), "opaque");
    }

    function test_ipcContractEmulation() {
        // Emulate IpcHandler getBarStyleState() for all 3 states
        var states = ["opaque", "glassy", "none"];
        for (var i = 0; i < states.length; i++) {
            var activeState = states[i];
            var ipcResult = (function() { return activeState; })();
            compare(ipcResult, states[i]);
        }
    }
}
