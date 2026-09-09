import QtQuick
import Quickshell
import "../../themes"

Item {
    id: root
    signal clicked()
    property bool vertical: false
    implicitWidth: vertical ? 28 : row.implicitWidth + 14
    implicitHeight: vertical ? vCol.implicitHeight + 10 : 24
    scale: Theme.animationsEnabled && mouse.containsMouse ? 1.04 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
    Behavior on implicitHeight { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
    opacity: enabled ? 1 : 0.6
    Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }

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
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            width: visible ? implicitWidth : 0
            Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            id: timeText
            text: Qt.formatDateTime(c.date, "HH:mm")
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); font.weight: Theme.textBold ? Font.Medium : Font.Normal
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            onTextChanged: tickFade.restart()
            SequentialAnimation on opacity {
                id: tickFade
                running: false
                NumberAnimation { to: 0.55; duration: Theme.animFast / 2; easing.type: Theme.easingSmooth }
                NumberAnimation { to: 1.0; duration: Theme.animFast; easing.type: Theme.easingSmooth }
            }
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
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: Qt.formatDateTime(c.date, "mm")
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); font.weight: Theme.textBold ? Font.Medium : Font.Normal
            anchors.horizontalCenter: parent.horizontalCenter
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            onTextChanged: vTick.restart()
            SequentialAnimation on opacity {
                id: vTick
                running: false
                NumberAnimation { to: 0.55; duration: Theme.animFast / 2; easing.type: Theme.easingSmooth }
                NumberAnimation { to: 1.0; duration: Theme.animFast; easing.type: Theme.easingSmooth }
            }
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
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            height: visible ? implicitHeight : 0
            Behavior on height { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
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
