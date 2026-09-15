pragma ComponentBehavior: Bound
import QtQuick
import "../../themes"

Item {
    id: root
    required property string moduleId
    required property string section
    required property int modIndex
    property bool vertical: false
    property var monitor: null
    property bool isSource: false
    property bool active: false
    property string barPos: "top"
    property var barWindow: null
    property bool anchorActive: true

    signal requestMenu()
    signal requestCalendar()
    signal requestWeather()
    signal requestUpdates()
    signal requestNetwork()
    signal requestVolume()
    signal requestBluetooth()
    signal requestVitals()
    signal requestSystemTray()
    signal hideRequest()
    signal pressBegun()
    signal thresholdPassed(var slot, real x, real y)
    signal dragMoved(var slot, real x, real y)
    signal dragReleased(var slot, bool wasDragging)
    signal dragCanceled()

    QtObject {
        id: internal
        property bool dirty: false
    }

    function requestPublishAnchor(): void {
        if (!internal.dirty) {
            internal.dirty = true
            Qt.callLater(publishBarAnchor)
        }
    }

    function publishBarAnchor(): void {
        internal.dirty = false
        if (!anchorActive) return
        // Bar anchors are published from the primary screen only (DP-1 when
        // present, else the Theme fallback screen).
        try { if (monitor && monitor.name && !Theme.isPrimaryScreen(monitor)) return } catch (e) { }
        if (!visible || width <= 0 || height <= 0) return
        try {
            let p = mapToItem(null, 0, 0)
            let sx = p.x, sy = p.y
            let win = barWindow
            if (win) {
                let sw = 0, sh = 0
                try { if (win.screen) { sw = win.screen.width; sh = win.screen.height } } catch (e1) { }
                if (!sw || !sh) { try { sw = Screen.width; sh = Screen.height } catch (e2) { } }
                let mL = 0, mT = 0, mR = 0, mB = 0
                try { let m = win.margins; if (m) { mL = m.left || 0; mT = m.top || 0; mR = m.right || 0; mB = m.bottom || 0 } } catch (e3) { }
                if (barPos === "bottom" && sh > 0) { sx += mL; sy += Math.max(0, sh - win.height - mB) }
                else if (barPos === "right" && sw > 0) { sx += Math.max(0, sw - win.width - mR); sy += mT }
                else { sx += mL; sy += mT }
            }
            Theme.setBarAnchor(moduleId, sx, sy, width, height)
        } catch (e) { }
    }

    onXChanged: requestPublishAnchor()
    onYChanged: requestPublishAnchor()
    onWidthChanged: requestPublishAnchor()
    onHeightChanged: requestPublishAnchor()
    onVisibleChanged: requestPublishAnchor()
    onBarPosChanged: requestPublishAnchor()
    onBarWindowChanged: requestPublishAnchor()
    onAnchorActiveChanged: requestPublishAnchor()
    Component.onCompleted: { requestPublishAnchor(); Qt.callLater(requestPublishAnchor) }
    Connections {
        target: Theme
        function onAnchorRefreshTriggerChanged() { requestPublishAnchor() }
        function onBarEdgeDistanceChanged() { requestPublishAnchor() }
        function onBarTopDistanceChanged() { requestPublishAnchor() }
    }

    property alias dragVisual: moduleLoader

    implicitWidth: moduleLoader.implicitWidth
    implicitHeight: moduleLoader.implicitHeight
    visible: moduleLoader.activeVisible
    opacity: isSource ? 0.25 : 1.0
    z: slotPointer.dragging ? 100 : 0



    BarModule {
        id: moduleLoader
        anchors.centerIn: parent
        moduleId: root.moduleId
        vertical: root.vertical
        monitor: root.monitor
        slotHovered: slotPointer.containsMouse
        onRequestMenu: root.requestMenu()
        onRequestCalendar: root.requestCalendar()
        onRequestWeather: root.requestWeather()
        onRequestUpdates: root.requestUpdates()
        onRequestNetwork: root.requestNetwork()
        onRequestVolume: root.requestVolume()
        onRequestBluetooth: root.requestBluetooth()
        onRequestVitals: root.requestVitals()
        onRequestSystemTray: root.requestSystemTray()
    }

    Rectangle {
        id: activeBar
        antialiasing: Theme.shapesAa
        property bool isH: root.barPos === "top" || root.barPos === "bottom"
        property real thick: 3
        width: isH ? parent.width : thick
        height: isH ? thick : parent.height
        radius: 0
        color: Theme.accent
        x: isH ? 0 : (root.barPos === "left" ? parent.width - width : 0)
        y: isH ? (root.barPos === "top" ? parent.height - height : 0) : 0
        opacity: root.active ? 1 : 0
    }

    MouseArea {
        id: slotPointer
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        enabled: root.visible && root.width > 0 && root.height > 0
        propagateComposedEvents: true
        hoverEnabled: true
        cursorShape: isSource ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        property bool dragging: false
        property bool suppressClick: false
        property real pressedX: 0
        property real pressedY: 0
        property real _lastHoverX: -1000
        property real _lastHoverY: -1000
        readonly property real dragThreshold: 12

        onPressed: mouse => {
            dragging = false
            suppressClick = false
            pressedX = mouse.x
            pressedY = mouse.y
            root.pressBegun()
        }
        onPositionChanged: mouse => {
            if (!(mouse.buttons & Qt.LeftButton)) {
                // PERF: hover scan does mapFromItem + child loop per pixel.
                // Skip sub-3px jitter moves (same delegate still hovered).
                let dx = mouse.x - slotPointer._lastHoverX
                let dy = mouse.y - slotPointer._lastHoverY
                if (dx * dx + dy * dy < 9) return
                slotPointer._lastHoverX = mouse.x
                slotPointer._lastHoverY = mouse.y
                let bp = moduleLoader.mapFromItem(slotPointer, mouse.x, mouse.y)
                moduleLoader.hoverAt(bp.x, bp.y)
                return
            }
            if (!dragging) {
                var distance = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
                if (distance < dragThreshold) return
                dragging = true
                root.thresholdPassed(root, mouse.x, mouse.y)
                return
            }
            root.dragMoved(root, mouse.x, mouse.y)
        }
        onReleased: mouse => {
            var wasDragging = dragging
            if (wasDragging) suppressClick = true
            dragging = false
            root.dragReleased(root, wasDragging)
            mouse.accepted = wasDragging
        }
        onCanceled: {
            dragging = false
            suppressClick = false
            root.dragCanceled()
        }
        onContainsMouseChanged: {
            if (!slotPointer.containsMouse) moduleLoader.hoverLeft()
        }
        onClicked: mouse => {
            if (suppressClick) {
                suppressClick = false
                mouse.accepted = true
                return
            }
            if (root.active && mouse.button === Qt.LeftButton) {
                root.hideRequest()
                mouse.accepted = true
                return
            }
            let bp = moduleLoader.mapFromItem(slotPointer, mouse.x, mouse.y)
            moduleLoader.click(mouse.button, bp.x, bp.y)
            mouse.accepted = true
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (moduleLoader.wheel(event.angleDelta.y)) event.accepted = true
        }
    }
}
