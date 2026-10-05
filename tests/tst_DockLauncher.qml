import QtQuick
import QtTest
import "../DockLauncher.js" as DockLauncher

TestCase {
    name: "DockLauncher"

    function launchedId(itemData) {
        var sink = ({ id: null })
        var shell = ({ appLibrary: { launch: function(id, name) { sink.id = id } } })
        DockLauncher.launchApp(shell, itemData, null)
        return sink.id
    }

    function test_entryIdEndingInDesktopSurvives() {
        // Quickshell reports the entry file org.telegram.desktop.desktop under
        // the id org.telegram.desktop, and AppLibrary.launch appends the suffix.
        compare(launchedId({ desktopId: "org.telegram.desktop", appId: "org.telegram.desktop", name: "Telegram" }),
                "org.telegram.desktop")
    }

    function test_plainEntryIdIsPassedThrough() {
        compare(launchedId({ desktopId: "google-chrome", appId: "google-chrome", name: "Google Chrome" }),
                "google-chrome")
    }

    function test_appIdIsUsedWithoutAnEntry() {
        compare(launchedId({ appId: "foo", name: "Foo" }), "foo")
    }

    function test_exeTailIsTrimmed() {
        compare(launchedId({ appId: "Photoshop.exe", name: "Photoshop" }), "Photoshop")
    }

    function launchedFallbackCmd(itemData) {
        var sink = ({ cmd: null })
        var util = ({ execDetached: function(c) { sink.cmd = c } })
        DockLauncher.launchApp(null, itemData, util)
        return sink.cmd
    }

    function test_fallbackTarget_chromeDesktopDoesNotDuplicateExtension() {
        var cmd = launchedFallbackCmd({ desktopId: "google-chrome.desktop", appId: "google-chrome", name: "Google Chrome" })
        verify(cmd != null)
        verify(cmd.indexOf("gtk-launch 'google-chrome.desktop'") !== -1)
        verify(cmd.indexOf("google-chrome.desktop.desktop") === -1 || cmd.indexOf("|| (uwsm-app -- gtk-launch 'google-chrome.desktop.desktop')") !== -1)
    }

    function test_fallbackTarget_telegramDesktopGetsDoubleExtension() {
        var cmd = launchedFallbackCmd({ desktopId: "org.telegram.desktop", appId: "org.telegram.desktop", name: "Telegram" })
        verify(cmd != null)
        verify(cmd.indexOf("gtk-launch 'org.telegram.desktop.desktop'") !== -1)
    }

    function test_fallbackTarget_bareIdGetsDesktopExtension() {
        var cmd = launchedFallbackCmd({ appId: "foot", name: "Foot" })
        verify(cmd != null)
        verify(cmd.indexOf("gtk-launch 'foot.desktop'") !== -1)
    }
}
