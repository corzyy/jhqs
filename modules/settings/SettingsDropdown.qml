pragma ComponentBehavior: Bound
import QtQuick
import "../../themes"

Column {
    id: root
    property string label: ""
    property var options: []
    property string current: ""
    signal picked(string value)
    width: parent ? parent.width : 300
    spacing: root.isMinimal ? 6 : 4
    readonly property bool isMinimal: Theme.minimalTheme

    Rectangle {
        antialiasing: Theme.shapesAa
        id: btn
        width: parent.width; height: 36
        radius: root.isMinimal ? 0 : Theme.cornerRadiusSmall
        color: root.isMinimal
            ? (ddMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08) : Theme.withAlpha(Theme.textPrimary, 0.04))
            : (ddMouse.containsMouse ? Theme.bgHover : Theme.panelSurface)
        border.color: root.isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.25) : Theme.divider; border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        Row {
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
            spacing: 8
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: root.label.length > 0 ? root.label : ""
                visible: root.label.length > 0
                font.family: root.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(12)
                color: Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: root.current
                font.family: root.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Medium
                color: Theme.textPrimary; elide: Text.ElideRight
                width: parent.width - (root.label.length > 0 ? 80 : 40)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: root.open ? "▴" : "▾"
                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12)
                color: Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea { id: ddMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.open = !root.open }
    }

    property bool open: false
    Column {
        id: list
        width: parent.width
        visible: root.open
        spacing: 2
        Repeater {
            model: root.options
            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool isCurrent: modelData + "" === root.current
                width: list.width; height: 32
                radius: root.isMinimal ? 0 : Theme.cornerRadiusSmall
                color: isCurrent && root.isMinimal ? Theme.withAlpha(Theme.accent, 0.16)
                    : optMouse.containsMouse ? (root.isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.08) : Theme.bgHover)
                    : isCurrent ? Theme.bgSelected : "transparent"
                border.color: isCurrent ? (root.isMinimal ? Theme.accent : Theme.divider) : "transparent"
                border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    anchors.fill: parent; anchors.leftMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    text: modelData + ""
                    font.family: root.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(12)
                    font.weight: isCurrent && root.isMinimal ? Font.Bold : Font.Normal
                    color: isCurrent ? Theme.textPrimary : Theme.textSecondary
                }
                MouseArea { id: optMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.picked(modelData + ""); root.open = false } }
            }
        }
    }
}
