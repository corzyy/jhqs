pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../../themes"
import "../../../Ui"

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
    // Optional image source for the leading slot (e.g. app launcher rows).
    // Empty falls back to the glyph `icon` Text as before.
    property string iconSource: ""
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
    // Caelestia ButtonBase radius morph: pressed corners tighten while held.
    radius: rowLayer.pressed ? Theme.cornerRadiusSmall : Theme.cornerRadius
    color: active ? (Theme.withAlpha(Theme.textPrimary, 0.08)) : rowLayer.containsMouse ? (Theme.withAlpha(Theme.textPrimary, 0.04)) : "transparent"
    border.color: "transparent"; border.width: 0
    Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: Theme.durSlowEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSlowEffects } }
    Behavior on radius { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects } }
    // Press squash: rows settle slightly while held (ButtonBase feel).
    scale: rowLayer.pressed ? 0.985 : 1
    transformOrigin: Item.Center
    Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
    // Entrance cascade: rows rise + fade in with a per-index stagger when
    // the list (re)builds — the "content appears" motion. Driven once at
    // creation so later selection/hover changes never replay it.
    // `enterOnCreate: false` lets a parent drive its own entrance (recycled
    // ListView delegates don't re-run Component.onCompleted).
    property bool enterOnCreate: true
    opacity: enterOnCreate ? 0 : 1
    transform: Translate { id: enterShift; y: 6 }
    Component.onCompleted: if (enterOnCreate) enterAnim.start()
    SequentialAnimation {
        id: enterAnim
        PauseAnimation { duration: Math.min(Math.max(0, root.index), 14) * Theme.animStagger }
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects }
            NumberAnimation { target: enterShift; property: "y"; to: 0; duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial }
        }
    }

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 6
        Item {
            Layout.preferredWidth: 36
            Layout.preferredHeight: Math.max(18, iconText.implicitHeight)
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            Text {
                id: iconText
                anchors.centerIn: parent
                width: 36
                visible: root.iconSource === ""
                text: root.effectiveIcon
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(18)
                color: root.active ? Theme.accent : (Theme.textPrimary)
                horizontalAlignment: Text.AlignHCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            IconImage {
                visible: root.iconSource !== ""
                anchors.centerIn: parent
                width: 18
                height: 18
                source: root.iconSource
                asynchronous: true
                implicitSize: Qt.size(36, 36)
                mipmap: Theme.imageMipmap
            }
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
    StateLayer {
        id: rowLayer
        radius: root.radius
        color: root.active ? Theme.accent : Theme.textPrimary
        onClicked: { root.clicked(); root.activated(root.index) }
    }
}
