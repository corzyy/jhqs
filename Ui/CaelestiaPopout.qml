// CaelestiaPopout — 1:1 port of Caelestia's bar-popout open/close animation.
//
// Sources (caelestia-dots/shell):
//   modules/bar/popouts/ClipWrapper.qml   offsetScale driver + curtain clip
//   modules/bar/popouts/Wrapper.qml       size Behaviors + slide offset
//   modules/bar/popouts/Content.qml       nested loader fades
//
// Caelestia drives the whole run off a single value, exactly as here:
//   offsetScale        Behavior Anim{}               expressive default spatial
//                                                    (500ms, [0.38,1.21,0.22,1,1,1])
//   axis extent        full * (1 - offsetScale)      curtain reveal, clip: true
//   content offset     (-full - 5) * offsetScale     slides out from behind the bar edge
//   perp position      bar item centre               Behavior Anim{} (ClipWrapper.x/y)
//   full size changes  Behavior Anim{500ms}          (Wrapper implicitWidth/Height)
//   popup fade         0/1, 200ms default effects    (Comp transitions)
//   inner fade         0/1, 300ms slow effects in    (Popout transitions)
//                           200ms default effects out
//
// Caelestia's bar is vertical so its curtain runs on x; the identical math
// runs on y for jhqs's horizontal bar (open from the top/bottom panel edge).
//
// One addition over the reference: the layer surface only maps on open, so
// the driver waits for the first rendered frame — starting the Behavior at
// the same instant the surface is created would swallow the first frames of
// the run (surface mapping latency) and visibly fast-forward the motion.
//
// Second addition: a drop shadow around the card (see the holder). The
// popout reserves extra room past the card's free edge so the shadow can
// paint there, while the curtain clip cuts it along the fused bar edge —
// the panel keeps reading as one mass with the bar.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "../themes"

