// PanelShell — shared window-anchored container for all bar panels.
// DRY: 7 panels duplicated this exact block (~50 lines each): BarAnchor
// positioning, spring show/hide, click-swallowing, Flickable + content
// column. Only module id, visibility flag, width and content differ.
// Usage: PanelShell { moduleId: "volume"; shown: scope.showVolume; ... }
// (SettingsPanel/CalendarMenu are intentionally excluded: centered modal
// and Loader-anchored popup follow different geometry.)
pragma ComponentBehavior: Bound
import QtQuick
import "../themes"

Rectangle {
    id: root

    required property string moduleId
    property string barPos: "top"
    property real panelGap: 0
    required property bool shown
    property real boxWidth: 340
    property real minHeight: 120
    // Extra height added to content (Flickable margins + breathing room).
    property real heightPadding: 20
    property real contentMargins: 10
    property real contentSpacing: 8

    default property alias content: contentCol.children

    antialiasing: Theme.shapesAa
    width: boxWidth
    implicitHeight: Math.max(minHeight, Math.min(contentCol.implicitHeight + heightPadding, shellAnchor.screenHeight - shellAnchor.edgeOffset - 24))

    BarAnchor {
        id: shellAnchor
        moduleId: root.moduleId
        barPos: root.barPos
        panelWidth: root.width
        panelHeight: root.implicitHeight
        screenWidth: root.parent.width
        screenHeight: root.parent.height
        gap: root.panelGap
        fallbackX: (root.parent.width - root.width) / 2
        fallbackY: (root.parent.height - root.implicitHeight) / 2
    }
    x: shellAnchor.panelX
    y: shellAnchor.panelY
    color: Theme.bg
    border.color: Theme.panelBorderColor
    border.width: 2
    radius: 0
    clip: true

    PanelSpring {
        id: shellSpring
        slideFade: true
        shown: root.shown
        hiddenX: root.barPos === "left" ? -(root.width + 5) : root.barPos === "right" ? (root.width + 5) : 0
        hiddenY: root.barPos === "top" ? -(root.implicitHeight + 5) : root.barPos === "bottom" ? (root.implicitHeight + 5) : 0
    }
    visible: shellSpring.boxVisible
    opacity: shellSpring.fade
    scale: shellSpring.zoom
    transformOrigin: shellAnchor.origin
    transform: Translate { x: shellSpring.slideX; y: shellSpring.slideY }

    // Swallow clicks/wheel so they don't dismiss the panel.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: mouse => mouse.accepted = true
        onPressed: mouse => mouse.accepted = true
        onWheel: wheel => wheel.accepted = true
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: root.contentMargins
        contentHeight: contentCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        Column {
            id: contentCol
            width: parent.width
            spacing: root.contentSpacing
        }
    }
}
