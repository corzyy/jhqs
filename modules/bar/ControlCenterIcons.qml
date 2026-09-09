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
        spacing: 10
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            id: netIcon
            text: NetworkService.netActive ? "󰈀" : "󰈂"
            font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(15); font.weight: Theme.textBold ? Font.Bold : Font.Normal
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            onTextChanged: netFade.restart()
            SequentialAnimation on opacity { id: netFade; running: false; NumberAnimation { to: 0.3; duration: Theme.animFast / 2 } NumberAnimation { to: 1; duration: Theme.animFast } }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            id: volIcon
            text: VolumeService.icon
            font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(15); font.weight: Theme.textBold ? Font.Bold : Font.Normal
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            onTextChanged: volFade.restart()
            SequentialAnimation on scale { id: volFade; running: false; NumberAnimation { to: 1.25; duration: Theme.animFast / 2; easing.type: Theme.easingEmph } NumberAnimation { to: 1.0; duration: Theme.animFast } }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: Theme.dndEnabled
            text: "󰂛"
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(15); font.weight: Theme.textBold ? Font.Bold : Font.Normal
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            opacity: visible ? 1 : 0
            scale: visible ? 1 : 0.7
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
            Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
            onVisibleChanged: if (visible) dndPop.restart()
            SequentialAnimation on scale { id: dndPop; running: false; NumberAnimation { to: 1.2; duration: Theme.animFast; easing.type: Theme.easingEmph } NumberAnimation { to: 1.0; duration: Theme.animFast } }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            id: pmIcon
            text: Theme.powerModeIcon()
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(15); font.weight: Theme.textBold ? Font.Bold : Font.Normal
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            onTextChanged: pmFade.restart()
            SequentialAnimation on scale { id: pmFade; running: false; NumberAnimation { to: 1.25; duration: Theme.animFast / 2; easing.type: Theme.easingEmph } NumberAnimation { to: 1.0; duration: Theme.animFast } }
        }
    }
    ColumnLayout {
        id: col
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 9
        Text { text: NetworkService.netActive ? "󰈀" : "󰈂"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14); font.weight: Theme.textBold ? Font.Bold : Font.Normal; color: mouse.containsMouse ? Theme.primary : Theme.textPrimary; Layout.alignment: Qt.AlignHCenter; Behavior on color { ColorAnimation { duration: Theme.animFast } }
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
        Text { text: VolumeService.icon; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14); font.weight: Theme.textBold ? Font.Bold : Font.Normal; color: mouse.containsMouse ? Theme.primary : Theme.textPrimary; Layout.alignment: Qt.AlignHCenter; Behavior on color { ColorAnimation { duration: Theme.animFast } }
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
        Text { visible: Theme.dndEnabled; text: "󰂛"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14); font.weight: Theme.textBold ? Font.Bold : Font.Normal; color: mouse.containsMouse ? Theme.primary : Theme.textPrimary; Layout.alignment: Qt.AlignHCenter; opacity: visible ? 1 : 0
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } } }
        Text { text: Theme.powerModeIcon(); font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14); font.weight: Theme.textBold ? Font.Bold : Font.Normal; color: mouse.containsMouse ? Theme.primary : Theme.textPrimary; Layout.alignment: Qt.AlignHCenter; Behavior on color { ColorAnimation { duration: Theme.animFast } }
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
        onWheel: event => { if (event.angleDelta.y > 0) VolumeService.stepUp(); else VolumeService.stepDown(); event.accepted = true }
    }
}
