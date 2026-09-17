// PanelMorph — handoff state for cross-panel morphs (Ui/CaelestiaPopout).
//
// shell.qml calls begin(from, to) just before it flips activePanel. Every
// bar popout publishes its settled card rect under its morphId while open;
// the incoming popout claims the outgoing rect when it maps, starts its
// card at that pose and glides to its own (container transform). The
// outgoing card holds until the incoming one has rendered its first frame
// (markReady), then fades out underneath it.
pragma Singleton
import QtQuick

QtObject {
    id: root

    // A handoff is in flight (from -> to); cleared by finish().
    property bool active: false
    // The incoming popout has rendered at the outgoing pose.
    property bool ready: false
    property string fromId: ""
    property string toId: ""
    // morphId -> { x, y, width, height } in window/screen coordinates.
    property var rects: ({})

    function begin(from: string, to: string): void {
        root.fromId = from
        root.toId = to
        root.ready = false
        root.active = from !== "" && to !== "" && from !== to
    }
    function isSource(id: string): bool {
        return root.active && root.fromId === id
    }
    function isTarget(id: string): bool {
        return root.active && root.toId === id
    }
    function publish(id: string, rect): void {
        if (!id || !rect || rect.width <= 0 || rect.height <= 0)
            return
        // Plain object on purpose: the rects map is read via rectOf() only,
        // so no change notification (and no binding churn) is needed.
        root.rects[id] = { x: rect.x, y: rect.y, width: rect.width, height: rect.height }
    }
    function rectOf(id: string): var {
        return root.rects[id] || null
    }
    function markReady(id: string): void {
        if (root.active && root.toId === id)
            root.ready = true
    }
    function finish(): void {
        root.active = false
        root.ready = false
        root.fromId = ""
        root.toId = ""
    }
}
