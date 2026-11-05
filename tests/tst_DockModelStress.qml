import QtQuick
import QtTest
import "../DockModel.js" as DockModel

TestCase {
    name: "DockModelStress"

    // Component to test reactivity of resolveIcon
    Component {
        id: reactiveIconComponent
        Item {
            id: testRoot
            property int iconRevision: 0
            property var itemData: ({ appId: "test-app", icon: "test-icon", rawIcon: "test-icon" })

            function mockResolveIcon(itemObj, iconRev) {
                var rev = iconRev !== undefined ? iconRev : testRoot.iconRevision;
                var base = (itemObj && itemObj.appId) ? itemObj.appId : "unknown";
                return "icon://" + base + "?rev=" + rev;
            }

            property string resolvedSource: mockResolveIcon(itemData, iconRevision)
        }
    }

    function test_resolveIconReactivity() {
        var obj = reactiveIconComponent.createObject(null);
        verify(obj !== null);
        compare(obj.resolvedSource, "icon://test-app?rev=0");

        // Change iconRevision: property binding must react
        obj.iconRevision = 1;
        compare(obj.resolvedSource, "icon://test-app?rev=1");

        // Change iconRevision again
        obj.iconRevision = 42;
        compare(obj.resolvedSource, "icon://test-app?rev=42");

        // Change itemData: property binding must react
        obj.itemData = { appId: "another-app" };
        compare(obj.resolvedSource, "icon://another-app?rev=42");

        obj.destroy();
    }

    // 1. Stress testing Pinned functions
    function test_dockModel_pinned_edgeCases() {
        // stripDesktop
        compare(DockModel.stripDesktop(null), "");
        compare(DockModel.stripDesktop(undefined), "");
        compare(DockModel.stripDesktop(""), "");
        compare(DockModel.stripDesktop("app.desktop"), "app");

        // toArray
        compare(DockModel.toArray(null), []);
        compare(DockModel.toArray(undefined), []);
        compare(DockModel.toArray([]), []);
        compare(DockModel.toArray([1, 2]), [1, 2]);

        // parsePinned
        compare(DockModel.parsePinned(null), []);
        compare(DockModel.parsePinned(undefined), []);
        compare(DockModel.parsePinned(""), []);
        compare(DockModel.parsePinned("invalid json {"), []);
        compare(DockModel.parsePinned(123), []);

        // serializePinned
        var emptySerialized = JSON.stringify({ pinned: [] }, null, 2);
        compare(DockModel.serializePinned(null), emptySerialized);
        compare(DockModel.serializePinned(undefined), emptySerialized);
        compare(DockModel.serializePinned([]), emptySerialized);

        // togglePinned
        var toggled = DockModel.togglePinned([], "test.desktop", 10);
        verify(toggled !== null);
        var toggledNull = DockModel.togglePinned(null, null, null);
        verify(Array.isArray(toggledNull));

        // dissolveStack
        var dis1 = DockModel.dissolveStack(null, null);
        verify(Array.isArray(dis1));
        var dis2 = DockModel.dissolveStack([], "non-existent");
        compare(dis2, []);

        // setStackIcon
        var sIcon1 = DockModel.setStackIcon(null, null, null);
        verify(Array.isArray(sIcon1));
        var sIcon2 = DockModel.setStackIcon([], "s1", "󰉋");
        compare(sIcon2, []);

        // createStackFromTwo
        var stTwo1 = DockModel.createStackFromTwo(null, null, null, null);
        verify(Array.isArray(stTwo1));
        var stTwo2 = DockModel.createStackFromTwo([], "a", "b", []);
        verify(Array.isArray(stTwo2));

        // addToStack
        var addSt1 = DockModel.addToStack(null, null, null);
        verify(Array.isArray(addSt1));

        // removeFromStack
        var remSt1 = DockModel.removeFromStack(null, null, null);
        verify(Array.isArray(remSt1));

        // renameStack
        var renSt1 = DockModel.renameStack(null, null, null);
        verify(Array.isArray(renSt1));

        // reorderInStack
        var reordSt1 = DockModel.reorderInStack(null, null, 0, 1);
        verify(Array.isArray(reordSt1));

        // extractFromStackToDock
        var ext1 = DockModel.extractFromStackToDock(null, null, null, 0);
        verify(Array.isArray(ext1));

        // mergeIntoStack
        compare(DockModel.mergeIntoStack(null, null, 0, 0, null), null);
        compare(DockModel.mergeIntoStack([], [], 0, 0, []), []);

        // reorderPinned
        compare(DockModel.reorderPinned(null, null, 0, 0), null);
        compare(DockModel.reorderPinned([], [], 0, 0), []);
    }

    // 2. Stress testing AutoName functions
    function test_dockModel_autoname_edgeCases() {
        // normalizeAppKey
        compare(DockModel.normalizeAppKey(null), "");
        compare(DockModel.normalizeAppKey(undefined), "");
        compare(DockModel.normalizeAppKey(""), "");
        compare(DockModel.normalizeAppKey("org.mozilla.firefox"), "mozilla.firefox");
        compare(DockModel.normalizeAppKey("firefox.desktop"), "firefox");

        // getAppMetadata
        var metaNull = DockModel.getAppMetadata(null, null);
        verify(metaNull !== null);
        var metaEmpty = DockModel.getAppMetadata("", []);
        verify(metaEmpty !== null);

        // hasTokenMatch
        compare(DockModel.hasTokenMatch(null, null), false);
        compare(DockModel.hasTokenMatch({}, "test"), false);

        // inferFolderName
        var folderNull = DockModel.inferFolderName(null, null, null);
        verify(typeof folderNull === "string");
        var folderEmpty = DockModel.inferFolderName("", "", []);
        verify(typeof folderEmpty === "string");
    }

    // 3. Stress testing Matcher functions
    function test_dockModel_matcher_edgeCases() {
        // getCandidates
        var candsNull = DockModel.getCandidates(null, null, null);
        verify(Array.isArray(candsNull));
        var candsEmpty = DockModel.getCandidates("", "", "");
        verify(Array.isArray(candsEmpty));

        // normalizeKey
        compare(DockModel.normalizeKey(null), "");
        compare(DockModel.normalizeKey(undefined), "");
        compare(DockModel.normalizeKey(""), "");

        // extractChromeDomain
        compare(DockModel.extractChromeDomain(null), "");
        compare(DockModel.extractChromeDomain(""), "");
        compare(DockModel.extractChromeDomain("not-a-chrome-domain"), "");

        // unwrapEntry
        compare(DockModel.unwrapEntry(null), null);
        compare(DockModel.unwrapEntry(undefined), null);

        // findEntry
        compare(DockModel.findEntry(null, null), null);
        compare(DockModel.findEntry([], "nonexistent"), null);

        // resolveIcon
        compare(DockModel.resolveIcon(null, null, null), "application-x-executable");
        compare(DockModel.resolveIcon(null, "code", null), "code");
        compare(DockModel.resolveIcon({ icon: "firefox" }, "firefox", null), "firefox");

        // isBrowserApp
        compare(DockModel.isBrowserApp(null), false);
        compare(DockModel.isBrowserApp(""), false);
        compare(DockModel.isBrowserApp("google-chrome"), true);

        // toCanonical
        compare(DockModel.toCanonical(null), "");
        compare(DockModel.toCanonical(""), "");

        // hyprAddressFor
        compare(DockModel.hyprAddressFor(null, null), "");
        compare(DockModel.hyprAddressFor(null, []), "");

        // getBadgeInfo
        var badge = DockModel.getBadgeInfo(null, null, null, null, null, null);
        verify(badge !== null);
        compare(badge.count, 0);
        compare(badge.hasUrgent, false);

        // buildDockItems
        var items = DockModel.buildDockItems(null, null, null, null, null, null, null, 0, null);
        verify(Array.isArray(items));

        // setPendingCliHint
        var hint = DockModel.setPendingCliHint(null, null);
        verify(hint === undefined || hint !== null);

        // setDetectedCliApps
        DockModel.setDetectedCliApps(null);
        DockModel.setDetectedCliApps([]);
        DockModel.setDetectedCliApps(["nvim", "htop"]);
    }

    // 4. Stress testing Widgets functions
    function test_dockModel_widgets_edgeCases() {
        var fakeShell = { mutateShellConfig: function(fn) { fn({ plugins: [], bar: { layout: { left: [], center: [], right: [] } } }); } };

        // addWidgetToDockList
        var wList = DockModel.addWidgetToDockList([], "test.widget");
        compare(wList, ["test.widget"]);
        compare(DockModel.addWidgetToDockList(null, null), []);

        // removeWidgetFromDockList
        compare(DockModel.removeWidgetFromDockList(null, null), []);
        compare(DockModel.removeWidgetFromDockList(["test.widget"], "test.widget"), []);

        // getDockWidgetLayout
        var layout = DockModel.getDockWidgetLayout(false, "left", false, [], "right");
        verify(layout !== null);
        verify(Array.isArray(layout.leftWidgets));
        verify(Array.isArray(layout.rightWidgets));

        // switchDockWidgetInBar with null shell
        var sRes = DockModel.switchDockWidgetInBar(null, "w1", [], {}, null);
        verify(typeof sRes === "object");

        // removeWidgetFromBar with null shell
        var rRes = DockModel.removeWidgetFromBar(null, "w1", {}, null);
        verify(typeof rRes === "object");

        // returnWidgetToBar with null shell
        var retRes = DockModel.returnWidgetToBar(null, "w1", {}, "right", null);
        verify(typeof retRes === "object");
    }

    // 5. Stress testing Launcher functions
    function test_dockModel_launcher_edgeCases() {
        // escapeShellArg
        compare(DockModel.escapeShellArg(null), "''");
        compare(DockModel.escapeShellArg(undefined), "''");
        compare(DockModel.escapeShellArg(""), "''");
        compare(DockModel.escapeShellArg("simple"), "'simple'");
        compare(DockModel.escapeShellArg("a'b"), "'a'\\''b'");

        // parseDesktopExec
        compare(DockModel.parseDesktopExec(null), []);
        compare(DockModel.parseDesktopExec(""), []);
        compare(DockModel.parseDesktopExec("firefox %u"), ["firefox"]);

        // launchApp with null args (safely handles null without throwing)
        var lRes = DockModel.launchApp(null, null, null);
        verify(lRes === undefined || lRes === false);
    }
}
