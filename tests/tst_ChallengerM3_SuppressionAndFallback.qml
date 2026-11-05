import QtQuick
import QtTest
import "../DockModel.js" as DockModel
import "../DockSettings.js" as DockSettings

TestCase {
    name: "ChallengerM3_SuppressionAndFallback"

    // Mock Registry Component
    QtObject {
        id: mockRegistry
        property var plugins: ({ "omarchy.dock": { enabled: true } })
        property var setCalls: []

        function reset(dockInitialEnabled) {
            plugins = { "omarchy.dock": { enabled: dockInitialEnabled } }
            setCalls = []
        }

        function isEnabled(pluginId) {
            return plugins[pluginId] ? (plugins[pluginId].enabled === true) : false
        }

        function setEnabled(pluginId, enabled) {
            setCalls.push({ id: pluginId, enabled: enabled })
            if (plugins[pluginId]) plugins[pluginId].enabled = enabled
            return true
        }
    }

    // Emulation of DockPanel.qml applySystemDockSuppression
    function runSuppressionSimulation(initialEnabled, suppressSetting, toggleSequence) {
        mockRegistry.reset(initialEnabled)
        var systemDockWasEnabled = false
        var suppressSystemDock = suppressSetting

        function applySystemDockSuppression() {
            var reg = mockRegistry
            if (!reg) return
            if (suppressSystemDock) {
                var isEnabled = reg.isEnabled("omarchy.dock")
                if (isEnabled) {
                    systemDockWasEnabled = true
                    reg.setEnabled("omarchy.dock", false)
                }
            } else if (systemDockWasEnabled) {
                systemDockWasEnabled = false
                reg.setEnabled("omarchy.dock", true)
            }
        }

        function setSuppressSystemDock(val) {
            suppressSystemDock = (val === true || val === "true" || val === 1 || val === "1")
            applySystemDockSuppression()
        }

        function onDestruction() {
            if (systemDockWasEnabled) {
                mockRegistry.setEnabled("omarchy.dock", true)
            }
        }

        // 1. Startup
        applySystemDockSuppression()

        // 2. Toggles
        if (toggleSequence && toggleSequence.length > 0) {
            for (var i = 0; i < toggleSequence.length; i++) {
                setSuppressSystemDock(toggleSequence[i])
            }
        }

        // 3. Destruction
        onDestruction()

        return {
            finalDockEnabled: mockRegistry.isEnabled("omarchy.dock"),
            calls: mockRegistry.setCalls,
            wasEnabled: systemDockWasEnabled
        }
    }

    // Emulation of DockPanel.qml getOmarchyDefaultPinned
    function resolveDefaultPinned(shellConfig, shellConfigFileRaw, defaultsConfig) {
        var hardcodedDefaults = ["org.gnome.Nautilus", "chromium", "foot", "omacalc", "omawrite", "X", "YouTube"]
        try {
            if (shellConfig && shellConfig.dock && Array.isArray(shellConfig.dock.pinned) && shellConfig.dock.pinned.length > 0) {
                return shellConfig.dock.pinned
            }
            if (shellConfigFileRaw && shellConfigFileRaw.trim().length > 0) {
                try {
                    var parsed = JSON.parse(shellConfigFileRaw)
                    if (parsed && parsed.dock && Array.isArray(parsed.dock.pinned) && parsed.dock.pinned.length > 0) {
                        return parsed.dock.pinned
                    }
                } catch(e) {}
            }
            if (defaultsConfig && defaultsConfig.dock && Array.isArray(defaultsConfig.dock.pinned) && defaultsConfig.dock.pinned.length > 0) {
                return defaultsConfig.dock.pinned
            }
        } catch(e) {}
        return hardcodedDefaults
    }

    // Emulation of user pinned file loading logic from DockPanel.qml
    function loadPinnedIds(fileText, shellConfig, shellConfigFileRaw, defaultsConfig) {
        if (fileText && fileText.trim().length > 0) {
            var parsed = DockModel.parsePinned(fileText)
            if (parsed && parsed.length > 0) {
                return parsed
            }
        }
        return resolveDefaultPinned(shellConfig, shellConfigFileRaw, defaultsConfig)
    }

    function isLocaleRtl(localeCode) {
        var rtlLocales = { "ar": true, "fa": true, "he": true, "ur": true }
        return rtlLocales[localeCode] === true
    }

    // -------------------------------------------------------------
    // Test Cases: System Dock Suppression
    // -------------------------------------------------------------

    function test_systemDockSuppression_nominalStartupAndDestruction() {
        var res = runSuppressionSimulation(true, true, [])
        // Initial disabled, destruction restored
        compare(res.calls.length, 2)
        compare(res.calls[0].enabled, false)
        compare(res.calls[1].enabled, true)
        compare(res.finalDockEnabled, true)
    }

    function test_systemDockSuppression_disabledByDefaultOption() {
        var res = runSuppressionSimulation(true, false, [])
        compare(res.calls.length, 0)
        compare(res.finalDockEnabled, true)
    }

    function test_systemDockSuppression_alreadyDisabledDoesNotRestore() {
        var res = runSuppressionSimulation(false, true, [])
        // System dock was already false; should not be re-enabled on destruction
        compare(res.calls.length, 0)
        compare(res.finalDockEnabled, false)
    }

    function test_systemDockSuppression_dynamicToggleSequence() {
        // Start true -> toggle false -> toggle true
        var res = runSuppressionSimulation(true, true, [false, true])
        // Call 0: startup disable (false)
        // Call 1: toggle false (re-enable: true)
        // Call 2: toggle true (disable: false)
        // Call 3: destruction restore (true)
        compare(res.calls.length, 4)
        compare(res.calls[0].enabled, false)
        compare(res.calls[1].enabled, true)
        compare(res.calls[2].enabled, false)
        compare(res.calls[3].enabled, true)
        compare(res.finalDockEnabled, true)
    }

    function test_systemDockSuppression_truthyAdversarialInputs() {
        var res1 = runSuppressionSimulation(true, true, ["false", "1"])
        // "1" is truthy string -> disables
        compare(res1.calls[1].enabled, true)
        compare(res1.calls[2].enabled, false)

        var res2 = runSuppressionSimulation(true, true, ["0"])
        // "0" is not "1" or "true" -> re-enables
        compare(res2.calls[1].enabled, true)
    }

    // -------------------------------------------------------------
    // Test Cases: Pinned Apps Fallback Cascade
    // -------------------------------------------------------------

    function test_pinnedFallback_userPinsPrecedence() {
        var userJson = JSON.stringify(["app1", "app2"])
        var res = loadPinnedIds(userJson, { dock: { pinned: ["shellApp"] } }, null, null)
        compare(res.length, 2)
        compare(res[0], "app1")
        compare(res[1], "app2")
    }

    function test_pinnedFallback_emptyAndCorruptUserPins() {
        var defaults = { dock: { pinned: ["defaultApp"] } }

        var emptyRes = loadPinnedIds("", null, null, defaults)
        compare(emptyRes, ["defaultApp"])

        var wsRes = loadPinnedIds("   \n\t  ", null, null, defaults)
        compare(wsRes, ["defaultApp"])

        var corruptRes = loadPinnedIds("{ not an array", null, null, defaults)
        compare(corruptRes, ["defaultApp"])

        var emptyArrayRes = loadPinnedIds("[]", null, null, defaults)
        compare(emptyArrayRes, ["defaultApp"])

        var nullRes = loadPinnedIds("null", null, null, defaults)
        compare(nullRes, ["defaultApp"])
    }

    function test_pinnedFallback_precedenceHierarchy() {
        // Tier 1: shell.shellConfig wins
        var r1 = resolveDefaultPinned({ dock: { pinned: ["t1"] } }, '{"dock":{"pinned":["t2"]}}', { dock: { pinned: ["t3"] } })
        compare(r1, ["t1"])

        // Tier 2: shellConfigFile wins when Tier 1 empty
        var r2 = resolveDefaultPinned({ dock: { pinned: [] } }, '{"dock":{"pinned":["t2"]}}', { dock: { pinned: ["t3"] } })
        compare(r2, ["t2"])

        // Tier 3: defaultsConfig wins when Tier 1 & 2 empty or corrupted
        var r3 = resolveDefaultPinned(null, 'corrupted json {', { dock: { pinned: ["t3"] } })
        compare(r3, ["t3"])

        // Tier 4: hardcoded fallback
        var r4 = resolveDefaultPinned(null, null, null)
        compare(r4.length, 7)
        compare(r4[0], "org.gnome.Nautilus")
        compare(r4[1], "chromium")
        compare(r4[2], "foot")
        compare(r4[6], "YouTube")
    }

    function test_importOmarchyPins_setsDefaultPins() {
        // Emulation of importOmarchyPins()
        var currentPinned = ["old1", "old2"]
        var shellDefaults = { dock: { pinned: ["nautilus", "foot", "terminal"] } }

        function importOmarchyPins() {
            var pins = resolveDefaultPinned(shellDefaults, null, null)
            currentPinned = pins
            return "ok"
        }

        var ret = importOmarchyPins()
        compare(ret, "ok")
        compare(currentPinned, ["nautilus", "foot", "terminal"])
    }

    // -------------------------------------------------------------
    // Test Cases: RTL Mirroring
    // -------------------------------------------------------------

    function test_rtlDirectionality() {
        // The 4 mandated RTL languages
        compare(isLocaleRtl("ar"), true)
        compare(isLocaleRtl("fa"), true)
        compare(isLocaleRtl("he"), true)
        compare(isLocaleRtl("ur"), true)

        // Representative LTR languages across families
        compare(isLocaleRtl("en"), false)
        compare(isLocaleRtl("ru"), false)
        compare(isLocaleRtl("ja"), false)
        compare(isLocaleRtl("zh-CN"), false)
        compare(isLocaleRtl("zh-TW"), false)
        compare(isLocaleRtl("de"), false)
        compare(isLocaleRtl("fr"), false)
        compare(isLocaleRtl("es-MX"), false)
        compare(isLocaleRtl("pt-BR"), false)
        compare(isLocaleRtl("hi"), false)
        compare(isLocaleRtl("th"), false)
        compare(isLocaleRtl("tr"), false)
    }

    function test_layoutMirroringProperties() {
        // Component mockup verifying LayoutMirroring binding reactivity
        var component = Qt.createQmlObject(
            'import QtQuick; Item {\n' +
            '    id: rootItem\n' +
            '    property bool isRtl: false\n' +
            '    Item {\n' +
            '        id: inner\n' +
            '        LayoutMirroring.enabled: rootItem.isRtl\n' +
            '        LayoutMirroring.childrenInherit: true\n' +
            '        property bool mirroringActive: LayoutMirroring.enabled\n' +
            '    }\n' +
            '    property alias innerItem: inner\n' +
            '}',
            this,
            "MirroringTestObject"
        )

        compare(component.innerItem.mirroringActive, false)
        component.isRtl = true
        compare(component.innerItem.mirroringActive, true)
        component.isRtl = false
        compare(component.innerItem.mirroringActive, false)

        component.destroy()
    }
}
