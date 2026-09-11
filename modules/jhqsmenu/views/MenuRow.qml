pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../../themes"

// Merged from ListRow.qml + ModuleRow.qml (were 90% identical:
// icon + title + trailing glyph row). One component, two spellings:
//  - list style:  isSelected + icon/title + showArrow/arrow + clicked()
//  - module style: selected + modelData/index + sub/glyph + activated(index)
// `modelData`/`index` stay required (as in both predecessors) so Repeater
// delegates receive them before any other binding evaluates.
Rectangle {
    antialiasing: Theme.shapesAa
    id: root

    required property var modelData
    required property int index

    property bool selected: false
    property bool isSelected: false
    readonly property bool active: selected || isSelected

    property string icon: ""
    property string title: ""
    property string sub: ""
    property string glyph: "›"
    property string arrow: ""
    property bool showArrow: false

    readonly property string effectiveIcon: icon !== "" ? icon : (modelData && modelData.icon ? modelData.icon : "")
    readonly property string effectiveTitle: title !== "" ? title : (modelData && modelData.title ? modelData.title : "")
    readonly property bool hasDetail: sub.length > 0
    readonly property string trailing: showArrow ? arrow : glyph
    readonly property bool trailingVisible: trailing.length > 0 && (!showArrow || arrow.length > 0)
    readonly property real trailingOpacity: showArrow
        ? (active ? 1.0 : 0.36)
        : ((glyph.length > 0 && glyph === "›") ? 0.36 : (active ? 1.0 : 0.4))

    signal clicked()
    signal activated(int index)

    height: hasDetail ? 58 : 50
    Layout.fillWidth: true
    Layout.preferredHeight: height
    radius: Theme.cornerRadius
    color: active ? (Theme.withAlpha(Theme.textPrimary, 0.08)) : rowMouse.containsMouse ? (Theme.withAlpha(Theme.textPrimary, 0.04)) : "transparent"
    border.color: "transparent"; border.width: 0

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 6
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: root.effectiveIcon
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fs(18)
            color: root.active ? Theme.accent : (Theme.textPrimary)
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignHCenter
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: root.effectiveTitle
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(16)
                font.weight: Font.Medium
                color: root.active ? (Theme.accent) : (Theme.textPrimary)
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                visible: root.hasDetail
                text: root.sub
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(11)
                color: Theme.textPrimary
                opacity: 0.52
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: root.trailingVisible
            text: root.trailing
            font.family: showArrow ? Theme.fontFamily : Theme.iconFontFamily
            font.pixelSize: Theme.fs(16)
            color: root.active ? Theme.accent : (Theme.textPrimary)
            opacity: root.trailingOpacity
            horizontalAlignment: Text.AlignHCenter
            Layout.preferredWidth: visible ? 14 : 0
        }
    }
    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { root.clicked(); root.activated(root.index) }
    }
}
