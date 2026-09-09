pragma ComponentBehavior: Bound
import QtQuick
import "../../themes"

Column {
    id: root
    property string title: ""
    default property alias content: body.children
    spacing: isMinimal ? 6 : 8
    width: parent ? parent.width : 300
    readonly property bool isMinimal: Theme.minimalTheme

    Text {
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
        visible: root.title.length > 0
        text: root.title.toUpperCase()
        font.family: root.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(10)
        font.weight: Font.Bold; font.letterSpacing: root.isMinimal ? 1.2 : 0.8
        color: root.isMinimal ? Theme.textSecondary : Theme.textMuted
    }
    Rectangle {
        antialiasing: Theme.shapesAa
        id: card
        width: parent.width
        implicitHeight: body.implicitHeight + (root.isMinimal ? 0 : 16)
        radius: root.isMinimal ? 0 : Theme.cornerRadiusSmall
        color: root.isMinimal ? "transparent" : Theme.cardBg
        border.color: root.isMinimal ? "transparent" : Theme.divider
        border.width: root.isMinimal ? 0 : 1
        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        Column {
            id: body
            anchors.fill: parent
            anchors.margins: root.isMinimal ? 0 : 8
            spacing: root.isMinimal ? 6 : 4
        }
    }
}
