pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../themes"
import "../../services"

Item {
    id: root
    property var monitor: null
    // Follow the focused monitor (single main-screen bar mirrors whichever
    // screen is active). `monitor` is kept for interface compat but the
    // display intentionally tracks focusedMonitor, not the bar's own screen.
    readonly property string screenName: {
        try {
            let f = MangoService.focusedMonitor
            if (f && ("" + f).length > 0) return "" + f
        } catch (e) {}
        try {
            if (monitor && monitor.name) return "" + monitor.name
            if (typeof monitor === "string" && ("" + monitor).length > 0) return "" + monitor
        } catch (e2) {}
        // Last resort when no monitor info exists yet: Theme falls back to
        // the first available screen when DP-1 is missing.
        try { return Theme.primaryScreenName } catch (e3) { return "DP-1" }
    }
    property bool vertical: false
    implicitWidth: vertical ? 24 : hRow.implicitWidth
    implicitHeight: vertical ? vCol.implicitHeight : hRow.implicitHeight

    // Mango-only: tags come from MangoService (mmsg). Unknown compositors
    // show the placeholder dash below.
    readonly property bool useMango: MangoService.isMango
    property var sortedWorkspaces: {
        if (useMango) {
            try {
                // Follow the focused monitor: single main-screen bar mirrors
                // whichever screen is active, so switching tags on another
                // monitor updates the module too.
                let monMap = MangoService.monitors
                let focMon = MangoService.focusedMonitor
                let dyn = false
                try { dyn = MangoService.mangoDynamicTags } catch (e) {}
                let tl = []
                try { tl = MangoService.tagsFor(root.screenName) } catch (e2) { tl = MangoService.tags }
                if (!tl || tl.length === 0) {
                    // Fallback: fixed tagCount so the bar never blanks while
                    // the first mmsg poll is still in flight.
                    let n = 10
                    try { n = MangoService.tagCountFor(root.screenName) || MangoService.tagCount || 10 } catch (e3) {}
                    n = Math.max(1, Math.min(20, n))
                    // If we know the focused screen's active tag, echo it;
                    // otherwise fall back to tag 1 so something highlights.
                    let guess = 1
                    try {
                        let ft = MangoService.tags
                        for (let gi = 0; gi < (ft || []).length; gi++) {
                            if (ft[gi] && ft[gi].active) { guess = ft[gi].index; break }
                        }
                    } catch (e4) {}
                    let out = []
                    for (let i = 1; i <= n; i++)
                        out.push({ id: i, name: "" + i, focused: i === guess, active: i === guess, occupied: false, clients: 0 })
                    return out
                }
                let out2 = []
                for (let i = 0; i < tl.length; i++) {
                    let tg = tl[i]
                    // Dynamic mode: only active / urgent / occupied /
                    // pinned (no_hide) tags — the rest appears on demand.
                    let keep = !!tg.active || !!tg.urgent || ((tg.clients || 0) > 0)
                    if (!keep) { try { keep = MangoService.isPinned(tg.index) } catch (e2) {} }
                    if (dyn && !keep) continue
                    out2.push({
                        id: tg.index,
                        name: "" + tg.index,
                        focused: !!tg.active,
                        active: !!tg.active,
                        occupied: (tg.clients || 0) > 0,
                        clients: tg.clients || 0
                    })
                }
                out2.sort((a, b) => a.id - b.id)
                return out2
            } catch (e) { return [] }
        }
        return []
    }
    readonly property bool isM3: Theme.workspaceStyle === "m3"
    readonly property bool isDefault2: Theme.workspaceStyle === "default2"
    readonly property real uiScale: Theme.workspaceScale
    property int hoveredIndex: -1
    // PERF: cache anim flag — hoverScaleFor() runs per delegate per hover move.
    readonly property bool _animHover: Theme.animationsEnabled && !isDefault2
    function hoverScaleFor(idx: int): real {
        if (!_animHover) return 1.0
        if (hoveredIndex < 0) return 1.0
        return idx === hoveredIndex ? 1.08 : 1.0
    }
    function setHoverAt(px: real, py: real): void {
        let container = vertical ? vCol : hRow
        for (let i = 0; i < container.children.length; i++) {
            let ch = container.children[i]
            if (!ch || ch.ws === undefined || ch.index === undefined || !ch.visible) continue
            let lp = ch.mapFromItem(root, px, py)
            if (lp.x >= 0 && lp.x <= ch.width && lp.y >= 0 && lp.y <= ch.height) {
                if (hoveredIndex !== ch.index) hoveredIndex = ch.index
                return
            }
        }
        if (hoveredIndex !== -1) hoveredIndex = -1
    }
    function clearHover(): void {
        hoveredIndex = -1
    }
    function isOccupied(ws): bool { if (!ws) return false
        try { if (ws.occupied !== undefined) return !!ws.occupied } catch (e) {}
        try { if (ws.clients !== undefined) return (ws.clients || 0) > 0 } catch (e2) {}
        return !!ws.active || !!ws.focused
    }
    function activateAt(px: real, py: real): bool {
        let container = vertical ? vCol : hRow
        for (let i = 0; i < container.children.length; i++) {
            let ch = container.children[i]
            if (!ch || ch.ws === undefined || !ch.visible) continue
            let lp = ch.mapFromItem(root, px, py)
            if (lp.x >= 0 && lp.x <= ch.width && lp.y >= 0 && lp.y <= ch.height) {
                let ws = ch.ws
                MangoService.activateTag(ws.id, root.screenName)
                return true
            }
        }
        return false
    }

    function enterWs(idx: int, anchorItem: Item, ws: var): void {
        hoveredIndex = idx
    }
    function leaveWs(idx: int): void {
        if (hoveredIndex === idx) hoveredIndex = -1
    }

    RowLayout {
        id: hRow
        anchors.centerIn: parent
        visible: !root.vertical
        spacing: root.isDefault2 ? 0 : Theme.workspaceSpacing
        Repeater {
            // PERF: hidden orientation keeps zero delegates (was 2x Repeaters
            // on the same model, hidden one still bound + hover-scanned).
            model: root.vertical ? [] : root.sortedWorkspaces
            delegate: Item {
                id: hDelegate
                required property var modelData
                required property int index
                property var ws: modelData
                // PERF: direct prop read (was root.isOccupied(ws) function call
                // per delegate per poll + per hover).
                property bool occupied: ws && (ws.occupied !== undefined ? !!ws.occupied : ((ws.clients || 0) > 0))
                implicitWidth: ((root.isM3 ? (ws.focused ? 28 : occupied ? 14 : 8) + 2 : 20) + (root.isDefault2 ? 0 : Theme.workspaceSpacing)) * root.uiScale; implicitHeight: 24 * root.uiScale
                opacity: root.isM3 ? 1.0 : (occupied || ws.focused ? 1.0 : 0.5)
                scale: root.hoverScaleFor(index)
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.centerIn: parent
                    visible: root.isM3
                    width: (ws.focused ? 28 : occupied ? 14 : 8) * root.uiScale
                    height: 10 * root.uiScale
                    radius: height / 2
                    color: ws.focused ? Theme.accent : occupied ? Theme.textSecondary : Theme.divider
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.centerIn: parent
                    width: 13 * root.uiScale; height: 13 * root.uiScale; radius: Math.max(2, Math.min(6.5, Theme.cornerRadius)); color: Theme.textPrimary
                    visible: !root.isM3 && !root.isDefault2
                    opacity: ws.focused ? 1 : 0
                    scale: ws.focused ? 1.1 : 0.6
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.fill: parent
                    anchors.topMargin: -(Theme.barThickness - 24 * root.uiScale) / 2
                    anchors.bottomMargin: -(Theme.barThickness - 24 * root.uiScale) / 2
                    radius: 0
                    color: ws.focused ? Theme.bgSelected : Theme.bgHover
                    border.color: Theme.divider
                    border.width: 1
                    visible: root.isDefault2 && (ws.focused || root.hoveredIndex === index)
                    opacity: (ws.focused || root.hoveredIndex === index) ? 1 : 0
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    anchors.centerIn: parent
                    text: ws.name
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(14) * root.uiScale; font.weight: root.isDefault2 ? ((ws.focused || root.hoveredIndex === index) ? Font.Medium : Font.Normal) : (Theme.textBold ? Font.Medium : Font.Normal)
                    color: root.hoveredIndex === index ? Theme.primary : (root.isDefault2 ? (ws.focused ? Theme.accent : Theme.textPrimary) : Theme.textPrimary)
                    visible: !root.isM3
                    opacity: root.isDefault2 ? 1 : (ws.focused ? 0 : 1)
                    scale: root.isDefault2 ? 1.0 : (ws.focused ? 0.7 : 1.0)
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 2 * root.uiScale; radius: 0
                    y: parent.height - height - 2 + (Theme.barThickness - 24 * root.uiScale) / 2
                    color: Theme.accent
                    visible: root.isDefault2
                    opacity: ws.focused ? 1 : 0
                }
                MouseArea {
                    id: hHover
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    z: 10
                    onEntered: root.enterWs(hDelegate.index, hDelegate, ws)
                    onExited: root.leaveWs(hDelegate.index)
                    onClicked: mouse => {
                        mouse.accepted = true
                        MangoService.activateTag(ws.id, root.screenName)
                    }
                    onWheel: wheel => {
                        if (wheel.angleDelta.y > 0) MangoService.prevTag(root.screenName)
                        else MangoService.nextTag(root.screenName)
                        wheel.accepted = true
                    }
                }
            }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: root.sortedWorkspaces.length===0; text:"\u2014"; color: Theme.textPrimary; font.pixelSize: Theme.fs(13)
            opacity: visible ? 1 : 0
        }
    }

    ColumnLayout {
        id: vCol
        anchors.centerIn: parent
        visible: root.vertical
        spacing: root.isDefault2 ? 0 : Theme.workspaceSpacing
        Repeater {
            model: root.vertical ? root.sortedWorkspaces : []
            delegate: Item {
                id: vDelegate
                required property var modelData
                required property int index
                property var ws: modelData
                property bool occupied: ws && (ws.occupied !== undefined ? !!ws.occupied : ((ws.clients || 0) > 0))
                implicitWidth: 24 * root.uiScale; implicitHeight: ((root.isM3 ? (ws.focused ? 28 : occupied ? 14 : 8) + 2 : 20) + (root.isDefault2 ? 0 : Theme.workspaceSpacing)) * root.uiScale
                opacity: root.isM3 ? 1.0 : (occupied || ws.focused ? 1.0 : 0.5)
                scale: root.hoverScaleFor(index)
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.centerIn: parent
                    visible: root.isM3
                    width: 10 * root.uiScale
                    height: (ws.focused ? 28 : occupied ? 14 : 8) * root.uiScale
                    radius: width / 2
                    color: ws.focused ? Theme.accent : occupied ? Theme.textSecondary : Theme.divider
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.centerIn: parent
                    width: 13 * root.uiScale; height: 13 * root.uiScale; radius: Math.max(2, Math.min(6.5, Theme.cornerRadius)); color: Theme.textPrimary
                    visible: !root.isM3 && !root.isDefault2
                    opacity: ws.focused ? 1 : 0
                    scale: ws.focused ? 1.1 : 0.6
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.fill: parent
                    anchors.leftMargin: -(Theme.barThickness - 24 * root.uiScale) / 2
                    anchors.rightMargin: -(Theme.barThickness - 24 * root.uiScale) / 2
                    radius: 0
                    color: ws.focused ? Theme.bgSelected : Theme.bgHover
                    border.color: Theme.divider
                    border.width: 1
                    visible: root.isDefault2 && (ws.focused || root.hoveredIndex === index)
                    opacity: (ws.focused || root.hoveredIndex === index) ? 1 : 0
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    anchors.centerIn: parent
                    text: ws.name
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(14) * root.uiScale; font.weight: root.isDefault2 ? ((ws.focused || root.hoveredIndex === index) ? Font.Medium : Font.Normal) : (Theme.textBold ? Font.Medium : Font.Normal)
                    color: root.hoveredIndex === index ? Theme.primary : (root.isDefault2 ? (ws.focused ? Theme.accent : Theme.textPrimary) : Theme.textPrimary)
                    visible: !root.isM3
                    opacity: root.isDefault2 ? 1 : (ws.focused ? 0 : 1)
                    scale: root.isDefault2 ? 1.0 : (ws.focused ? 0.7 : 1.0)
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2 * root.uiScale; radius: 0
                    x: Theme.barPosition === "right" ? parent.width - width - 2 + (Theme.barThickness - 24 * root.uiScale) / 2 : 2 - (Theme.barThickness - 24 * root.uiScale) / 2
                    color: Theme.accent
                    visible: root.isDefault2
                    opacity: ws.focused ? 1 : 0
                }
                MouseArea {
                    id: vHover
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    z: 10
                    onEntered: root.enterWs(vDelegate.index, vDelegate, ws)
                    onExited: root.leaveWs(vDelegate.index)
                    onClicked: mouse => {
                        mouse.accepted = true
                        MangoService.activateTag(ws.id, root.screenName)
                    }
                    onWheel: wheel => {
                        if (wheel.angleDelta.y > 0) MangoService.prevTag(root.screenName)
                        else MangoService.nextTag(root.screenName)
                        wheel.accepted = true
                    }
                }
            }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: root.sortedWorkspaces.length===0; text:"\u2014"; color: Theme.textPrimary; font.pixelSize: Theme.fs(13)
            Layout.alignment: Qt.AlignHCenter
            opacity: visible ? 1 : 0
        }
    }
}
