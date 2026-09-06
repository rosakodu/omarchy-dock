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
}
