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
    id: menuWindow
    visible: menuWindow.root.isMenuOpen && menuWindow.root.dockRevealed

    required property var root
    required property var dockWindow
    property var stackWindow: null
    property alias menuCard: menuCard
    screen: menuWindow.dockWindow ? menuWindow.dockWindow.screen : null

    readonly property bool isDirectDockPopup: !menuWindow.root.isMenuFromFolder

    WlrLayershell.namespace: "omarchy-dock-menu"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: menuWindow.root.isMenuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: menuWindow.root.reservesSpace ? ExclusionMode.Auto : ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: (!menuWindow.root.isVertical && menuWindow.root.barPosition === "bottom") ? true : (menuWindow.root.isVertical ? true : false)
        bottom: (!menuWindow.root.isVertical && menuWindow.root.barPosition === "top") ? true : (menuWindow.root.isVertical ? true : false)
        left: (menuWindow.root.isVertical && menuWindow.root.barPosition === "right") ? true : (!menuWindow.root.isVertical ? true : false)
        right: (menuWindow.root.isVertical && menuWindow.root.barPosition === "left") ? true : (!menuWindow.root.isVertical ? true : false)
    }

    margins {
        bottom: (!menuWindow.root.isVertical && menuWindow.root.barPosition === "top")
            ? (isDirectDockPopup ? (Style.gapsOut || 5) : ((Style.gapsOut || 5) + 54 + 6 + (stackWindow && stackWindow.stackCard ? stackWindow.stackCard.height : 180) + 6))
            : 0
        top: (!menuWindow.root.isVertical && menuWindow.root.barPosition === "bottom")
            ? (isDirectDockPopup ? (Style.gapsOut || 5) : ((Style.gapsOut || 5) + 54 + 6 + (stackWindow && stackWindow.stackCard ? stackWindow.stackCard.height : 180) + 6))
            : 0
        right: (menuWindow.root.isVertical && menuWindow.root.barPosition === "left")
            ? (isDirectDockPopup ? (Style.gapsOut || 5) : ((Style.gapsOut || 5) + 54 + 6 + (stackWindow && stackWindow.stackCard ? stackWindow.stackCard.width : 180) + 6))
            : 0
        left: (menuWindow.root.isVertical && menuWindow.root.barPosition === "right")
            ? (isDirectDockPopup ? (Style.gapsOut || 5) : ((Style.gapsOut || 5) + 54 + 6 + (stackWindow && stackWindow.stackCard ? stackWindow.stackCard.width : 180) + 6))
            : 0
    }

    implicitWidth: menuWindow.root.isVertical ? menuCard.width : (dockWindow.screen ? dockWindow.screen.width : 1920)
    implicitHeight: menuWindow.root.isVertical ? (dockWindow.screen ? dockWindow.screen.height : 1080) : menuCard.height

    onVisibleChanged: {
        if (visible) {
            menuCard.forceActiveFocus()
            var foundIdx = -1
            if (menuWindow.root.activeMenuItem && menuWindow.root.activeMenuItem.isStack && menuWindow.root.activeMenuItem.icon) {
                foundIdx = menuWindow.root.availableFolderIcons.indexOf(menuWindow.root.activeMenuItem.icon)
            }
            if (menuWindow.root.activeMenuItem && menuWindow.root.activeMenuItem.isStack) {
                menuCard.selectedIndex = (foundIdx >= 0) ? foundIdx : 0
            } else {
                menuCard.selectedIndex = -1
            }
        }
    }

    // Dismissal MouseArea covering the entire transparent overlay area of menuWindow outside menuCard
    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
            menuWindow.root.activeMenuItem = null
        }
    }

    // Visual Action Card (Strictly centered above the dock, Folder Icon Picker only)
    Rectangle {
        id: menuCard
        z: 1
        anchors.centerIn: parent
        focus: true

        property int selectedIndex: -1
        property bool isWheelOrKeyNav: false

        HoverHandler {
            id: menuCardHover
            onHoveredChanged: {
                menuWindow.root.isMenuHovered = hovered
                menuWindow.root.evaluateHoverState()
            }
        }

        readonly property bool isFolderMenu: !!(menuWindow.root.activeMenuItem && (menuWindow.root.activeMenuItem.isStack === true || menuWindow.root.isMenuFromFolder))

        readonly property int totalMenuItems: {
            if (!menuWindow.root.activeMenuItem) return 0
            return menuWindow.root.availableFolderIcons.length + 1
        }

        function triggerCurrentSelection() {
            if (!menuWindow.root.activeMenuItem) return
            if (isFolderMenu) {
                if (selectedIndex >= 0 && selectedIndex < menuWindow.root.availableFolderIcons.length) {
                    var chosenIcon = menuWindow.root.availableFolderIcons[selectedIndex]
                    var cur = menuWindow.root.activeMenuItem.icon || "grid"
                    var targetIcon = (cur === chosenIcon) ? "grid" : chosenIcon
                    menuWindow.root.setPinned(DockModel.setStackIcon(menuWindow.root.pinnedIds, menuWindow.root.activeMenuItem.id, targetIcon))
                } else if (selectedIndex === menuWindow.root.availableFolderIcons.length) {
                    menuWindow.root.setPinned(DockModel.dissolveStack(menuWindow.root.pinnedIds, menuWindow.root.activeMenuItem.id))
                    menuWindow.root.activeStackItem = null
                }
            }
            menuWindow.root.activeMenuItem = null
        }

        Keys.onLeftPressed: function(event) {
            event.accepted = true
            isWheelOrKeyNav = true
            if (totalMenuItems > 0) {
                selectedIndex = (selectedIndex <= 0) ? (totalMenuItems - 1) : (selectedIndex - 1)
            }
        }

        Keys.onRightPressed: function(event) {
            event.accepted = true
            isWheelOrKeyNav = true
            if (totalMenuItems > 0) {
                selectedIndex = (selectedIndex + 1) % totalMenuItems
            }
        }

        Keys.onUpPressed: function(event) {
            event.accepted = true
            isWheelOrKeyNav = true
            if (totalMenuItems > 0) {
                selectedIndex = (selectedIndex <= 0) ? (totalMenuItems - 1) : (selectedIndex - 1)
            }
        }

        Keys.onDownPressed: function(event) {
            event.accepted = true
            isWheelOrKeyNav = true
            if (totalMenuItems > 0) {
                selectedIndex = (selectedIndex + 1) % totalMenuItems
            }
        }

        Keys.onReturnPressed: function(event) {
            event.accepted = true
            triggerCurrentSelection()
        }

        Keys.onEnterPressed: function(event) {
            event.accepted = true
            triggerCurrentSelection()
        }

        Keys.onSpacePressed: function(event) {
            event.accepted = true
            triggerCurrentSelection()
        }

        Keys.onEscapePressed: function(event) {
            event.accepted = true
            menuWindow.root.activeMenuItem = null
        }

        width: menuWindow.root.isVertical ? 36 : Math.max(36, (menuWindow.root.availableFolderIcons.length + 1) * 30 + 10)
        height: !menuWindow.root.isVertical ? 36 : Math.max(36, (menuWindow.root.availableFolderIcons.length + 1) * 30 + 10)
        color: menuWindow.root.isBarTransparent
            ? Util.alpha(Color.popups.background, 0.45)
            : Color.popups.background
        border.width: menuWindow.root.isBarTransparent ? 0 : menuWindow.root.systemBorderSize
        border.color: menuWindow.root.isBarTransparent ? "transparent" : Color.accent
        radius: Math.min(10, menuWindow.root.systemRounding)
        antialiasing: true
        smooth: true

        Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.InOutCubic } }
        Behavior on border.color { ColorAnimation { duration: 300; easing.type: Easing.InOutCubic } }
        Behavior on border.width { NumberAnimation { duration: 250; easing.type: Easing.InOutCubic } }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                menuCard.isWheelOrKeyNav = true
                if (menuCard.totalMenuItems > 0) {
                    var delta = (event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x)
                    var step = delta > 0 ? -1 : 1
                    menuCard.selectedIndex = (menuCard.selectedIndex + step + menuCard.totalMenuItems) % menuCard.totalMenuItems
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            hoverEnabled: true
            cursorShape: menuCard.isWheelOrKeyNav ? Qt.BlankCursor : Qt.ArrowCursor
            onPositionChanged: function(mouse) {
                menuCard.isWheelOrKeyNav = false
            }
            onWheel: function(wheel) {
                menuCard.isWheelOrKeyNav = true
                if (menuCard.totalMenuItems > 0) {
                    var delta = (wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x)
                    var step = delta > 0 ? -1 : 1
                    menuCard.selectedIndex = (menuCard.selectedIndex + step + menuCard.totalMenuItems) % menuCard.totalMenuItems
                }
            }
        }

        // 1. Horizontal layout when dock is horizontal (Folder Icon Picker)
        Row {
            id: actionRow
            visible: !menuWindow.root.isVertical && menuCard.isFolderMenu
            anchors.centerIn: parent
            spacing: 4

            // Folder Symbols Picker List (Monochrome vector glyphs with optical centering)
            Repeater {
                model: (!menuWindow.root.isMenuFromFolder && menuWindow.root.activeMenuItem && menuWindow.root.activeMenuItem.isStack) ? menuWindow.root.availableFolderIcons : []

                Item {
                    id: iconChoiceBtnH
                    width: 26
                    height: 24

                    readonly property bool isCurrentIcon: {
                        if (!menuWindow.root.activeMenuItem) return false
                        return menuWindow.root.activeMenuItem.icon === modelData
                    }
                    readonly property bool isFocused: menuCard.selectedIndex === index

                    DockGlyph {
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        text: modelData
                        fontFamily: Style.font.family
                        fontSize: 14
                        color: isCurrentIcon
                            ? Color.accent
                            : (iconChoiceBtnH.isFocused ? Color.accent : Color.popups.text)

                        scale: iconChoiceBtnH.isFocused ? 1.25 : 1.0
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: isCurrentIcon ? Color.composed("accent", "accent-alpha", Color.accent, 0.22) : "transparent"
                        border.width: isCurrentIcon ? 1 : 0
                        border.color: isCurrentIcon ? Color.accent : "transparent"
                    }

                    MouseArea {
                        id: iconChoiceMouseH
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: menuCard.isWheelOrKeyNav ? Qt.BlankCursor : Qt.PointingHandCursor
                        onEntered: {
                            if (!menuCard.isWheelOrKeyNav) {
                                menuCard.selectedIndex = index
                            }
                        }
                        onPositionChanged: function(mouse) {
                            menuCard.isWheelOrKeyNav = false
                            menuCard.selectedIndex = index
                        }
                        onWheel: function(wheel) {
                            menuCard.isWheelOrKeyNav = true
                            if (menuCard.totalMenuItems > 0) {
                                var delta = (wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x)
                                var step = delta > 0 ? -1 : 1
                                menuCard.selectedIndex = (menuCard.selectedIndex + step + menuCard.totalMenuItems) % menuCard.totalMenuItems
                            }
                        }
                        onClicked: {
                            if (menuWindow.root.activeMenuItem && menuWindow.root.activeMenuItem.isStack) {
                                var cur = menuWindow.root.activeMenuItem.icon || "grid"
                                var targetIcon = (cur === modelData) ? "grid" : modelData
                                menuWindow.root.setPinned(DockModel.setStackIcon(menuWindow.root.pinnedIds, menuWindow.root.activeMenuItem.id, targetIcon))
                            }
                            menuWindow.root.activeMenuItem = null
                        }
                    }
                }
            }

            // Divider before action buttons for folder
            Rectangle {
                visible: !menuWindow.root.isMenuFromFolder && (menuWindow.root.activeMenuItem && menuWindow.root.activeMenuItem.isStack)
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 14
                color: Color.composed("popups.border", "popups.border-alpha", Color.border, 0.35)
            }

            // 3. Minus Button: Extract app from folder OR Delete entire folder
            Item {
                id: minusBtnH
                visible: menuWindow.root.isMenuFromFolder || (menuWindow.root.activeMenuItem && menuWindow.root.activeMenuItem.isStack)
                width: 26
                height: 24

                readonly property bool isFocused: menuCard.selectedIndex === menuWindow.root.availableFolderIcons.length

                DockGlyph {
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    text: "-"
                    fontFamily: Style.font.family
                    fontSize: 16
                    color: minusBtnH.isFocused ? Color.accent : Color.popups.text

                    scale: minusBtnH.isFocused ? 1.25 : 1.0
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: minusMouseH
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: menuCard.isWheelOrKeyNav ? Qt.BlankCursor : Qt.PointingHandCursor
                    onEntered: {
                        if (!menuCard.isWheelOrKeyNav) {
                            menuCard.selectedIndex = menuWindow.root.availableFolderIcons.length
                        }
                    }
                    onPositionChanged: function(mouse) {
                        menuCard.isWheelOrKeyNav = false
                        menuCard.selectedIndex = menuWindow.root.availableFolderIcons.length
                    }
                    onWheel: function(wheel) {
                        menuCard.isWheelOrKeyNav = true
                        if (menuCard.totalMenuItems > 0) {
                            var delta = (wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x)
                            var step = delta > 0 ? -1 : 1
                            menuCard.selectedIndex = (menuCard.selectedIndex + step + menuCard.totalMenuItems) % menuCard.totalMenuItems
                        }
                    }
                    onClicked: {
                        if (!menuWindow.root.activeMenuItem) return
                        if (menuWindow.root.activeMenuItem.isStack) {
                            menuWindow.root.setPinned(DockModel.dissolveStack(menuWindow.root.pinnedIds, menuWindow.root.activeMenuItem.id))
                            menuWindow.root.activeStackItem = null
                        } else if (menuWindow.root.isMenuFromFolder && menuWindow.root.activeStackItem) {
                            menuWindow.root.setPinned(DockModel.extractFromStackToDock(menuWindow.root.pinnedIds, menuWindow.root.activeStackItem.id, menuWindow.root.activeMenuItem.appId, menuWindow.root.activeStackItemIndex + 1))
                        }
                        menuWindow.root.activeMenuItem = null
                    }
                }
            }
        }

        // 2. Vertical layout when dock is vertical (Folder Icon Picker)
        Column {
            id: actionCol
            visible: menuWindow.root.isVertical && menuCard.isFolderMenu
            anchors.centerIn: parent
            spacing: 4

            // Folder Symbols Picker List (Monochrome vector glyphs with optical centering)
            Repeater {
                model: (!menuWindow.root.isMenuFromFolder && menuWindow.root.activeMenuItem && menuWindow.root.activeMenuItem.isStack) ? menuWindow.root.availableFolderIcons : []

                Item {
                    id: iconChoiceBtnV
                    width: 24
                    height: 26

                    readonly property bool isCurrentIcon: {
                        if (!menuWindow.root.activeMenuItem) return false
                        return menuWindow.root.activeMenuItem.icon === modelData
                    }
                    readonly property bool isFocused: menuCard.selectedIndex === index

                    DockGlyph {
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        text: modelData
                        fontFamily: Style.font.family
                        fontSize: 14
                        color: isCurrentIcon
                            ? Color.accent
                            : (iconChoiceBtnV.isFocused ? Color.accent : Color.popups.text)

                        scale: iconChoiceBtnV.isFocused ? 1.25 : 1.0
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: isCurrentIcon ? Color.composed("accent", "accent-alpha", Color.accent, 0.22) : "transparent"
                        border.width: isCurrentIcon ? 1 : 0
                        border.color: isCurrentIcon ? Color.accent : "transparent"
                    }

                    MouseArea {
                        id: iconChoiceMouseV
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: menuCard.isWheelOrKeyNav ? Qt.BlankCursor : Qt.PointingHandCursor
                        onEntered: {
                            if (!menuCard.isWheelOrKeyNav) {
                                menuCard.selectedIndex = index
                            }
                        }
                        onPositionChanged: function(mouse) {
                            menuCard.isWheelOrKeyNav = false
                            menuCard.selectedIndex = index
                        }
                        onWheel: function(wheel) {
                            menuCard.isWheelOrKeyNav = true
                            if (menuCard.totalMenuItems > 0) {
                                var delta = (wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x)
                                var step = delta > 0 ? -1 : 1
                                menuCard.selectedIndex = (menuCard.selectedIndex + step + menuCard.totalMenuItems) % menuCard.totalMenuItems
                            }
                        }
                        onClicked: {
                            if (menuWindow.root.activeMenuItem && menuWindow.root.activeMenuItem.isStack) {
                                var cur = menuWindow.root.activeMenuItem.icon || "grid"
                                var targetIcon = (cur === modelData) ? "grid" : modelData
                                menuWindow.root.setPinned(DockModel.setStackIcon(menuWindow.root.pinnedIds, menuWindow.root.activeMenuItem.id, targetIcon))
                            }
                            menuWindow.root.activeMenuItem = null
                        }
                    }
                }
            }

            // Divider before action buttons for folder
            Rectangle {
                visible: !menuWindow.root.isMenuFromFolder && (menuWindow.root.activeMenuItem && menuWindow.root.activeMenuItem.isStack)
                anchors.horizontalCenter: parent.horizontalCenter
                width: 14
                height: 1
                color: Color.composed("popups.border", "popups.border-alpha", Color.border, 0.35)
            }

            // 3. Minus Button: Extract app from folder OR Delete entire folder at the bottom of the column
            Item {
                id: minusBtnV
                visible: menuWindow.root.isMenuFromFolder || (menuWindow.root.activeMenuItem && menuWindow.root.activeMenuItem.isStack)
                width: 24
                height: 26

                readonly property bool isFocused: menuCard.selectedIndex === menuWindow.root.availableFolderIcons.length

                DockGlyph {
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    text: "-"
                    fontFamily: Style.font.family
                    fontSize: 16
                    color: minusBtnV.isFocused ? Color.accent : Color.popups.text

                    scale: minusBtnV.isFocused ? 1.25 : 1.0
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: minusMouseV
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: menuCard.isWheelOrKeyNav ? Qt.BlankCursor : Qt.PointingHandCursor
                    onEntered: {
                        if (!menuCard.isWheelOrKeyNav) {
                            menuCard.selectedIndex = menuWindow.root.availableFolderIcons.length
                        }
                    }
                    onPositionChanged: function(mouse) {
                        menuCard.isWheelOrKeyNav = false
                        menuCard.selectedIndex = menuWindow.root.availableFolderIcons.length
                    }
                    onWheel: function(wheel) {
                        menuCard.isWheelOrKeyNav = true
                        if (menuCard.totalMenuItems > 0) {
                            var delta = (wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x)
                            var step = delta > 0 ? -1 : 1
                            menuCard.selectedIndex = (menuCard.selectedIndex + step + menuCard.totalMenuItems) % menuCard.totalMenuItems
                        }
                    }
                    onClicked: {
                        if (!menuWindow.root.activeMenuItem) return
                        if (menuWindow.root.activeMenuItem.isStack) {
                            menuWindow.root.setPinned(DockModel.dissolveStack(menuWindow.root.pinnedIds, menuWindow.root.activeMenuItem.id))
                            menuWindow.root.activeStackItem = null
                        } else if (menuWindow.root.isMenuFromFolder && menuWindow.root.activeStackItem) {
                            menuWindow.root.setPinned(DockModel.extractFromStackToDock(menuWindow.root.pinnedIds, menuWindow.root.activeStackItem.id, menuWindow.root.activeMenuItem.appId, menuWindow.root.activeStackItemIndex + 1))
                        }
                        menuWindow.root.activeMenuItem = null
                    }
                }
            }
        }
    }
}
