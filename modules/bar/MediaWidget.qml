import QtQuick
import QtQuick.Layouts
import "../../themes"
import "../../services"

Item {
    id: root
    signal clicked()
    property bool vertical: false
    implicitWidth: vertical ? col.implicitWidth + 12 : row.implicitWidth + 16
    implicitHeight: vertical ? col.implicitHeight + 10 : row.implicitHeight + 10
    scale: Theme.animationsEnabled && mouse.containsMouse ? 1.06 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
    RowLayout {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 8
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            id: mediaIcon
            text: MediaService.widgetIcon
            font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(15); font.weight: Theme.textBold ? Font.Bold : Font.Normal
            color: mouse.containsMouse ? Theme.primary : (MediaService.isPlaying ? Theme.accent : Theme.textPrimary)
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: MediaService.hasPlayer
            text: MediaService.trackLabel
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Theme.textBold ? Font.Bold : Font.Normal
            color: mouse.containsMouse ? Theme.primary : Theme.textSecondary
            elide: Text.ElideRight
            Layout.maximumWidth: 160
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
    }
    ColumnLayout {
        id: col
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 9
        Text { text: MediaService.widgetIcon; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14); font.weight: Theme.textBold ? Font.Bold : Font.Normal; color: mouse.containsMouse ? Theme.primary : (MediaService.isPlaying ? Theme.accent : Theme.textPrimary); Layout.alignment: Qt.AlignHCenter; Behavior on color { ColorAnimation { duration: Theme.animFast } }
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => { if (event.angleDelta.y > 0) MediaService.playNext(); else MediaService.playPrev(); event.accepted = true }
    }
}
