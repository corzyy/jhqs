import QtQuick
import Quickshell
import "../../themes"

Item {
    id: root
    signal clicked()
    property bool vertical: false
    implicitWidth: vertical ? 28 : row.implicitWidth + 14
    implicitHeight: vertical ? vCol.implicitHeight + 10 : 24
    // NOTE: `opacity: enabled ? ...` + its Behavior removed — `enabled` is
    // never set false, so this was a permanent 1.0 with a dead animation.

    readonly property bool isTimeOnly: Theme.clockFormat === "timeOnly"

    SystemClock { id: c; precision: SystemClock.Minutes }

    Row {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 8
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            id: dayText
            visible: !root.isTimeOnly
            text: Qt.formatDateTime(c.date, "dddd")
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); font.weight: Theme.textBold ? Font.Medium : Font.Normal
            anchors.verticalCenter: parent.verticalCenter
            opacity: visible ? 1 : 0
            width: visible ? implicitWidth : 0
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            id: timeText
            text: Qt.formatDateTime(c.date, "HH:mm")
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); font.weight: Theme.textBold ? Font.Medium : Font.Normal
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    Column {
        id: vCol
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 2
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: Qt.formatDateTime(c.date, "HH")
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); font.weight: Theme.textBold ? Font.Medium : Font.Normal
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: Qt.formatDateTime(c.date, "mm")
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); font.weight: Theme.textBold ? Font.Medium : Font.Normal
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: !root.isTimeOnly
            text: Qt.formatDateTime(c.date, "ddd")
            color: mouse.containsMouse ? Theme.primary : Theme.textMuted
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Normal
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: visible ? 0.85 : 0
            height: visible ? implicitHeight : 0
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) Theme.toggleClockFormat()
            else root.clicked()
        }
    }
}
