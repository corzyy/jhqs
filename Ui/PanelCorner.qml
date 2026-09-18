// PanelCorner — square fused corner patch for dropdown boxes.
//
// Makes the box corners on the bar side square so the box melts straight
// into the bar (like a tray menu fused to its bar: no notch, no outline
// along the joint), while the far corners keep the box's rounding. The
// patch fills only the rounded cutout (square minus quarter disc), so a
// translucent card is not double-painted and does not darken at the corner.
// Pair with a seam strip (see call sites) that erases the straight collar
// segment between the two patches. Only for horizontal bars; vertical bars
// keep fully rounded boxes.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../themes"

Shape {
    id: root

    // "left" | "right": which corner of the fused edge to square.
    required property string side
    // Bar edge the box hangs off: "top" (square the top corners) or
    // "bottom" (mirrored: square the bottom corners).
    property string edge: "top"
    property real extent: Theme.cornerRadius
    // Fill should match the owning card so the joint stays one mass when the
    // panel is translucent.
    property color fillColor: Theme.bg

    readonly property bool usable: (edge === "top" || edge === "bottom")
        && (side === "left" || side === "right")
        && extent > 0
    readonly property bool atTop: edge === "top"
    readonly property bool atLeft: side === "left"
    // Cubic control offset for a near-circular quarter arc.
    readonly property real ck: 0.5523

    x: atLeft ? 0 : parent.width - extent
    y: atTop ? 0 : parent.height - extent
    width: extent
    height: extent
    visible: false
    // Vertical bars: no patches (fully rounded boxes there).
    opacity: usable ? 1 : 0
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.fillColor
        strokeWidth: 0
        strokeColor: "transparent"

        // Canonical geometry: top-left cutout — top edge, arc hugging the
        // card's rounded corner, left edge. Mirrors handle the other corners.
        startX: 0
        startY: 0
        PathLine { x: root.extent; y: 0 }
        PathCubic {
            x: 0
            y: root.extent
            control1X: root.extent - root.ck * root.extent
            control1Y: 0
            control2X: 0
            control2Y: root.extent - root.ck * root.extent
        }
        PathLine { x: 0; y: 0 }
    }

    // Mirrors map the canonical top-left path onto the other three corners.
    transform: Scale {
        xScale: root.atLeft ? 1 : -1
        yScale: root.atTop ? 1 : -1
        origin.x: root.width / 2
        origin.y: root.height / 2
    }
}
