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
//
// Third addition: the cross-panel morph (Ui/PanelMorph). Opening a bar panel
// while another one is open no longer plays two independent runs. Instead
// the incoming popout maps already at the outgoing card's pose, the outgoing
// card waits for that first frame and then fades out underneath it, and the
// incoming card glides to its own settled pose on a plain NumberAnimation
// (no curtain): a container transform. Content is hidden only while the
// frame is still moving and fades back in as the glide nears its pose
// (`contentFade`), not after the settle — the curve is front-loaded, so
// that is ~200ms into the run.
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
    // Settled (open) sizes, straight from the host bindings.
    readonly property real settledAxis: horizontalBar ? fullHeight : fullWidth
    readonly property real settledPerp: horizontalBar ? fullWidth : fullHeight

    // ---- cross-panel morph (Ui/PanelMorph, see header) -----------------
    // morphId is the bar module id of the host panel: it keys the published
    // card rect and tells this popout whether it is the outgoing or the
    // incoming side of a switch. `_morphIn` drives the card from the
    // outgoing panel's pose instead of the settled one; `_morphOut` holds
    // the card open until the incoming surface has rendered, then fades it.
    property string morphId: ""
    property bool _morphIn: false
    property bool _morphOut: false
    property bool _morphFade: false
    property bool _morphAnimate: false
    property bool _morphStarted: false
    // Only the primary screen's window runs the handoff; the other screen
    // variants share the show flags but never map. Hosts pass
    // Theme.isPrimaryScreen(modelData) down (PanelShell forwards it via
    // screenActive), so this is decided at construction, not at map time.
    property bool morphActive: true
    readonly property bool morphEnabled: Theme.animationsEnabled && root.morphActive
    // Effective sizes/edge: morphed while `_morphIn`, settled otherwise.
    readonly property real axisSize: root._morphIn ? (horizontalBar ? _morphH : _morphW) : settledAxis
    readonly property real perpSize: root._morphIn ? (horizontalBar ? _morphW : _morphH) : settledPerp
    readonly property real effEdge: root._morphIn ? _morphEdge : edge
    // Card rect in window coordinates (== screen coordinates: every panel
    // window is full-screen). Published while open so the next switch can
    // start from the exact pose this card settles at.
    readonly property rect cardRect: Qt.rect(Math.round(x + holder.x), Math.round(y + holder.y), holder.width, holder.height)

    // ---- surface-mapping gate (see header) -----------------------------
    property bool _open: false
    FrameAnimation {
        id: enterFrame
        running: false
        onTriggered: {
            running = false
            root._open = true
            root._publishRect()
        }
    }
    onShownChanged: {
        if (root.shown) {
            morphSettleTimer.stop()
            morphRun.stop()
            if (root._tryMorphIn())
                return
            morphHoldTimer.stop()
            root._morphIn = false
            root._morphOut = false
            root._morphFade = false
            root._open = false
            enterFrame.running = true
        } else {
            enterFrame.running = false
            morphSettleTimer.stop()
            morphRun.stop()
            if (root._tryMorphOut())
                return
            root._morphIn = false
            root._morphOut = false
            root._morphFade = false
            root._open = false
        }
    }
    Component.onCompleted: {
        if (!root.shown)
            return
        if (root._tryMorphIn())
            return
        enterFrame.running = true
    }

    // ---- drivers -------------------------------------------------------
    // Frame driver (ClipWrapper offsetScale): the frame STRETCHES along the
    // bar axis. Its near edge is pinned to the bar, so the panel is attached
    // for the whole run and can never be separated from the bar by a gap.
    property real _offsetScale: _open ? 0 : 1
    Behavior on _offsetScale {
        // Morph-in snaps the curtain open: the card is already at the
        // outgoing pose and only glides from there (see morph below).
        enabled: Theme.animationsEnabled && !root._morphIn
        Anim {}
    }
    // Content driver: the content rides the same 0/1 range but on its own
    // curve/duration, so the frame stretches first and the content settles
    // after it — the content moves independently of the frame.
    property real _contentOffset: _open ? 0 : 1
    Behavior on _contentOffset {
        enabled: Theme.animationsEnabled && !root._morphIn
        NumberAnimation {
            duration: Theme.durSlowSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveSlowSpatial
        }
    }

    // ---- morph drivers -------------------------------------------------
    // The incoming card glides from the outgoing pose (primed in
    // `_tryMorphIn` into `_from*`) to the settled pose over one shared
    // 0..1 run. The settled side is read live, so a host geometry change
    // during the glide (content settling after the first frame) is
    // followed instead of being frozen at the value captured at start.
    property real _morphT: 0
    property real _fromW: 0
    property real _fromH: 0
    property real _fromPos: 0
    property real _fromEdge: 0
    readonly property real _morphW: root._fromW + (root.fullWidth - root._fromW) * root._morphT
    readonly property real _morphH: root._fromH + (root.fullHeight - root._fromH) * root._morphT
    readonly property real _morphPos: root._fromPos + (root.perpTarget - root._fromPos) * root._morphT
    readonly property real _morphEdge: root._fromEdge + (root.edge - root._fromEdge) * root._morphT
    component MorphShift: NumberAnimation {
        duration: Theme.durPanelMorph
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curvePanelMorph
    }
    MorphShift {
        id: morphRun
        target: root
        property: "_morphT"
        from: 0
        to: 1
    }

    function _publishRect(): void {
        if (root.morphId === "" || !root._open || !root.morphActive)
            return
        PanelMorph.publish(root.morphId, root.cardRect)
    }
    onMorphIdChanged: root._publishRect()
    onCardRectChanged: root._publishRect()

    // Incoming side: claim the outgoing pose, then glide to the settled one.
    function _tryMorphIn(): bool {
        if (!root.morphEnabled || root._morphIn)
            return false
        if (root.morphId === "" || !PanelMorph.isTarget(root.morphId))
            return false
        const r = PanelMorph.rectOf(PanelMorph.fromId)
        if (!r) {
            PanelMorph.finish()
            return false
        }
        root._morphOut = false
        root._morphFade = false
        morphHoldTimer.stop()
        morphRun.stop()
        root._morphT = 0
        root._fromW = r.width
        root._fromH = r.height
        root._fromPos = root.horizontalBar ? r.x : r.y
        root._fromEdge = root.horizontalBar
            ? (root.barPos === "top" ? r.y : r.y + r.height)
            : (root.barPos === "left" ? r.x : r.x + r.width)
        root._morphIn = true
        root._morphAnimate = false
        root._morphStarted = false
        root._open = true
        root._publishRect()
        morphFrame.running = true
        return true
    }
    FrameAnimation {
        id: morphFrame
        running: false
        onTriggered: {
            running = false
            if (!root._morphIn || root._morphStarted)
                return
            // First rendered frame: start the glide and let the outgoing
            // card fade (markReady -> PanelMorph.ready).
            root._morphStarted = true
            root._morphAnimate = true
            morphRun.start()
            morphSettleTimer.restart()
            PanelMorph.markReady(root.morphId)
        }
    }
    Timer {
        id: morphSettleTimer
        interval: Theme.durPanelMorph + 20
        repeat: false
        onTriggered: root._morphIn = false
    }

    // Outgoing side: hold the open card until the incoming surface is on
    // screen, then fade it out (the incoming card covers the same pixels).
    function _tryMorphOut(): bool {
        if (!root.morphEnabled || root._morphIn || !root._open)
            return false
        if (root.morphId === "" || !PanelMorph.isSource(root.morphId))
            return false
        root._morphOut = true
        root._morphFade = false
        morphHoldTimer.restart()
        return true
    }
    Timer {
        id: morphHoldTimer
        interval: Theme.durPanelMorphHold
        repeat: false
        onTriggered: {
            // Incoming surface never rendered: fall back to a normal close.
            if (!root._morphOut || root._morphFade)
                return
            PanelMorph.finish()
            root._morphOut = false
            root._open = false
        }
    }
    Connections {
        target: PanelMorph
        function onReadyChanged() {
            if (!PanelMorph.ready || !root._morphOut || root._morphFade)
                return
            morphHoldTimer.stop()
            root._morphFade = true
            PanelMorph.finish()
        }
        function onActiveChanged() {
            // Handoff aborted (incoming side could not claim a rect).
            if (PanelMorph.active || !root._morphOut || root._morphFade)
                return
            morphHoldTimer.stop()
            root._morphOut = false
            root._open = false
        }
    }

    // ---- geometry ------------------------------------------------------
    // Stretched frame size along the bar axis: 0 at the bar edge -> full.
    readonly property real frameAxis: axisSize * (1 - _offsetScale)
    // The holder is drawn through the MultiEffect shadow layer below, which
    // resamples its texture on fractional geometry (soft text). Snap the
    // frame extent to whole pixels so the layer stays 1:1.
    readonly property real frameExtent: Math.ceil(frameAxis)
    readonly property real perpExtent: Math.ceil(perpSize)
    // Content offset along the axis: full-size content parked outside the
    // frame's far edge (own driver -> independent motion).
    readonly property real contentTranslate: -axisSize * _contentOffset
    readonly property real contentX: horizontalBar ? 0 : barPos === "left" ? contentTranslate : -contentTranslate
    readonly property real contentY: horizontalBar ? barPos === "top" ? contentTranslate : -contentTranslate : 0
    // While the frame is shorter than the radius, clamp so it reads as a
    // pill being stretched out of the bar instead of a squashed panel.
    readonly property real frameRadius: Math.min(Theme.cornerRadius, frameAxis / 2)

    width: horizontalBar ? perpExtent + perpPad * 2 : frameExtent + shadowPad
    height: horizontalBar ? frameExtent + shadowPad : perpExtent + perpPad * 2
    visible: frameAxis > 0.5
    clip: true

    // Perp anchor follow, gated like the reference: a closed popout snaps
    // into place so the next open starts from the right spot.
    readonly property real perpTarget: {
        const lo = margin;
        const hi = screenSize - settledPerp - margin;
        if (hi < lo)
            return lo;
        return Math.max(lo, Math.min(anchorCenter - settledPerp / 2, hi));
    }
    // While morphing in, the card rides the morphed position directly (the
    // perp Behavior is off, so the two runs cannot chase each other).
    property real perpPos: root._morphIn ? root._morphPos : perpTarget
    Behavior on perpPos {
        enabled: Theme.animationsEnabled && root._offsetScale < 1 && !root._morphIn
        NumberAnimation {
            duration: Theme.durDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveDefaultSpatial
        }
    }
    // The fixed edge stays put; the far edge is where the curtain grows.
    // Integer positions keep the shadow layer from resampling (see above).
    x: horizontalBar ? Math.round(perpPos - perpPad) : barPos === "left" ? Math.round(effEdge) : Math.round(effEdge - width)
    y: horizontalBar ? barPos === "top" ? Math.round(effEdge) : Math.round(effEdge - height) : Math.round(perpPos - perpPad)

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
        width: root.horizontalBar ? root.perpExtent : root.frameExtent
        height: root.horizontalBar ? root.frameExtent : root.perpExtent

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

        // Comp transition: 0/1 with default effects both ways. A morphing
        // source fades its frame here once the incoming surface is up.
        opacity: root._open && !root._morphFade ? 1 : 0
        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    // Content handoff: during a morph the cards show frame only while the
    // frame is still moving — the full-size content would spill past it.
    // The outgoing content clears right away (fade-through); the incoming
    // content fades in as soon as the glide is nearly at its pose
    // (panelMorphReveal), so it no longer waits for the settle. Hosts bind
    // their content item's opacity to this — PanelShell multiplies it into
    // innerFade, the direct popouts bind their Flickable/Loader.
    property real contentFade: root._morphOut || (root._morphIn && root._morphT < Theme.panelMorphReveal) ? 0 : 1
    Behavior on contentFade {
        // The incoming prime snaps (its card is not visible yet); every
        // other change fades on the default effects run.
        enabled: Theme.animationsEnabled && !(root._morphIn && !root._morphAnimate)
        NumberAnimation {
            duration: Theme.durDefaultEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveDefaultEffects
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
