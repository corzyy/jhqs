import QtQuick
import "../../themes"

Item {
    id: root
    implicitWidth: 22; implicitHeight: 22
    signal clicked()
    Text {
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
        id: launcherIcon
        anchors.centerIn: parent
        text: ""
        font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(18)
        color: m.containsMouse ? Theme.primary : Theme.textPrimary
        scale: 1.0
    }
    MouseArea {
        id: m
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
