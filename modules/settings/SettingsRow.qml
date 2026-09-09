pragma ComponentBehavior: Bound
import QtQuick
import "../../themes"

Rectangle {
    antialiasing: Theme.shapesAa
    id: root
    property string title: ""
    property string subtitle: ""
    property bool selected: false
    default property alias control: slot.children
    readonly property bool isMinimal: Theme.minimalTheme
    width: parent ? parent.width : 300
    height: subtitle.length > 0 ? 52 : 40
    radius: root.isMinimal ? 0 : Theme.cornerRadiusSmall
    color: root.isMinimal
        ? (selected || rowMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08) : "transparent")
        : (selected ? Theme.bgSelected : rowMouse.containsMouse ? Theme.bgHover : "transparent")
    border.color: (!root.isMinimal && selected) ? Theme.divider : "transparent"
    border.width: (!root.isMinimal && selected) ? 1 : 0
    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }

    MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 10; anchors.rightMargin: 10
        spacing: 10
        Column {
            width: parent.width - slotWrap.width - 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: root.title
                font.family: root.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(root.isMinimal ? 12 : 13)
                font.weight: root.isMinimal && root.selected ? Font.Bold : Font.Medium
                color: root.isMinimal ? Theme.textPrimary : (selected ? Theme.textPrimary : Theme.textSecondary)
                elide: Text.ElideRight; width: parent.width
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                visible: root.subtitle.length > 0
                text: root.subtitle
                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
                color: Theme.textMuted
                elide: Text.ElideRight; width: parent.width
            }
        }
        Item {
            id: slotWrap
            width: slot.children.length > 0 ? slot.implicitWidth : 0
            height: parent.height
            Row { id: slot; anchors.centerIn: parent; spacing: 6 }
        }
    }
}
