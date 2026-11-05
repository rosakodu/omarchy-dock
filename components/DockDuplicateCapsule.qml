import QtQuick
import qs.Commons

Rectangle {
    id: root

    property int totalWindows: 0
    property int effectiveTopIndex: 0
    property bool isAppActive: false
    property bool isPreviewing: false

    readonly property int winCount: Math.min(totalWindows, 3)

    function getSlotWindowIndex(slotIdx) {
        if (totalWindows <= 3) {
            return slotIdx
        }
        var cur = root.effectiveTopIndex
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
            model: root.winCount
            Rectangle {
                readonly property int targetWinIdx: root.getSlotWindowIndex(index)
                readonly property bool isSlotHighlighted: (root.isAppActive || root.isPreviewing) && (targetWinIdx === root.effectiveTopIndex)
                readonly property bool isOriginalApp: (targetWinIdx === 0)

                width: isOriginalApp ? 9.0 : (isSlotHighlighted ? 3.5 : 2.5)
                height: 2.5
                radius: 1.25
                color: isSlotHighlighted ? Color.accent : Color.composed("popups.text", "popups.text-alpha", Color.foreground, isOriginalApp ? 0.45 : 0.28)
                antialiasing: true
                smooth: true

                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
    }
}
