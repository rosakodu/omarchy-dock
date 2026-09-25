import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs.Commons

Item {
    id: tracker

    property var shell: null
    property var knownWindows: []
    
    readonly property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/dock-badges.json"

    // In-memory canonical state backed by PersistentProperties
    property var canonicalCounts: ({})
    property var canonicalUrgent: ({})
    property var lastNotifTimestamps: ({})

    PersistentProperties {
        id: persisted
        reloadableId: "omarchy-dock-notification-tracker"
        property var counts: ({})
        property var urgent: ({})
    }

    FileView {
        id: badgeStateFile
        path: tracker.statePath
        onLoaded: tracker.loadDiskState()
    }

    Process {
        id: saveProc
        running: false
    }

    Timer {
        id: saveDebounceTimer
        interval: 400
        repeat: false
        onTriggered: {
            persisted.counts = tracker.canonicalCounts
            persisted.urgent = tracker.canonicalUrgent
            try {
                var jsonStr = JSON.stringify({
                    counts: tracker.canonicalCounts,
                    urgent: tracker.canonicalUrgent
                })
                saveProc.command = ["python3", "-c",
                    "import sys, pathlib; p = pathlib.Path(sys.argv[1]); p.parent.mkdir(parents=True, exist_ok=True); p.write_text(sys.argv[2], encoding='utf-8')",
                    tracker.statePath, jsonStr]
                saveProc.running = true
            } catch (e) {}
        }
    }

    function scheduleSave() {
        persisted.counts = tracker.canonicalCounts
        persisted.urgent = tracker.canonicalUrgent
        saveDebounceTimer.restart()
    }

    function loadDiskState() {
        // Priority 1: In-process PersistentProperties (survives theme reload)
        if (persisted.counts && typeof persisted.counts === "object" && Object.keys(persisted.counts).length > 0) {
            canonicalCounts = Object.assign({}, persisted.counts)
            canonicalUrgent = Object.assign({}, persisted.urgent || {})
            badgeChanged()
            return
        }
        // Priority 2: Disk file (survives full shell restart and reboot)
        try {
            var raw = badgeStateFile.text()
            if (raw) {
                var data = JSON.parse(raw)
                if (data && typeof data === "object" && data.counts) {
                    canonicalCounts = Object.assign({}, data.counts || {})
                    canonicalUrgent = Object.assign({}, data.urgent || {})
                    persisted.counts = canonicalCounts
                    persisted.urgent = canonicalUrgent
                    badgeChanged()
                }
            }
        } catch (e) {}
    }

    signal badgeChanged()

    // -------------------------------------------------------------------------
    // 1. Canonical Key Normalization & Matching Engine (Desktop + Web Apps)
    // -------------------------------------------------------------------------
    function toCanonical(str) {
        if (!str || typeof str !== "string") return ""
        var raw = str.trim().toLowerCase()
        if (!raw) return ""

        // 1. First-class desktop & Web App service aliases (checked on raw string)
        if (raw.indexOf("telegram") !== -1) return "telegram"
        if (raw.indexOf("whatsapp") !== -1) return "whatsapp"
        if (raw.indexOf("chatgpt") !== -1 || raw.indexOf("openai") !== -1) return "chatgpt"
        if (raw.indexOf("claude") !== -1 || raw.indexOf("anthropic") !== -1) return "claude"
        if (raw.indexOf("gemini") !== -1) return "gemini"
        if (raw.indexOf("notion") !== -1) return "notion"
        if (raw.indexOf("figma") !== -1) return "figma"
        if (raw.indexOf("github") !== -1) return "github"
        if (raw.indexOf("gitlab") !== -1) return "gitlab"
        if (raw.indexOf("linear") !== -1) return "linear"
        if (raw.indexOf("trello") !== -1) return "trello"
        if (raw.indexOf("jira") !== -1) return "jira"
        if (raw.indexOf("slack") !== -1) return "slack"
        if (raw.indexOf("discord") !== -1 || raw.indexOf("vesktop") !== -1 || raw.indexOf("webcord") !== -1) return "discord"
        if (raw.indexOf("spotify") !== -1) return "spotify"
        if (raw.indexOf("gmail") !== -1 || raw.indexOf("mail.google.com") !== -1) return "gmail"
        if (raw.indexOf("outlook") !== -1) return "outlook"
        if (raw.indexOf("proton") !== -1 || raw.indexOf("protonmail") !== -1) return "protonmail"
        if (raw.indexOf("antigravity") !== -1) return "antigravity"
        if (raw.indexOf("code") !== -1 || raw.indexOf("vscodium") !== -1 || raw.indexOf("vscode") !== -1) return "code"
        if (raw.indexOf("nautilus") !== -1 || raw.indexOf("org.gnome.nautilus") !== -1 || raw.indexOf("thunar") !== -1 || raw.indexOf("dolphin") !== -1) return "nautilus"
        if (raw.indexOf("kitty") !== -1 || raw.indexOf("alacritty") !== -1 || raw.indexOf("ghostty") !== -1 || raw.indexOf("foot") !== -1 || raw.indexOf("terminal") !== -1) return "terminal"
        // Chromium web apps ("chrome-youtube.com__-Default") must keep their own site
        // as the key. Folding them all into "chrome" made a number in ONE app's title
        // (YouTube's "(13) ...") show as a badge on EVERY web app (Maps too).
        var webApp = raw.match(/^chrome-([a-z0-9.-]+?)__/)
        if (webApp) {
            var labels = webApp[1].replace(/^(www|web|app|m)\./, "").split(".")
            if (labels[0]) return labels[0]
        }
        if (raw.indexOf("chrome") !== -1 || raw.indexOf("chromium") !== -1) return "chrome"
        if (raw.indexOf("firefox") !== -1 || raw.indexOf("zen-browser") !== -1) return "firefox"

        // 2. Extract domain core from Web App URLs (e.g. https://web.whatsapp.com -> whatsapp, https://photos.google.com -> photos)
        var urlMatch = raw.match(/https?:\/\/(?:www\.|web\.|app\.|mail\.)?([a-zA-Z0-9-]+)\./i)
        if (urlMatch && urlMatch[1]) {
            var dom = urlMatch[1].toLowerCase()
            var ignoredProviders = ["com", "org", "net", "io", "app", "dev", "google", "yandex", "microsoft", "apple"]
            if (ignoredProviders.indexOf(dom) === -1) {
                return dom
            } else {
                // If subdomain is provider itself (e.g. google.com/photos), extract path token
                var pathMatch = raw.match(/https?:\/\/[^\/]+\/([a-zA-Z0-9-]+)/i)
                if (pathMatch && pathMatch[1] && pathMatch[1].length >= 3) {
                    return pathMatch[1].toLowerCase()
                }
            }
        }

        // 3. Generic stripping
        var s = raw
        s = s.replace(/\.desktop$/i, "")
        s = s.replace(/\.appimage$/i, "")
        s = s.replace(/-(?:bin|git|stable|nightly|electron|desktop)$/i, "")
        s = s.replace(/^(?:org|com|io|net|edu|dev)\.[a-z0-9_]+\./i, "")
        s = s.replace(/^(?:org|com|io|net|edu|dev)\./i, "")
        return s.replace(/[^a-z0-9]/g, "")
    }

    function getCandidateKeys(appId, entry, name, desktopId) {
        var keys = []
        if (appId) keys.push(String(appId))
        if (desktopId) keys.push(String(desktopId))
        if (entry && entry.id) keys.push(String(entry.id))
        if (entry && entry.name) keys.push(String(entry.name))
        if (entry && entry.exec) keys.push(String(entry.exec))
        if (name) keys.push(String(name))
        
        var canonicalSet = []
        for (var i = 0; i < keys.length; i++) {
            var raw = String(keys[i]).trim().toLowerCase()
            if (raw && canonicalSet.indexOf(raw) === -1) canonicalSet.push(raw)
            var clean = raw.replace(/[^a-z0-9]/g, "")
            if (clean && canonicalSet.indexOf(clean) === -1) canonicalSet.push(clean)
            var c = toCanonical(keys[i])
            if (c && canonicalSet.indexOf(c) === -1) canonicalSet.push(c)
        }
        return canonicalSet
    }

    // -------------------------------------------------------------------------
    // 2. Querying Badge Count & Urgency
    // -------------------------------------------------------------------------
    function getBadgeCount(appId, entry, name, desktopId) {
        var keys = getCandidateKeys(appId, entry, name, desktopId)
        var maxCount = 0
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i]
            if (canonicalCounts[k] != null && Number(canonicalCounts[k]) > maxCount) {
                maxCount = Number(canonicalCounts[k])
            }
        }
        return maxCount
    }

    function getBadgeInfo(appId, entry, name, desktopId) {
        var keys = getCandidateKeys(appId, entry, name, desktopId)
        var maxCount = 0
        var isUrgent = false
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i]
            if (canonicalCounts[k] != null && Number(canonicalCounts[k]) > maxCount) {
                maxCount = Number(canonicalCounts[k])
            }
            if (canonicalUrgent[k] === true) {
                isUrgent = true
            }
        }
        return { count: maxCount, hasUrgent: isUrgent }
    }

    // -------------------------------------------------------------------------
    // 3. Increment & Deduplication Engine
    // -------------------------------------------------------------------------
    function incrementBadge(appKey, delta, isUrgent) {
        if (!appKey) return
        var rawKey = String(appKey).trim().toLowerCase()
        var cKey = toCanonical(appKey)
        var cleanKey = rawKey.replace(/[^a-z0-9]/g, "")
        if (!cKey && !rawKey) return

        var targetKey = cKey || rawKey
        var current = canonicalCounts[targetKey] ? Number(canonicalCounts[targetKey]) : 0
        var add = (delta != null && delta > 0) ? delta : 1

        var nextCounts = Object.assign({}, canonicalCounts)
        var nextUrgent = Object.assign({}, canonicalUrgent)
        var nextTimestamps = Object.assign({}, lastNotifTimestamps)

        var keysToSet = [targetKey, rawKey, cleanKey, cKey]
        for (var i = 0; i < keysToSet.length; i++) {
            var k = keysToSet[i]
            if (!k) continue
            nextCounts[k] = current + add
            if (isUrgent) nextUrgent[k] = true
            nextTimestamps[k] = Date.now()
        }

        canonicalCounts = nextCounts
        canonicalUrgent = nextUrgent
        lastNotifTimestamps = nextTimestamps

        badgeChanged()
        scheduleSave()
    }

    // -------------------------------------------------------------------------
    // 4. Reliable Badge Clearing (Window Focus, Click & Dismissal)
    // -------------------------------------------------------------------------
    function clearBadge(itemData) {
        if (!itemData) return
        var keysToCheck = [
            itemData.id,
            itemData.appId,
            itemData.desktopId,
            itemData.name
        ]
        if (itemData.isStack && itemData.subApps) {
            for (var i = 0; i < itemData.subApps.length; i++) {
                var sub = itemData.subApps[i]
                keysToCheck.push(sub.id, sub.appId, sub.desktopId, sub.name)
            }
        }

        var nextCounts = Object.assign({}, canonicalCounts)
        var nextUrgent = Object.assign({}, canonicalUrgent)
        var changed = false

        for (var j = 0; j < keysToCheck.length; j++) {
            if (!keysToCheck[j]) continue
            var rawK = String(keysToCheck[j]).trim().toLowerCase()
            var cleanK = rawK.replace(/[^a-z0-9]/g, "")
            var cK = toCanonical(keysToCheck[j])
            
            var targets = [rawK, cleanK, cK]
            for (var t = 0; t < targets.length; t++) {
                var tk = targets[t]
                if (tk && nextCounts[tk] != null) {
                    delete nextCounts[tk]
                    delete nextUrgent[tk]
                    changed = true
                }
            }
        }

        if (changed) {
            canonicalCounts = nextCounts
            canonicalUrgent = nextUrgent
            badgeChanged()
            scheduleSave()
        }
    }

    function clearByRawIdentifier(rawId) {
        if (!rawId) return
        var rawK = String(rawId).trim().toLowerCase()
        var cleanK = rawK.replace(/[^a-z0-9]/g, "")
        var cK = toCanonical(rawId)
        var nextCounts = Object.assign({}, canonicalCounts)
        var nextUrgent = Object.assign({}, canonicalUrgent)
        var changed = false

        var targets = [rawK, cleanK, cK]
        for (var t = 0; t < targets.length; t++) {
            var tk = targets[t]
            if (tk && nextCounts[tk] != null) {
                delete nextCounts[tk]
                delete nextUrgent[tk]
                changed = true
            }
        }
        if (changed) {
            canonicalCounts = nextCounts
            canonicalUrgent = nextUrgent
            badgeChanged()
            scheduleSave()
        }
    }

    // -------------------------------------------------------------------------
    // 5. Channel 1: Omarchy Notification Service Listener (D-Bus)
    // -------------------------------------------------------------------------
    readonly property var notificationService: (shell && typeof shell.firstPartyServiceFor === "function")
        ? shell.firstPartyServiceFor("omarchy.notifications")
        : null

    readonly property var notifPopupModel: (notificationService && notificationService.popupModel) ? notificationService.popupModel : null
    readonly property int notifPopupCount: notifPopupModel ? notifPopupModel.count : 0

    // Snapshot of active popup app keys
    property var activePopupSnapshot: []

    function snapshotKey(item) {
        if (!item) return ""
        return item.app || item.appName || item.appIcon || item.summary || ""
    }

    function rebuildSnapshot() {
        if (!notifPopupModel) { activePopupSnapshot = []; return }
        var snap = []
        for (var i = 0; i < notifPopupModel.count; i++) {
            try {
                var it = notifPopupModel.get(i)
                var k = snapshotKey(it)
                if (k) snap.push(k)
            } catch (e) {}
        }
        activePopupSnapshot = snap
    }

    function isAppCurrentlyActive(appKey) {
        if (!appKey) return false
        var targetCanonical = toCanonical(appKey)
        if (!targetCanonical) return false

        // Check ToplevelManager
        if (typeof ToplevelManager !== "undefined" && ToplevelManager.activeToplevel) {
            var top = ToplevelManager.activeToplevel
            var topId = top.appId || top.title || ""
            if (toCanonical(topId) === targetCanonical) return true
        }

        // Check knownWindows
        if (tracker.knownWindows && tracker.knownWindows.length > 0) {
            for (var i = 0; i < tracker.knownWindows.length; i++) {
                var win = tracker.knownWindows[i]
                if (win && (win.active || win.activated)) {
                    var winId = win.appId || win.title || ""
                    if (toCanonical(winId) === targetCanonical) return true
                }
            }
        }
        return false
    }

    function processIncomingNotification(item) {
        if (!item) return
        var appKey = snapshotKey(item)
        if (!appKey) return
        var isCritical = (item.urgency === 2 || item.urgency === "critical")

        // If the application is already active and focused right now, do not show badge
        if (isAppCurrentlyActive(appKey)) {
            rebuildSnapshot()
            return
        }

        // 1. Primary app target
        tracker.incrementBadge(appKey, 1, isCritical)

        // 2. If sent from a browser — check summary for Web App / PWA name
        var isBrowser = (appKey.indexOf("chrome") !== -1 || appKey.indexOf("chromium") !== -1 || appKey.indexOf("brave") !== -1 || appKey.indexOf("firefox") !== -1 || appKey.indexOf("edge") !== -1)
        if (isBrowser) {
            var sum = String(item.summary || "").trim()
            if (sum) {
                var cSum = tracker.toCanonical(sum)
                if (cSum && cSum !== "chrome" && cSum !== "firefox" && cSum !== "browser") {
                    if (!isAppCurrentlyActive(cSum)) {
                        tracker.incrementBadge(cSum, 1, isCritical)
                    }
                }
            }
        }

        rebuildSnapshot()
    }

    function processDisappeared() {
        rebuildSnapshot()
    }

    function hydrateActivePopups() {
        if (!notifPopupModel || notifPopupModel.count === 0) return
        for (var i = 0; i < notifPopupModel.count; i++) {
            try {
                var item = notifPopupModel.get(i)
                if (item) processIncomingNotification(item)
            } catch (e) {}
        }
        rebuildSnapshot()
    }

    onNotifPopupModelChanged: {
        if (notifPopupModel) {
            hydrateActivePopups()
        }
    }

    Component.onCompleted: {
        loadDiskState()
        Qt.callLater(function() {
            hydrateActivePopups()
            if (typeof ToplevelManager !== "undefined" && ToplevelManager.activeToplevel) {
                var top = ToplevelManager.activeToplevel
                if (top.appId) tracker.clearByRawIdentifier(top.appId)
                if (top.title) tracker.clearByRawIdentifier(top.title)
            }
            if (tracker.knownWindows) {
                for (var i = 0; i < tracker.knownWindows.length; i++) {
                    var w = tracker.knownWindows[i]
                    if (w && (w.active || w.activated)) {
                        if (w.appId) tracker.clearByRawIdentifier(w.appId)
                        if (w.title) tracker.clearByRawIdentifier(w.title)
                    }
                }
            }
        })
    }

    onNotifPopupCountChanged: {
        if (!notifPopupModel) return

        var prevCount = activePopupSnapshot.length
        var newCount = notifPopupModel.count

        if (newCount > prevCount) {
            // New notification arrived — increment badge
            try {
                var newest = notifPopupModel.get(0)
                if (newest) processIncomingNotification(newest)
            } catch (e) {}
        } else if (newCount < prevCount) {
            // Notification disappeared (auto-expire or click) — just sync snapshot
            processDisappeared()
        } else {
            // Same count but model changed (update/replace) — rebuild snapshot only
            rebuildSnapshot()
        }
    }

    // -------------------------------------------------------------------------
    // 6. Channel 2: Ghost Badge Cleanup Engine (Window Closed / Destroyed)
    // -------------------------------------------------------------------------
    property var previouslyOpenAppKeys: []

    function updateOpenWindowsAndClearClosed(currentWindows) {
        var currentAppKeys = []
        if (currentWindows && currentWindows.length > 0) {
            for (var i = 0; i < currentWindows.length; i++) {
                var win = currentWindows[i]
                if (!win) continue
                var appIdentifier = win.appId || win.title || ""
                var cKey = tracker.toCanonical(appIdentifier)
                if (cKey && currentAppKeys.indexOf(cKey) === -1) {
                    currentAppKeys.push(cKey)
                }
                var rawApp = String(win.appId || "").trim().toLowerCase()
                if (rawApp && currentAppKeys.indexOf(rawApp) === -1) {
                    currentAppKeys.push(rawApp)
                }

                // If this window is currently active, clear its badge immediately!
                if (win.active || win.activated) {
                    if (win.appId) tracker.clearByRawIdentifier(win.appId)
                    if (win.title) tracker.clearByRawIdentifier(win.title)
                }
            }
        }

        // 🌟 Feature 3: Auto-clear ghost badges when all windows of an application are closed
        if (tracker.previouslyOpenAppKeys && tracker.previouslyOpenAppKeys.length > 0) {
            for (var p = 0; p < tracker.previouslyOpenAppKeys.length; p++) {
                var closedAppKey = tracker.previouslyOpenAppKeys[p]
                if (closedAppKey && currentAppKeys.indexOf(closedAppKey) === -1) {
                    // All windows of this application were closed! Clear ghost badge.
                    tracker.clearByRawIdentifier(closedAppKey)
                }
            }
        }

        tracker.previouslyOpenAppKeys = currentAppKeys
        tracker.syncWindowTitles()
    }

    Connections {
        target: (typeof ToplevelManager !== "undefined") ? ToplevelManager : null
        function onActiveToplevelChanged() {
            if (ToplevelManager && ToplevelManager.activeToplevel) {
                var top = ToplevelManager.activeToplevel
                if (top.appId) tracker.clearByRawIdentifier(top.appId)
                if (top.title) tracker.clearByRawIdentifier(top.title)
            }
        }
    }

    Connections {
        target: (typeof Hyprland !== "undefined") ? Hyprland : null

        function onRawEvent(event) {
            if (!event) return
            var evName = String(event.name || "")

            if (evName === "activewindow" || evName === "activewindowv2") {
                var wArgs = String(event.args || "")
                if (wArgs) {
                    var comma = wArgs.indexOf(",")
                    if (comma !== -1) {
                        var cls = wArgs.substring(0, comma).trim()
                        var ttl = wArgs.substring(comma + 1).trim()
                        if (cls) tracker.clearByRawIdentifier(cls)
                        if (ttl) tracker.clearByRawIdentifier(ttl)
                    } else {
                        tracker.clearByRawIdentifier(wArgs)
                        if (tracker.knownWindows) {
                            for (var kw = 0; kw < tracker.knownWindows.length; kw++) {
                                var win = tracker.knownWindows[kw]
                                if (win && (win.address === wArgs || String(win.address || "").indexOf(wArgs) !== -1)) {
                                    if (win.appId) tracker.clearByRawIdentifier(win.appId)
                                    if (win.title) tracker.clearByRawIdentifier(win.title)
                                    break
                                }
                            }
                        }
                    }
                }
                return
            }

            if (evName === "closewindow") {
                Qt.callLater(function() {
                    tracker.updateOpenWindowsAndClearClosed(tracker.knownWindows)
                })
                return
            }

            if (evName === "urgent") {
                var uAddr = String(event.args || "").trim()
                if (tracker.knownWindows) {
                    for (var u = 0; u < tracker.knownWindows.length; u++) {
                        var ut = tracker.knownWindows[u]
                        if (ut && (ut.address === uAddr || String(ut.address || "").indexOf(uAddr) !== -1)) {
                            var uApp = ut.appId || ut.title || ""
                            if (uApp && !ut.active && !ut.activated) {
                                var cKey = tracker.toCanonical(uApp)
                                var lastTime = tracker.lastNotifTimestamps[cKey] || 0
                                // Deduplicate: If D-Bus notification arrived within last 1500ms, skip duplicate urgent trigger
                                if (Date.now() - lastTime > 1500) {
                                    tracker.incrementBadge(uApp, 1, true)
                                }
                            }
                            break
                        }
                    }
                }
                return
            }

            if (evName === "windowtitle" || evName === "windowtitlev2") {
                tracker.syncWindowTitles()
            }
        }
    }

    // -------------------------------------------------------------------------
    // 7. Channel 3: Live Window Title Badge Extractor (Web Apps & PWAs)
    // -------------------------------------------------------------------------
    property var titleExtractedBadges: ({})

    function extractUnreadFromTitle(title) {
        if (!title || typeof title !== "string") return 0
        // Matches (3), [5], (99+), etc. with sane bound <= 999 to avoid process IDs or ports
        var m = title.match(/(?:\(|\[)(\d{1,3})(?:\+)?(?:\)|\])/)
        if (m && m[1]) {
            var val = parseInt(m[1], 10)
            return (!isNaN(val) && val > 0 && val <= 999) ? val : 0
        }
        return 0
    }

    function syncWindowTitles() {
        if (!tracker.knownWindows || tracker.knownWindows.length === 0) return
        var nextTitleBadges = {}
        var hasChanged = false

        for (var i = 0; i < tracker.knownWindows.length; i++) {
            var win = tracker.knownWindows[i]
            if (!win) continue
            var ttl = String(win.title || "").trim()
            if (!ttl) continue
            var unread = extractUnreadFromTitle(ttl)
            var appIdentifier = win.appId || win.title || ""
            var cKey = tracker.toCanonical(appIdentifier)
            if (cKey && unread > 0) {
                nextTitleBadges[cKey] = Math.max(nextTitleBadges[cKey] || 0, unread)
                hasChanged = true
            }
        }

        var nextCounts = Object.assign({}, tracker.canonicalCounts)
        for (var k in nextTitleBadges) {
            if (nextTitleBadges[k] > (nextCounts[k] || 0)) {
                nextCounts[k] = nextTitleBadges[k]
                hasChanged = true
            }
        }

        if (hasChanged) {
            tracker.canonicalCounts = nextCounts
            tracker.titleExtractedBadges = nextTitleBadges
            tracker.badgeChanged()
        }
    }

    onKnownWindowsChanged: {
        updateOpenWindowsAndClearClosed(tracker.knownWindows)
    }
}
