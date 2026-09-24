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
}
