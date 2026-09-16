// PanelCorner — square fused corner patch for dropdown boxes.
//
// Makes the box corners on the bar side square so the box melts straight
// into the bar (like a tray menu fused to its bar: no notch, no outline
// along the joint), while the far corners keep the box's rounding. A
// Theme.bg square covers the rounded cutout and the corner arc; content
// paints over it untouched. Pair with a seam strip (see call sites) that
// erases the straight collar segment between the two patches. Only for
// horizontal bars; vertical bars keep fully rounded boxes.
pragma ComponentBehavior: Bound
import QtQuick
import "../themes"

Item {
    id: root

    // "left" | "right": which corner of the fused edge to square.
    required property string side
    // Bar edge the box hangs off: "top" (square the top corners) or
    // "bottom" (mirrored: square the bottom corners).
    property string edge: "top"
    property real extent: Theme.cornerRadius

    readonly property bool usable: (edge === "top" || edge === "bottom")
        && (side === "left" || side === "right")
        && extent > 0
    readonly property bool atTop: edge === "top"
    readonly property bool atLeft: side === "left"

    x: atLeft ? 0 : parent.width - extent
    y: atTop ? 0 : parent.height - extent
    width: extent
    height: extent
    visible: false
    // Vertical bars: no patches (fully rounded boxes there).
    opacity: usable ? 1 : 0

    Rectangle {
        antialiasing: Theme.shapesAa
        anchors.fill: parent
        color: Theme.bg
    }
}
