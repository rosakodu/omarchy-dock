import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../DockModel.js" as DockModel
import ".."

PanelWindow {
    id: stackWindow

    required property var root
    required property var dockWindow
    property alias stackCard: stackCard
    screen: stackWindow.dockWindow ? stackWindow.dockWindow.screen : null

    visible: stackWindow.root.isStackOpen && stackWindow.root.dockRevealed

        WlrLayershell.namespace: "omarchy-dock-stack"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: stackWindow.root.isEditingFolderTitle
            ? WlrKeyboardFocus.Exclusive
            : (stackWindow.root.isStackOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)
    exclusionMode: stackWindow.root.reservesSpace ? ExclusionMode.Auto : ExclusionMode.Ignore
        color: "transparent"

        anchors {
            top: (!stackWindow.root.isVertical && stackWindow.root.barPosition === "bottom") ? true : (stackWindow.root.isVertical ? true : false)
            bottom: (!stackWindow.root.isVertical && stackWindow.root.barPosition === "top") ? true : (stackWindow.root.isVertical ? true : false)
            left: (stackWindow.root.isVertical && stackWindow.root.barPosition === "right") ? true : (!stackWindow.root.isVertical ? true : false)
            right: (stackWindow.root.isVertical && stackWindow.root.barPosition === "left") ? true : (!stackWindow.root.isVertical ? true : false)
        }

        margins {
            bottom: (!stackWindow.root.isVertical && stackWindow.root.barPosition === "top") ? (Style.gapsOut || 5) : 0
            top: (!stackWindow.root.isVertical && stackWindow.root.barPosition === "bottom") ? (Style.gapsOut || 5) : 0
            right: (stackWindow.root.isVertical && stackWindow.root.barPosition === "left") ? (Style.gapsOut || 5) : 0
            left: (stackWindow.root.isVertical && stackWindow.root.barPosition === "right") ? (Style.gapsOut || 5) : 0
        }

        implicitWidth: stackWindow.root.isVertical ? stackCard.width : (dockWindow.screen ? dockWindow.screen.width : 1920)
        implicitHeight: stackWindow.root.isVertical ? (dockWindow.screen ? dockWindow.screen.height : 1080) : stackCard.height

        // Dismissal MouseArea covering the entire transparent overlay area of stackWindow outside stackCard
        MouseArea {
            anchors.fill: parent
            z: 0
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) {
                if (stackWindow.root.isEditingFolderTitle && typeof titleInput !== "undefined") {
                    titleInput.saveAndClose()
                }
                stackWindow.root.activeStackItem = null
                stackWindow.root.isEditMode = false
                stackWindow.root.isEditingFolderTitle = false
            }
        }

        // Frosted Card for Folder Contents
        Rectangle {
            id: stackCard
            z: 1
            anchors.centerIn: parent
            focus: true

            HoverHandler {
                id: stackCardHover
                onHoveredChanged: {
                    stackWindow.root.isStackHovered = hovered
                    stackWindow.root.evaluateHoverState()
                }
            }

            onVisibleChanged: {
                if (visible) {
                    stackCard.forceActiveFocus()
                }
            }

            Keys.onEscapePressed: function(event) {
                event.accepted = true
                if (stackWindow.root.isEditingFolderTitle) {
                    if (typeof titleInput !== "undefined") {
                        titleInput.text = stackWindow.root.activeStackItem ? stackWindow.root.activeStackItem.name : "Folder"
                    }
                    stackWindow.root.isEditingFolderTitle = false
                    stackCard.forceActiveFocus()
                    return
                }
                if (stackWindow.root.isEditMode) {
                    stackWindow.root.isEditMode = false
                }
                stackWindow.root.activeStackItem = null
            }

            readonly property int totalApps: (stackWindow.root.activeStackItem && stackWindow.root.activeStackItem.subApps) ? stackWindow.root.activeStackItem.subApps.length : 0
            readonly property int gridCols: totalApps <= 4 ? 2 : 3
            readonly property int gridRows: Math.max(1, Math.ceil(totalApps / gridCols))

            readonly property int baseGridWidth: gridCols * 50 - 6 + 24

            width: baseGridWidth
            height: (stackWindow.root.showFolderTitles ? 36 : 0) + (gridRows * 50 - 6) + 24

            color: stackWindow.root.isBarTransparent
                ? Util.alpha(Color.popups.background, 0.45)
                : Color.popups.background
            border.width: stackWindow.root.isBarTransparent ? 0 : stackWindow.root.systemBorderSize
            border.color: stackWindow.root.isBarTransparent ? "transparent" : Color.accent
            radius: stackWindow.root.systemRounding
            antialiasing: true
            smooth: true

            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: (stackWindow.root.folderDragActiveIndex >= 0) ? Qt.BlankCursor : (stackWindow.root.isEditMode ? Qt.PointingHandCursor : Qt.ArrowCursor)
                onClicked: function(mouse) {
                    if (stackWindow.root.isEditingFolderTitle && typeof titleInput !== "undefined") {
                        titleInput.saveAndClose()
                    }
                    if (mouse.button === Qt.RightButton || mouse.button === Qt.LeftButton) {
                        stackWindow.root.isEditMode = false
                    }
                }
            }

            // Folder Title Header (shown when stackWindow.root.showFolderTitles is true)
            Item {
                id: titleContainer
                visible: stackWindow.root.showFolderTitles
                anchors.top: parent.top
                anchors.topMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 24
                height: 28

                // Silky smooth wiggle animation on hover and in edit mode
                SequentialAnimation {
                    id: titleJiggleAnim
                    running: (stackWindow.root.isEditMode || titleHoverArea.containsMouse) && !stackWindow.root.isEditingFolderTitle && !titleInput.activeFocus
                    loops: Animation.Infinite

                    NumberAnimation {
                        target: titleContainer
                        property: "rotation"
                        to: -3.8
                        duration: 105
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: titleContainer
                        property: "rotation"
                        to: 3.8
                        duration: 105
                        easing.type: Easing.InOutSine
                    }
                }

                NumberAnimation {
                    id: resetTitleRotation
                    target: titleContainer
                    property: "rotation"
                    to: 0.0
                    duration: 120
                    easing.type: Easing.OutCubic
                    running: (!stackWindow.root.isEditMode && !titleHoverArea.containsMouse || stackWindow.root.isEditingFolderTitle || titleInput.activeFocus) && titleContainer.rotation !== 0.0
                }

                readonly property real availableTitleWidth: Math.max(10, width - 16)
                readonly property bool needsMarquee: !stackWindow.root.isEditingFolderTitle && !titleInput.activeFocus && (titleLabel.implicitWidth > availableTitleWidth)
                readonly property real scrollDistance: Math.max(0, titleLabel.implicitWidth - availableTitleWidth)
                property real marqueeOffset: 0

                onNeedsMarqueeChanged: {
                    if (!needsMarquee) {
                        marqueeOffset = 0
                        marqueeAnim.stop()
                    } else {
                        marqueeAnim.restart()
                    }
                }

                    // Background pill (hover / edit)
                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: (stackWindow.root.isEditingFolderTitle || titleInput.activeFocus)
                            ? Style.hoverFillFor(Color.popups.text, Color.accent)
                            : (titleHoverArea.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent")
                        border.width: (stackWindow.root.isEditingFolderTitle || titleInput.activeFocus) ? 1 : 0
                        border.color: Color.accent
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // Marquee Animation: smooth ticker for long folder names
                    SequentialAnimation {
                        id: marqueeAnim
                        running: titleContainer.needsMarquee && stackWindow.visible
                        loops: Animation.Infinite

                        PauseAnimation { duration: 1200 }
                        NumberAnimation {
                            target: titleContainer
                            property: "marqueeOffset"
                            to: -titleContainer.scrollDistance
                            duration: Math.max(1600, titleContainer.scrollDistance * 32)
                            easing.type: Easing.InOutQuad
                        }
                        PauseAnimation { duration: 1200 }
                        NumberAnimation {
                            target: titleContainer
                            property: "marqueeOffset"
                            to: 0
                            duration: Math.max(1600, titleContainer.scrollDistance * 32)
                            easing.type: Easing.InOutQuad
                        }
                    }

                    // === DISPLAY: Text Viewport with smooth marquee / ticker ===
                    Item {
                        id: titleViewport
                        anchors.centerIn: parent
                        width: titleContainer.availableTitleWidth
                        height: parent.height
                        clip: true
                        visible: !stackWindow.root.isEditingFolderTitle

                        Text {
                            id: titleLabel
                            x: titleContainer.needsMarquee ? titleContainer.marqueeOffset : Math.round((parent.width - implicitWidth) / 2)
                            anchors.verticalCenter: parent.verticalCenter
                            text: stackWindow.root.activeStackItem ? stackWindow.root.activeStackItem.name : "Folder"
                            font.family: Style.font.family
                            font.pixelSize: 12
                            font.bold: true
                            color: Color.popups.text
                            elide: Text.ElideNone
                            wrapMode: Text.NoWrap
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // === EDIT: TextInput с прокруткой, виден только при фокусе ===
                    TextInput {
                        id: titleInput
                        anchors.centerIn: parent
                        width: parent.width - 12
                        visible: stackWindow.root.isEditingFolderTitle
                        enabled: stackWindow.root.isEditingFolderTitle
                        focus: stackWindow.root.isEditingFolderTitle
                        text: stackWindow.root.activeStackItem ? stackWindow.root.activeStackItem.name : "Folder"
                        font.family: Style.font.family
                        font.pixelSize: 12
                        font.bold: true
                        color: Color.popups.text
                        selectByMouse: true
                        cursorVisible: true
                        clip: true
                        horizontalAlignment: Text.AlignHCenter

                        onVisibleChanged: {
                            if (visible && stackWindow.root.activeStackItem) {
                                text = stackWindow.root.activeStackItem.name
                                selectAll()
                                forceActiveFocus()
                            }
                        }

                        function saveAndClose() {
                            var n = text.trim() || "Folder"
                            if (stackWindow.root.activeStackItem) {
                                stackWindow.root.setPinned(DockModel.renameStack(stackWindow.root.pinnedIds, stackWindow.root.activeStackItem.id, n))
                                stackWindow.root.activeStackItem.name = n
                            }
                            stackWindow.root.isEditingFolderTitle = false
                            focus = false
                            stackCard.forceActiveFocus()
                        }

                        Keys.onReturnPressed: function(event) { event.accepted = true; saveAndClose() }
                        Keys.onEnterPressed:  function(event) { event.accepted = true; saveAndClose() }
                        Keys.onEscapePressed: function(event) {
                            event.accepted = true
                            text = stackWindow.root.activeStackItem ? stackWindow.root.activeStackItem.name : "Folder"
                            stackWindow.root.isEditingFolderTitle = false
                            focus = false
                            stackCard.forceActiveFocus()
                        }
                        onEditingFinished: saveAndClose()
                    }

                    MouseArea {
                        id: titleHoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        visible: !stackWindow.root.isEditingFolderTitle
                        enabled: !stackWindow.root.isEditingFolderTitle
                        cursorShape: (stackWindow.root.folderDragActiveIndex >= 0 || titleHoverArea.containsMouse) ? Qt.BlankCursor : Qt.IBeamCursor
                        onClicked: {
                            if (stackWindow.root.activeStackItem) {
                                stackWindow.root.isEditingFolderTitle = true
                            }
                        }
                    }
                }

            // Grid of App Icons inside the Folder (Reordering restricted to 2D grid rails)
            Item {
                id: gridContainer
                anchors.top: stackWindow.root.showFolderTitles ? titleContainer.bottom : parent.top
                anchors.topMargin: stackWindow.root.showFolderTitles ? 6 : 12
                anchors.horizontalCenter: parent.horizontalCenter
                width: stackCard.gridCols * 50 - 6
                height: stackCard.gridRows * 50 - 6

                    Repeater {
                        model: (stackWindow.root.activeStackItem && stackWindow.root.activeStackItem.subApps) ? stackWindow.root.activeStackItem.subApps : []

                        Item {
                            id: subItemRoot
                            readonly property int totalSub: (stackWindow.root.activeStackItem && stackWindow.root.activeStackItem.subApps) ? stackWindow.root.activeStackItem.subApps.length : 0
                            readonly property int visualSubSlot: (stackWindow.root.folderDragActiveIndex === index) ? index : stackWindow.root.getFolderVisualSlot(index, stackWindow.root.folderDragActiveIndex, stackWindow.root.folderDragTargetIndex)
                            readonly property int slotCol: visualSubSlot % stackCard.gridCols
                            readonly property int slotRow: Math.floor(visualSubSlot / stackCard.gridCols)

                            property int subPreviewTopIndex: -1
                            property bool isSubWheelScrolling: false

                            Timer {
                                id: subWheelCursorTimer
                                interval: 1200
                                repeat: false
                                onTriggered: {
                                    subItemRoot.isSubWheelScrolling = false
                                }
                            }

                            readonly property int subRealActiveTopIndex: (modelData && typeof modelData.activeTopIndex === "number") ? modelData.activeTopIndex : 0

                            readonly property int subEffectiveTopIndex: {
                                var total = (modelData && modelData.toplevels) ? modelData.toplevels.length : 0
                                if (total === 0) return 0
                                if (subItemRoot.subPreviewTopIndex >= 0 && subItemRoot.subPreviewTopIndex < total) return subItemRoot.subPreviewTopIndex
                                return subItemRoot.subRealActiveTopIndex
                            }

                            Timer {
                                id: subPreviewResetTimer
                                interval: 1500
                                repeat: false
                                onTriggered: {
                                    if (!subMouse.containsMouse) {
                                        subItemRoot.subPreviewTopIndex = -1
                                    }
                                }
                            }

                            x: slotCol * 50
                            y: slotRow * 50
                            width: 44
                            height: 44
                            z: (stackWindow.root.folderDragActiveIndex === index) ? 100 : (subMouse.containsMouse ? 50 : 1)

                            Behavior on x {
                                enabled: stackWindow.root.folderDragActiveIndex >= 0 && stackWindow.root.folderDragActiveIndex !== index
                                NumberAnimation { duration: 320; easing.type: Easing.OutQuint }
                            }
                            Behavior on y {
                                enabled: stackWindow.root.folderDragActiveIndex >= 0 && stackWindow.root.folderDragActiveIndex !== index
                                NumberAnimation { duration: 320; easing.type: Easing.OutQuint }
                            }

                            property real subClickScaleFactor: 1.0

                            Rectangle {
                                id: subClickRipple
                                anchors.centerIn: parent
                                width: parent.width
                                height: parent.height
                                radius: width / 2
                                color: "transparent"
                                border.width: 2
                                border.color: Color.accent
                                opacity: 0.0
                                scale: 0.5
                                z: 0
                            }

                            SequentialAnimation {
                                id: subClickEffectAnim
                                alwaysRunToEnd: true

                                ParallelAnimation {
                                    NumberAnimation { target: subItemRoot; property: "subClickScaleFactor"; from: 0.92; to: 1.07; duration: 130; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: subClickRipple; property: "scale"; from: 0.5; to: 1.35; duration: 240; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: subClickRipple; property: "opacity"; from: 0.65; to: 0.0; duration: 240; easing.type: Easing.OutCubic }
                                }
                                NumberAnimation { target: subItemRoot; property: "subClickScaleFactor"; to: 1.0; duration: 120; easing.type: Easing.OutCubic }
                            }

                            // Independent Drag Offset for folder items
                            Item {
                                id: subDragOffset
                                x: 0
                                y: 0
                            }

                            Item {
                                id: subItemWrapper
                                x: (parent.width - width) / 2 + Math.max(- (index % stackCard.gridCols) * 50, Math.min((stackCard.gridCols - 1 - (index % stackCard.gridCols)) * 50, subDragOffset.x))
                                y: (parent.height - height) / 2 + Math.max(- Math.floor(index / stackCard.gridCols) * 50, Math.min((stackCard.gridRows - 1 - Math.floor(index / stackCard.gridCols)) * 50, subDragOffset.y))
                                width: 34
                                height: 34
                                scale: ((stackWindow.root.folderDragActiveIndex === index) ? 1.15 : (stackWindow.root.isEditMode ? 0.82 : (subMouse.pressed ? 0.92 : (subMouse.containsMouse ? 1.10 : 1.0)))) * subItemRoot.subClickScaleFactor
                                opacity: (stackWindow.root.folderDragActiveIndex === index) ? 0.92 : 1.0
                                Behavior on scale {
                                    enabled: !subClickEffectAnim.running && (subMouse.containsMouse || subMouse.pressed || stackWindow.root.isEditMode || stackWindow.root.folderDragActiveIndex >= 0)
                                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                }

                                Image {
                                    id: subIcon
                                    anchors.centerIn: parent
                                    width: 28
                                    height: 28
                                    fillMode: Image.PreserveAspectFit
                                    source: (stackWindow.root.iconRevision, stackWindow.root.resolveIcon(modelData))
                                    sourceSize: Qt.size(Math.max(128, 28 * 4 * Screen.devicePixelRatio), Math.max(128, 28 * 4 * Screen.devicePixelRatio))
                                    asynchronous: false
                                    mipmap: true
                                    smooth: true
                                    antialiasing: true
                                }

                                // iOS-Style Theme Notification Badge on Sub-App (Modular)
                                NotificationBadge {
                                    anchors.top: parent.top
                                    anchors.topMargin: -3
                                    anchors.right: parent.right
                                    anchors.rightMargin: -3
                                    badgeHeight: 16
                                    badgeFontSize: 9
                                    count: (modelData && modelData.badgeCount) ? modelData.badgeCount : 0
                                    hasUrgent: (modelData && !!modelData.hasUrgent)
                                    isSuppressed: stackWindow.root.isEditMode || stackWindow.root.folderDragActiveIndex >= 0 || !stackWindow.root.showBadges
                                }

                                // Silky smooth, organic wiggle animation
                                SequentialAnimation {
                                    id: subJiggleAnim
                                    running: (stackWindow.root.folderDragActiveIndex === index) || stackWindow.root.isEditMode
                                    loops: Animation.Infinite

                                    NumberAnimation {
                                        target: subIcon
                                        property: "rotation"
                                        to: -3.8
                                        duration: 105
                                        easing.type: Easing.InOutSine
                                    }
                                    NumberAnimation {
                                        target: subIcon
                                        property: "rotation"
                                        to: 3.8
                                        duration: 105
                                        easing.type: Easing.InOutSine
                                    }
                                }

                                NumberAnimation {
                                    id: resetSubRotation
                                    target: subIcon
                                    property: "rotation"
                                    to: 0.0
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                    running: stackWindow.root.folderDragActiveIndex !== index && !stackWindow.root.isEditMode && subIcon.rotation !== 0.0
                                }

                                // Multi-instance duplicate capsule under subApp icon (Sliding window viewport)
                                Rectangle {
                                    id: subDuplicateCapsule
                                    visible: opacity > 0
                                    opacity: (modelData.isRunning && modelData.toplevels && modelData.toplevels.length >= 2 && !stackWindow.root.isEditMode) ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 180 } }

                                    readonly property int totalWindows: (modelData && modelData.toplevels) ? modelData.toplevels.length : 0
                                    readonly property int winCount: Math.min(totalWindows, 3)

                                    function getSubSlotWindowIndex(slotIdx) {
                                        if (totalWindows <= 3) {
                                            return slotIdx
                                        }
                                        var cur = subItemRoot.subEffectiveTopIndex
                                        if (cur === 0 || cur === 1) {
                                            return slotIdx
                                        }
                                        if (cur === totalWindows - 1) {
                                            if (slotIdx === 0) return totalWindows - 2
                                            if (slotIdx === 1) return totalWindows - 1
                                            return 0
                                        }
                                        if (slotIdx === 0) return cur - 1
                                        if (slotIdx === 1) return cur
                                        return cur + 1
                                    }

                                    anchors.top: subIcon.bottom
                                    anchors.topMargin: 2
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    height: 6
                                    width: Math.max(18, 12 + winCount * 5)
                                    radius: height / 2

                                    color: Color.composed("popups.background", "popups.background-alpha", Color.background, 0.92)
                                    antialiasing: true
                                    smooth: true

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 3

                                        Repeater {
                                            model: subDuplicateCapsule.winCount
                                            Rectangle {
                                                readonly property int targetWinIdx: subDuplicateCapsule.getSubSlotWindowIndex(index)
                                                readonly property bool isAppActive: (modelData && modelData.isActive === true)
                                                readonly property bool isPreviewing: (subItemRoot.subPreviewTopIndex >= 0)
                                                readonly property bool isSlotHighlighted: (isAppActive || isPreviewing) && (targetWinIdx === subItemRoot.subEffectiveTopIndex)
                                                readonly property bool isOriginalApp: (targetWinIdx === 0)

                                                width: isOriginalApp ? 9.0 : (isSlotHighlighted ? 3.5 : 2.5)
                                                height: 2.5
                                                radius: 1.25
                                                color: isSlotHighlighted ? Color.accent : Color.composed("popups.text", "popups.text-alpha", Color.text, isOriginalApp ? 0.45 : 0.28)
                                                antialiasing: true
                                                smooth: true

                                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                                Behavior on color { ColorAnimation { duration: 120 } }
                                            }
                                        }
                                    }
                                }

                                // Running indicator dot under subApp icon (Single instance)
                                Rectangle {
                                    id: subDot
                                    visible: opacity > 0
                                    opacity: (modelData.isRunning && (!modelData.toplevels || modelData.toplevels.length <= 1) && !subMouse.containsMouse && !stackWindow.root.isEditMode) ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                                    anchors.top: subIcon.bottom
                                    anchors.topMargin: 2
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    width: modelData.isActive ? 10 : 4
                                    height: 2
                                    radius: 1
                                    color: modelData.isActive ? Color.accent : Color.composed("popups.text", "popups.text-alpha", Color.text, 0.6)
                                    antialiasing: true
                                    smooth: true

                                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }

                            // Long press timer for Edit Mode (450ms, folder only)
                            Timer {
                                id: subLongPressTimer
                                interval: 450
                                repeat: false
                                onTriggered: {
                                    if (stackWindow.root.activeStackItem && stackWindow.root.folderDragActiveIndex < 0) {
                                        subMouse.didSubLongPress = true
                                        stackWindow.root.isEditMode = true
                                    }
                                }
                            }

                            // Extract Glyph (Centered directly above subItemWrapper, folder only)
                            Item {
                                id: subExtractBadge
                                visible: stackWindow.root.activeStackItem && stackWindow.root.isEditMode && (stackWindow.root.folderDragActiveIndex < 0)
                                anchors.horizontalCenter: subItemWrapper.horizontalCenter
                                anchors.bottom: subItemWrapper.top
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
                                    color: subExtractMouse.containsMouse ? Color.accent : Color.composed("popups.text", "popups.text-alpha", Color.text, 0.85)

                                    scale: subExtractMouse.containsMouse ? 1.25 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                MouseArea {
                                    id: subExtractMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: (stackWindow.root.folderDragActiveIndex >= 0) ? Qt.BlankCursor : Qt.PointingHandCursor
                                    onClicked: function(mouse) {
                                        if (mouse.button === Qt.RightButton) {
                                            stackWindow.root.isEditMode = false
                                            return
                                        }
                                        if (stackWindow.root.activeStackItem) {
                                            var stackId = stackWindow.root.activeStackItem.id
                                            var remaining = (stackWindow.root.activeStackItem.subApps ? stackWindow.root.activeStackItem.subApps.length : 0) - 1
                                            stackWindow.root.setPinned(DockModel.extractFromStackToDock(stackWindow.root.pinnedIds, stackId, modelData.appId, stackWindow.root.activeStackItemIndex + 1))
                                            if (remaining <= 1) {
                                                stackWindow.root.activeStackItem = null
                                                stackWindow.root.isEditMode = false
                                            }
                                        }
                                    }
                                }
                            }

                            function cycleSubDuplicate(forward) {
                                if (!modelData || !modelData.isRunning || !modelData.toplevels) return
                                var len = modelData.toplevels.length
                                if (len <= 1) return

                                subItemRoot.isSubWheelScrolling = true
                                subWheelCursorTimer.restart()
                                subPreviewResetTimer.stop()
                                var curIdx = subItemRoot.subEffectiveTopIndex
                                var nextIdx = forward ? ((curIdx + 1) % len) : ((curIdx - 1 + len) % len)
                                subItemRoot.subPreviewTopIndex = nextIdx
                            }

                            MouseArea {
                                id: subMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                cursorShape: (stackWindow.root.folderDragActiveIndex >= 0 || subMouse.drag.active || isDraggingActive || subItemRoot.isSubWheelScrolling) ? Qt.BlankCursor : (stackWindow.root.isEditMode ? Qt.PointingHandCursor : Qt.ArrowCursor)

                                drag.target: stackWindow.root.activeStackItem ? subDragOffset : null
                                drag.axis: Drag.XAndYAxis
                                drag.minimumX: -99999
                                drag.maximumX: 99999
                                drag.minimumY: -99999
                                drag.maximumY: 99999
                                drag.threshold: 6

                                property bool isDraggingActive: false
                                property bool didSubLongPress: false

                                focus: containsMouse

                                onEntered: {
                                    subMouse.forceActiveFocus()
                                }

                                Keys.onRightPressed: function(event) {
                                    if (modelData && modelData.isRunning && modelData.toplevels && modelData.toplevels.length >= 2) {
                                        subItemRoot.cycleSubDuplicate(true)
                                        event.accepted = true
                                    }
                                }

                                Keys.onLeftPressed: function(event) {
                                    if (modelData && modelData.isRunning && modelData.toplevels && modelData.toplevels.length >= 2) {
                                        subItemRoot.cycleSubDuplicate(false)
                                        event.accepted = true
                                    }
                                }

                                Keys.onTabPressed: function(event) {
                                    if (modelData) {
                                        subClickEffectAnim.restart()
                                        DockModel.launchApp(stackWindow.root.shell, modelData, Util)
                                        event.accepted = true
                                    }
                                }

                                Keys.onReturnPressed: function(event) {
                                    if (modelData && modelData.isRunning && modelData.toplevels && modelData.toplevels.length >= 2 && subItemRoot.subPreviewTopIndex >= 0) {
                                        var top = modelData.toplevels[subItemRoot.subPreviewTopIndex]
                                        if (top && typeof top.activate === "function") {
                                            top.activate()
                                            subItemRoot.subPreviewTopIndex = -1
                                            event.accepted = true
                                        }
                                    }
                                }

                                onPressed: function(mouse) {
                                    if (mouse.button === Qt.LeftButton) {
                                        isDraggingActive = false
                                        didSubLongPress = false
                                        if (stackWindow.root.activeStackItem) {
                                            subLongPressTimer.restart()
                                        }
                                    }
                                }

                                onPositionChanged: function(mouse) {
                                    if (subItemRoot.isSubWheelScrolling) {
                                        subItemRoot.isSubWheelScrolling = false
                                    }
                                    if (subMouse.drag.active) {
                                        subLongPressTimer.stop()
                                        if (!isDraggingActive) {
                                            isDraggingActive = true
                                            stackWindow.root.folderDragActiveIndex = index
                                        }

                                        var rawOffsetX = subDragOffset.x
                                        var rawOffsetY = subDragOffset.y
                                        var clampedOffsetX = Math.max(- (index % stackCard.gridCols) * 50, Math.min((stackCard.gridCols - 1 - (index % stackCard.gridCols)) * 50, rawOffsetX))
                                        var clampedOffsetY = Math.max(- Math.floor(index / stackCard.gridCols) * 50, Math.min((stackCard.gridRows - 1 - Math.floor(index / stackCard.gridCols)) * 50, rawOffsetY))

                                        var currentPosX = (index % stackCard.gridCols) * 50 + clampedOffsetX
                                        var currentPosY = Math.floor(index / stackCard.gridCols) * 50 + clampedOffsetY

                                        var col = Math.max(0, Math.min(stackCard.gridCols - 1, Math.round(currentPosX / 50)))
                                        var row = Math.max(0, Math.min(stackCard.gridRows - 1, Math.round(currentPosY / 50)))
                                        var targetIdx = Math.max(0, Math.min(totalSub - 1, row * stackCard.gridCols + col))
                                        stackWindow.root.folderDragTargetIndex = targetIdx
                                    }
                                }

                                onReleased: function(mouse) {
                                    subLongPressTimer.stop()
                                    if (isDraggingActive && stackWindow.root.activeStackItem) {
                                        isDraggingActive = false
                                        var finalTarget = stackWindow.root.folderDragTargetIndex
                                        stackWindow.root.folderDragActiveIndex = -1
                                        stackWindow.root.folderDragTargetIndex = -1
                                        subDragOffset.x = 0
                                        subDragOffset.y = 0

                                        if (finalTarget >= 0 && finalTarget !== index) {
                                            stackWindow.root.setPinned(DockModel.reorderInStack(stackWindow.root.pinnedIds, stackWindow.root.activeStackItem.id, index, finalTarget))
                                        }
                                    }
                                }

                                onExited: {
                                    subItemRoot.isSubWheelScrolling = false
                                    subPreviewResetTimer.restart()
                                }

                                onWheel: function(wheel) {
                                    if (modelData && modelData.isRunning && modelData.toplevels && modelData.toplevels.length >= 2) {
                                        if (wheel.angleDelta.y < 0 || wheel.angleDelta.x > 0) {
                                            subItemRoot.cycleSubDuplicate(true)
                                            wheel.accepted = true
                                        } else if (wheel.angleDelta.y > 0 || wheel.angleDelta.x < 0) {
                                            subItemRoot.cycleSubDuplicate(false)
                                            wheel.accepted = true
                                        }
                                    }
                                }

                                onClicked: function(mouse) {
                                    if (isDraggingActive || didSubLongPress) {
                                        didSubLongPress = false
                                        return
                                    }

                                    // Middle Click (Wheel Button click) -> Immediately launch duplicate
                                    if (mouse.button === Qt.MiddleButton) {
                                        subClickEffectAnim.restart()
                                        DockModel.launchApp(stackWindow.root.shell, modelData, Util)
                                        return
                                    }

                                    if (mouse.button === Qt.LeftButton) {
                                        subClickEffectAnim.restart()
                                        if (modelData) {
                                            stackWindow.root.clearBadge(modelData)
                                        }
                                        if (stackWindow.root.isEditMode) {
                                            return
                                        }
                                        // 1. If not running, launch it (Folder stays open!)
                                        if (!modelData.isRunning || !modelData.toplevels || modelData.toplevels.length === 0) {
                                            var launchId = modelData.desktopId || modelData.appId || ""
                                            stackWindow.root.requestFocusOnLaunch(launchId)
                                            DockModel.launchApp(stackWindow.root.shell, modelData, Util)
                                            return
                                        }

                                        // 2. If running: activate chosen window (LMB focuses/switches)
                                        var tops = modelData.toplevels
                                        var targetIdx = subItemRoot.subEffectiveTopIndex
                                        if (targetIdx < 0 || targetIdx >= tops.length) targetIdx = 0

                                        var chosenWin = tops[targetIdx]
                                        if (chosenWin && typeof chosenWin.activate === "function") {
                                            chosenWin.activate()
                                        }
                                        subItemRoot.subPreviewTopIndex = -1
                                    } else if (mouse.button === Qt.RightButton) {
                                        if (stackWindow.root.isEditMode) {
                                            stackWindow.root.isEditMode = false
                                            return
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
