import QtQuick
import QtTest
import "../DockMatcher.js" as DockMatcher

TestCase {
    name: "DockMatcher"

    function test_stripDesktop() {
        compare(DockMatcher.stripDesktop("google-chrome.desktop"), "google-chrome")
        compare(DockMatcher.stripDesktop("Photoshop.exe"), "Photoshop")
        compare(DockMatcher.stripDesktop("code"), "code")
        compare(DockMatcher.stripDesktop(""), "")
    }

    function test_desktopEntryIndex_fastLookup() {
        var mockEntries = [
            { id: "google-chrome.desktop", name: "Google Chrome", exec: "/usr/bin/google-chrome-stable", icon: "google-chrome" },
            { id: "org.kde.dolphin.desktop", name: "Dolphin", exec: "dolphin %u", icon: "system-file-manager" },
            { id: "com.mitchellh.ghostty.desktop", name: "Ghostty", exec: "ghostty", icon: "com.mitchellh.ghostty" }
        ]

        var index = DockMatcher.createDesktopEntryIndex(mockEntries)
        verify(index != null)

        // Exact ID lookup O(1)
        var chromeEntry = DockMatcher.findEntryFast(index, "google-chrome")
        verify(chromeEntry != null)
        compare(chromeEntry.name, "Google Chrome")

        // Exact Name lookup O(1)
        var dolphinEntry = DockMatcher.findEntryFast(index, "dolphin")
        verify(dolphinEntry != null)
        compare(dolphinEntry.id, "org.kde.dolphin.desktop")

        // Exec binary lookup O(1)
        var ghosttyEntry = DockMatcher.findEntryFast(index, "ghostty")
        verify(ghosttyEntry != null)
        compare(ghosttyEntry.name, "Ghostty")
    }

    function test_collectMatchingToplevels_activeAndMinimized() {
        var top1 = { appId: "google-chrome", title: "GitHub - Omarchy Dock" }
        var top2 = { appId: "google-chrome", title: "YouTube" }
        var toplevels = [top1, top2]
        var assigned = {}

        // Mock min check: top1 is not min, top2 is min
        var isMin = function(top) { return top === top2 }

        var res = DockMatcher.collectMatchingToplevels(
            "google-chrome",
            { id: "google-chrome.desktop", name: "Google Chrome", icon: "google-chrome" },
            [],
            toplevels,
            assigned,
            null,
            top1, // active top
            isMin,
            null
        )

        compare(res.windowCount, 2)
        compare(res.isActive, true)
        compare(res.isMinimized, false)
        compare(res.activeTopIndex, 0)

        // All minimized scenario
        var assigned2 = {}
        var isAllMin = function(top) { return true }
        var resAllMin = DockMatcher.collectMatchingToplevels(
            "google-chrome",
            { id: "google-chrome.desktop", name: "Google Chrome", icon: "google-chrome" },
            [],
            toplevels,
            assigned2,
            null,
            top1,
            isAllMin,
            null
        )

        compare(resAllMin.windowCount, 2)
        compare(resAllMin.isActive, false) // Minimized cannot be active
        compare(resAllMin.isMinimized, true)
    }

    function test_braveBrowserMatching() {
        var braveTop = { appId: "brave-browser", title: "New Tab - Brave" }
        var toplevels = [braveTop]
        var assigned = {}
        var isMin = function(top) { return false }

        var res = DockMatcher.collectMatchingToplevels(
            "brave-browser",
            { id: "brave-browser.desktop", name: "Brave", icon: "brave-desktop" },
            [],
            toplevels,
            assigned,
            null,
            braveTop,
            isMin,
            null
        )

        compare(res.windowCount, 1)
        compare(res.isActive, true)
        compare(res.matching.length, 1)
        compare(res.matching[0], braveTop)
    }

    function test_transmissionMatching() {
        var transTop = { appId: "com.transmissionbt.transmission_54_620133", title: "Transmission" }
        var transEntry = { id: "transmission-gtk.desktop", name: "Transmission", icon: "transmission-gtk", exec: "transmission-gtk %U" }
        var toplevels = [transTop]
        var assigned = {}
        var isMin = function(top) { return false }

        // 1. Matching dynamic Wayland app ID against pinned transmission-gtk
        var res = DockMatcher.collectMatchingToplevels(
            "transmission-gtk",
            transEntry,
            [transEntry],
            toplevels,
            assigned,
            null,
            transTop,
            isMin,
            null
        )
        compare(res.windowCount, 1)
        compare(res.isActive, true)
        compare(res.matching.length, 1)
        compare(res.matching[0], transTop)

        // 2. findEntryFast resolves dynamic app ID to transmission-gtk entry
        var index = DockMatcher.createDesktopEntryIndex([transEntry])
        var foundEntry = DockMatcher.findEntryFast(index, "com.transmissionbt.transmission_54_620133")
        verify(foundEntry !== null)
        compare(foundEntry.id, "transmission-gtk.desktop")

        // 3. buildDockItems with unpinned Transmission window
        var unpinnedItems = DockMatcher.buildDockItems(
            [],
            [transTop],
            transTop,
            [transEntry],
            null,
            {},
            {},
            0,
            []
        )
        compare(unpinnedItems.length, 1)
        compare(unpinnedItems[0].appId, "transmission-gtk")
        compare(unpinnedItems[0].name, "Transmission")
        compare(unpinnedItems[0].isRunning, true)
        compare(unpinnedItems[0].isActive, true)
    }

    function test_steamGameMatching() {
        var arxTop = { appId: "steam_app_1700", title: "Arx Fatalis" }
        var arxEntry = { id: "Arx Fatalis.desktop", name: "Arx Fatalis", icon: "steam_icon_1700", exec: "steam steam://rungameid/1700" }
        var steamEntry = { id: "steam.desktop", name: "Steam", icon: "steam", exec: "steam %U" }
        var toplevels = [arxTop]
        var assigned = {}
        var isMin = function(top) { return false }

        // 1. Generic Steam dock item should NOT swallow Steam game window
        var steamRes = DockMatcher.collectMatchingToplevels(
            "steam",
            steamEntry,
            [steamEntry, arxEntry],
            toplevels,
            assigned,
            null,
            arxTop,
            isMin,
            null
        )
        compare(steamRes.windowCount, 0)
        compare(steamRes.isActive, false)

        // 2. Matching steam_app_1700 against pinned game desktop entry
        var gameRes = DockMatcher.collectMatchingToplevels(
            "Arx Fatalis",
            arxEntry,
            [steamEntry, arxEntry],
            toplevels,
            assigned,
            null,
            arxTop,
            isMin,
            null
        )
        compare(gameRes.windowCount, 1)
        compare(gameRes.isActive, true)
        compare(gameRes.matching[0], arxTop)

        // 3. findEntryFast resolves steam_app_1700 to Arx Fatalis desktop entry
        var index = DockMatcher.createDesktopEntryIndex([steamEntry, arxEntry])
        var found = DockMatcher.findEntryFast(index, "steam_app_1700")
        verify(found !== null)
        compare(found.name, "Arx Fatalis")

        // 4. buildDockItems with unpinned Steam game window
        var unpinned = DockMatcher.buildDockItems(
            [],
            [arxTop],
            arxTop,
            [steamEntry, arxEntry],
            null,
            {},
            {},
            0,
            []
        )
        compare(unpinned.length, 1)
        compare(unpinned[0].appId, "Arx Fatalis")
        compare(unpinned[0].name, "Arx Fatalis")
    }

    function test_yandexBrowserMatching() {
        var yandexTop = { appId: "yandex-browser", title: "Яндекс — быстрый поиск в интернете" }
        var yandexEntry = { id: "yandex-browser.desktop", name: "Yandex Browser", icon: "yandex-browser", exec: "/usr/bin/yandex-browser-stable %U" }
        var toplevels = [yandexTop]
        var assigned = {}
        var isMin = function(top) { return false }

        var res = DockMatcher.collectMatchingToplevels(
            "yandex-browser",
            yandexEntry,
            [yandexEntry],
            toplevels,
            assigned,
            null,
            yandexTop,
            isMin,
            null
        )
        compare(res.windowCount, 1)
        compare(res.isActive, true)
        compare(res.matching.length, 1)
        compare(res.matching[0], yandexTop)
    }

    // A dock icon numbers its windows in its own sticky creation order, but the
    // helper script resolves a window against Hyprland's client list, whose
    // order changes on its own — a lock screen, a workspace move or a restore
    // from the scratchpad is enough. Passing a position therefore aims at
    // whichever window happens to sit there now; an address names one window.
    function test_hyprAddressForFindsTheWindowByIdentity() {
        var firstWayland = { title: "first" }
        var secondWayland = { title: "second" }
        var hyprToplevels = [
            { address: "0xaaa111", wayland: firstWayland },
            { address: "0xbbb222", wayland: secondWayland }
        ]
        compare(DockMatcher.hyprAddressFor(secondWayland, hyprToplevels), "0xbbb222")
        compare(DockMatcher.hyprAddressFor(firstWayland, hyprToplevels), "0xaaa111")
    }

    function test_hyprAddressForPrefixesABareHexAddress() {
        // The script recognises an address only by its 0x prefix, so a bare
        // address from Hyprland has to grow one before it is passed along.
        var wayland = { title: "first" }
        compare(DockMatcher.hyprAddressFor(wayland, [{ address: "ccc333", wayland: wayland }]), "0xccc333")
    }

    function test_hyprAddressForIgnoresPositionAndOrder() {
        // The same window keeps its address after Hyprland reshuffles its list.
        var wayland = { title: "first" }
        var before = [{ address: "0xaaa111", wayland: wayland }, { address: "0xbbb222", wayland: {} }]
        var after = [{ address: "0xbbb222", wayland: {} }, { address: "0xaaa111", wayland: wayland }]
        compare(DockMatcher.hyprAddressFor(wayland, before), DockMatcher.hyprAddressFor(wayland, after))
    }

    function test_hyprAddressForReturnsNothingForAnUnknownWindow() {
        // A window that closed between the click and the lookup has no address,
        // and the caller falls back rather than aiming at a stranger.
        compare(DockMatcher.hyprAddressFor({ title: "gone" }, [{ address: "0xaaa111", wayland: {} }]), "")
    }

    function test_hyprAddressForHandlesMissingOperands() {
        compare(DockMatcher.hyprAddressFor(null, [{ address: "0xaaa111", wayland: {} }]), "")
        compare(DockMatcher.hyprAddressFor({ title: "first" }, null), "")
        compare(DockMatcher.hyprAddressFor(null, null), "")
    }

    function test_cleanWindowAppId() {
        compare(DockMatcher.cleanWindowAppId("SyncTERM 1.8 - Wayland"), "SyncTERM")
        compare(DockMatcher.cleanWindowAppId("SyncTERM 1.8"), "SyncTERM")
        compare(DockMatcher.cleanWindowAppId("SyncTERM (Wayland)"), "SyncTERM")
        compare(DockMatcher.cleanWindowAppId("SyncTERM - X11"), "SyncTERM")
        compare(DockMatcher.cleanWindowAppId("Dolphin 5.0"), "Dolphin")
        compare(DockMatcher.cleanWindowAppId("Claude Desktop"), "Claude Desktop")
        compare(DockMatcher.cleanWindowAppId(""), "")
    }

    function test_syncTermMatching() {
        var synctermEntry = { id: "syncterm.desktop", name: "SyncTERM", exec: "syncterm %u", icon: "syncterm" }
        var entries = [synctermEntry]
        var index = DockMatcher.createDesktopEntryIndex(entries)

        // 1. Fast lookup from Wayland app_id with version and backend suffix
        var entryFromWayland = DockMatcher.findEntryFast(index, "SyncTERM 1.8 - Wayland")
        verify(entryFromWayland != null)
        compare(entryFromWayland.id, "syncterm.desktop")

        // 2. Fast lookup from mixed-case appId
        var entryFromMixedCase = DockMatcher.findEntryFast(index, "SyncTERM")
        verify(entryFromMixedCase != null)
        compare(entryFromMixedCase.id, "syncterm.desktop")

        // 3. Toplevel window matching
        var top = { appId: "SyncTERM 1.8 - Wayland", title: "SyncTERM 1.8" }
        compare(DockMatcher.matchToplevel(top, "syncterm", synctermEntry, entries), true)

        // 4. buildDockItems with running unpinned SyncTERM window:
        // Must normalize rAppId to "syncterm" (so pinning and launching work seamlessly)
        var items = DockMatcher.buildDockItems([], [top], top, entries, null, {}, {}, 0, [])
        compare(items.length, 1)
        compare(items[0].appId, "syncterm")
        compare(items[0].id, "syncterm")
        compare(items[0].desktopId, "syncterm.desktop")
        compare(items[0].rawIcon, "syncterm")
        compare(items[0].isRunning, true)
        compare(items[0].isActive, true)

        // 5. buildDockItems with pinned legacy "SyncTERM" and running window:
        // Must resolve to syncterm.desktop and match the running window
        var pinnedItems = DockMatcher.buildDockItems(["SyncTERM"], [top], top, entries, null, {}, {}, 0, [])
        compare(pinnedItems.length, 1)
        compare(pinnedItems[0].desktopId, "syncterm.desktop")
        compare(pinnedItems[0].isRunning, true)
        compare(pinnedItems[0].isActive, true)
    }

    function test_claudeDesktopMatching() {
        var claudeEntry = { id: "claude-desktop.desktop", name: "Claude", exec: "claude-desktop", icon: "claude-desktop" }
        var entries = [claudeEntry]
        var index = DockMatcher.createDesktopEntryIndex(entries)

        var found = DockMatcher.findEntryFast(index, "Claude Desktop")
        verify(found != null)
        compare(found.id, "claude-desktop.desktop")

        var top = { appId: "Claude Desktop", title: "Claude" }
        compare(DockMatcher.matchToplevel(top, "claude-desktop", claudeEntry, entries), true)
    }

    function test_getCandidates_caseAndVariants() {
        var cands1 = DockMatcher.getCandidates("SyncTERM", "", "SyncTERM")
        verify(cands1.indexOf("syncterm") !== -1)

        var cands2 = DockMatcher.getCandidates("", "", "SyncTERM 1.8 - Wayland")
        verify(cands2.indexOf("syncterm") !== -1)

        var cands3 = DockMatcher.getCandidates("", "", "Claude Desktop")
        verify(cands3.indexOf("claude-desktop") !== -1)
        verify(cands3.indexOf("claude") !== -1)
    }
}
