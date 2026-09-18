// PanelShell — shared container for all bar panels.
//
// The open/close run is the 1:1 Caelestia popout animation (Ui/CaelestiaPopout
// — ClipWrapper + Wrapper + Content): the card is clipped at the bar's inner
// edge and slides out from behind it on the expressive default spatial curve
// (500ms) while the popout fades in over 200ms, exactly like the reference.
// The old pill/size/scale morph is gone: Caelestia's popouts keep their full
// size and are revealed by the curtain, so nothing reflows.
//
// Usage: PanelShell { moduleId: "volume"; shown: scope.showVolume; ... }
pragma ComponentBehavior: Bound
import QtQuick
import "../themes"

Item {
    id: root

    required property string moduleId
    // Bar module whose anchor the panel settles under. Defaults to moduleId;
    // drill-in panels whose own id has no bar widget (audio) share the
    // anchor of the panel they morph out of.
    property string anchorModuleId: root.moduleId
    property string barPos: "top"
    property real panelGap: 0
    // Theme.isPrimaryScreen(modelData): only that window runs the
    // cross-panel morph (see CaelestiaPopout).
    property bool screenActive: true
    required property bool shown
    property real boxWidth: 340
    property real minHeight: 120
    // Extra height added to content (Flickable margins + breathing room).
    property real heightPadding: 20
    property real contentMargins: 10
    property real contentSpacing: 8

    default property alias content: contentCol.children

    // Full (open) card height; changes glide inside the popout while open.
    readonly property real cardHeight: Math.max(minHeight, Math.min(contentCol.implicitHeight + heightPadding, shellAnchor.screenHeight - shellAnchor.edgeOffset - 24))

    BarAnchor {
        id: shellAnchor
        moduleId: root.anchorModuleId
        barPos: root.barPos
        panelWidth: root.boxWidth
        panelHeight: root.cardHeight
        screenWidth: root.parent.width
        screenHeight: root.parent.height
        gap: root.panelGap
        fallbackX: (root.parent.width - root.boxWidth) / 2
        fallbackY: (root.parent.height - root.cardHeight) / 2
    }

    CaelestiaPopout {
        id: popout

        shown: root.shown
        morphId: root.moduleId
        morphActive: root.screenActive
        barPos: root.barPos
        fullWidth: root.boxWidth
        fullHeight: root.cardHeight
        anchorCenter: shellAnchor.isVertical ? shellAnchor.cy : shellAnchor.cx
        // Bar inner edge: the fixed edge the curtain reveals from.
        edge: root.barPos === "bottom" ? shellAnchor.panelY + root.cardHeight : root.barPos === "right" ? shellAnchor.panelX + root.boxWidth : root.barPos === "left" ? shellAnchor.panelX : shellAnchor.panelY
        screenSize: shellAnchor.isVertical ? shellAnchor.screenHeight : shellAnchor.screenWidth
        margin: shellAnchor.margin

        Rectangle {
            id: card

            // Frame: stretched by the popout (top edge pinned at the bar),
            // radius clamped while short so it reads as a pill being pulled
            // out of the bar.
            width: parent.width
            height: parent.height
            antialiasing: Theme.shapesAa
            // Fill comes from the popout's shadow layer (see CaelestiaPopout
            // shadowSource): it paints the same rounded silhouette behind
            // this card so the shadow silhouette is only composited once.
            color: "transparent"
            border.color: Theme.panelBorderColor
            border.width: 2
            radius: popout.frameRadius
            // Unclipped: the fillets paint outside the box and the content
            // stage overflows it; the popout viewport clips both exactly at
            // the frame's far edge.
            clip: false

            // Swallow clicks/wheel so they don't dismiss the panel. Off
            // while closing: the window outlives the card (morph/close
            // hold) and must not steal input from the panel on top.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                enabled: root.shown
                onClicked: mouse => mouse.accepted = true
                onPressed: mouse => mouse.accepted = true
                onWheel: wheel => wheel.accepted = true
            }

            // Square fused corners (tray-menu joint): the patches melt the
            // box straight into the bar while the far corners keep their
            // rounding. Plain children: they emerge with the card.
            PanelCorner { fillColor: Theme.panelWindowBg; side: "left"; edge: root.barPos === "bottom" ? "bottom" : "top"; visible: popout.offsetScale < 1 }
            PanelCorner { fillColor: Theme.panelWindowBg; side: "right"; edge: root.barPos === "bottom" ? "bottom" : "top"; visible: popout.offsetScale < 1 }
            // Outward-curved shoulders on top of the fusion (Caelestia joint).
            PanelFillet { fillColor: Theme.panelWindowBg; side: "left"; edge: root.barPos === "bottom" ? "bottom" : "top"; visible: popout.offsetScale < 1 }
            PanelFillet { fillColor: Theme.panelWindowBg; side: "right"; edge: root.barPos === "bottom" ? "bottom" : "top"; visible: popout.offsetScale < 1 }
            // Seam strip: erases the collar outline along the fused edge so
            // the joint reads as one mass. Same background, below content.
            // Only needed while the accent border draws that outline; with the
            // transparent default it would just double-paint the card top.
            Rectangle {
                antialiasing: Theme.shapesAa
                visible: Theme.panelAccentBorder
                x: 0
                y: root.barPos === "bottom" ? root.cardHeight - 2 : 0
                width: root.boxWidth
                height: 2
                color: Theme.panelWindowBg
            }

            Flickable {
                // Content moves independently of the frame: always laid out
                // at the full panel size (so nothing reflows mid-stretch) and
                // travelled by the popout's own content driver.
                x: root.contentMargins + popout.contentX
                y: root.contentMargins + popout.contentY
                width: root.boxWidth - root.contentMargins * 2
                height: popout.fullHeight - root.contentMargins * 2
                contentHeight: contentCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
                // Cross-panel morph choreography: the outgoing content
                // shifts/scales out, the incoming one shifts/scales in
                // (direction-aware, see Ui/CaelestiaPopout).
                scale: popout.contentScale
                transform: Translate { x: popout.contentOffsetX; y: popout.contentOffsetY }
                // Popout transition (Caelestia Content/Popout loader fades):
                // slow effects in, default effects out. No scale/rise — the
                // reference only folds the content. contentFade additionally
                // hides the full-size layout while the card morphs between
                // panel poses (see CaelestiaPopout).
                opacity: popout.innerFade * popout.contentFade
                Column {
                    id: contentCol
                    width: root.boxWidth - root.contentMargins * 2
                    spacing: root.contentSpacing
                }
            }
        }
    }
}