Item {
    id: root

    property bool shown: false
    // Bar side the popout hangs off.
    property string barPos: "top"
    // Open (full) size of the popout. Changes glide on the spatial curve
    // while open (Caelestia Wrapper implicitWidth/implicitHeight).
    property real fullWidth: 300
    property real fullHeight: 200
    // Perpendicular centre the popout tracks: the bar item's centre on that
    // axis (Caelestia popouts.currentCenter).
    property real anchorCenter: 0
    // Along-axis coordinate of the bar's inner edge: the fixed edge the
    // curtain reveals from. Top bar: panel top; bottom: panel bottom;
    // left: panel left; right: panel right.
    property real edge: 0
    property real screenSize: 0
    property real margin: 12
    // Perpendicular room for decor painting outside the card (fillets) and
    // for the drop shadow on the card's free sides.
    property real perpPad: 48
    // Room past the card's free (far) edge for the drop shadow. The shadow
    // is clipped at the fused bar edge, so the panel stays one mass with
    // the bar.
    property real shadowPad: 48
    // Caelestia's "(-implicitWidth - 5)": the hidden pose clears the far edge.
    readonly property real travel: 5

    default property alias content: holder.data
    readonly property alias offsetScale: root._offsetScale
    // Inner (popout) fold fade, for hosts to bind their content to.
    readonly property alias innerFade: root._innerFade
    readonly property bool horizontalBar: barPos === "top" || barPos === "bottom"
    readonly property real axisSize: horizontalBar ? fullHeight : fullWidth
    readonly property real perpSize: horizontalBar ? fullWidth : fullHeight

    // ---- surface-mapping gate (see header) -----------------------------
    property bool _open: false
    FrameAnimation {
        id: enterFrame
        running: false
        onTriggered: {
            running = false
            root._open = true
        }
    }
    onShownChanged: {
        if (root.shown) {
            root._open = false
            enterFrame.running = true
        } else {
            enterFrame.running = false
            root._open = false
        }
    }
    Component.onCompleted: if (root.shown) enterFrame.running = true

    // ---- drivers -------------------------------------------------------
    // Frame driver (ClipWrapper offsetScale): the frame STRETCHES along the
    // bar axis. Its near edge is pinned to the bar, so the panel is attached
    // for the whole run and can never be separated from the bar by a gap.
    property real _offsetScale: _open ? 0 : 1
    Behavior on _offsetScale {
        Anim {}
    }
    // Content driver: the content rides the same 0/1 range but on its own
    // curve/duration, so the frame stretches first and the content settles
    // after it — the content moves independently of the frame.
    property real _contentOffset: _open ? 0 : 1
    Behavior on _contentOffset {
        enabled: Theme.animationsEnabled
        NumberAnimation {
            duration: Theme.durSlowSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveSlowSpatial
        }
    }

    // ---- geometry ------------------------------------------------------
    // Stretched frame size along the bar axis: 0 at the bar edge -> full.
    readonly property real frameAxis: axisSize * (1 - _offsetScale)
    // Content offset along the axis: full-size content parked outside the
    // frame's far edge (own driver -> independent motion).
    readonly property real contentTranslate: -axisSize * _contentOffset
    readonly property real contentX: horizontalBar ? 0 : barPos === "left" ? contentTranslate : -contentTranslate
    readonly property real contentY: horizontalBar ? barPos === "top" ? contentTranslate : -contentTranslate : 0
    // While the frame is shorter than the radius, clamp so it reads as a
    // pill being stretched out of the bar instead of a squashed panel.
    readonly property real frameRadius: Math.min(Theme.cornerRadius, frameAxis / 2)

    width: horizontalBar ? perpSize + perpPad * 2 : frameAxis + shadowPad
    height: horizontalBar ? frameAxis + shadowPad : perpSize + perpPad * 2
    visible: frameAxis > 0.5
    clip: true

    // Perp anchor follow, gated like the reference: a closed popout snaps
    // into place so the next open starts from the right spot.
    readonly property real perpTarget: {
        const lo = margin;
        const hi = screenSize - perpSize - margin;
        if (hi < lo)
            return lo;
        return Math.max(lo, Math.min(anchorCenter - perpSize / 2, hi));
    }
    property real perpPos: perpTarget
    Behavior on perpPos {
        enabled: Theme.animationsEnabled && root._offsetScale < 1
        NumberAnimation {
            duration: Theme.durDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveDefaultSpatial
        }
    }
    // The fixed edge stays put; the far edge is where the curtain grows.
    x: horizontalBar ? perpPos - perpPad : barPos === "left" ? edge : edge - width
    y: horizontalBar ? barPos === "top" ? edge : edge - height : perpPos - perpPad

    // Wrapper implicitWidth/implicitHeight Behaviors.
    Behavior on fullWidth {
        enabled: Theme.animationsEnabled && root._offsetScale < 1
        NumberAnimation {
            duration: Theme.durDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveDefaultSpatial
        }
    }
    Behavior on fullHeight {
        enabled: Theme.animationsEnabled && root._offsetScale < 1
        NumberAnimation {
            duration: Theme.durDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveDefaultSpatial
        }
    }

    // Holder = the stretched frame. Its near edge sits exactly on the bar
    // edge (the viewport is pinned there), so the card always touches the
    // bar. The extra shadowPad keeps the card's free edge away from the far
    // viewport edge, leaving room for the drop shadow.
    Item {
        id: holder

        x: root.horizontalBar ? root.perpPad : root.barPos === "left" ? 0 : root.shadowPad
        y: root.horizontalBar ? root.barPos === "top" ? 0 : root.shadowPad : root.perpPad
        width: root.horizontalBar ? root.fullWidth : root.frameAxis
        height: root.horizontalBar ? root.frameAxis : root.fullHeight

        // Drop shadow cast by the whole card (frame + fused fillets):
        // applied to the holder so the popout's own clip cuts it at the
        // bar edge. sourceRect reaches into the perpendicular padding so
        // the fillet shoulders are part of the silhouette; the effect's
        // auto-padding then lets the shadow spill into perpPad/shadowPad.
        layer.enabled: root.visible
        layer.sourceRect: Qt.rect(-root.perpPad, 0, width + root.perpPad * 2, height)
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.withAlpha(Theme.shadow, 0.5)
            shadowOpacity: 0.45
            shadowBlur: 0.9
            shadowVerticalOffset: 8
        }

        // Comp transition: 0/1 with default effects both ways.
        opacity: root._open ? 1 : 0
        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    // Popout transition: slow effects on the way in, default effects out.
    property real _innerFade: _open ? 1 : 0
    Behavior on _innerFade {
        enabled: Theme.animationsEnabled
        NumberAnimation {
            duration: root._open ? Theme.durSlowEffects : Theme.durDefaultEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root._open ? Theme.curveSlowEffects : Theme.curveDefaultEffects
        }
    }
}
