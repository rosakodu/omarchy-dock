import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "DockModel.js" as DockModel
import "components"

Item {
    id: root

    property var itemData: null
    property int itemIndex: 0
    property int totalCount: 1
    property string barPosition: "bottom"
    property var shell: null
    property real slotSize: 42
    property real iconBaseSize: 24
    property int systemBorderSize: Style.normalBorderWidth > 0 ? Style.normalBorderWidth : 2
    property int systemRounding: Style.cornerRadius >= 0 ? Style.cornerRadius : 12
    property bool isSelected: false
    property bool isMergeTarget: false
    property bool isEditMode: false
    property int dockDragActiveIndex: -1
    readonly property bool isAnyDragging: dockDragActiveIndex >= 0 || isDragging
    property bool showBadges: true

    signal itemLeftClicked(var itemData)
    signal itemRightClicked(var itemData, var itemItem)
    signal moveRequested(int fromIndex, int toIndex)
    signal mergeRequested(int fromIndex, int targetIndex)
    signal dragHoverChanged(int fromIndex, int targetIndex, bool isMergeIntent)
    signal editModeRequested()
    signal editModeExitRequested()
    signal togglePinRequested(string appId)
    signal dissolveRequested(string stackId)
    signal originalAppLaunched(string appId)
    signal restoreOrLaunchRequested(var itemData, int targetIndex)
    signal minimizeRequested(var itemData, int targetIndex)
    signal dragStarted(int fromIndex)
    signal dragEnded()
    signal windowListHoverChanged(bool hovered)

    readonly property int badgeCount: (root.itemData && typeof root.itemData.badgeCount === "number") ? root.itemData.badgeCount : 0

    readonly property bool isVertical: barPosition === "left" || barPosition === "right"

    // The dock sits on the screen edge opposite the status bar.
    readonly property string dockEdge: barPosition === "top" ? "bottom" : (barPosition === "bottom" ? "top" : (barPosition === "left" ? "right" : "left"))

    // Hovering an app with several windows lists them by title, so the one to
    // focus can be picked directly instead of by its dot in the capsule.
    readonly property bool hasSeveralWindows: !!(root.itemData && !root.itemData.isStack && root.itemData.isRunning && root.itemData.toplevels && root.itemData.toplevels.length >= 2)
    readonly property bool canShowWindowList: root.hasSeveralWindows && root.iconsReady && !root.isEditMode && !root.isAnyDragging
    property bool windowListOpen: false
    property bool windowListHovered: false

    onCanShowWindowListChanged: if (!canShowWindowList) root.closeWindowList()

    // Windows of one app often share a title prefix, so each row also names its workspace.
    function windowWorkspaceName(toplevel) {
        var values = Hyprland.toplevels ? Hyprland.toplevels.values : []
        for (var i = 0; i < values.length; i++) {
            if (values[i] && (values[i] === toplevel || values[i].wayland === toplevel)) {
                var name = values[i].workspace ? String(values[i].workspace.name || "") : ""
                return name.indexOf("special:") === 0 ? name.slice(8) : name
            }
        }
        if (toplevel) {
            var topTitle = String(toplevel.title || "")
            var topApp = String(toplevel.appId || "").toLowerCase()
            for (var j = 0; j < values.length; j++) {
                var cand = values[j]
                if (cand && String(cand.title || "") === topTitle) {
                    var candClass = String(cand.class || cand.initialClass || "").toLowerCase()
                    if (!topApp || candClass === topApp || topApp.indexOf(candClass) >= 0 || candClass.indexOf(topApp) >= 0) {
                        var cName = cand.workspace ? String(cand.workspace.name || "") : ""
                        return cName.indexOf("special:") === 0 ? cName.slice(8) : cName
                    }
                }
            }
        }
        return ""
    }

    function windowAddress(toplevel) {
        var values = Hyprland.toplevels ? Hyprland.toplevels.values : []
        for (var i = 0; i < values.length; i++) {
            if (values[i] && (values[i] === toplevel || values[i].wayland === toplevel)) {
                var addr = String(values[i].address || "")
                if (!addr) return ""
                return addr.indexOf("0x") === 0 ? addr : ("0x" + addr)
            }
        }
        if (toplevel) {
            var topTitle = String(toplevel.title || "")
            var topApp = String(toplevel.appId || "").toLowerCase()
            for (var j = 0; j < values.length; j++) {
                var cand = values[j]
                if (cand && String(cand.title || "") === topTitle) {
                    var candClass = String(cand.class || cand.initialClass || "").toLowerCase()
                    if (!topApp || candClass === topApp || topApp.indexOf(candClass) >= 0 || candClass.indexOf(topApp) >= 0) {
                        var cAddr = String(cand.address || "")
                        if (cAddr) return cAddr.indexOf("0x") === 0 ? cAddr : ("0x" + cAddr)
                    }
                }
            }
        }
        return ""
    }

    function closeWindowList() {
        windowListOpenTimer.stop()
        windowListCloseTimer.stop()
        root.windowListOpen = false
        if (root.windowListHovered) {
            root.windowListHovered = false
            root.windowListHoverChanged(false)
        }
        if (!mouseArea.containsMouse) {
            root.previewTopIndex = -1
        }
    }

    Timer {
        id: windowListOpenTimer
        interval: 350
        onTriggered: if (mouseArea.containsMouse && root.canShowWindowList) root.windowListOpen = true
    }

    Timer {
        id: windowListCloseTimer
        interval: 300
        onTriggered: if (!mouseArea.containsMouse && !root.windowListHovered) root.closeWindowList()
    }

    width: slotSize
    height: slotSize
    z: isDragging ? 100 : (isSelected ? 60 : (mouseArea.containsMouse ? 50 : 1))

    property bool isDragging: false
    property bool isMergeActive: false
    property int iconRevision: 0
    property bool iconsReady: true

    // Dynamic Real-time Theme-aware Icon Resolution
    function resolveIcon(itemObj) {
        if (!itemObj) return Quickshell.iconPath("application-x-executable", true) || "file:///usr/share/pixmaps/omarchy.png"
        var raw = (typeof itemObj === "string") ? itemObj : (itemObj.rawIcon || itemObj.icon || itemObj.appId || itemObj.id || "")
        if (!raw) return Quickshell.iconPath("application-x-executable", true) || "file:///usr/share/pixmaps/omarchy.png"
        if (raw.indexOf("://") >= 0) return raw
        if (raw.indexOf("/") === 0) return "file://" + raw

        var cands = (typeof itemObj === "string")
            ? DockModel.getCandidates(itemObj, itemObj, itemObj)
            : DockModel.getCandidates(itemObj.rawIcon, itemObj.icon, itemObj.appId || itemObj.id)

        for (var i = 0; i < cands.length; i++) {
            var c = cands[i]
            if (c.indexOf("://") >= 0) return c
            if (c.indexOf("/") === 0) return "file://" + c
            var diskHit = DockModel.getDiskIcon(c)
            if (diskHit) return diskHit
            var diskHitLow = DockModel.getDiskIcon(c.toLowerCase())
            if (diskHitLow) return diskHitLow
            if (shell && shell.appLibrary && typeof shell.appLibrary.iconSource === "function") {
                var src = shell.appLibrary.iconSource(c)
                if (src && src.length > 0 && src.indexOf("application-x-executable") === -1) {
                    return src
                }
                var cLow = c.toLowerCase()
                if (cLow !== c) {
                    var srcLow = shell.appLibrary.iconSource(cLow)
                    if (srcLow && srcLow.length > 0 && srcLow.indexOf("application-x-executable") === -1) {
                        return srcLow
                    }
                }
            }
            var qs = Quickshell.iconPath(c, true)
            if (qs && qs.length > 0 && qs.indexOf("application-x-executable") === -1) {
                return qs
            }
            var qsLow = Quickshell.iconPath(c.toLowerCase(), true)
            if (qsLow && qsLow.length > 0 && qsLow.indexOf("application-x-executable") === -1) {
                return qsLow
            }
        }

        if (shell && shell.appLibrary && typeof shell.appLibrary.iconSource === "function") {
            var fbApp = shell.appLibrary.iconSource("omarchy") || shell.appLibrary.iconSource("ghostty") || shell.appLibrary.iconSource("utilities-terminal")
            if (fbApp && fbApp.length > 0) return fbApp
        }

        var fbQs = Quickshell.iconPath("omarchy", true) || Quickshell.iconPath("com.mitchellh.ghostty", true) || Quickshell.iconPath("utilities-terminal", true) || Quickshell.iconPath("application-x-executable", true)
        if (fbQs && fbQs.length > 0) return fbQs

        return "file:///usr/share/pixmaps/omarchy.png"
    }

    // Clear, steady Merge Target Halo (stays perfectly still while hovered)
    Rectangle {
        id: mergeTargetHalo
        anchors.centerIn: parent
        width: root.slotSize - 6
        height: root.slotSize - 6
        radius: root.systemRounding
        color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
        border.width: root.systemBorderSize
        border.color: Color.accent
        visible: opacity > 0
        opacity: root.isMergeTarget ? 1.0 : 0.0
        scale: root.isMergeTarget ? 1.04 : 0.92
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        z: 0
    }

    property real clickScaleFactor: 1.0
    property real clickLiftY: 0

    // Bouncy macOS-style physical press response
    ParallelAnimation {
        id: clickEffectAnim
        running: false
        NumberAnimation {
            target: root
            property: "clickScaleFactor"
            from: 0.88
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
        }
        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "clickLiftY"
                to: (root.isVertical ? 0 : (root.barPosition === "bottom" ? -4 : 4))
                duration: 90
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "clickLiftY"
                to: 0
                duration: 130
                easing.type: Easing.OutBounce
            }
        }
    }

    // Independent drag offset so root.x and root.y bindings are NEVER broken
    Item {
        id: dragOffset
        x: 0
        y: 0
    }

    // Clamped drag offset for visual rendering (strictly confined within dock surface boundaries)
    readonly property real clampedDragOffsetX: root.isVertical ? 0 : Math.max(-root.itemIndex * root.slotSize, Math.min((root.totalCount - 1 - root.itemIndex) * root.slotSize, dragOffset.x))
    readonly property real clampedDragOffsetY: root.isVertical ? Math.max(-root.itemIndex * root.slotSize, Math.min((root.totalCount - 1 - root.itemIndex) * root.slotSize, dragOffset.y)) : 0

    readonly property bool isPressVisualActive: {
        if (!mouseArea.pressed) return false
        if (mouseArea.pressedButtons & (Qt.LeftButton | Qt.MiddleButton)) return true
        if (root.isEditMode) return true
        if (root.itemData) {
            if (root.itemData.isStack) return true
            if (root.itemData.isRunning) return true
        }
        return false
    }

    // Main animated icon wrapper (smooth, buttery rail motion)
    Item {
        id: iconWrapper
        x: (parent.width - width) / 2 + root.clampedDragOffsetX
        y: Math.round((parent.height - height) / 2) - 1 + root.clampedDragOffsetY + root.clickLiftY
        width: root.iconBaseSize
        height: root.iconBaseSize
        z: 1

        scale: (root.isDragging ? 1.15 : (root.isEditMode ? 0.82 : (root.isMergeTarget ? 0.94 : (root.isPressVisualActive ? 0.92 : (mouseArea.containsMouse ? 1.10 : 1.0))))) * root.clickScaleFactor
        opacity: root.iconsReady ? (root.isDragging ? 0.92 : 1.0) : 0.0

        Behavior on scale {
            enabled: !clickEffectAnim.running
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // Normal Single App Icon (Instantly react to rawIcon theme swaps, crisp HiDPI rasterization)
        Image {
            id: appIcon
            visible: root.itemData && !root.itemData.isStack && (status !== Image.Error)
            anchors.centerIn: parent
            width: root.iconBaseSize
            height: root.iconBaseSize
            fillMode: Image.PreserveAspectFit
            cache: true
            source: (root.iconRevision, root.resolveIcon(root.itemData))
            sourceSize: Qt.size(Math.max(128, width * 4 * Screen.devicePixelRatio), Math.max(128, height * 4 * Screen.devicePixelRatio))
            asynchronous: false
            mipmap: true
            smooth: true
            antialiasing: true
        }

        Image {
            id: fallbackAppIcon
            visible: root.itemData && !root.itemData.isStack && (appIcon.status === Image.Error || !appIcon.visible)
            anchors.centerIn: parent
            width: root.iconBaseSize
            height: root.iconBaseSize
            fillMode: Image.PreserveAspectFit
            source: {
                if (root.itemData) {
                    var raw = root.itemData.rawIcon || root.itemData.icon || root.itemData.appId || root.itemData.id || ""
                    var dIcon = DockModel.getDiskIcon(raw)
                    if (dIcon) return dIcon
                    var dIconLow = DockModel.getDiskIcon(String(raw).toLowerCase())
                    if (dIconLow) return dIconLow
                }
                return "file:///usr/share/pixmaps/omarchy.png"
            }
            sourceSize: Qt.size(Math.max(128, width * 4 * Screen.devicePixelRatio), Math.max(128, height * 4 * Screen.devicePixelRatio))
            smooth: true
            antialiasing: true
        }

        // Folder Custom Symbol Icon (Optically centered vector glyph with smooth anti-aliased rotation)
        DockGlyph {
            id: stackSymbolText
            visible: root.itemData && root.itemData.isStack === true && root.itemData.icon && root.itemData.icon !== "grid" && root.itemData.icon !== "folder" && root.itemData.icon !== "󰕰"
            anchors.centerIn: parent
            width: root.iconBaseSize
            height: root.iconBaseSize
            text: (root.itemData && root.itemData.icon) ? root.itemData.icon : ""
            fontFamily: Style.font.family
            fontSize: 20
            color: Color.accent
        }

        // Folder Mini-Grid (Shown when icon is "grid", "folder", "󰕰" or not set)
        Grid {
            id: stackGrid
            visible: root.itemData && root.itemData.isStack === true && (!root.itemData.icon || root.itemData.icon === "grid" || root.itemData.icon === "folder" || root.itemData.icon === "󰕰")
            anchors.centerIn: parent
            readonly property int totalSubs: (root.itemData && root.itemData.subApps) ? root.itemData.subApps.length : 0
            readonly property bool is3x3: totalSubs > 4
            columns: is3x3 ? 3 : 2
            spacing: is3x3 ? 1.5 : 2

            readonly property int cellWidth: is3x3
                ? Math.max(6, Math.floor((root.iconBaseSize - 4) / 3))
                : Math.max(9, Math.floor((root.iconBaseSize - 3) / 2))

            Repeater {
                model: (root.itemData && root.itemData.subApps) ? root.itemData.subApps.slice(0, stackGrid.is3x3 ? 9 : 4) : []
                Image {
                    width: stackGrid.cellWidth
                    height: stackGrid.cellWidth
                    fillMode: Image.PreserveAspectFit
                    cache: true
                    source: (root.iconRevision, root.resolveIcon(modelData))
                    sourceSize: Qt.size(Math.max(64, width * 4 * Screen.devicePixelRatio), Math.max(64, height * 4 * Screen.devicePixelRatio))
                    mipmap: true
                    smooth: true
                    antialiasing: true
                }
            }
        }

        // Silky smooth, organic wiggle animation
        SequentialAnimation {
            id: jiggleAnim
            running: root.isDragging || root.isEditMode
            loops: Animation.Infinite

            NumberAnimation {
                target: iconWrapper
                property: "rotation"
                to: -3.8
                duration: 105
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: iconWrapper
                property: "rotation"
                to: 3.8
                duration: 105
                easing.type: Easing.InOutSine
            }
        }

        NumberAnimation {
            id: resetRotation
            target: iconWrapper
            property: "rotation"
            to: 0.0
            duration: 150
            easing.type: Easing.OutCubic
            running: !root.isDragging && !root.isEditMode && iconWrapper.rotation !== 0.0
        }
    }

    // Long press timer for Edit Mode activation (450ms)
    Timer {
        id: longPressTimer
        interval: 450
        repeat: false
        onTriggered: {
            if (!root.isDragging) {
                mouseArea.didLongPress = true
                root.editModeRequested()
            }
        }
    }

    property int previewTopIndex: -1
    property bool isWheelScrolling: false

    Timer {
        id: wheelCursorTimer
        interval: 1200
        repeat: false
        onTriggered: {
            root.isWheelScrolling = false
        }
    }

    readonly property int realActiveTopIndex: (root.itemData && typeof root.itemData.activeTopIndex === "number") ? root.itemData.activeTopIndex : 0

    readonly property int effectiveTopIndex: {
        var total = (root.itemData && root.itemData.toplevels) ? root.itemData.toplevels.length : 0
        if (total === 0) return 0
        if (root.previewTopIndex >= 0 && root.previewTopIndex < total) return root.previewTopIndex
        return root.realActiveTopIndex
    }

    Timer {
        id: previewResetTimer
        interval: 1500
        repeat: false
        onTriggered: {
            if (!mouseArea.containsMouse && !root.windowListHovered && !root.windowListOpen) {
                root.previewTopIndex = -1
            }
        }
    }

    // 0. iOS / macOS-Style Theme Notification Badge with Count (Anchored to top-right of iconWrapper)
    NotificationBadge {
        anchors.top: iconWrapper.top
        anchors.topMargin: -2
        anchors.right: iconWrapper.right
        anchors.rightMargin: -2
        count: root.badgeCount
        hasUrgent: (root.itemData && !!root.itemData.hasUrgent)
        isSuppressed: root.isEditMode || root.isAnyDragging || !root.showBadges
    }

    // 1. Pin / Unpin Glyph (Centered directly above scaled iconWrapper, hidden while dragging)
    Item {
        id: pinBadge
        visible: root.isEditMode && !root.isAnyDragging && root.itemData && !root.itemData.isStack
        anchors.horizontalCenter: iconWrapper.horizontalCenter
        anchors.bottom: iconWrapper.top
        anchors.bottomMargin: -5
        width: 16
        height: 14
        z: 200

        DockGlyph {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            text: "•"
            fontFamily: Style.font.family
            fontSize: 11
            color: (root.itemData && root.itemData.isPinned)
                ? Color.accent
                : (pinBadgeMouse.containsMouse ? Color.accent : Color.composed("popups.text", "popups.text-alpha", Color.text, 0.45))

            scale: pinBadgeMouse.containsMouse ? 1.35 : 1.0
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        MouseArea {
            id: pinBadgeMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: (root.isAnyDragging || root.isDragging || mouseArea.drag.active) ? Qt.BlankCursor : Qt.PointingHandCursor
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    root.editModeExitRequested()
                    return
                }
                if (root.itemData && !root.itemData.isStack) {
                    root.togglePinRequested(root.itemData.appId)
                }
            }
        }
    }

    // 2. Dissolve Folder Glyph (Centered directly above scaled iconWrapper, hidden while dragging)
    Item {
        id: dissolveBadge
        visible: root.isEditMode && !root.isAnyDragging && root.itemData && root.itemData.isStack
        anchors.horizontalCenter: iconWrapper.horizontalCenter
        anchors.bottom: iconWrapper.top
        anchors.bottomMargin: -5
        width: 16
        height: 14
        z: 200

        DockGlyph {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            text: "-"
            fontFamily: Style.font.family
            fontSize: 16
            color: dissolveBadgeMouse.containsMouse ? Color.accent : Color.composed("popups.text", "popups.text-alpha", Color.text, 0.85)

            scale: dissolveBadgeMouse.containsMouse ? 1.25 : 1.0
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        MouseArea {
            id: dissolveBadgeMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: (root.isAnyDragging || root.isDragging || mouseArea.drag.active) ? Qt.BlankCursor : Qt.PointingHandCursor
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    root.editModeExitRequested()
                    return
                }
                if (root.itemData && root.itemData.isStack) {
                    root.dissolveRequested(root.itemData.id)
                }
            }
        }
    }

    // 3. Multi-instance Duplicate Status Capsule (Sliding window viewport)
    DockDuplicateCapsule {
        id: duplicateCapsule
        visible: root.iconsReady && !root.isEditMode && root.itemData && !root.itemData.isStack && root.itemData.isRunning && root.itemData.toplevels && root.itemData.toplevels.length >= 2
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        totalWindows: (root.itemData && root.itemData.toplevels) ? root.itemData.toplevels.length : 0
        effectiveTopIndex: root.effectiveTopIndex
        isAppActive: (root.itemData && root.itemData.isActive === true && !root.itemData.isMinimized)
        isPreviewing: (root.previewTopIndex >= 0)

        x: Math.round((parent.width - width) / 2 + root.clampedDragOffsetX)
        y: parent.height - height - 2 + root.clampedDragOffsetY
        z: root.isDragging ? 101 : 1
    }

    // 4. Running / Active Application Indicator (Single instance)
    Rectangle {
        id: runningDot
        visible: root.iconsReady && !root.isEditMode && root.itemData && root.itemData.isRunning && (!root.itemData.toplevels || root.itemData.toplevels.length <= 1)
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        x: Math.round((parent.width - width) / 2 + root.clampedDragOffsetX)
        y: parent.height - height - 3 + root.clampedDragOffsetY
        z: root.isDragging ? 101 : 1

        height: 2
        width: (root.itemData && root.itemData.isActive && !root.itemData.isMinimized) ? 10 : 4
        radius: 1
        color: (root.itemData && root.itemData.isActive && !root.itemData.isMinimized) ? Color.accent : Color.composed("popups.text", "popups.text-alpha", Color.text, 0.6)
        antialiasing: true
        smooth: true

        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    function cycleDuplicate(forward) {
        if (!root.itemData || root.itemData.isStack || !root.itemData.isRunning || !root.itemData.toplevels) return
        var len = root.itemData.toplevels.length
        if (len <= 1) return

        root.isWheelScrolling = true
        wheelCursorTimer.restart()
        previewResetTimer.stop()
        var curIdx = root.effectiveTopIndex
        var nextIdx = forward ? ((curIdx + 1) % len) : ((curIdx - 1 + len) % len)
        root.previewTopIndex = nextIdx
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: (root.isDragging || mouseArea.drag.active || root.dockDragActiveIndex >= 0 || root.isAnyDragging || root.isWheelScrolling) ? Qt.BlankCursor : (root.isEditMode ? Qt.PointingHandCursor : Qt.ArrowCursor)

        drag.target: (mouseArea.pressedButtons & Qt.LeftButton) ? dragOffset : null
        drag.axis: root.isVertical ? Drag.YAxis : Drag.XAxis
        // Allow free mouse movement across the full screen while dragging along the rail
        drag.minimumX: -99999
        drag.maximumX: 99999
        drag.minimumY: -99999
        drag.maximumY: 99999
        drag.threshold: 6

        property bool didDrag: false
        property bool didLongPress: false

        focus: containsMouse

        onEntered: {
            mouseArea.forceActiveFocus()
            windowListCloseTimer.stop()
            if (root.canShowWindowList && !root.windowListOpen) windowListOpenTimer.restart()
        }

        Keys.onRightPressed: function(event) {
            if (root.itemData && !root.itemData.isStack && root.itemData.isRunning && root.itemData.toplevels && root.itemData.toplevels.length >= 2) {
                root.cycleDuplicate(true)
                event.accepted = true
            }
        }

        Keys.onLeftPressed: function(event) {
            if (root.itemData && !root.itemData.isStack && root.itemData.isRunning && root.itemData.toplevels && root.itemData.toplevels.length >= 2) {
                root.cycleDuplicate(false)
                event.accepted = true
            }
        }

        Keys.onDownPressed: function(event) {
            if (root.itemData && !root.itemData.isStack && root.itemData.isRunning && root.itemData.toplevels && root.itemData.toplevels.length >= 2) {
                root.cycleDuplicate(true)
                event.accepted = true
            }
        }

        Keys.onUpPressed: function(event) {
            if (root.itemData && !root.itemData.isStack && root.itemData.isRunning && root.itemData.toplevels && root.itemData.toplevels.length >= 2) {
                root.cycleDuplicate(false)
                event.accepted = true
            }
        }

        Keys.onTabPressed: function(event) {
            if (root.itemData) {
                clickEffectAnim.restart()
                DockModel.setPendingCliHint(root.itemData.appId || root.itemData.desktopId || "", (root.parentDock && root.parentDock.knownWindows) ? root.parentDock.knownWindows : [])
                DockModel.launchApp(root.shell, root.itemData, Util)
                event.accepted = true
            }
        }

        Keys.onReturnPressed: function(event) {
            if (root.itemData && !root.itemData.isStack && root.itemData.isRunning && root.itemData.toplevels && root.itemData.toplevels.length >= 2 && root.previewTopIndex >= 0) {
                var top = root.itemData.toplevels[root.previewTopIndex]
                if (top && typeof top.activate === "function") {
                    try { top.activate() } catch (e) {}
                }
                var targetIdx = root.previewTopIndex
                root.previewTopIndex = -1
                root.restoreOrLaunchRequested(root.itemData, targetIdx)
                root.closeWindowList()
                event.accepted = true
            }
        }

        onPressed: function(mouse) {
            root.closeWindowList()
            didDrag = false
            didLongPress = false
            if (mouse.button === Qt.LeftButton) {
                longPressTimer.restart()
            } else if (mouse.button === Qt.RightButton) {
                if (root.isEditMode) {
                    clickEffectAnim.restart()
                    root.editModeExitRequested()
                    return
                }
                if (root.itemData) {
                    if (root.itemData.isStack) {
                        clickEffectAnim.restart()
                        root.itemRightClicked(root.itemData, root)
                    } else if (root.itemData.isRunning && !root.itemData.isMinimized) {
                        clickEffectAnim.restart()
                        root.minimizeRequested(root.itemData, root.effectiveTopIndex)
                    }
                }
            }
        }

        onPositionChanged: function(mouse) {
            if (root.isWheelScrolling) {
                root.isWheelScrolling = false
            }
            if (mouseArea.drag.active) {
                longPressTimer.stop()
                if (!root.isDragging) {
                    root.isDragging = true
                    root.dragStarted(root.itemIndex)
                }
                // Enforce strict 1D rail axis lock (zero orthogonal wobble)
                if (root.isVertical) {
                    dragOffset.x = 0
                } else {
                    dragOffset.y = 0
                }

                var rawOffset = root.isVertical ? dragOffset.y : dragOffset.x
                var currentOffset = Math.max(-root.itemIndex * root.slotSize, Math.min((root.totalCount - 1 - root.itemIndex) * root.slotSize, rawOffset))
                var absolutePos = root.itemIndex * root.slotSize + currentOffset

                var targetIdx = Math.max(0, Math.min(root.totalCount - 1, Math.round(absolutePos / root.slotSize)))
                var slotCenter = targetIdx * root.slotSize
                var distFromSlotCenter = absolutePos - slotCenter

                var canMerge = root.itemData && !root.itemData.isStack
                var isMerge = false

                if (canMerge && targetIdx !== root.itemIndex) {
                    if (targetIdx > root.itemIndex) {
                        isMerge = (distFromSlotCenter >= -22 && distFromSlotCenter <= 0)
                    } else {
                        isMerge = (distFromSlotCenter <= 22 && distFromSlotCenter >= 0)
                    }
                }

                // Outer edge insert: dragging all the way to the far outer edges opens the rail slot
                if ((targetIdx === 0 && absolutePos <= 8) || (targetIdx === root.totalCount - 1 && absolutePos >= (root.totalCount - 1) * root.slotSize - 8)) {
                    isMerge = false
                }

                root.isMergeActive = isMerge
                root.dragHoverChanged(root.itemIndex, targetIdx, isMerge)
            }
        }

        onReleased: function(mouse) {
            longPressTimer.stop()
            if (root.isDragging) {
                root.isDragging = false
                var rawOffset = root.isVertical ? dragOffset.y : dragOffset.x
                var currentOffset = Math.max(-root.itemIndex * root.slotSize, Math.min((root.totalCount - 1 - root.itemIndex) * root.slotSize, rawOffset))
                var absolutePos = root.itemIndex * root.slotSize + currentOffset
                var targetIdx = Math.max(0, Math.min(root.totalCount - 1, Math.round(absolutePos / root.slotSize)))
                var slotCenter = targetIdx * root.slotSize
                var distFromSlotCenter = absolutePos - slotCenter

                var canMerge = root.itemData && !root.itemData.isStack
                var isMerge = false

                if (canMerge && targetIdx !== root.itemIndex) {
                    if (targetIdx > root.itemIndex) {
                        isMerge = (distFromSlotCenter >= -22 && distFromSlotCenter <= 0)
                    } else {
                        isMerge = (distFromSlotCenter <= 22 && distFromSlotCenter >= 0)
                    }
                }

                if ((targetIdx === 0 && absolutePos <= 8) || (targetIdx === root.totalCount - 1 && absolutePos >= (root.totalCount - 1) * root.slotSize - 8)) {
                    isMerge = false
                }

                root.isMergeActive = false
                dragOffset.x = 0
                dragOffset.y = 0

                if (targetIdx !== root.itemIndex) {
                    if (isMerge) {
                        root.mergeRequested(root.itemIndex, targetIdx)
                    } else {
                        root.moveRequested(root.itemIndex, targetIdx)
                    }
                } else {
                    root.dragEnded()
                }
            }
        }

        onExited: {
            windowListOpenTimer.stop()
            if (root.windowListOpen) windowListCloseTimer.restart()
            longPressTimer.stop()
            root.isWheelScrolling = false
            if (!root.windowListHovered && !root.windowListOpen) {
                previewResetTimer.restart()
            }
        }

        onCanceled: {
            longPressTimer.stop()
            didLongPress = false
            if (root.isDragging) {
                root.isDragging = false
                root.isMergeActive = false
                dragOffset.x = 0
                dragOffset.y = 0
                root.dragEnded()
            }
        }

        onWheel: function(wheel) {
            if (root.itemData && !root.itemData.isStack && root.itemData.isRunning && root.itemData.toplevels && root.itemData.toplevels.length >= 2) {
                if (wheel.angleDelta.y < 0 || wheel.angleDelta.x > 0) {
                    root.cycleDuplicate(true)
                    wheel.accepted = true
                } else if (wheel.angleDelta.y > 0 || wheel.angleDelta.x < 0) {
                    root.cycleDuplicate(false)
                    wheel.accepted = true
                }
            }
        }

        onClicked: function(mouse) {
            longPressTimer.stop()
            if (didDrag || didLongPress) {
                didLongPress = false
                return
            }

            // Middle Click (Wheel Button click) -> Immediately launch a duplicate
            if (mouse.button === Qt.MiddleButton) {
                if (root.itemData && !root.itemData.isStack) {
                    clickEffectAnim.restart()
                    DockModel.setPendingCliHint(root.itemData.appId || root.itemData.desktopId || "", (root.parentDock && root.parentDock.knownWindows) ? root.parentDock.knownWindows : [])
                    DockModel.launchApp(root.shell, root.itemData, Util)
                }
                return
            }

            if (mouse.button === Qt.LeftButton) {
                clickEffectAnim.restart()
                if (root.isEditMode) {
                    if (root.itemData && root.itemData.isStack) {
                        root.itemLeftClicked(root.itemData)
                    }
                    return
                }
                if (root.itemData && root.itemData.isStack) {
                    root.itemLeftClicked(root.itemData)
                    return
                }
                if (root.itemData) {
                    root.itemLeftClicked(root.itemData)
                    if (root.previewTopIndex >= 0) {
                        root.restoreOrLaunchRequested(root.itemData, root.previewTopIndex)
                    } else {
                        var tops = root.itemData.toplevels || []
                        if (tops.length >= 2 && root.itemData.isActive) {
                            var nextIdx = (root.realActiveTopIndex + 1) % tops.length
                            root.restoreOrLaunchRequested(root.itemData, nextIdx)
                        } else {
                            root.restoreOrLaunchRequested(root.itemData, root.realActiveTopIndex)
                        }
                    }
                    root.previewTopIndex = -1
                }
            } else if (mouse.button === Qt.RightButton) {
                return
            }
        }

        onDoubleClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                clickEffectAnim.restart()
                if (root.itemData && root.itemData.isStack) {
                    root.itemLeftClicked(root.itemData)
                }
            }
        }
    }

    PopupWindow {
        id: windowList
        visible: root.windowListOpen && root.hasSeveralWindows
        color: "transparent"
        implicitWidth: windowListCard.width
        implicitHeight: windowListCard.height

        anchor {
            window: root.QsWindow.window
            adjustment: PopupAdjustment.Slide
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            rect.width: 1
            rect.height: 1

            onAnchoring: {
                var window = root.QsWindow.window
                if (!window) return

                var gap = 8
                var popupWidth = windowList.implicitWidth
                var popupHeight = windowList.implicitHeight
                var localX = root.width / 2 - popupWidth / 2
                var localY = -popupHeight - gap

                if (root.dockEdge === "top") {
                    localY = root.height + gap
                } else if (root.dockEdge === "left") {
                    localX = root.width + gap
                    localY = root.height / 2 - popupHeight / 2
                } else if (root.dockEdge === "right") {
                    localX = -popupWidth - gap
                    localY = root.height / 2 - popupHeight / 2
                }

                var point = window.contentItem.mapFromItem(root, localX, localY)
                windowList.anchor.rect.x = Math.round(point.x)
                windowList.anchor.rect.y = Math.round(point.y)
            }
        }

        Rectangle {
            id: windowListCard
            width: windowListColumn.width + 12
            height: Math.min(windowListColumn.height + 12, 420)
            radius: root.systemRounding
            color: Color.popups.background
            border.width: root.systemBorderSize
            border.color: Color.composed("popups.border", "popups.border-alpha", Color.border, 0.45)
            clip: true

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function(event) {
                    if (root.itemData && !root.itemData.isStack && root.itemData.isRunning && root.itemData.toplevels && root.itemData.toplevels.length >= 2) {
                        if (event.angleDelta.y < 0 || event.angleDelta.x > 0) {
                            root.cycleDuplicate(true)
                        } else if (event.angleDelta.y > 0 || event.angleDelta.x < 0) {
                            root.cycleDuplicate(false)
                        }
                    }
                }
            }

            TapHandler {
                acceptedButtons: Qt.MiddleButton
                onTapped: {
                    if (root.itemData && !root.itemData.isStack) {
                        clickEffectAnim.restart()
                        root.closeWindowList()
                        DockModel.setPendingCliHint(root.itemData.appId || root.itemData.desktopId || "", (root.parentDock && root.parentDock.knownWindows) ? root.parentDock.knownWindows : [])
                        DockModel.launchApp(root.shell, root.itemData, Util)
                    }
                }
            }

            HoverHandler {
                onHoveredChanged: {
                    root.windowListHovered = hovered
                    root.windowListHoverChanged(hovered)
                    if (hovered) {
                        windowListCloseTimer.stop()
                    } else {
                        windowListCloseTimer.restart()
                    }
                }
            }

            Flickable {
                id: windowListFlickable
                x: 6
                y: 6
                width: windowListColumn.width
                height: windowListCard.height - 12
                contentWidth: windowListColumn.width
                contentHeight: windowListColumn.height
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Connections {
                    target: root
                    function onEffectiveTopIndexChanged() {
                        if (windowListFlickable.contentHeight > windowListFlickable.height) {
                            var itemY = root.effectiveTopIndex * 30
                            if (itemY < windowListFlickable.contentY) {
                                windowListFlickable.contentY = itemY
                            } else if (itemY + 30 > windowListFlickable.contentY + windowListFlickable.height) {
                                windowListFlickable.contentY = itemY + 30 - windowListFlickable.height
                            }
                        }
                    }
                }

                Column {
                    id: windowListColumn

                    Repeater {
                        model: (root.itemData && root.itemData.toplevels) ? root.itemData.toplevels : []

                        Item {
                            id: windowRow
                            required property var modelData
                            required property int index

                            readonly property bool isSelected: index === root.effectiveTopIndex
                            readonly property bool isOriginalApp: index === 0
                            readonly property string label: (modelData && modelData.title) ? modelData.title : (root.itemData ? (root.itemData.name || "") : "")
                            readonly property string workspaceName: root.windowWorkspaceName(modelData)
                            readonly property real workspaceWidth: workspaceName ? windowWorkspace.implicitWidth + 12 : 0

                            width: Math.min(420, Math.max(160, windowTitle.implicitWidth + 34 + workspaceWidth))
                            height: 30

                            Rectangle {
                                width: windowListColumn.width
                                height: parent.height
                                radius: Math.max(0, root.systemRounding - 4)
                                color: windowRowMouse.containsMouse
                                    ? Util.alpha(Color.accent, 0.22)
                                    : (windowRow.isSelected ? Util.alpha(Color.accent, 0.12) : "transparent")
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            // Duplicate Status Capsule Indicator (Synchronized with capsule under the dock icon)
                            Rectangle {
                                id: statusIndicator
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: windowRow.isOriginalApp ? 9.0 : (windowRow.isSelected ? 4.0 : 2.5)
                                height: 2.5
                                radius: 1.25
                                color: windowRow.isSelected
                                    ? Color.accent
                                    : Color.composed("popups.text", "popups.text-alpha", Color.text, windowRow.isOriginalApp ? 0.45 : 0.28)
                                antialiasing: true
                                smooth: true

                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Text {
                                id: windowTitle
                                x: 23
                                width: windowListColumn.width - 31 - windowRow.workspaceWidth
                                anchors.verticalCenter: parent.verticalCenter
                                text: windowRow.label
                                elide: Text.ElideRight
                                color: windowRow.isSelected
                                    ? Color.accent
                                    : (windowRowMouse.containsMouse ? Color.text : Color.composed("popups.text", "popups.text-alpha", Color.text, 0.9))
                                font.family: Style.font.family
                                font.pixelSize: 12
                                font.weight: windowRow.isSelected ? Font.Medium : Font.Normal
                            }

                            Text {
                                id: windowWorkspace
                                x: windowListColumn.width - implicitWidth - 8
                                anchors.verticalCenter: parent.verticalCenter
                                visible: windowRow.workspaceName !== ""
                                text: windowRow.workspaceName
                                color: windowRow.isSelected
                                    ? Util.alpha(Color.accent, 0.85)
                                    : Color.composed("popups.text", "popups.text-alpha", Color.text, 0.5)
                                font.family: Style.font.family
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: windowRowMouse
                                width: windowListColumn.width
                                height: parent.height
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                                onEntered: {
                                    root.previewTopIndex = windowRow.index
                                }

                                onClicked: function(mouse) {
                                    var item = root.itemData
                                    var target = windowRow.index
                                    var top = windowRow.modelData

                                    if (mouse.button === Qt.MiddleButton) {
                                        if (item && !item.isStack) {
                                            clickEffectAnim.restart()
                                            root.closeWindowList()
                                            DockModel.setPendingCliHint(item.appId || item.desktopId || "", (root.parentDock && root.parentDock.knownWindows) ? root.parentDock.knownWindows : [])
                                            DockModel.launchApp(root.shell, item, Util)
                                        }
                                        return
                                    }

                                    if (top && typeof top.activate === "function") {
                                        try {
                                            top.activate()
                                        } catch (e) {}
                                    }
                                    root.restoreOrLaunchRequested(item, target)
                                    Qt.callLater(function() {
                                        root.closeWindowList()
                                    })
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
