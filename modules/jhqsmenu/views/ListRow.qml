pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../../themes"

Rectangle {
    antialiasing: Theme.shapesAa
    id: root
    required property bool isSelected
    required property string icon
    required property string title
    property string arrow: ""
    property bool showArrow: false
    readonly property bool isMinimal: Theme.shellTheme === "minimal"

    height: isMinimal ? 50 : 40
    radius: isMinimal ? Theme.cornerRadius : Theme.cornerRadiusSmall
    color: isSelected ? (isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.08) : Theme.bgSelected) : rowMouse.containsMouse ? (isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.04) : Theme.panelSurface) : "transparent"
    border.color: isMinimal ? "transparent" : (isSelected ? Theme.accent : "transparent"); border.width: isMinimal ? 0 : (isSelected ? 1 : 0)
    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingSmooth } }
    Behavior on border.width { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }

    signal clicked()

    RowLayout {
        anchors.fill: parent; anchors.leftMargin: isMinimal ? 8 : 12; anchors.rightMargin: isMinimal ? 8 : 10; spacing: isMinimal ? 6 : 10
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: root.icon
            font.family: Theme.iconFontFamily; font.pixelSize: isMinimal ? Theme.fs(18) : Theme.fs(14)
            color: root.isSelected ? Theme.accent : (isMinimal ? Theme.textPrimary : Theme.textMuted)
            Layout.preferredWidth: isMinimal ? 36 : 18; horizontalAlignment: Text.AlignHCenter
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingSmooth } }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: root.title
            font.family: isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: isMinimal ? Theme.fs(16) : Theme.fs(13)
            font.weight: isMinimal ? Font.Medium : (root.isSelected ? Font.Medium : Font.Normal)
            color: root.isSelected ? (isMinimal ? Theme.accent : Theme.textPrimary) : (isMinimal ? Theme.textPrimary : Theme.textSecondary)
            Layout.fillWidth: true; elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingSmooth } }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: root.showArrow && root.arrow.length > 0
            text: root.arrow
            font.family: isMinimal ? Theme.fontFamily : Theme.iconFontFamily; font.pixelSize: Theme.fs(16)
            color: root.isSelected ? Theme.accent : (isMinimal ? Theme.textPrimary : Theme.textMuted)
            opacity: root.isSelected ? 1.0 : (isMinimal ? 0.36 : 0.65)
            horizontalAlignment: Text.AlignHCenter; Layout.preferredWidth: isMinimal ? 14 : 16
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingSmooth } }
            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        }
    }
    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
