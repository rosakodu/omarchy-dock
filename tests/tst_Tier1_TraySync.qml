import QtQuick
import QtTest

TestCase {
    name: "Tier1_TraySync"

    function resolveTrayState(shellBarConfig, detectedBackground, legacyTransparent) {
        if (shellBarConfig && shellBarConfig.background !== undefined) {
            var val = shellBarConfig.background;
            if (val === "opaque" || val === "glassy" || val === "none") return val;
        }
        if (detectedBackground === "opaque" || detectedBackground === "glassy" || detectedBackground === "none") {
            return detectedBackground;
        }
        if (shellBarConfig && shellBarConfig.transparent !== undefined) {
            return (shellBarConfig.transparent === true) ? "glassy" : "opaque";
        }
        if (legacyTransparent !== undefined) {
            return (legacyTransparent === true) ? "glassy" : "opaque";
        }
        return "opaque";
    }

    function computeStyle(state, systemBorderSize) {
        var size = (systemBorderSize !== undefined) ? systemBorderSize : 2;
        if (state === "opaque") {
            return { alpha: 1.0, borderWidth: size, blurEnabled: false };
        } else if (state === "glassy") {
            return { alpha: 0.35, borderWidth: Math.max(1, size), blurEnabled: true };
        } else if (state === "none") {
            return { alpha: 0.0, borderWidth: 0, blurEnabled: false };
        }
        return { alpha: 1.0, borderWidth: size, blurEnabled: false };
    }

    function test_trayStatePrecedence() {
        // 1. shellBarConfig wins
        var s1 = resolveTrayState({ background: "glassy" }, "opaque", false);
        compare(s1, "glassy");

        // 2. detectedBackground wins when shellBarConfig is missing
        var s2 = resolveTrayState(null, "none", false);
        compare(s2, "none");

        // 3. legacy transparent boolean
        var s3 = resolveTrayState(null, null, true);
        compare(s3, "glassy");

        // 4. Default fallback
        var s4 = resolveTrayState(null, null, undefined);
        compare(s4, "opaque");
    }

    function test_opaqueStateProperties() {
        var style = computeStyle("opaque", 2);
        compare(style.alpha, 1.0);
        compare(style.borderWidth, 2);
        compare(style.blurEnabled, false);
    }

    function test_glassyStateProperties() {
        var style = computeStyle("glassy", 2);
        compare(style.alpha, 0.35);
        compare(style.borderWidth, 2);
        compare(style.blurEnabled, true);
    }

    function test_noneStateProperties() {
        var style = computeStyle("none", 2);
        compare(style.alpha, 0.0);
        compare(style.borderWidth, 0);
        compare(style.blurEnabled, false);
    }

    function test_corruptedValuesFallback() {
        var s1 = resolveTrayState({ background: "neon" }, "invalid", undefined);
        compare(s1, "opaque");

        var s2 = resolveTrayState({ background: 123 }, null, undefined);
        compare(s2, "opaque");
    }

    function test_dynamicStateReactivity() {
        var states = ["opaque", "glassy", "none"];
        var expectedAlphas = [1.0, 0.35, 0.0];
        for (var i = 0; i < states.length; i++) {
            var st = computeStyle(states[i], 2);
            compare(st.alpha, expectedAlphas[i]);
        }
    }
}
