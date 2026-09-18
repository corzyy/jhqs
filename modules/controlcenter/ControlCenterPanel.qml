pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import "../../themes"
import "../../services"
import "../../Ui"

Scope {
    id: scope

    property bool showControlCenter: false
    signal dismissed()
    signal settingsRequested()
    signal powerRequested()
    // Opens the audio drill-in panel (shell.qml panel.audio): the card morphs
    // into the audio panel and back.
    signal audioRequested()
    // Opens the bluetooth drill-in panel (shell.qml panel.bluetoothMenu),
    // same morph handoff.
    signal bluetoothRequested()
    // Opens the updates drill-in panel (shell.qml panel.updatesMenu), same
    // morph handoff.
    signal updatesRequested()

    property bool editing: false

    property bool _winVisible: showControlCenter
    Timer {
        id: hideTimer
        interval: Theme.panelHideDelay
        repeat: false
        onTriggered: if (!scope.showControlCenter) scope._winVisible = false
    }
    onShowControlCenterChanged: {
        if (showControlCenter) {
            _winVisible = true
            hideTimer.stop()
        } else {
            editing = false
            hideTimer.restart()
        }
    }

    readonly property string barPos: Theme.barPosition
    property int panelGap: -(Theme.barThickness + Theme.panelAttachOverlap)

    // Hidden tiles persist in config/controlcenter.json (hiddenTiles array)
    // so a hide survives closing/reopening the panel.
    function hiddenTileIds(): var {
        let out = []
        try {
            let v = ccLayoutFile.adapter.hiddenTiles
            if (v && typeof v.length === "number") {
                for (let i = 0; i < v.length; i++) {
                    let id = "" + v[i]
                    if (ccTileIds.indexOf(id) >= 0 && out.indexOf(id) < 0) out.push(id)
                }
            }
        } catch (e) { }
        return out
    }
    function tileHidden(id: string): bool { return hiddenTileIds().indexOf(id) >= 0 }
    function tileVisible(id: string): bool { return editing || !tileHidden(id) }
    function toggleTile(id: string): void {
        let h = hiddenTileIds()
        let i = h.indexOf(id)
        if (i >= 0) h.splice(i, 1)
        else h.push(id)
        ccLayoutFile.adapter.hiddenTiles = h
        ccLayoutFile.writeAdapter()
    }

    // Edit mode: the panel's reorderable sections (see moveBlock) and the
    // tiles inside the tiles block (order + 2x1/1x1 width per tile, see
    // tileCols/toggleTileCols). All of it persists in
    // config/controlcenter.json so a dragged layout survives restarts;
    // unknown/missing ids fall back to the default order.
    readonly property var ccBlockIds: ["tiles", "sliders", "media"]
    readonly property var ccTileIds: ["wifi", "bluetooth", "dnd", "updates"]
    FileView {
        id: ccLayoutFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/controlcenter.json"
        watchChanges: true; onFileChanged: ccReloadTimer.restart(); blockLoading: true; printErrors: false
        adapter: JsonAdapter {
            property var blocks: ["tiles", "sliders", "media"]
            property var tiles: ["wifi", "bluetooth", "dnd", "updates"]
            property var tileCols: ({})
            property var hiddenTiles: []
        }
    }
    // Debounce: our own writeAdapter() triggers the watcher; reloading the
    // just-written file mid-drag would momentarily revert the adapter.
    Timer {
        id: ccReloadTimer
        interval: 300; repeat: false
        onTriggered: { try { ccLayoutFile.reload() } catch (e) { } }
    }
    function sanitizeCcBlocks(v: var): var {
        let out = []
        try {
            if (v !== null && v !== undefined && typeof v.length === "number") {
                for (let i = 0; i < v.length; i++) {
                    let id = "" + v[i]
                    if (ccBlockIds.indexOf(id) >= 0 && out.indexOf(id) < 0) out.push(id)
                }
            }
        } catch (e) {}
        for (let i = 0; i < ccBlockIds.length; i++) if (out.indexOf(ccBlockIds[i]) < 0) out.push(ccBlockIds[i])
        return out
    }
    readonly property var ccBlocks: sanitizeCcBlocks(ccLayoutFile.adapter.blocks)
    function setCcBlocks(arr: var): void {
        ccLayoutFile.adapter.blocks = arr
        ccLayoutFile.writeAdapter()
    }
    function moveBlock(from: int, to: int): void {
        let arr = ccBlocks.slice()
        if (from < 0 || from >= arr.length) return
        let target = Math.max(0, Math.min(to, arr.length - 1))
        if (target === from) return
        let block = arr.splice(from, 1)[0]
        arr.splice(target, 0, block)
        setCcBlocks(arr)
    }

    function sanitizeTileOrder(v: var): var {
        let out = []
        try {
            if (v !== null && v !== undefined && typeof v.length === "number") {
                for (let i = 0; i < v.length; i++) {
                    let id = "" + v[i]
                    if (ccTileIds.indexOf(id) >= 0 && out.indexOf(id) < 0) out.push(id)
                }
            }
        } catch (e) {}
        for (let i = 0; i < ccTileIds.length; i++) if (out.indexOf(ccTileIds[i]) < 0) out.push(ccTileIds[i])
        return out
    }
    readonly property var ccTileOrder: sanitizeTileOrder(ccLayoutFile.adapter.tiles)
    function moveTile(from: int, to: int): void {
        let arr = ccTileOrder.slice()
        if (from < 0 || from >= arr.length) return
        let target = Math.max(0, Math.min(to, arr.length - 1))
        if (target === from) return
        let tile = arr.splice(from, 1)[0]
        arr.splice(target, 0, tile)
        ccLayoutFile.adapter.tiles = arr
        ccLayoutFile.writeAdapter()
    }
    // Column span: 2 = 2x1 (half width, the default), 1 = 1x1 (compact
    // quarter-width tile, icon only).
    function tileCols(id: string): int {
        try {
            let m = ccLayoutFile.adapter.tileCols
            if (m && typeof m === "object") {
                if (m[id] === 1) return 1
                if (m[id] === 2) return 2
            }
        } catch (e) { }
        return 2
    }
    function setTileCols(id: string, cols: int): void {
        let m = {}
        try {
            let cur = ccLayoutFile.adapter.tileCols
            for (let k in cur) m[k] = cur[k]
        } catch (e) { }
        m[id] = cols === 1 ? 1 : 2
        ccLayoutFile.adapter.tileCols = m
        ccLayoutFile.writeAdapter()
    }
    function toggleTileCols(id: string): void { setTileCols(id, tileCols(id) === 2 ? 1 : 2) }

    // Tile metadata (the tiles block renders ccTileOrder through these).
    function tileGlyph(id: string): string {
        if (id === "wifi") return NetworkService.icon
        if (id === "bluetooth") return BluetoothService.icon
        if (id === "dnd") return "󰂛"
        if (id === "updates") return "󰚰"
        return "󰝚"
    }
    function tileTitle(id: string): string {
        if (id === "wifi") return "WLAN"
        if (id === "bluetooth") return "Bluetooth"
        if (id === "dnd") return "Nicht stören"
        if (id === "updates") return "Updates"
        return id
    }
    function tileStatus(id: string): string {
        if (id === "wifi") return wifiStatus()
        if (id === "bluetooth") return bluetoothStatus()
        if (id === "dnd") return Theme.dndEnabled ? "An" : "Aus"
        if (id === "updates") return UpdateService.displayCount > 0 ? UpdateService.displayCount + " verfügbar" : "Aktuell"
        return ""
    }
    function tileActive(id: string): bool {
        if (id === "wifi") return NetworkService.wifiEnabled
        if (id === "bluetooth") return BluetoothService.btActive
        if (id === "dnd") return Theme.dndEnabled
        if (id === "updates") return UpdateService.hasUpdates
        return false
    }
    function tileAction(id: string): void {
        if (id === "wifi") NetworkService.toggleWifi()
        // Tile opens the bluetooth menu (Android QS style); power lives on
        // the switch inside the drill-in and on bar middle/right-click.
        else if (id === "bluetooth") scope.bluetoothRequested()
        else if (id === "dnd") Theme.toggleDnd()
        // Update tile opens the update center as its own drill-in panel
        // (shell.qml panel.updatesMenu), same as bluetooth/audio.
        else if (id === "updates") scope.updatesRequested()
    }

    // Drag state for edit mode. The dragged block follows the pointer via a
    // Translate (layout untouched), the drop math runs against the stable
    // positioner y values of all blocks.
    property bool blockDragActive: false
    property int blockDragIndex: -1
    property int blockDropIndex: -1
    property real blockDragDelta: 0
    property real blockDragStartY: 0
    function beginBlockDrag(index: int, pointerY: real): void {
        blockDragActive = true
        blockDragIndex = index
        blockDropIndex = index
        blockDragStartY = pointerY
        blockDragDelta = 0
    }
    // delta/dropIndex are computed by the delegate: only it can see the
    // block repeater (id scoping — a scope-level lookup would be undefined).
    function updateBlockDrag(deltaY: real, dropIndex: int): void {
        if (!blockDragActive) return
        blockDragDelta = deltaY
        blockDropIndex = dropIndex
    }
    function endBlockDrag(): void {
        if (!blockDragActive) return
        let from = blockDragIndex
        let boundary = blockDropIndex
        cancelBlockDrag()
        if (boundary < 0) return
        // Dropping below its own slot shifts the insert position by one
        // (the block is removed from the list before re-inserting).
        moveBlock(from, boundary > from ? boundary - 1 : boundary)
    }
    function cancelBlockDrag(): void {
        blockDragActive = false
        blockDragIndex = -1
        blockDropIndex = -1
        blockDragDelta = 0
    }

    readonly property var battery: UPower.displayDevice
    readonly property bool batteryVisible: battery !== null && battery.ready && battery.isPresent
    readonly property int batteryPct: batteryVisible ? Math.round(battery.percentage * 100) : 0
    readonly property bool batteryCharging: batteryVisible
        && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged)

    function batteryGlyph(pct: int, charging: bool): string {
        if (charging) return "󰂄"
        if (pct >= 90) return "󰁹"
        if (pct >= 80) return "󰂁"
        if (pct >= 60) return "󰁿"
        if (pct >= 40) return "󰁽"
        if (pct >= 20) return "󰁻"
        return "󰂃"
    }

    readonly property int btConnected: BluetoothService.connectedDevs ? BluetoothService.connectedDevs.length : 0

    function wifiStatus(): string {
        if (!NetworkService.wifiEnabled) return "Aus"
        if (!NetworkService.netActive) return "Kein Netz"
        if (NetworkService.activeType === "ethernet") return NetworkService.ssid !== "" ? NetworkService.ssid : "Ethernet"
        return NetworkService.ssid !== "" ? NetworkService.ssid : "Verbunden"
    }
    function bluetoothStatus(): string {
        if (!BluetoothService.btActive) return "Aus"
        if (btConnected > 0) return btConnected + (btConnected === 1 ? " Gerät" : " Geräte")
        return "An"
    }

    component HeaderStatusIcon: Text {
        color: Theme.textPrimary
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.fs(16)
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
        verticalAlignment: Text.AlignVCenter
    }

    component FooterButton: Item {
        id: footerButton
        property string glyph
        property bool emphasized: false
        signal clicked()
        implicitWidth: 42
        implicitHeight: 42

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadiusSmall
            antialiasing: Theme.shapesAa
            color: "transparent"

            Text {
                anchors.centerIn: parent
                text: footerButton.glyph
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(18)
                color: footerButton.emphasized ? Theme.primary : (footerMouse.containsMouse ? Theme.primary : Theme.textPrimary)
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType

                Behavior on color {
                    enabled: Theme.animationsEnabled
                    ColorAnimation { duration: Theme.durSlowEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSlowEffects }
                }
            }
        }

        StateLayer {
            id: footerMouse
            radius: Theme.cornerRadiusSmall
            color: footerButton.emphasized ? Theme.primary : Theme.textPrimary
            onClicked: footerButton.clicked()
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: scope._winVisible && Theme.isPrimaryScreen(modelData)
            color: "transparent"
            exclusiveZone: 0
            anchors { top: true; left: true; right: true; bottom: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "controlcenterpanel"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        scope.dismissed()
                        event.accepted = true
                    }
                }
                Component.onCompleted: forceActiveFocus()
            }

            // Disabled while the panel is closing: during a morph handoff
            // the outgoing window stays mapped for panelHideDelay and must
            // not eat the click that belongs to the panel now on top.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                enabled: scope.showControlCenter
                onClicked: scope.dismissed()
            }

            PanelShell {
                moduleId: "controlcenter"
                screenActive: Theme.isPrimaryScreen(modelData)
                barPos: scope.barPos
                panelGap: scope.panelGap
                shown: scope.showControlCenter
                boxWidth: 360
                contentSpacing: 12

                // Header: settings / edit / session buttons (moved up from the
                // footer) with the battery tucked in before the session button
                // on machines that have one.
                RowLayout {
                    width: parent.width
                    spacing: 6

                    FooterButton {
                        glyph: "󰒓"
                        onClicked: scope.settingsRequested()
                    }
                    FooterButton {
                        glyph: scope.editing ? "󰄬" : "󰏫"
                        emphasized: scope.editing
                        onClicked: scope.editing = !scope.editing
                    }
                    Item { Layout.fillWidth: true }

                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        visible: scope.batteryVisible
                        spacing: 4
                        HeaderStatusIcon { text: scope.batteryGlyph(scope.batteryPct, scope.batteryCharging) }
                        Text {
                            text: scope.batteryPct + "%"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                            font.weight: Font.Medium
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                    }

                    FooterButton {
                        glyph: "󰐥"
                        emphasized: true
                        onClicked: scope.powerRequested()
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: 8
                    // Edit chrome enters/exits within the screen: M3 fade
                    // (enter emphasized decelerate, exit emphasized accelerate).
                    opacity: scope.editing ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity {
                        enabled: Theme.animationsEnabled
                        NumberAnimation {
                            duration: scope.editing ? Theme.durSlowEffects : Theme.durFastEffects
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: scope.editing ? Theme.curveEmphasizedDecelerate : Theme.curveEmphasizedAccelerate
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Layout bearbeiten"
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(13)
                        font.weight: Font.Medium
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Text {
                        text: "Ziehen sortiert · Tippen blendet aus"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(11)
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                }

                // Reorderable sections (edit mode): one delegate per block id
                // in stored order. Dragging happens on the block handle and
                // moves the section with a Translate; the drop line shows
                // where it lands. Must stay named "blocksRepeater" (drop math).
                Repeater {
                    id: blocksRepeater
                    model: scope.ccBlocks
                    delegate: Item {
                        id: blockItem
                        required property string modelData
                        required property int index

                        readonly property bool dragging: scope.blockDragActive && scope.blockDragIndex === blockItem.index
                        readonly property bool dropBefore: scope.blockDragActive && !dragging && scope.blockDropIndex === blockItem.index
                        readonly property bool dropAfter: scope.blockDragActive && !dragging && blockItem.index === blocksRepeater.count - 1 && scope.blockDropIndex === blocksRepeater.count

                        // First block whose vertical center is below the pointer;
                        // count = drop past the last block (delegate-local:
                        // blocksRepeater is only visible in this scope).
                        function dropBoundaryAt(pointerY: real): int {
                            for (let i = 0; i < blocksRepeater.count; i++) {
                                let it = blocksRepeater.itemAt(i)
                                if (!it) continue
                                if (pointerY < it.y + it.height / 2) return i
                            }
                            return blocksRepeater.count
                        }

                        width: parent.width
                        height: blockLoader.implicitHeight
                        z: dragging ? 100 : 0
                        transform: Translate { y: blockItem.dragging ? scope.blockDragDelta : 0 }

                        Loader {
                            id: blockLoader
                            width: parent.width
                            sourceComponent: blockItem.modelData === "tiles" ? tilesBlockComp
                                : blockItem.modelData === "sliders" ? slidersBlockComp
                                : mediaBlockComp
                        }

                        // Drop indicator at the block edge the drag currently
                        // targets (the trailing edge gets its own line).
                        Rectangle {
                            visible: blockItem.dropBefore
                            anchors.top: parent.top
                            anchors.topMargin: -6
                            width: parent.width
                            height: 3
                            radius: height / 2
                            color: Theme.accent
                            antialiasing: Theme.shapesAa
                        }
                        Rectangle {
                            visible: blockItem.dropAfter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: -6
                            width: parent.width
                            height: 3
                            radius: height / 2
                            color: Theme.accent
                            antialiasing: Theme.shapesAa
                        }

                        // Drag handle: floats in the gap above each section so
                        // it never covers tile/slider content.
                        Rectangle {
                            id: blockHandle
                            // M3 fade in/out with the edit-mode chrome.
                            opacity: scope.editing ? 1 : 0
                            visible: opacity > 0.01
                            width: 46
                            height: 16
                            radius: height / 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: -6
                            z: 60
                            color: blockHandleMouse.containsMouse || blockItem.dragging ? Theme.primary : Theme.surface_container_highest
                            border.width: 1
                            border.color: blockItem.dragging ? Theme.primary : Theme.outline_variant
                            antialiasing: Theme.shapesAa

                            Behavior on color {
                                enabled: Theme.animationsEnabled
                                ColorAnimation { duration: Theme.durSlowEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSlowEffects }
                            }
                            Behavior on opacity {
                                enabled: Theme.animationsEnabled
                                NumberAnimation {
                                    duration: scope.editing ? Theme.durSlowEffects : Theme.durFastEffects
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: scope.editing ? Theme.curveEmphasizedDecelerate : Theme.curveEmphasizedAccelerate
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰇝"
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(10)
                                color: blockHandleMouse.containsMouse || blockItem.dragging ? Theme.on_primary : Theme.textMuted
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }

                            MouseArea {
                                id: blockHandleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.SizeVerCursor
                                preventStealing: true
                                onPressed: mouse => {
                                    let p = blockItem.mapToItem(blockItem.parent, mouse.x, mouse.y)
                                    scope.beginBlockDrag(blockItem.index, p.y)
                                }
                                onPositionChanged: mouse => {
                                    if (!scope.blockDragActive) return
                                    let p = blockItem.mapToItem(blockItem.parent, mouse.x, mouse.y)
                                    scope.updateBlockDrag(p.y - scope.blockDragStartY, blockItem.dropBoundaryAt(p.y))
                                }
                                onReleased: scope.endBlockDrag()
                                onCanceled: scope.cancelBlockDrag()
                            }
                        }
                    }
                }

            }
        }
    }

    // Tiles block: one delegate per tile in the stored order. In edit mode
    // each tile carries a grip (drag to reorder within the grid, drop lands on
    // the tile under the pointer) and a circular 2x1/2x2 resize button.
    Component {
        id: tilesBlockComp
        GridLayout {
            id: tilesGrid
            width: parent.width
            // 4 columns: a normal tile spans two (halfwidth, 2x1), the
            // compact size spans one (quarter width, 1x1).
            columns: 4
            columnSpacing: 10
            rowSpacing: 10

            // Drag state local to the tile area.
            property int dragIndex: -1
            property int dropIndex: -1
            property real dragDX: 0
            property real dragDY: 0
            property real pressX: 0
            property real pressY: 0
            readonly property bool dragActive: dragIndex >= 0

            function tileAt(px: real, py: real): int {
                for (let i = 0; i < tilesRepeater.count; i++) {
                    let it = tilesRepeater.itemAt(i)
                    if (!it || !it.visible || it.width <= 0 || it.height <= 0) continue
                    if (px >= it.x && px <= it.x + it.width && py >= it.y && py <= it.y + it.height) return i
                }
                return -1
            }
            function beginTileDrag(index: int, px: real, py: real): void {
                dragIndex = index
                dropIndex = index
                pressX = px
                pressY = py
                dragDX = 0
                dragDY = 0
            }
            function updateTileDrag(px: real, py: real): void {
                if (!dragActive) return
                dragDX = px - pressX
                dragDY = py - pressY
                let over = tileAt(px, py)
                if (over >= 0) dropIndex = over
            }
            function endTileDrag(): void {
                if (!dragActive) return
                let from = dragIndex
                let to = dropIndex
                cancelTileDrag()
                if (from >= 0 && to >= 0 && from !== to) scope.moveTile(from, to)
            }
            function cancelTileDrag(): void {
                dragIndex = -1
                dropIndex = -1
                dragDX = 0
                dragDY = 0
            }

            Repeater {
                id: tilesRepeater
                model: scope.ccTileOrder
                delegate: Item {
                    id: tileItem
                    required property string modelData
                    required property int index

                    readonly property int cols: scope.tileCols(modelData)
                    readonly property bool compact: cols === 1
                    readonly property bool dragging: tilesGrid.dragIndex === index
                    readonly property bool dropTarget: tilesGrid.dragActive && tilesGrid.dropIndex === index && !dragging
                    // Explicit cell math keeps all four columns equal; the
                    // layout's fillWidth distribution skews spanned rows.
                    readonly property real cellW: (tilesGrid.width - 3 * tilesGrid.columnSpacing) / 4

                    // 2x1 = halfwidth tile (default, spans two columns);
                    // 1x1 = compact quarter-width tile, icon only.
                    Layout.columnSpan: cols
                    Layout.preferredWidth: cols * cellW + (cols - 1) * tilesGrid.columnSpacing
                    Layout.preferredHeight: 72
                    visible: scope.tileVisible(modelData)
                    z: dragging ? 50 : 0
                    transform: Translate {
                        x: tileItem.dragging ? tilesGrid.dragDX : 0
                        y: tileItem.dragging ? tilesGrid.dragDY : 0
                    }
                    opacity: dragging ? 0.9 : 1

                    QuickToggle {
                        anchors.fill: parent
                        compact: tileItem.compact
                        editing: scope.editing
                        selected: !scope.tileHidden(tileItem.modelData)
                        glyph: scope.tileGlyph(tileItem.modelData)
                        title: scope.tileTitle(tileItem.modelData)
                        status: scope.tileStatus(tileItem.modelData)
                        active: scope.tileActive(tileItem.modelData)
                        onToggled: scope.tileAction(tileItem.modelData)
                        onEditToggled: scope.toggleTile(tileItem.modelData)
                    }

                    // Drop target highlight.
                    Rectangle {
                        anchors.fill: parent
                        visible: tileItem.dropTarget
                        radius: 26
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.accent
                        antialiasing: Theme.shapesAa
                    }

                    // Drag grip (edit mode only).
                    Rectangle {
                        visible: scope.editing
                        width: 40
                        height: 16
                        radius: height / 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: -6
                        z: 60
                        color: gripMouse.containsMouse || tileItem.dragging ? Theme.primary : Theme.surface_container_highest
                        border.width: 1
                        border.color: tileItem.dragging ? Theme.primary : Theme.outline_variant
                        antialiasing: Theme.shapesAa
                        opacity: scope.editing ? 1 : 0

                        Text {
                            anchors.centerIn: parent
                            text: "󰇝"
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(10)
                            color: gripMouse.containsMouse || tileItem.dragging ? Theme.on_primary : Theme.textMuted
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }

                        MouseArea {
                            id: gripMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.SizeVerCursor
                            preventStealing: true
                            onPressed: mouse => {
                                let p = tileItem.mapToItem(tilesGrid, mouse.x, mouse.y)
                                tilesGrid.beginTileDrag(tileItem.index, p.x, p.y)
                            }
                            onPositionChanged: mouse => {
                                if (!tilesGrid.dragActive) return
                                let p = tileItem.mapToItem(tilesGrid, mouse.x, mouse.y)
                                tilesGrid.updateTileDrag(p.x, p.y)
                            }
                            onReleased: tilesGrid.endTileDrag()
                            onCanceled: tilesGrid.cancelTileDrag()
                        }
                    }

                    // Resize button (edit mode only): taps cycle 2x1 <-> 1x1,
                    // Android QS style circular badge.
                    Rectangle {
                        id: spanButton
                        visible: scope.editing
                        width: 22
                        height: 22
                        radius: width / 2
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        z: 60
                        color: Theme.surface_container_highest
                        border.width: 1
                        border.color: Theme.outline_variant
                        antialiasing: Theme.shapesAa

                        Text {
                            anchors.centerIn: parent
                            text: "󰩨"
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(13)
                            color: Theme.textPrimary
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }

                        StateLayer {
                            id: spanMouse
                            radius: Math.round(width / 2)
                            color: Theme.primary
                            onClicked: scope.toggleTileCols(tileItem.modelData)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: slidersBlockComp
        ColumnLayout {
            id: slidersBlock
            width: parent.width
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                CcSlider {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    muted: VolumeService.isMuted
                    value: Math.max(0, Math.min(1, VolumeService.pct / 100))
                    onUserMoved: v => VolumeService.setVolumeFrac(v)
                }

                // Audio drill-in: the chevron opens the audio panel, which
                // morphs out of this card and back into it (shell.qml
                // panel.audio). Same height as the slider row.
                Rectangle {
                    id: audioMenuButton
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 48
                    implicitHeight: 48
                    radius: height / 2
                    antialiasing: Theme.shapesAa
                    color: Theme.surface_container_highest
                    scale: audioMenuButtonMouse.pressed ? Theme.pressScale : 1

                    Behavior on scale {
                        enabled: Theme.animationsEnabled
                        NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅀"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fs(22)
                        color: Theme.textPrimary
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }

                    StateLayer {
                        id: audioMenuButtonMouse
                        radius: Math.round(width / 2)
                        color: Theme.textPrimary
                        onClicked: scope.audioRequested()
                    }
                }
            }
        }
    }

    Component {
        id: mediaBlockComp
        MediaPlayerCard {
            width: parent.width
        }
    }
}
