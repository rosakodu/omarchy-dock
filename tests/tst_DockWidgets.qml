import QtQuick
import QtTest
import "../DockWidgets.js" as DockWidgets

TestCase {
    name: "DockWidgets"

    function test_switchDockWidgetInBar_addsToPlugins() {
        var fakeConfig = {
            bar: {
                layout: {
                    left: ["omarchy.menu"],
                    center: ["rosakodu.dock"],
                    right: ["silvaio.gamemode", "omarchy.audio"]
                }
            },
            plugins: []
        };
        var fakeShell = {
            mutateShellConfig: function(fn) {
                fn(fakeConfig);
            }
        };

        var saved = {};
        saved = DockWidgets.switchDockWidgetInBar(fakeShell, "silvaio.gamemode", [], saved, null);

        // 1. Should be removed from bar.layout.right
        compare(fakeConfig.bar.layout.right.indexOf("silvaio.gamemode"), -1);
        // 2. Should be added to plugins to keep enabled
        var foundInPlugins = false;
        for (var i = 0; i < fakeConfig.plugins.length; i++) {
            var p = fakeConfig.plugins[i];
            var pid = (typeof p === "string") ? p : (p && p.id);
            if (pid === "silvaio.gamemode") foundInPlugins = true;
        }
        compare(foundInPlugins, true);
        compare(saved["silvaio.gamemode"].addedToPlugins, true);

        // 3. Switching back (returning to bar)
        DockWidgets.switchDockWidgetInBar(fakeShell, "", ["silvaio.gamemode"], saved, null);

        // Should be back in bar.layout.right
        var foundInBar = false;
        for (var j = 0; j < fakeConfig.bar.layout.right.length; j++) {
            var b = fakeConfig.bar.layout.right[j];
            var bid = (typeof b === "string") ? b : (b && b.id);
            if (bid === "silvaio.gamemode") foundInBar = true;
        }
        compare(foundInBar, true);

        // Should be removed from plugins
        var stillInPlugins = false;
        for (var k = 0; k < fakeConfig.plugins.length; k++) {
            var p2 = fakeConfig.plugins[k];
            var pid2 = (typeof p2 === "string") ? p2 : (p2 && p2.id);
            if (pid2 === "silvaio.gamemode") stillInPlugins = true;
        }
        compare(stillInPlugins, false);
    }

    function test_addWidgetToDockList() {
        var list = DockWidgets.addWidgetToDockList([], "silvaio.gamemode");
        compare(list, ["silvaio.gamemode"]);

        var withApps = DockWidgets.addWidgetToDockList(list, "omarchy.apps");
        compare(withApps, ["omarchy.apps", "silvaio.gamemode"]);

        var replaced = DockWidgets.addWidgetToDockList(withApps, "lgse.sandman");
        compare(replaced, ["omarchy.apps", "lgse.sandman"]);

        var removed = DockWidgets.removeWidgetFromDockList(replaced, "lgse.sandman");
        compare(removed, ["omarchy.apps"]);
    }

    function test_getDockWidgetLayout() {
        var layout = DockWidgets.getDockWidgetLayout(true, "left", true, ["omarchy.apps", "silvaio.gamemode"], "right");
        compare(layout.leftWidgets, ["omarchy.apps"]);
        compare(layout.rightWidgets, ["silvaio.gamemode"]);
    }
}
