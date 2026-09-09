pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../../themes"

Rectangle {
    antialiasing: Theme.shapesAa
    id: root
    required property var modelData
    required property int index
    property bool selected: false
    property string glyph: "›"
    property string sub: ""
    signal activated(int index)
    readonly property bool isMinimal: Theme.shellTheme === "minimal"
    readonly property bool hasDetail: sub.length > 0
    Layout.fillWidth: true
    Layout.preferredHeight: hasDetail ? 58 : 50
    radius: isMinimal ? Theme.cornerRadius : Theme.cornerRadiusSmall
    color: selected ? (isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.08) : Theme.bgSelected) : rowMouse.containsMouse ? (isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.04) : Theme.panelSurface) : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingSmooth } }
    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 6
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: modelData.icon
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fs(isMinimal ? 18 : 16)
            color: root.selected ? Theme.accent : (isMinimal ? Theme.textPrimary : Theme.textSecondary)
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingSmooth } }
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignHCenter
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: modelData.title
                font.family: isMinimal ? Theme.iconFontFamily : Theme.fontFamily
                font.pixelSize: Theme.fs(isMinimal ? 16 : 13)
                font.weight: Font.Medium
                color: root.selected ? (isMinimal ? Theme.accent : Theme.textPrimary) : (isMinimal ? Theme.textPrimary : Theme.textSecondary)
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingSmooth } }
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                visible: root.hasDetail
                text: root.sub
                font.family: isMinimal ? Theme.iconFontFamily : Theme.fontFamily
                font.pixelSize: Theme.fs(11)
                color: Theme.textPrimary
                opacity: 0.52
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
        Text { text: root.glyph; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); color: root.selected ? Theme.accent : Theme.textPrimary; opacity: (root.glyph.length > 0 && root.glyph === "›") ? 0.36 : (root.selected ? 1.0 : 0.4)
            visible: root.glyph.length > 0
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            Layout.preferredWidth: visible ? 14 : 0
            horizontalAlignment: Text.AlignHCenter
        }
    }
    MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: activated(index) }
}
