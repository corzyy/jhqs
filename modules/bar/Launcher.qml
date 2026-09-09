import QtQuick
import "../../themes"

Item {
    id: root
    implicitWidth: 22; implicitHeight: 22
    signal clicked()
    scale: Theme.animationsEnabled && m.containsMouse ? 1.08 : (Theme.animationsEnabled && m.pressed ? 0.96 : 1.0)
    Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
    Text {
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
        id: launcherIcon
        anchors.centerIn: parent
        text: ""
        font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(18)
        color: m.containsMouse ? Theme.primary : Theme.textPrimary
        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
        scale: Theme.animationsEnabled && m.pressed ? 0.92 : 1.0
    }
    MouseArea {
        id: m
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
