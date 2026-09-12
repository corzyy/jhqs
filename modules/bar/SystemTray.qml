pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.DBusMenu
import Quickshell.Services.SystemTray as TrayService
import "../../themes"

Item {
    id: root
    signal requestManage()
    property bool vertical: false
    // NOTE: monitor removed — never read by any delegate.

    readonly property int extent: 26
    readonly property int iconPx: 16
    readonly property int chevronPx: 26
    // PERF: 600ms layout animation drove implicitWidth/Height + x/y every
    // frame. 150ms is visually identical for a 26px reveal, 4x fewer frames.
    readonly property int drawerDur: Theme.animationsEnabled ? 150 : 1

    property bool hoverExpand: false
    property bool touchExpand: false
    readonly property bool expanded: hoverExpand || touchExpand
    property real revealProgress: expanded ? 1 : 0
    Behavior on revealProgress {
        enabled: Theme.animationsEnabled
        NumberAnimation {
            duration: root.drawerDur
            easing.type: Easing.OutCubic
        }
    }

    property var hoveredItem: null

    readonly property var rawItems: {
        let out = []
        try {
            let vals = TrayService.SystemTray.items.values
            for (let i = 0; i < vals.length; i++) {
                let it = vals[i]
                if (!it || it.status === TrayService.Status.Passive) continue
                out.push(it)
            }
        } catch (e) { }
        return out
    }
    function bucketOf(item): string {
        let iid = String((item && item.id) || "")
        if (Theme.isTrayHidden(iid)) return "hidden"
        if (Theme.isTrayPinned(iid)) return "pinned"
        return "drawer"
    }
    readonly property var trayBuckets: {
        let p = [], d = []
        let items = rawItems
        for (let i = 0; i < items.length; i++) {
            let b = ""
            try { b = bucketOf(items[i]) } catch (e) { }
            if (b === "pinned") p.push(items[i])
            else if (b === "drawer") d.push(items[i])
        }
        return { pinned: p, drawer: d }
    }
    readonly property var pinnedItems: trayBuckets.pinned
    readonly property var drawerItems: trayBuckets.drawer
    readonly property int drawerCount: drawerItems.length
    readonly property int drawerExtent: drawerCount * root.extent
    readonly property real revealExtent: drawerExtent * revealProgress
    readonly property int drawerBlockW: rawItems.length > 0 ? root.chevronPx + Math.round(revealExtent) : 0
    readonly property int drawerBlockH: rawItems.length > 0 ? root.chevronPx + Math.round(revealExtent) : 0

    implicitWidth: root.vertical ? root.extent : drawerBlockW + pinnedItems.length * root.extent
    implicitHeight: root.vertical ? drawerBlockH + pinnedItems.length * root.extent : root.extent

    function iconClick(item, anchorItem, button: int): void {
        if (!item) return
        if (button === Qt.RightButton) {
            if (item.hasMenu && anchorItem) anchorItem.openMenu()
            return
        }
        if (button === Qt.MiddleButton) {
            try { item.secondaryActivate() } catch (e) { }
            return
        }
        if (item.onlyMenu) {
            if (item.hasMenu && anchorItem) anchorItem.openMenu()
        } else {
            try { item.activate() } catch (e) { }
        }
    }
    function click(button: int, x: real, y: real): void {
        if (root.vertical) {
            let revealH = Math.round(root.revealExtent)
            let pinnedH = root.pinnedItems.length * root.extent
            if (root.rawItems.length > 0) {
                if (y < revealH) {
                    if (root.revealProgress > 0.5) {
                        let i = Math.floor(y / root.extent)
                        if (i >= 0 && i < root.drawerCount) {
                            iconClick(root.drawerItems[i], vDrawerRepeater.itemAt(i), button)
                        }
                    }
                    return
                }
            }
            if (y >= revealH && y < revealH + pinnedH) {
                let j = Math.floor((y - revealH) / root.extent)
                if (j >= 0 && j < root.pinnedItems.length) iconClick(root.pinnedItems[j], vPinnedRepeater.itemAt(j), button)
                return
            }
            if (root.rawItems.length > 0 && y >= revealH + pinnedH && y < revealH + pinnedH + root.chevronPx) {
                if (button === Qt.RightButton) root.requestManage()
                else if (button === Qt.LeftButton) root.touchExpand = !root.expanded
                return
            }
            return
        }
        let revealW = Math.round(root.revealExtent)
        let pinnedW = root.pinnedItems.length * root.extent
        if (root.rawItems.length > 0) {
            if (x < revealW) {
                if (root.revealProgress > 0.5) {
                    let i = Math.floor(x / root.extent)
                    if (i >= 0 && i < root.drawerCount) {
                        iconClick(root.drawerItems[i], hDrawerRepeater.itemAt(i), button)
                    }
                }
                return
            }
        }
        if (x >= revealW && x < revealW + pinnedW) {
            let j = Math.floor((x - revealW) / root.extent)
            if (j >= 0 && j < root.pinnedItems.length) iconClick(root.pinnedItems[j], hPinnedRepeater.itemAt(j), button)
            return
        }
        if (root.rawItems.length > 0 && x >= revealW + pinnedW && x < revealW + pinnedW + root.chevronPx) {
            if (button === Qt.RightButton) root.requestManage()
            else if (button === Qt.LeftButton) root.touchExpand = !root.expanded
            return
        }
    }
    function wheel(dy: real): bool {
        if (root.hoveredItem) {
            try { root.hoveredItem.scroll(dy, false) } catch (e) { }
            return true
        }
        return false
    }

    function iconIsSymbolic(icon): bool {
        let name = String(icon || "").split("?")[0]
        return name.slice(-9) === "-symbolic"
    }

    Item {
        id: hWrap
        visible: !root.vertical
        anchors.fill: parent
        // Order left->right: [drawer programs][pinned tray][chevron arrow].
        // Chevron sits at the trailing (right) edge so its screen position
        // stays fixed while the drawer grows leftwards; pinned stays fixed
        // in the middle for the same reason (bar is right-anchored).
        Item {
            x: 0
            y: Math.round((hWrap.height - root.extent) / 2)
            width: Math.round(root.revealExtent)
            height: root.extent
            clip: true
            visible: root.rawItems.length > 0
            Row {
                x: 0
                y: 0
                spacing: 0
                Repeater {
                    id: hDrawerRepeater
                    model: root.drawerItems
                    delegate: TraySlot { vertical: false; slotIndex: index }
                }
            }
        }
        Row {
            x: Math.round(root.revealExtent)
            y: Math.round((hWrap.height - root.extent) / 2)
            spacing: 0
            Repeater {
                id: hPinnedRepeater
                model: root.pinnedItems
                delegate: TraySlot { vertical: false; slotIndex: index }
            }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            x: Math.round(root.revealExtent) + root.pinnedItems.length * root.extent
            y: Math.round((hWrap.height - root.extent) / 2)
            width: root.chevronPx
            height: root.extent
            visible: root.rawItems.length > 0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.expanded ? "›" : "‹"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(12)
            color: Theme.textSecondary
        }
    }

    Item {
        id: vWrap
        visible: root.vertical
        anchors.fill: parent
        // Order top->bottom: [drawer programs][pinned tray][chevron arrow].
        // Chevron sits at the trailing (bottom) edge so its screen position
        // stays fixed while the drawer grows upwards; pinned stays fixed
        // in the middle (bar bottom section is bottom-anchored).
        Item {
            x: Math.round((vWrap.width - root.extent) / 2)
            y: 0
            width: root.extent
            height: Math.round(root.revealExtent)
            clip: true
            visible: root.rawItems.length > 0
            Column {
                x: 0
                y: 0
                spacing: 0
                Repeater {
                    id: vDrawerRepeater
                    model: root.drawerItems
                    delegate: TraySlot { vertical: true; slotIndex: index }
                }
            }
        }
        Column {
            x: Math.round((vWrap.width - root.extent) / 2)
            y: Math.round(root.revealExtent)
            spacing: 0
            Repeater {
                id: vPinnedRepeater
                model: root.pinnedItems
                delegate: TraySlot { vertical: true; slotIndex: index }
            }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            x: Math.round((vWrap.width - root.extent) / 2)
            y: Math.round(root.revealExtent) + root.pinnedItems.length * root.extent
            width: root.extent
            height: root.chevronPx
            visible: root.rawItems.length > 0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.expanded ? "›" : "‹"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(12)
            rotation: 90
            color: Theme.textSecondary
        }
    }

    component TraySlot: Item {
        id: traySlot
        required property var modelData
        property bool vertical: false
        property int slotIndex: 0
        width: root.extent
        height: root.extent
        opacity: 1
        // PERF: cache per-delegate so iconIsSymbolic() string split isn't
        // re-run on every revealProgress frame for every icon.
        readonly property string iconSrc: String(traySlot.modelData.icon || "")
        readonly property bool symbolic: {
            let n = iconSrc.split("?")[0]
            return n.slice(-9) === "-symbolic"
        }
        function openMenu(): void { slotMenuAnchor.open() }
        Item {
            anchors.centerIn: parent
            width: root.iconPx
            height: root.iconPx
            Image {
                smooth: Theme.imageSmooth
                mipmap: Theme.imageMipmap
                id: slotImg
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                // PERF: fixed 32px decode (was DPR-scaled, refetching all
                // icons on DPR change for 16px display).
                sourceSize.width: 32
                sourceSize.height: 32
                source: traySlot.symbolic ? "" : traySlot.iconSrc
                asynchronous: true
                cache: true
                visible: !traySlot.symbolic
                onStatusChanged: if (status === Image.Error && source !== "") source = ""
            }
            // PERF: MultiEffect is an offscreen pass per icon. Loader-gate so
            // only symbolic icons pay for it.
            Loader {
                anchors.fill: parent
                active: traySlot.symbolic
                asynchronous: true
                sourceComponent: symbolFx
            }
            Component {
                id: symbolFx
                MultiEffect {
                    source: slotImg
                    colorization: 1.0
                    colorizationColor: Theme.textPrimary
                }
            }
        }
        HoverHandler {
            onHoveredChanged: {
                if (hovered) root.hoveredItem = traySlot.modelData
                else if (root.hoveredItem === traySlot.modelData) root.hoveredItem = null
            }
        }
        QsMenuAnchor {
            id: slotMenuAnchor
            anchor.window: traySlot.QsWindow.window
            anchor.item: traySlot
            anchor.rect.x: traySlot.width / 2
            anchor.rect.y: traySlot.height
            anchor.rect.width: 1
            anchor.rect.height: 1
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Top
            anchor.margins.top: 4
            anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipX | PopupAdjustment.FlipY
            menu: traySlot.modelData ? traySlot.modelData.menu : null
        }
    }
}
