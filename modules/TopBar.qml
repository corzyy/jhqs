pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "./bar" as Bar
import "./bar/BarDropModel.js" as BarDropModel

import "../services"
import "../themes"

Scope {
    id: topBarScope
    signal toggleMenu()
    signal toggleControlCenter()
    signal toggleCalendar()
    signal toggleMedia()
    signal toggleWeather()
    signal toggleNotif()
    signal toggleNetwork()
    signal toggleVolume()
    signal toggleBluetooth()
    signal toggleVitals()
    signal toggleSystemTray()
    signal openUpdates()
    signal closePanel(string moduleId)

    property bool menuOpen: false
    property bool ccOpen: false
    property bool calendarOpen: false
    property bool mediaOpen: false
    property bool weatherOpen: false
    property bool notifOpen: false
    property bool networkOpen: false
    property bool volumeOpen: false
    property bool bluetoothOpen: false
    property bool vitalsOpen: false
    property bool trayOpen: false
    property bool updatesOpen: false
    function moduleActive(id: string): bool {
        if (id === "launcher") return topBarScope.menuOpen
        if (id === "clock") return topBarScope.calendarOpen
        if (id === "controlcenter") return topBarScope.ccOpen
        if (id === "media") return topBarScope.mediaOpen
        if (id === "weather") return topBarScope.weatherOpen
        if (id === "notif") return topBarScope.notifOpen
        if (id === "network") return topBarScope.networkOpen
        if (id === "volume") return topBarScope.volumeOpen
        if (id === "bluetooth") return topBarScope.bluetoothOpen
        if (id === "vitals") return topBarScope.vitalsOpen
        if (id === "systemtray") return topBarScope.trayOpen
        if (id === "updates") return topBarScope.updatesOpen
        return false
    }

    property bool dragActive: false
    property var dragSourceSlot: null
    property string dragSourceId: ""
    property var dragTargetSlot: null
    property bool dragAfter: false
    property var dragMarker: null
    property string dragTargetSection: ""
    property int dragTargetIndex: 0
    property bool leftGapEmpty: false
    property bool twoFifthsGapEmpty: false
    property bool middleGapEmpty: false
    property bool fourFifthsGapEmpty: false
    property bool rightGapEmpty: false
    property url dragImageUrl: ""
    property real dragGhostX: 0
    property real dragGhostY: 0
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property real dragGhostW: 1
    property real dragGhostH: 1

    IpcHandler {
        target: "vitals"
        function status(): string { return VitalsService.status() }
        function refresh(): string { VitalsService.refresh(); return "refreshing " + VitalsService.status() }
    }
    IpcHandler {
        target: "updates"
        function check(): string { UpdateService.checkNow(); return "checking system+aur+flatpak..." }
        function status(): string { return UpdateService.status() }
        function debug(arg: string): string { return UpdateService.setDebug(arg) }
        function debugCount(n: int): string { UpdateService.debugCount = n; UpdateService.debugForce = true; return "debugCount=" + n }
    }

    property var fullscreenByScreen: ({ })
    Timer { id: fsDebounce; interval: 200; repeat: false; onTriggered: if (!fsProc.running) fsProc.running = true }
    function refreshFullscreen() {
        if (fsProc.running) return
        if (fsDebounce.running) return
        fsDebounce.restart()
    }
    Process {
        id: fsProc
        command: ["bash", "-c", "hyprctl monitors -j 2>/dev/null; echo '__JHQS_WS__'; hyprctl workspaces -j 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: topBarScope.finishFullscreenRefresh(text || "")
        }
    }
    function finishFullscreenRefresh(out) {
        try {
            let parts = ("" + (out || "")).split("__JHQS_WS__")
            if (parts.length < 2) return
            let mons = JSON.parse((parts[0] || "").trim() || "[]")
            let wss = JSON.parse((parts[1] || "").trim() || "[]")
            let fsIds = { }
            for (let i = 0; i < wss.length; i++) {
                let w = wss[i]
                if (w && w.hasfullscreen) fsIds[w.id] = true
            }
            let m = { }
            for (let j = 0; j < mons.length; j++) {
                let mon = mons[j]
                if (!mon || !mon.name) continue
                let aid = (mon.activeWorkspace && mon.activeWorkspace.id !== undefined) ? mon.activeWorkspace.id : -1
                m[mon.name] = !!fsIds[aid]
            }
            fullscreenByScreen = m
        } catch (e) { }
    }
    Connections {
        target: Hyprland
        ignoreUnknownSignals: true
        function onRawEvent(event) {
            try {
                let n = event ? event.name : ""
                if (n === "fullscreen" || n === "activewindow" || n === "activewindowv2"
                        || n === "workspace" || n === "workspacev2" || n === "focusedmon" || n === "focusedmonv2"
                        || n === "movewindow" || n === "movewindowv2" || n === "openwindow" || n === "closewindow") {
                    topBarScope.refreshFullscreen()
                }
            } catch (e) { }
        }
    }
    Component.onCompleted: refreshFullscreen()

    IpcHandler {
        target: "bar"
        function layout(): string { return Theme.barLayoutString() }
        function move(id: string, section: string, index: int): string { return Theme.moveBarWidget(id, section, index) }
        function reset(): string { Theme.resetBarLayout(); return "reset: " + Theme.barLayoutString() }
        function hide(id: string): string { return Theme.hideBarModule(id) }
        function show(id: string): string { return Theme.showBarModule(id) }
        function fullscreen(): string { try { return JSON.stringify(topBarScope.fullscreenByScreen) } catch (e) { return "{ }" } }
        function refreshFullscreen(): string { topBarScope.refreshFullscreen(); return "refreshing" }
        function trayAnchor(): string { try { return "systemtray=" + JSON.stringify(Theme.barAnchor("systemtray")) + " bar=" + JSON.stringify(Theme.barWindowRect) } catch (e) { return "err " + e } }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: topBarWindow
            required property var modelData
            screen: modelData
            readonly property int cfgThickness: Theme.barThickness
            property int barHeight: Math.max(20, Math.min(64, topBarWindow.cfgThickness))
            property int barWidth: Math.max(20, Math.min(64, topBarWindow.cfgThickness))
            onBarWidthChanged: Theme.barEffectiveWidth = barWidth
            onBarHeightChanged: Theme.barEffectiveHeight = barHeight
            onWidthChanged: publishWindowRect()
            onHeightChanged: publishWindowRect()
            onBarPosChanged: publishWindowRect()
            onEdgeDistChanged: publishWindowRect()
            onTopDistChanged: publishWindowRect()
            property string barPos: Theme.barPosition
            property real barOpacity: Theme.barOpacity
            property bool isVertical: barPos === "left" || barPos === "right"
            property bool isHorizontal: !isVertical
            property bool isIsland: Theme.barStyle === "island"
            property int edgeDist: Theme.barEdgeDistance
            property int topDist: Theme.barTopDistance
            property bool screenFullscreen: {
                try {
                    let m = topBarScope.fullscreenByScreen
                    if (m && m[modelData.name] === true) return true
                } catch (e) { }
                return false
            }
            visible: modelData.name === "DP-1" && !screenFullscreen
            WlrLayershell.namespace: "bar"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusiveZone: (modelData.name === "DP-1" && !screenFullscreen) ? (isVertical ? barWidth + topDist : barHeight + topDist) : 0
            anchors { top: barPos === "top" || isVertical; bottom: barPos === "bottom" || isVertical; left: barPos === "left" || isHorizontal; right: barPos === "right" || isHorizontal }
            margins {
                top: topBarWindow.isVertical ? topBarWindow.edgeDist : (topBarWindow.barPos === "top" ? topBarWindow.topDist : 0)
                bottom: topBarWindow.isVertical ? topBarWindow.edgeDist : (topBarWindow.barPos === "bottom" ? topBarWindow.topDist : 0)
                left: topBarWindow.isVertical ? (topBarWindow.barPos === "left" ? topBarWindow.topDist : 0) : topBarWindow.edgeDist
                right: topBarWindow.isVertical ? (topBarWindow.barPos === "right" ? topBarWindow.topDist : 0) : topBarWindow.edgeDist
            }
            implicitHeight: isVertical ? 0 : barHeight
            implicitWidth: isVertical ? barWidth : 0
            color: "transparent"
            Behavior on implicitHeight { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingStandard } }
            Behavior on implicitWidth { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingStandard } }

            Rectangle {
                antialiasing: Theme.shapesAa
                id: barBackground
                anchors.fill: parent
                visible: !topBarWindow.isIsland
                radius: (topBarWindow.edgeDist > 0 || topBarWindow.topDist > 0) ? Theme.cornerRadius : 0
                color: topBarWindow.barOpacity >= 0.999 ? Theme.panelBg : Theme.withAlpha(Theme.bg, Math.max(0, Math.min(1, topBarWindow.barOpacity * Theme.panelBgAlpha)))
                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }
                Behavior on radius { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingStandard } }
            }

            property real _entrance: 0
            Component.onCompleted: { _entrance = 1; Theme.barEffectiveWidth = barWidth; Theme.barEffectiveHeight = barHeight; publishWindowRect(); Qt.callLater(publishWindowRect) }

            function clearDrag(): void {
                topBarScope.dragActive = false
                topBarScope.dragSourceSlot = null
                topBarScope.dragSourceId = ""
                topBarScope.dragTargetSlot = null
                topBarScope.dragAfter = false
                topBarScope.dragMarker = null
                topBarScope.dragTargetSection = ""
                topBarScope.dragTargetIndex = 0
                topBarScope.leftGapEmpty = false
                topBarScope.twoFifthsGapEmpty = false
                topBarScope.middleGapEmpty = false
                topBarScope.fourFifthsGapEmpty = false
                topBarScope.rightGapEmpty = false
                topBarScope.dragImageUrl = ""
                topBarScope.dragGhostX = 0
                topBarScope.dragGhostY = 0
                topBarScope.dragOffsetX = 0
                topBarScope.dragOffsetY = 0
            }
            function sceneToScreen(p: var): var {
                let x = p ? p.x : 0
                let y = p ? p.y : 0
                let sw = 0
                let sh = 0
                try { sw = Screen.width; sh = Screen.height } catch (e) { }
                if (!isFinite(sw)) sw = 0
                if (!isFinite(sh)) sh = 0
                let mL = 0, mT = 0, mR = 0, mB = 0
                try { let m = topBarWindow.margins; if (m) { mL = m.left || 0; mT = m.top || 0; mR = m.right || 0; mB = m.bottom || 0 } } catch (e2) { }
                if (barPos === "bottom") { x += mL; y += Math.max(0, sh - topBarWindow.height - mB) }
                else if (barPos === "right") { x += Math.max(0, sw - topBarWindow.width - mR); y += mT }
                else { x += mL; y += mT }
                return { x: x, y: y }
            }
            function publishWindowRect(): void {
                if (modelData.name !== "DP-1") return
                try {
                    let sw = 0, sh = 0
                    try { if (screen) { sw = screen.width; sh = screen.height } } catch (e1) { }
                    if (!sw || !sh) { try { sw = Screen.width; sh = Screen.height } catch (e2) { } }
                    let mL = 0, mT = 0, mR = 0, mB = 0
                    try { let m = margins; if (m) { mL = m.left || 0; mT = m.top || 0; mR = m.right || 0; mB = m.bottom || 0 } } catch (e3) { }
                    let rx = mL, ry = mT
                    if (barPos === "bottom" && sh > 0) { rx = mL; ry = Math.max(0, sh - height - mB) }
                    else if (barPos === "right" && sw > 0) { rx = Math.max(0, sw - width - mR); ry = mT }
                    else if (barPos === "left") { rx = mL; ry = mT }
                    Theme.setBarWindowRect(rx, ry, width, height)
                } catch (e) { }
            }
            function captureDragGhost(slot: var): void {
                topBarScope.dragImageUrl = ""
                let item = slot && slot.dragVisual ? slot.dragVisual : null
                if (!item || typeof item.grabToImage !== "function") return
                let w = Math.max(1, Math.ceil(item.width || item.implicitWidth || 1))
                let h = Math.max(1, Math.ceil(item.height || item.implicitHeight || 1))
                topBarScope.dragGhostW = w
                topBarScope.dragGhostH = h
                item.grabToImage(function(result) {
                    if (topBarScope.dragSourceSlot !== slot || !result || !result.url) return
                    topBarScope.dragImageUrl = result.url
                }, Qt.size(w, h))
            }
            function startSlotDrag(slot: var, x: real, y: real): void {
                if (!slot) return
                topBarScope.dragSourceSlot = slot
                topBarScope.dragSourceId = slot.moduleId
                topBarScope.dragOffsetX = x
                topBarScope.dragOffsetY = y
                topBarScope.dragActive = true
                captureDragGhost(slot)
                moveSlotDrag(slot, x, y)
            }
            function dropCandidates(sourceSlot: var): var {
                let rows = []
                if (isVertical) rows = [{ row: vTopCol, box: vTopWrap, sec: "left" }, { row: vTwoFifthsCol, box: vTwoFifthsWrap, sec: "twofifths" }, { row: vMidCol, box: vMidWrap, sec: "center" }, { row: vFourFifthsCol, box: vFourFifthsWrap, sec: "fourfifths" }, { row: vBottomCol, box: vBottomWrap, sec: "right" }]
                else rows = [{ row: leftZoneRow, box: leftZoneWrap, sec: "left" }, { row: twoFifthsZoneRow, box: twoFifthsZoneWrap, sec: "twofifths" }, { row: centerZoneRow, box: centerZoneWrap, sec: "center" }, { row: fourFifthsZoneRow, box: fourFifthsZoneWrap, sec: "fourfifths" }, { row: rightZoneRow, box: rightZoneWrap, sec: "right" }]
                let list = []
                let counts = [-1, -1, -1, -1, -1]
                for (let r = 0; r < rows.length; r++) {
                    let row = rows[r].row
                    if (!row) { counts[r] = 0; continue }
                    let n = 0
                    for (let i = 0; i < row.children.length; i++) {
                        let ch = row.children[i]
                        if (!ch || ch.moduleId === undefined || ch === sourceSlot) continue
                        if (!ch.visible || ch.width <= 0 || ch.height <= 0) continue
                        n++
                        let p = { x: ch.x, y: ch.y }
                        try { p = ch.mapToItem(null, 0, 0) } catch (e) { }
                        list.push({ slot: ch, x: p.x, y: p.y, width: ch.width, height: ch.height })
                    }
                    if (r >= 0 && r < 5) counts[r] = n
                    if (n === 0) {
                        let bx = rows[r].box || row
                        let bw = Math.max(bx.width || 0, bx.implicitWidth || 0)
                        let bh = Math.max(bx.height || 0, bx.implicitHeight || 0)
                        let rp = { x: 0, y: 0 }
                        try { rp = bx.mapToItem(null, 0, 0) } catch (e) { }
                        list.push({ slot: bx, x: rp.x, y: rp.y, width: bw, height: bh, emptySection: rows[r].sec, emptyIndex: 0 })
                    }
                }
                topBarScope.leftGapEmpty = (counts[0] === 0)
                topBarScope.twoFifthsGapEmpty = (counts[1] === 0)
                topBarScope.middleGapEmpty = (counts[2] === 0)
                topBarScope.fourFifthsGapEmpty = (counts[3] === 0)
                topBarScope.rightGapEmpty = (counts[4] === 0)
                return list
            }
            function markerRect(slot: var, after: bool, centered: bool): var {
                if (!slot) return null
                try {
                    let sp = sceneToScreen(slot.mapToItem(null, 0, 0))
                    let t = 4
                    if (isVertical) {
                        if (centered) return { x: sp.x, y: sp.y + slot.height / 2 - t / 2, width: slot.width, height: t }
                        return { x: sp.x, y: sp.y + (after ? slot.height : 0) - t / 2, width: slot.width, height: t }
                    }
                    if (centered) return { x: sp.x + slot.width / 2 - t / 2, y: sp.y, width: t, height: slot.height }
                    return { x: sp.x + (after ? slot.width : 0) - t / 2, y: sp.y, width: t, height: slot.height }
                } catch (e) {
                    return null
                }
            }
            function moveSlotDrag(slot: var, x: real, y: real): void {
                if (!topBarScope.dragActive) return
                let scenePoint = { x: x, y: y }
                try { scenePoint = slot.mapToItem(null, x, y) } catch (e) { }
                let pad = 40
                if (scenePoint.x < -pad || scenePoint.y < -pad
                        || scenePoint.x > topBarWindow.width + pad || scenePoint.y > topBarWindow.height + pad) {
                    topBarScope.dragTargetSlot = null
                    topBarScope.dragTargetSection = ""
                    topBarScope.dragTargetIndex = 0
                    topBarScope.dragMarker = null
                    return
                }
                let screenPoint = sceneToScreen(scenePoint)
                topBarScope.dragGhostX = screenPoint.x
                topBarScope.dragGhostY = screenPoint.y
                let drop = BarDropModel.nearestDropTarget(dropCandidates(slot), scenePoint, isVertical)
                if (!drop) {
                    topBarScope.dragTargetSlot = null
                    topBarScope.dragTargetSection = ""
                    topBarScope.dragTargetIndex = 0
                    topBarScope.dragAfter = false
                    topBarScope.dragMarker = null
                    return
                }
                if (drop.emptySection !== undefined && drop.emptySection !== null) {
                    topBarScope.dragTargetSlot = null
                    topBarScope.dragTargetSection = drop.emptySection
                    topBarScope.dragTargetIndex = drop.emptyIndex || 0
                    topBarScope.dragAfter = false
                    topBarScope.dragMarker = markerRect(drop.slot, false, true)
                    return
                }
                topBarScope.dragTargetSlot = drop.slot
                topBarScope.dragTargetSection = ""
                topBarScope.dragTargetIndex = 0
                topBarScope.dragAfter = drop.after
                topBarScope.dragMarker = markerRect(drop.slot, drop.after, false)
            }
            function commitDrop(): void {
                let src = topBarScope.dragSourceSlot
                if (!src) return
                if (topBarScope.dragTargetSection !== "") {
                    Theme.moveBarWidget(src.moduleId, topBarScope.dragTargetSection, topBarScope.dragTargetIndex || 0)
                    return
                }
                let dst = topBarScope.dragTargetSlot
                if (!dst) return
                let sec = dst.section
                let t = dst.modIndex
                if (src.section === sec && src.modIndex < dst.modIndex) t--
                Theme.moveBarWidget(src.moduleId, sec, t + (topBarScope.dragAfter ? 1 : 0))
            }
            function endSlotDrag(slot: var, wasDragging: bool): void {
                if (wasDragging && topBarScope.dragActive) commitDrop()
                clearDrag()
            }
            function cancelSlotDrag(): void { clearDrag() }

            Item {
                id: horizontalContainer
                visible: topBarWindow.isHorizontal
                anchors.fill: parent; anchors.leftMargin: Theme.barContentPadding; anchors.rightMargin: Theme.barContentPadding
                opacity: visible ? topBarWindow._entrance : 0
                transform: Translate {
                    y: visible ? (1 - topBarWindow._entrance) * (topBarWindow.barPos === "top" ? -12 : 12) : 0
                    Behavior on y { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                }
                Behavior on opacity { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }

                Item {
                    id: leftZoneWrap
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(leftZoneRow.implicitWidth + ((topBarWindow.isIsland || Theme.barModuleBackground || Theme.barContentPadding > 0) ? 14 : 0), (topBarScope.dragActive && topBarScope.leftGapEmpty) ? 96 : 0)
                    height: Math.max(0, Math.min(leftZoneRow.implicitHeight + 8, parent.height - 4))
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        anchors.fill: parent
                        visible: (topBarWindow.isIsland || Theme.barModuleBackground) && (leftZoneRow.implicitWidth > 0 || (topBarScope.dragActive && topBarScope.leftGapEmpty))
                        radius: Math.min(Theme.cornerRadius, height / 2)
                        color: {
                            if (topBarWindow.barOpacity >= 0.999) return topBarWindow.isIsland ? Theme.panelBg : Theme.cardBg
                            let a = Math.max(0, Math.min(1, topBarWindow.barOpacity * Theme.panelBgAlpha))
                            let base = topBarWindow.isIsland ? Theme.bg : Theme.surface_container_high
                            return Theme.withAlpha(base, a)
                        }
                        Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }
                    }
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        id: leftDropDot
                        width: 10; height: width; radius: width / 2
                        anchors.centerIn: parent
                        color: Theme.accent
                        visible: topBarWindow.isHorizontal && topBarScope.dragActive && topBarScope.leftGapEmpty
                    }
                    RowLayout {
                        id: leftZoneRow
                        anchors.centerIn: parent
                        spacing: Theme.barModuleSpacing
                        Repeater {
                            model: Theme.barLayoutLeft
                                Bar.DraggableModule {
                                    required property var modelData
                                    required property int index
                                    moduleId: modelData
                                    active: topBarScope.moduleActive(modelData)
                                    section: "left"
                                    modIndex: index
                                    Layout.alignment: Qt.AlignVCenter
                                    vertical: false
                                    monitor: topBarWindow.modelData
                                    barPos: topBarWindow.barPos
                                    barWindow: topBarWindow
                                    anchorActive: topBarWindow.isHorizontal
                                    isSource: topBarScope.dragSourceId === modelData

                                    onRequestMenu: topBarScope.toggleMenu()
                                    onRequestCalendar: topBarScope.toggleCalendar()
                                    onRequestWeather: topBarScope.toggleWeather()
                                    onRequestUpdates: topBarScope.openUpdates()
                                    onRequestCC: topBarScope.toggleControlCenter()
                                    onRequestMedia: topBarScope.toggleMedia()
                                    onRequestNetwork: topBarScope.toggleNetwork()
                                    onRequestVolume: topBarScope.toggleVolume()
                                    onRequestBluetooth: topBarScope.toggleBluetooth()
                                    onRequestVitals: topBarScope.toggleVitals()
                                    onRequestSystemTray: topBarScope.toggleSystemTray()
                                    onRequestNotif: topBarScope.toggleNotif()
                                    onHideRequest: topBarScope.closePanel(modelData)
                                    onPressBegun: topBarWindow.clearDrag()
                                    onThresholdPassed: (slot, x, y) => topBarWindow.startSlotDrag(slot, x, y)
                                    onDragMoved: (slot, x, y) => topBarWindow.moveSlotDrag(slot, x, y)
                                    onDragReleased: (slot, was) => topBarWindow.endSlotDrag(slot, was)
                                    onDragCanceled: topBarWindow.cancelSlotDrag()
                                }
                        }

                    }
                }

                Item {
                    id: twoFifthsZoneWrap
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: parent.width * -0.25
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(twoFifthsZoneRow.implicitWidth + ((topBarWindow.isIsland || Theme.barModuleBackground || Theme.barContentPadding > 0) ? 14 : 0), (topBarScope.dragActive && topBarScope.twoFifthsGapEmpty) ? 110 : 0)
                    height: Math.max(0, Math.min(twoFifthsZoneRow.implicitHeight + 8, parent.height - 4))
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        anchors.fill: parent
                        visible: (topBarWindow.isIsland || Theme.barModuleBackground) && (twoFifthsZoneRow.implicitWidth > 0 || (topBarScope.dragActive && topBarScope.twoFifthsGapEmpty))
                        radius: Math.min(Theme.cornerRadius, height / 2)
                        color: {
                            if (topBarWindow.barOpacity >= 0.999) return topBarWindow.isIsland ? Theme.panelBg : Theme.cardBg
                            let a = Math.max(0, Math.min(1, topBarWindow.barOpacity * Theme.panelBgAlpha))
                            let base = topBarWindow.isIsland ? Theme.bg : Theme.surface_container_high
                            return Theme.withAlpha(base, a)
                        }
                        Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }
                    }
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        id: twoFifthsDropDot
                        width: 10; height: width; radius: width / 2
                        anchors.centerIn: parent
                        color: Theme.accent
                        visible: topBarWindow.isHorizontal && topBarScope.dragActive && topBarScope.twoFifthsGapEmpty
                    }
                    RowLayout {
                        id: twoFifthsZoneRow
                        anchors.centerIn: parent
                        spacing: Theme.barModuleSpacing
                        Repeater {
                            model: Theme.barLayoutTwoFifths
                                Bar.DraggableModule {
                                    required property var modelData
                                    required property int index
                                    moduleId: modelData
                                    active: topBarScope.moduleActive(modelData)
                                    section: "twofifths"
                                    modIndex: index
                                    Layout.alignment: Qt.AlignVCenter
                                    vertical: false
                                    monitor: topBarWindow.modelData
                                    barPos: topBarWindow.barPos
                                    barWindow: topBarWindow
                                    anchorActive: topBarWindow.isHorizontal
                                    isSource: topBarScope.dragSourceId === modelData

                                    onRequestMenu: topBarScope.toggleMenu()
                                    onRequestCalendar: topBarScope.toggleCalendar()
                                    onRequestWeather: topBarScope.toggleWeather()
                                    onRequestUpdates: topBarScope.openUpdates()
                                    onRequestCC: topBarScope.toggleControlCenter()
                                    onRequestMedia: topBarScope.toggleMedia()
                                    onRequestNetwork: topBarScope.toggleNetwork()
                                    onRequestVolume: topBarScope.toggleVolume()
                                    onRequestBluetooth: topBarScope.toggleBluetooth()
                                    onRequestVitals: topBarScope.toggleVitals()
                                    onRequestSystemTray: topBarScope.toggleSystemTray()
                                    onRequestNotif: topBarScope.toggleNotif()
                                    onHideRequest: topBarScope.closePanel(modelData)
                                    onPressBegun: topBarWindow.clearDrag()
                                    onThresholdPassed: (slot, x, y) => topBarWindow.startSlotDrag(slot, x, y)
                                    onDragMoved: (slot, x, y) => topBarWindow.moveSlotDrag(slot, x, y)
                                    onDragReleased: (slot, was) => topBarWindow.endSlotDrag(slot, was)
                                    onDragCanceled: topBarWindow.cancelSlotDrag()
                                }
                        }

                    }
                }

                Item {
                    id: centerZoneWrap
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(centerZoneRow.implicitWidth + ((topBarWindow.isIsland || Theme.barModuleBackground || Theme.barContentPadding > 0) ? 14 : 0), (topBarScope.dragActive && topBarScope.middleGapEmpty) ? 110 : 0)
                    height: Math.max(0, Math.min(centerZoneRow.implicitHeight + 8, parent.height - 4))
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        anchors.fill: parent
                        visible: (topBarWindow.isIsland || Theme.barModuleBackground) && (centerZoneRow.implicitWidth > 0 || (topBarScope.dragActive && topBarScope.middleGapEmpty))
                        radius: Math.min(Theme.cornerRadius, height / 2)
                        color: {
                            if (topBarWindow.barOpacity >= 0.999) return topBarWindow.isIsland ? Theme.panelBg : Theme.cardBg
                            let a = Math.max(0, Math.min(1, topBarWindow.barOpacity * Theme.panelBgAlpha))
                            let base = topBarWindow.isIsland ? Theme.bg : Theme.surface_container_high
                            return Theme.withAlpha(base, a)
                        }
                        Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }
                    }
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        id: centerDropDot
                        width: 10; height: width; radius: width / 2
                        anchors.centerIn: parent
                        color: Theme.accent
                        visible: topBarWindow.isHorizontal && topBarScope.dragActive && topBarScope.middleGapEmpty
                    }
                    RowLayout {
                        id: centerZoneRow
                        anchors.centerIn: parent
                        spacing: Theme.barModuleSpacing
                        Repeater {
                            model: Theme.barLayoutCenter
                                Bar.DraggableModule {
                                    required property var modelData
                                    required property int index
                                    moduleId: modelData
                                    active: topBarScope.moduleActive(modelData)
                                    section: "center"
                                    modIndex: index
                                    Layout.alignment: Qt.AlignVCenter
                                    vertical: false
                                    monitor: topBarWindow.modelData
                                    barPos: topBarWindow.barPos
                                    barWindow: topBarWindow
                                    anchorActive: topBarWindow.isHorizontal
                                    isSource: topBarScope.dragSourceId === modelData

                                    onRequestMenu: topBarScope.toggleMenu()
                                    onRequestCalendar: topBarScope.toggleCalendar()
                                    onRequestWeather: topBarScope.toggleWeather()
                                    onRequestUpdates: topBarScope.openUpdates()
                                    onRequestCC: topBarScope.toggleControlCenter()
                                    onRequestMedia: topBarScope.toggleMedia()
                                    onRequestNetwork: topBarScope.toggleNetwork()
                                    onRequestVolume: topBarScope.toggleVolume()
                                    onRequestBluetooth: topBarScope.toggleBluetooth()
                                    onRequestVitals: topBarScope.toggleVitals()
                                    onRequestSystemTray: topBarScope.toggleSystemTray()
                                    onRequestNotif: topBarScope.toggleNotif()
                                    onHideRequest: topBarScope.closePanel(modelData)
                                    onPressBegun: topBarWindow.clearDrag()
                                    onThresholdPassed: (slot, x, y) => topBarWindow.startSlotDrag(slot, x, y)
                                    onDragMoved: (slot, x, y) => topBarWindow.moveSlotDrag(slot, x, y)
                                    onDragReleased: (slot, was) => topBarWindow.endSlotDrag(slot, was)
                                    onDragCanceled: topBarWindow.cancelSlotDrag()
                                }
                        }

                    }
                }

                Item {
                    id: fourFifthsZoneWrap
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: parent.width * 0.25
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(fourFifthsZoneRow.implicitWidth + ((topBarWindow.isIsland || Theme.barModuleBackground || Theme.barContentPadding > 0) ? 14 : 0), (topBarScope.dragActive && topBarScope.fourFifthsGapEmpty) ? 110 : 0)
                    height: Math.max(0, Math.min(fourFifthsZoneRow.implicitHeight + 8, parent.height - 4))
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        anchors.fill: parent
                        visible: (topBarWindow.isIsland || Theme.barModuleBackground) && (fourFifthsZoneRow.implicitWidth > 0 || (topBarScope.dragActive && topBarScope.fourFifthsGapEmpty))
                        radius: Math.min(Theme.cornerRadius, height / 2)
                        color: {
                            if (topBarWindow.barOpacity >= 0.999) return topBarWindow.isIsland ? Theme.panelBg : Theme.cardBg
                            let a = Math.max(0, Math.min(1, topBarWindow.barOpacity * Theme.panelBgAlpha))
                            let base = topBarWindow.isIsland ? Theme.bg : Theme.surface_container_high
                            return Theme.withAlpha(base, a)
                        }
                        Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }
                    }
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        id: fourFifthsDropDot
                        width: 10; height: width; radius: width / 2
                        anchors.centerIn: parent
                        color: Theme.accent
                        visible: topBarWindow.isHorizontal && topBarScope.dragActive && topBarScope.fourFifthsGapEmpty
                    }
                    RowLayout {
                        id: fourFifthsZoneRow
                        anchors.centerIn: parent
                        spacing: Theme.barModuleSpacing
                        Repeater {
                            model: Theme.barLayoutFourFifths
                                Bar.DraggableModule {
                                    required property var modelData
                                    required property int index
                                    moduleId: modelData
                                    active: topBarScope.moduleActive(modelData)
                                    section: "fourfifths"
                                    modIndex: index
                                    Layout.alignment: Qt.AlignVCenter
                                    vertical: false
                                    monitor: topBarWindow.modelData
                                    barPos: topBarWindow.barPos
                                    barWindow: topBarWindow
                                    anchorActive: topBarWindow.isHorizontal
                                    isSource: topBarScope.dragSourceId === modelData

                                    onRequestMenu: topBarScope.toggleMenu()
                                    onRequestCalendar: topBarScope.toggleCalendar()
                                    onRequestWeather: topBarScope.toggleWeather()
                                    onRequestUpdates: topBarScope.openUpdates()
                                    onRequestCC: topBarScope.toggleControlCenter()
                                    onRequestMedia: topBarScope.toggleMedia()
                                    onRequestNetwork: topBarScope.toggleNetwork()
                                    onRequestVolume: topBarScope.toggleVolume()
                                    onRequestBluetooth: topBarScope.toggleBluetooth()
                                    onRequestVitals: topBarScope.toggleVitals()
                                    onRequestSystemTray: topBarScope.toggleSystemTray()
                                    onRequestNotif: topBarScope.toggleNotif()
                                    onHideRequest: topBarScope.closePanel(modelData)
                                    onPressBegun: topBarWindow.clearDrag()
                                    onThresholdPassed: (slot, x, y) => topBarWindow.startSlotDrag(slot, x, y)
                                    onDragMoved: (slot, x, y) => topBarWindow.moveSlotDrag(slot, x, y)
                                    onDragReleased: (slot, was) => topBarWindow.endSlotDrag(slot, was)
                                    onDragCanceled: topBarWindow.cancelSlotDrag()
                                }
                        }

                    }
                }

                Item {
                    id: rightZoneWrap
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(rightZoneRow.implicitWidth + ((topBarWindow.isIsland || Theme.barModuleBackground || Theme.barContentPadding > 0) ? 14 : 0), (topBarScope.dragActive && topBarScope.rightGapEmpty) ? 96 : 0)
                    height: Math.max(0, Math.min(rightZoneRow.implicitHeight + 8, parent.height - 4))
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        anchors.fill: parent
                        visible: (topBarWindow.isIsland || Theme.barModuleBackground) && (rightZoneRow.implicitWidth > 0 || (topBarScope.dragActive && topBarScope.rightGapEmpty))
                        radius: Math.min(Theme.cornerRadius, height / 2)
                        color: {
                            if (topBarWindow.barOpacity >= 0.999) return topBarWindow.isIsland ? Theme.panelBg : Theme.cardBg
                            let a = Math.max(0, Math.min(1, topBarWindow.barOpacity * Theme.panelBgAlpha))
                            let base = topBarWindow.isIsland ? Theme.bg : Theme.surface_container_high
                            return Theme.withAlpha(base, a)
                        }
                        Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }
                    }
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        id: rightDropDot
                        width: 10; height: width; radius: width / 2
                        anchors.centerIn: parent
                        color: Theme.accent
                        visible: topBarWindow.isHorizontal && topBarScope.dragActive && topBarScope.rightGapEmpty
                    }
                    RowLayout {
                        id: rightZoneRow
                        anchors.centerIn: parent
                        spacing: Theme.barModuleSpacing
                        Repeater {
                            model: Theme.barLayoutRight
                                Bar.DraggableModule {
                                    required property var modelData
                                    required property int index
                                    moduleId: modelData
                                    active: topBarScope.moduleActive(modelData)
                                    section: "right"
                                    modIndex: index
                                    Layout.alignment: Qt.AlignVCenter
                                    vertical: false
                                    monitor: topBarWindow.modelData
                                    barPos: topBarWindow.barPos
                                    barWindow: topBarWindow
                                    anchorActive: topBarWindow.isHorizontal
                                    isSource: topBarScope.dragSourceId === modelData

                                    onRequestMenu: topBarScope.toggleMenu()
                                    onRequestCalendar: topBarScope.toggleCalendar()
                                    onRequestWeather: topBarScope.toggleWeather()
                                    onRequestUpdates: topBarScope.openUpdates()
                                    onRequestCC: topBarScope.toggleControlCenter()
                                    onRequestMedia: topBarScope.toggleMedia()
                                    onRequestNetwork: topBarScope.toggleNetwork()
                                    onRequestVolume: topBarScope.toggleVolume()
                                    onRequestBluetooth: topBarScope.toggleBluetooth()
                                    onRequestVitals: topBarScope.toggleVitals()
                                    onRequestSystemTray: topBarScope.toggleSystemTray()
                                    onRequestNotif: topBarScope.toggleNotif()
                                    onHideRequest: topBarScope.closePanel(modelData)
                                    onPressBegun: topBarWindow.clearDrag()
                                    onThresholdPassed: (slot, x, y) => topBarWindow.startSlotDrag(slot, x, y)
                                    onDragMoved: (slot, x, y) => topBarWindow.moveSlotDrag(slot, x, y)
                                    onDragReleased: (slot, was) => topBarWindow.endSlotDrag(slot, was)
                                    onDragCanceled: topBarWindow.cancelSlotDrag()
                                }
                        }

                    }
                }
            }

            Item {
                id: verticalContainer
                visible: topBarWindow.isVertical
                anchors.fill: parent; anchors.topMargin: Theme.barContentPadding; anchors.bottomMargin: Theme.barContentPadding; anchors.leftMargin: 4; anchors.rightMargin: 4
                clip: true
                opacity: visible ? topBarWindow._entrance : 0
                transform: Translate {
                    x: visible ? (1 - topBarWindow._entrance) * (topBarWindow.barPos === "left" ? -12 : 12) : 0
                    Behavior on x { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                }
                Behavior on opacity { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }

                ColumnLayout {
                    id: vCol; anchors.fill: parent; spacing: 10
                    Item {
                        id: vTopWrap
                        Layout.fillWidth: true
                        implicitHeight: vTopCol.implicitHeight + ((topBarWindow.isIsland || Theme.barModuleBackground || Theme.barContentPadding > 0) ? 14 : 0)
                        Layout.minimumHeight: (topBarScope.dragActive && topBarScope.leftGapEmpty && topBarWindow.isVertical) ? 96 : 0
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            anchors.fill: parent
                            visible: (topBarWindow.isIsland || Theme.barModuleBackground) && (vTopCol.implicitHeight > 0 || (topBarScope.dragActive && topBarScope.leftGapEmpty))
                            radius: Math.min(Theme.cornerRadius, width / 2)
                            color: {
                                if (topBarWindow.barOpacity >= 0.999) return topBarWindow.isIsland ? Theme.panelBg : Theme.cardBg
                                let a = Math.max(0, Math.min(1, topBarWindow.barOpacity * Theme.panelBgAlpha))
                                let base = topBarWindow.isIsland ? Theme.bg : Theme.surface_container_high
                                return Theme.withAlpha(base, a)
                            }
                        }
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            id: vTopDot
                            width: 10; height: width; radius: width / 2
                            anchors.centerIn: parent
                            color: Theme.accent
                            visible: topBarWindow.isVertical && topBarScope.dragActive && topBarScope.leftGapEmpty
                        }
                        ColumnLayout {
                            id: vTopCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.barModuleSpacing
                            Repeater {
                                model: Theme.barLayoutLeft
                                Bar.DraggableModule {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    moduleId: modelData
                                    active: topBarScope.moduleActive(modelData)
                                    section: "left"
                                    modIndex: index
                                    vertical: true
                                    monitor: topBarWindow.modelData
                                    barPos: topBarWindow.barPos
                                    barWindow: topBarWindow
                                    anchorActive: topBarWindow.isVertical
                                    isSource: topBarScope.dragSourceId === modelData

                                    onRequestMenu: topBarScope.toggleMenu()
                                    onRequestCalendar: topBarScope.toggleCalendar()
                                    onRequestWeather: topBarScope.toggleWeather()
                                    onRequestUpdates: topBarScope.openUpdates()
                                    onRequestCC: topBarScope.toggleControlCenter()
                                    onRequestMedia: topBarScope.toggleMedia()
                                    onRequestNetwork: topBarScope.toggleNetwork()
                                    onRequestVolume: topBarScope.toggleVolume()
                                    onRequestBluetooth: topBarScope.toggleBluetooth()
                                    onRequestVitals: topBarScope.toggleVitals()
                                    onRequestSystemTray: topBarScope.toggleSystemTray()
                                    onRequestNotif: topBarScope.toggleNotif()
                                    onHideRequest: topBarScope.closePanel(modelData)
                                    onPressBegun: topBarWindow.clearDrag()
                                    onThresholdPassed: (slot, x, y) => topBarWindow.startSlotDrag(slot, x, y)
                                    onDragMoved: (slot, x, y) => topBarWindow.moveSlotDrag(slot, x, y)
                                    onDragReleased: (slot, was) => topBarWindow.endSlotDrag(slot, was)
                                    onDragCanceled: topBarWindow.cancelSlotDrag()
                                }
                            }

                        }
                    }
                    Item { Layout.fillHeight: true }
                    Item {
                        id: vTwoFifthsWrap
                        Layout.fillWidth: true
                        implicitHeight: vTwoFifthsCol.implicitHeight + ((topBarWindow.isIsland || Theme.barModuleBackground || Theme.barContentPadding > 0) ? 14 : 0)
                        Layout.minimumHeight: (topBarScope.dragActive && topBarScope.twoFifthsGapEmpty && topBarWindow.isVertical) ? 110 : 0
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            anchors.fill: parent
                            visible: (topBarWindow.isIsland || Theme.barModuleBackground) && (vTwoFifthsCol.implicitHeight > 0 || (topBarScope.dragActive && topBarScope.twoFifthsGapEmpty))
                            radius: Math.min(Theme.cornerRadius, width / 2)
                            color: {
                                if (topBarWindow.barOpacity >= 0.999) return topBarWindow.isIsland ? Theme.panelBg : Theme.cardBg
                                let a = Math.max(0, Math.min(1, topBarWindow.barOpacity * Theme.panelBgAlpha))
                                let base = topBarWindow.isIsland ? Theme.bg : Theme.surface_container_high
                                return Theme.withAlpha(base, a)
                            }
                        }
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            id: vTwoFifthsDot
                            width: 10; height: width; radius: width / 2
                            anchors.centerIn: parent
                            color: Theme.accent
                            visible: topBarWindow.isVertical && topBarScope.dragActive && topBarScope.twoFifthsGapEmpty
                        }
                        ColumnLayout {
                            id: vTwoFifthsCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.barModuleSpacing
                            Repeater {
                                model: Theme.barLayoutTwoFifths
                                Bar.DraggableModule {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    moduleId: modelData
                                    active: topBarScope.moduleActive(modelData)
                                    section: "twofifths"
                                    modIndex: index
                                    vertical: true
                                    monitor: topBarWindow.modelData
                                    barPos: topBarWindow.barPos
                                    barWindow: topBarWindow
                                    anchorActive: topBarWindow.isVertical
                                    isSource: topBarScope.dragSourceId === modelData

                                    onRequestMenu: topBarScope.toggleMenu()
                                    onRequestCalendar: topBarScope.toggleCalendar()
                                    onRequestWeather: topBarScope.toggleWeather()
                                    onRequestUpdates: topBarScope.openUpdates()
                                    onRequestCC: topBarScope.toggleControlCenter()
                                    onRequestMedia: topBarScope.toggleMedia()
                                    onRequestNetwork: topBarScope.toggleNetwork()
                                    onRequestVolume: topBarScope.toggleVolume()
                                    onRequestBluetooth: topBarScope.toggleBluetooth()
                                    onRequestVitals: topBarScope.toggleVitals()
                                    onRequestSystemTray: topBarScope.toggleSystemTray()
                                    onRequestNotif: topBarScope.toggleNotif()
                                    onHideRequest: topBarScope.closePanel(modelData)
                                    onPressBegun: topBarWindow.clearDrag()
                                    onThresholdPassed: (slot, x, y) => topBarWindow.startSlotDrag(slot, x, y)
                                    onDragMoved: (slot, x, y) => topBarWindow.moveSlotDrag(slot, x, y)
                                    onDragReleased: (slot, was) => topBarWindow.endSlotDrag(slot, was)
                                    onDragCanceled: topBarWindow.cancelSlotDrag()
                                }
                            }

                        }
                    }
                    Item { Layout.fillHeight: true }
                    Item {
                        id: vMidWrap
                        Layout.fillWidth: true
                        implicitHeight: vMidCol.implicitHeight + ((topBarWindow.isIsland || Theme.barModuleBackground || Theme.barContentPadding > 0) ? 14 : 0)
                        Layout.minimumHeight: (topBarScope.dragActive && topBarScope.middleGapEmpty && topBarWindow.isVertical) ? 110 : 0
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            anchors.fill: parent
                            visible: (topBarWindow.isIsland || Theme.barModuleBackground) && (vMidCol.implicitHeight > 0 || (topBarScope.dragActive && topBarScope.middleGapEmpty))
                            radius: Math.min(Theme.cornerRadius, width / 2)
                            color: {
                                if (topBarWindow.barOpacity >= 0.999) return topBarWindow.isIsland ? Theme.panelBg : Theme.cardBg
                                let a = Math.max(0, Math.min(1, topBarWindow.barOpacity * Theme.panelBgAlpha))
                                let base = topBarWindow.isIsland ? Theme.bg : Theme.surface_container_high
                                return Theme.withAlpha(base, a)
                            }
                        }
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            id: vMidDot
                            width: 10; height: width; radius: width / 2
                            anchors.centerIn: parent
                            color: Theme.accent
                            visible: topBarWindow.isVertical && topBarScope.dragActive && topBarScope.middleGapEmpty
                        }
                        ColumnLayout {
                            id: vMidCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.barModuleSpacing
                            Repeater {
                                model: Theme.barLayoutCenter
                                Bar.DraggableModule {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    moduleId: modelData
                                    active: topBarScope.moduleActive(modelData)
                                    section: "center"
                                    modIndex: index
                                    vertical: true
                                    monitor: topBarWindow.modelData
                                    barPos: topBarWindow.barPos
                                    barWindow: topBarWindow
                                    anchorActive: topBarWindow.isVertical
                                    isSource: topBarScope.dragSourceId === modelData

                                    onRequestMenu: topBarScope.toggleMenu()
                                    onRequestCalendar: topBarScope.toggleCalendar()
                                    onRequestWeather: topBarScope.toggleWeather()
                                    onRequestUpdates: topBarScope.openUpdates()
                                    onRequestCC: topBarScope.toggleControlCenter()
                                    onRequestMedia: topBarScope.toggleMedia()
                                    onRequestNetwork: topBarScope.toggleNetwork()
                                    onRequestVolume: topBarScope.toggleVolume()
                                    onRequestBluetooth: topBarScope.toggleBluetooth()
                                    onRequestVitals: topBarScope.toggleVitals()
                                    onRequestSystemTray: topBarScope.toggleSystemTray()
                                    onRequestNotif: topBarScope.toggleNotif()
                                    onHideRequest: topBarScope.closePanel(modelData)
                                    onPressBegun: topBarWindow.clearDrag()
                                    onThresholdPassed: (slot, x, y) => topBarWindow.startSlotDrag(slot, x, y)
                                    onDragMoved: (slot, x, y) => topBarWindow.moveSlotDrag(slot, x, y)
                                    onDragReleased: (slot, was) => topBarWindow.endSlotDrag(slot, was)
                                    onDragCanceled: topBarWindow.cancelSlotDrag()
                                }
                            }

                        }
                    }
                    Item { Layout.fillHeight: true }
                    Item {
                        id: vFourFifthsWrap
                        Layout.fillWidth: true
                        implicitHeight: vFourFifthsCol.implicitHeight + ((topBarWindow.isIsland || Theme.barModuleBackground || Theme.barContentPadding > 0) ? 14 : 0)
                        Layout.minimumHeight: (topBarScope.dragActive && topBarScope.fourFifthsGapEmpty && topBarWindow.isVertical) ? 110 : 0
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            anchors.fill: parent
                            visible: (topBarWindow.isIsland || Theme.barModuleBackground) && (vFourFifthsCol.implicitHeight > 0 || (topBarScope.dragActive && topBarScope.fourFifthsGapEmpty))
                            radius: Math.min(Theme.cornerRadius, width / 2)
                            color: {
                                if (topBarWindow.barOpacity >= 0.999) return topBarWindow.isIsland ? Theme.panelBg : Theme.cardBg
                                let a = Math.max(0, Math.min(1, topBarWindow.barOpacity * Theme.panelBgAlpha))
                                let base = topBarWindow.isIsland ? Theme.bg : Theme.surface_container_high
                                return Theme.withAlpha(base, a)
                            }
                        }
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            id: vFourFifthsDot
                            width: 10; height: width; radius: width / 2
                            anchors.centerIn: parent
                            color: Theme.accent
                            visible: topBarWindow.isVertical && topBarScope.dragActive && topBarScope.fourFifthsGapEmpty
                        }
                        ColumnLayout {
                            id: vFourFifthsCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.barModuleSpacing
                            Repeater {
                                model: Theme.barLayoutFourFifths
                                Bar.DraggableModule {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    moduleId: modelData
                                    active: topBarScope.moduleActive(modelData)
                                    section: "fourfifths"
                                    modIndex: index
                                    vertical: true
                                    monitor: topBarWindow.modelData
                                    barPos: topBarWindow.barPos
                                    barWindow: topBarWindow
                                    anchorActive: topBarWindow.isVertical
                                    isSource: topBarScope.dragSourceId === modelData

                                    onRequestMenu: topBarScope.toggleMenu()
                                    onRequestCalendar: topBarScope.toggleCalendar()
                                    onRequestWeather: topBarScope.toggleWeather()
                                    onRequestUpdates: topBarScope.openUpdates()
                                    onRequestCC: topBarScope.toggleControlCenter()
                                    onRequestMedia: topBarScope.toggleMedia()
                                    onRequestNetwork: topBarScope.toggleNetwork()
                                    onRequestVolume: topBarScope.toggleVolume()
                                    onRequestBluetooth: topBarScope.toggleBluetooth()
                                    onRequestVitals: topBarScope.toggleVitals()
                                    onRequestSystemTray: topBarScope.toggleSystemTray()
                                    onRequestNotif: topBarScope.toggleNotif()
                                    onHideRequest: topBarScope.closePanel(modelData)
                                    onPressBegun: topBarWindow.clearDrag()
                                    onThresholdPassed: (slot, x, y) => topBarWindow.startSlotDrag(slot, x, y)
                                    onDragMoved: (slot, x, y) => topBarWindow.moveSlotDrag(slot, x, y)
                                    onDragReleased: (slot, was) => topBarWindow.endSlotDrag(slot, was)
                                    onDragCanceled: topBarWindow.cancelSlotDrag()
                                }
                            }

                        }
                    }
                    Item { Layout.fillHeight: true }
                    Item {
                        id: vBottomWrap
                        Layout.fillWidth: true
                        implicitHeight: vBottomCol.implicitHeight + ((topBarWindow.isIsland || Theme.barModuleBackground || Theme.barContentPadding > 0) ? 14 : 0)
                        Layout.minimumHeight: (topBarScope.dragActive && topBarScope.rightGapEmpty && topBarWindow.isVertical) ? 96 : 0
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            anchors.fill: parent
                            visible: (topBarWindow.isIsland || Theme.barModuleBackground) && (vBottomCol.implicitHeight > 0 || (topBarScope.dragActive && topBarScope.rightGapEmpty))
                            radius: Math.min(Theme.cornerRadius, width / 2)
                            color: {
                                if (topBarWindow.barOpacity >= 0.999) return topBarWindow.isIsland ? Theme.panelBg : Theme.cardBg
                                let a = Math.max(0, Math.min(1, topBarWindow.barOpacity * Theme.panelBgAlpha))
                                let base = topBarWindow.isIsland ? Theme.bg : Theme.surface_container_high
                                return Theme.withAlpha(base, a)
                            }
                        }
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            id: vBottomDot
                            width: 10; height: width; radius: width / 2
                            anchors.centerIn: parent
                            color: Theme.accent
                            visible: topBarWindow.isVertical && topBarScope.dragActive && topBarScope.rightGapEmpty
                        }
                        ColumnLayout {
                            id: vBottomCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.barModuleSpacing
                            Repeater {
                                model: Theme.barLayoutRight
                                Bar.DraggableModule {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    moduleId: modelData
                                    active: topBarScope.moduleActive(modelData)
                                    section: "right"
                                    modIndex: index
                                    vertical: true
                                    monitor: topBarWindow.modelData
                                    barPos: topBarWindow.barPos
                                    barWindow: topBarWindow
                                    anchorActive: topBarWindow.isVertical
                                    isSource: topBarScope.dragSourceId === modelData

                                    onRequestMenu: topBarScope.toggleMenu()
                                    onRequestCalendar: topBarScope.toggleCalendar()
                                    onRequestWeather: topBarScope.toggleWeather()
                                    onRequestUpdates: topBarScope.openUpdates()
                                    onRequestCC: topBarScope.toggleControlCenter()
                                    onRequestMedia: topBarScope.toggleMedia()
                                    onRequestNetwork: topBarScope.toggleNetwork()
                                    onRequestVolume: topBarScope.toggleVolume()
                                    onRequestBluetooth: topBarScope.toggleBluetooth()
                                    onRequestVitals: topBarScope.toggleVitals()
                                    onRequestSystemTray: topBarScope.toggleSystemTray()
                                    onRequestNotif: topBarScope.toggleNotif()
                                    onHideRequest: topBarScope.closePanel(modelData)
                                    onPressBegun: topBarWindow.clearDrag()
                                    onThresholdPassed: (slot, x, y) => topBarWindow.startSlotDrag(slot, x, y)
                                    onDragMoved: (slot, x, y) => topBarWindow.moveSlotDrag(slot, x, y)
                                    onDragReleased: (slot, was) => topBarWindow.endSlotDrag(slot, was)
                                    onDragCanceled: topBarWindow.cancelSlotDrag()
                                }
                            }

                        }
                    }
                }
            }

        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: topBarScope.dragActive && modelData.name === "DP-1"
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "jhqs-bar-drag"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }
            mask: Region { }
            Item {
                visible: topBarScope.dragImageUrl !== ""
                x: Math.round(topBarScope.dragGhostX - topBarScope.dragOffsetX)
                y: Math.round(topBarScope.dragGhostY - topBarScope.dragOffsetY)
                width: topBarScope.dragGhostW
                height: topBarScope.dragGhostH
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.fill: parent
                    radius: Theme.cornerRadiusSmall
                    color: Theme.bgSelected
                    border.color: Theme.accent
                    border.width: 1
                    opacity: 0.94
                }
                Image {
                    smooth: Theme.imageSmooth
                    mipmap: Theme.imageMipmap
                    anchors.fill: parent
                    anchors.margins: 3
                    source: topBarScope.dragImageUrl
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    sourceSize.width: 256
                    sourceSize.height: 256
                    opacity: 0.9
                }
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                visible: topBarScope.dragActive && topBarScope.dragMarker !== null
                x: topBarScope.dragMarker ? Math.round(topBarScope.dragMarker.x) : 0
                y: topBarScope.dragMarker ? Math.round(topBarScope.dragMarker.y) : 0
                width: topBarScope.dragMarker ? topBarScope.dragMarker.width : 0
                height: topBarScope.dragMarker ? topBarScope.dragMarker.height : 0
                color: Theme.accent
                radius: Math.min(width, height) / 2
            }
        }
    }
}
