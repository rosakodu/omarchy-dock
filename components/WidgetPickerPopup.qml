import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs.Commons
import qs.Ui
import ".."
import "../DockModel.js" as DockModel

PanelWindow {
    id: pickerWindow

    property var root: null
    property var dockWindow: null
    property var shell: null
    property bool opened: false

    onOpenedChanged: {
        if (pickerWindow.root && typeof pickerWindow.root.handleWidgetPickerOpenedChanged === "function") {
            pickerWindow.root.handleWidgetPickerOpenedChanged(opened)
        }
    }

    WlrLayershell.namespace: "omarchy-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: pickerWindow.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    screen: (pickerWindow.dockWindow && pickerWindow.dockWindow.screen) ? pickerWindow.dockWindow.screen : (Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)

    visible: opened && pickerWindow.root && pickerWindow.root.dockRevealed

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Fullscreen Screen Dimming / Blur Scrim (Matches Omarchy Menu)
    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Color.menu.scrim
        opacity: pickerWindow.opened ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    // Outside click dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: {
            pickerWindow.opened = false
        }
    }

    // Centered Picker Card (Exact Omarchy Menu border & theme styling)
    BorderSurface {
        id: pickerCard
        width: 380
        height: 540
        anchors.centerIn: parent

        color: Color.menu.background
        borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
        radius: Style.cornerRadius >= 0 ? Style.cornerRadius : 14
        antialiasing: true
        smooth: true

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        focus: pickerWindow.opened
        Keys.onEscapePressed: function(event) {
            pickerWindow.opened = false
            event.accepted = true
        }

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // 1. Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Dock Widgets"
                    font.family: Style.font.family
                    font.pixelSize: 14
                    font.bold: true
                    color: Color.menu.text
                    Layout.fillWidth: true
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Color.composed("menu.border", "menu.border-alpha", Color.border, 0.25)
            }

            // 2. App Menu Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                // App Menu Position Control
                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: 7
                    color: Color.composed("menu.text", "menu.text-alpha", Color.text, 0.05)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 4
                        spacing: 8

                        Text {
                            text: "App Menu position:"
                            font.family: Style.font.family
                            font.pixelSize: 11
                            font.bold: true
                            color: Color.menu.text
                            Layout.fillWidth: true
                        }

                        // Segmented Button: Left | Right
                        Row {
                            spacing: 3

                            Rectangle {
                                width: 60
                                height: 26
                                radius: 5
                                readonly property bool isLeft: (!pickerWindow.root || pickerWindow.root.appMenuPosition !== "right")
                                color: isLeft ? Color.accent : (posAppLeftMouse.containsMouse ? Color.composed("menu.text", "menu.text-alpha", Color.text, 0.12) : "transparent")
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Left"
                                    font.family: Style.font.family
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: parent.isLeft ? Color.background : Color.menu.text
                                }

                                MouseArea {
                                    id: posAppLeftMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: function(mouse) {
                                        if (pickerWindow.root) pickerWindow.root.setAppMenuPosition("left")
                                        mouse.accepted = true
                                    }
                                    onClicked: {
                                        if (pickerWindow.root) pickerWindow.root.setAppMenuPosition("left")
                                    }
                                }
                            }

                            Rectangle {
                                width: 60
                                height: 26
                                radius: 5
                                readonly property bool isRight: (pickerWindow.root && pickerWindow.root.appMenuPosition === "right")
                                color: isRight ? Color.accent : (posAppRightMouse.containsMouse ? Color.composed("menu.text", "menu.text-alpha", Color.text, 0.12) : "transparent")
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Right"
                                    font.family: Style.font.family
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: parent.isRight ? Color.background : Color.menu.text
                                }

                                MouseArea {
                                    id: posAppRightMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: function(mouse) {
                                        if (pickerWindow.root) pickerWindow.root.setAppMenuPosition("right")
                                        mouse.accepted = true
                                    }
                                    onClicked: {
                                        if (pickerWindow.root) pickerWindow.root.setAppMenuPosition("right")
                                    }
                                }
                            }
                        }
                    }
                }

                // App Menu Item Toggle
                Rectangle {
                    id: appMenuItemRow
                    Layout.fillWidth: true
                    height: 38
                    radius: 7

                    readonly property bool isInDock: (pickerWindow.root && pickerWindow.root.dockWidgets && pickerWindow.root.dockWidgets.indexOf("omarchy.apps") !== -1)
                    readonly property bool isHovered: appItemMouse.containsMouse

                    color: isInDock ? Color.composed("menu.selectedBackground", "menu.selectedBackground-alpha", Color.accent, isHovered ? 0.18 : 0.10) : (isHovered ? Color.composed("menu.text", "menu.text-alpha", Color.text, 0.06) : "transparent")
                    border.width: 1
                    border.color: isInDock ? Color.composed("accent", "accent-alpha", Color.accent, 0.4) : (isHovered ? Color.composed("menu.border", "menu.border-alpha", Color.border, 0.2) : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        // Icon
                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            Layout.alignment: Qt.AlignVCenter
                            radius: 5
                            color: appMenuItemRow.isInDock ? Color.composed("accent", "accent-alpha", Color.accent, 0.2) : Color.composed("menu.text", "menu.text-alpha", Color.text, 0.08)

                            DockGlyph {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                text: "󰀻"
                                fontFamily: Style.font.family
                                fontSize: 14
                                color: appMenuItemRow.isInDock ? Color.accent : Color.menu.text
                            }
                        }

                        // Title & Badge
                        Row {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            spacing: 8

                            Text {
                                text: "Apps"
                                font.family: Style.font.family
                                font.pixelSize: 12
                                font.bold: true
                                color: Color.menu.text
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                height: 16
                                width: appBadgeText.implicitWidth + 8
                                radius: 4
                                color: appMenuItemRow.isInDock ? Color.composed("accent", "accent-alpha", Color.accent, 0.25) : Color.composed("menu.text", "menu.text-alpha", Color.text, 0.08)
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    id: appBadgeText
                                    anchors.centerIn: parent
                                    text: appMenuItemRow.isInDock ? "Dock" : "Off"
                                    font.family: Style.font.family
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: appMenuItemRow.isInDock ? Color.accent : Color.muted
                                }
                            }
                        }

                        // Toggle Switch
                        Rectangle {
                            id: appSwitchTrack
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 18
                            Layout.alignment: Qt.AlignVCenter
                            radius: 9
                            color: appMenuItemRow.isInDock ? Color.accent : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.25)
                            Behavior on color { ColorAnimation { duration: 180 } }

                            Rectangle {
                                id: appSwitchThumb
                                width: 12
                                height: 12
                                radius: 6
                                anchors.verticalCenter: parent.verticalCenter
                                x: appMenuItemRow.isInDock ? (appSwitchTrack.width - width - 3) : 3
                                color: appMenuItemRow.isInDock ? Color.background : Color.popups.text
                                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            }
                        }
                    }

                    MouseArea {
                        id: appItemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (appMenuItemRow.isInDock) {
                                pickerWindow.root.removeDockWidget("omarchy.apps")
                            } else {
                                pickerWindow.root.addDockWidget("omarchy.apps")
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Color.composed("menu.border", "menu.border-alpha", Color.border, 0.25)
            }

            // 3. Widgets Section
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                // Other Widget Position Control
                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: 7
                    color: Color.composed("menu.text", "menu.text-alpha", Color.text, 0.05)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 4
                        spacing: 8

                        Text {
                            text: "Widget position:"
                            font.family: Style.font.family
                            font.pixelSize: 11
                            font.bold: true
                            color: Color.menu.text
                            Layout.fillWidth: true
                        }

                        // Segmented Button: Left | Right
                        Row {
                            spacing: 3

                            Rectangle {
                                width: 60
                                height: 26
                                radius: 5
                                readonly property bool isLeft: (pickerWindow.root && pickerWindow.root.widgetPosition === "left")
                                color: isLeft ? Color.accent : (posLeftMouse.containsMouse ? Color.composed("menu.text", "menu.text-alpha", Color.text, 0.12) : "transparent")
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Left"
                                    font.family: Style.font.family
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: parent.isLeft ? Color.background : Color.menu.text
                                }

                                MouseArea {
                                    id: posLeftMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: function(mouse) {
                                        if (pickerWindow.root) pickerWindow.root.setWidgetPosition("left")
                                        mouse.accepted = true
                                    }
                                    onClicked: {
                                        if (pickerWindow.root) pickerWindow.root.setWidgetPosition("left")
                                    }
                                }
                            }

                            Rectangle {
                                width: 60
                                height: 26
                                radius: 5
                                readonly property bool isRight: (!pickerWindow.root || pickerWindow.root.widgetPosition !== "left")
                                color: isRight ? Color.accent : (posRightMouse.containsMouse ? Color.composed("menu.text", "menu.text-alpha", Color.text, 0.12) : "transparent")
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Right"
                                    font.family: Style.font.family
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: parent.isRight ? Color.background : Color.menu.text
                                }

                                MouseArea {
                                    id: posRightMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: function(mouse) {
                                        if (pickerWindow.root) pickerWindow.root.setWidgetPosition("right")
                                        mouse.accepted = true
                                    }
                                    onClicked: {
                                        if (pickerWindow.root) pickerWindow.root.setWidgetPosition("right")
                                    }
                                }
                            }
                        }
                    }
                }

                // Compact Widgets List View (Excluding omarchy.apps which is configured above)
                ListView {
                    id: widgetsList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4

                    readonly property var standardWidgets: [
                        { id: "omarchy.clock", name: "Clock & Calendar", icon: "󰥔", defaultRegion: "center" },
                        { id: "omarchy.weather", name: "Weather", icon: "󰖐", defaultRegion: "center" },
                        { id: "omarchy.audio", name: "Volume & Audio", icon: "󰕾", defaultRegion: "right" },
                        { id: "omarchy.network", name: "Network & Wi-Fi", icon: "󰖩", defaultRegion: "right" },
                        { id: "omarchy.bluetooth", name: "Bluetooth", icon: "󰂯", defaultRegion: "right" },
                        { id: "omarchy.power", name: "Battery & Power", icon: "󰁹", defaultRegion: "right" },
                        { id: "omarchy.monitor", name: "Display", icon: "󰍹", defaultRegion: "right" },
                        { id: "omarchy.tailscale", name: "Tailscale VPN", icon: "󰖂", defaultRegion: "right" }
                    ]

                    model: {
                        var list = []
                        for (var i = 0; i < standardWidgets.length; i++) {
                            var w = standardWidgets[i]
                            // Only show installed widgets
                            var isInstalled = true
                            if (pickerWindow.shell && pickerWindow.shell.pluginRegistry && pickerWindow.shell.pluginRegistry.installedPlugins) {
                                isInstalled = (pickerWindow.shell.pluginRegistry.installedPlugins[w.id] !== undefined)
                            }
                            if (!isInstalled) continue
                            list.push(w)
                        }
                        return list
                    }

                    delegate: Rectangle {
                        id: rowItem
                        width: widgetsList.width
                        height: 38
                        radius: 7

                        readonly property bool isInDock: (pickerWindow.root && pickerWindow.root.dockWidgets && pickerWindow.root.dockWidgets.indexOf(modelData.id) !== -1)
                        readonly property bool isHovered: itemMouse.containsMouse

                        color: isInDock ? Color.composed("menu.selectedBackground", "menu.selectedBackground-alpha", Color.accent, isHovered ? 0.18 : 0.10) : (isHovered ? Color.composed("menu.text", "menu.text-alpha", Color.text, 0.06) : "transparent")
                        border.width: 1
                        border.color: isInDock ? Color.composed("accent", "accent-alpha", Color.accent, 0.4) : (isHovered ? Color.composed("menu.border", "menu.border-alpha", Color.border, 0.2) : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            // Widget Icon
                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                Layout.alignment: Qt.AlignVCenter
                                radius: 5
                                color: rowItem.isInDock ? Color.composed("accent", "accent-alpha", Color.accent, 0.2) : Color.composed("menu.text", "menu.text-alpha", Color.text, 0.08)

                                DockGlyph {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    text: modelData.icon
                                    fontFamily: modelData.fontFamily ? modelData.fontFamily : Style.font.family
                                    fontSize: 14
                                    color: rowItem.isInDock ? Color.accent : Color.menu.text
                                }
                            }

                            // Widget Title & Badge (Strictly Left-Aligned)
                            Row {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                                spacing: 8

                                Text {
                                    text: modelData.name
                                    font.family: Style.font.family
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Color.menu.text
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    height: 16
                                    width: badgeText.implicitWidth + 8
                                    radius: 4
                                    color: rowItem.isInDock ? Color.composed("accent", "accent-alpha", Color.accent, 0.25) : Color.composed("menu.text", "menu.text-alpha", Color.text, 0.08)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        id: badgeText
                                        anchors.centerIn: parent
                                        text: rowItem.isInDock ? "Dock" : "Tray"
                                        font.family: Style.font.family
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: rowItem.isInDock ? Color.accent : Color.muted
                                    }
                                }
                            }

                            // Toggle Switch for Quick Transfer
                            Rectangle {
                                id: switchTrack
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 18
                                Layout.alignment: Qt.AlignVCenter
                                radius: 9
                                color: rowItem.isInDock ? Color.accent : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.25)
                                Behavior on color { ColorAnimation { duration: 180 } }

                                Rectangle {
                                    id: switchThumb
                                    width: 12
                                    height: 12
                                    radius: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: rowItem.isInDock ? (switchTrack.width - width - 3) : 3
                                    color: rowItem.isInDock ? Color.background : Color.popups.text
                                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (rowItem.isInDock) {
                                    pickerWindow.root.removeDockWidget(modelData.id, modelData.defaultRegion)
                                } else {
                                    pickerWindow.root.addDockWidget(modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
