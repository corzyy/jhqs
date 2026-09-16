// PanelFillet — concave cove fusing a dropdown box into the bar.
//
// Caelestia-style junction: the Theme.bg mass hangs off the bar edge and
// the panel side edge, joined by one concave sweep (like a cove molding
// or a quarter-pipe) that bows toward the box corner. No steps, no outer
// corners, no wallpaper notches: bar, fillet and box melt into a single
// mass with a scooped valley at each joint. Pairs with PanelCorner
// (which squares the inner corner).
// Inherits the box's spring opacity/scale/translate automatically (plain
// child); callers only bind `visible` to the box's spring visibility.
// Only for horizontal bars; vertical bars keep the plain attached look.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../themes"

Shape {
    id: root

    // "left" | "right": which top corner of the box to hug.
    required property string side
    // Bar edge the box hangs off: "top" (horns above the box top edge)
    // or "bottom" (mirrored below the box bottom edge).
    property string edge: "top"
    // Horn footprint along the bar edge.
    property real extent: 30
    // Horn reach down the panel side; lands where the side border starts
    // so the outline emerges straight out of the joint.
    property real length: 20

    readonly property bool usable: (edge === "top" || edge === "bottom")
        && (side === "left" || side === "right")
        && extent > 0 && length > 0
    readonly property bool mirrorX: side === "right"
    readonly property bool mirrorY: edge === "bottom"
    // Cubic control offset for a near-circular tangent cove.
    readonly property real ck: 0.5523

    // Canonical geometry is drawn for left/top; mirrors handle the rest.
    x: side === "left" ? -extent : parent.width
    y: edge === "top" ? 0 : parent.height - length
    width: extent
    height: length
    visible: false
    // Vertical bars: no fillets (plain attached look).
    opacity: usable ? 1 : 0
    preferredRendererType: Shape.CurveRenderer
    // Mirrors map the canonical left/top path onto the other three
    // corners. NOTE: transformOrigin does NOT apply to the transform
    // list — the Scale carries its own origin, otherwise the mirrored
    // path lands outside the item.
    transform: Scale {
        xScale: root.mirrorX ? -1 : 1
        yScale: root.mirrorY ? -1 : 1
        origin.x: root.width / 2
        origin.y: root.height / 2
    }

    ShapePath {
fillColor: Theme.bg
        strokeWidth: 0
        strokeColor: "transparent"

        // Top edge (fused with the bar) -> right edge (fused with the box
        // side) -> concave cubic back to the start, scooping toward the
        // box corner. Tangent to both fused edges, like Caelestia's
        // blob valleys.
        startX: 0
        startY: 0
        PathLine { x: root.extent; y: 0 }
        PathLine { x: root.extent; y: root.length }
        PathCubic {
            x: 0
            y: 0
            control1X: root.extent
            control1Y: root.length - root.ck * root.length
            control2X: root.ck * root.extent
            control2Y: 0
        }
    }
}
