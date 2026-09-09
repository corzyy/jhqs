import QtQuick
import QtQuick.Layouts
import "../../themes"
import "../../services"

Item {
    id: root
    signal clicked()
    property bool vertical: false
    implicitWidth: row.implicitWidth + 16
    implicitHeight: row.implicitHeight + 10
    scale: Theme.animationsEnabled && mouse.containsMouse ? 1.06 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: NetworkService.icon
            font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14)
            color: mouse.containsMouse ? Theme.accent : (NetworkService.netActive ? Theme.textPrimary : Theme.textMuted)
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
