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
    property var monitor: null

    readonly property int extent: 26
    readonly property int iconPx: 16
    readonly property int chevronPx: 26
    readonly property int drawerDur: Math.max(1, Math.round(600 * Theme.animationScale))

    property bool hoverExpand: false
    property bool touchExpand: false
    readonly property bool expanded: hoverExpand || touchExpand
    property real revealProgress: expanded ? 1 : 0
    Behavior on revealProgress { NumberAnimation { duration: root.drawerDur; easing.type: Theme.easingStandard } }

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
            let blockH = root.drawerBlockH
            if (y < blockH && root.rawItems.length > 0) {
                if (y < root.chevronPx) {
                    if (button === Qt.RightButton) root.requestManage()
                    else if (button === Qt.LeftButton) root.touchExpand = !root.expanded
                    return
                }
                if (root.revealProgress > 0.5) {
                    let i = Math.floor((y - root.chevronPx) / root.extent)
                    if (i >= 0 && i < root.drawerCount) {
                        iconClick(root.drawerItems[i], vDrawerRepeater.itemAt(i), button)
                        return
                    }
                }
                return
            }
            let j = Math.floor((y - blockH) / root.extent)
            if (j >= 0 && j < root.pinnedItems.length) iconClick(root.pinnedItems[j], vPinnedRepeater.itemAt(j), button)
            return
        }
        let blockW = root.drawerBlockW
        if (x < blockW && root.rawItems.length > 0) {
            if (x < root.chevronPx) {
                if (button === Qt.RightButton) root.requestManage()
                else if (button === Qt.LeftButton) root.touchExpand = !root.expanded
                return
            }
            if (root.revealProgress > 0.5) {
                let i = Math.floor((x - root.chevronPx) / root.extent)
                if (i >= 0 && i < root.drawerCount) {
                    iconClick(root.drawerItems[i], hDrawerRepeater.itemAt(i), button)
                    return
                }
            }
            return
        }
        let j = Math.floor((x - blockW) / root.extent)
        if (j >= 0 && j < root.pinnedItems.length) iconClick(root.pinnedItems[j], hPinnedRepeater.itemAt(j), button)
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
        Item {
            id: hDrawerArea
            x: 0; y: Math.round((hWrap.height - root.extent) / 2)
            width: root.drawerBlockW
            height: root.extent
            visible: root.rawItems.length > 0
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                x: 0
                y: 0
                width: root.chevronPx
                height: root.extent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.expanded ? "›" : "‹"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(12)
                color: Theme.textSecondary
            }
            Item {
                x: root.chevronPx
                y: 0
                width: Math.round(root.revealExtent)
                height: root.extent
                clip: true
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
        }
        Row {
            x: root.drawerBlockW
            y: Math.round((hWrap.height - root.extent) / 2)
            spacing: 0
            Repeater {
                id: hPinnedRepeater
                model: root.pinnedItems
                delegate: TraySlot { vertical: false; slotIndex: index }
            }
        }
    }

    Item {
        id: vWrap
        visible: root.vertical
        anchors.fill: parent
        Item {
            id: vDrawerArea
            x: Math.round((vWrap.width - root.extent) / 2); y: 0
            width: root.extent
            height: root.drawerBlockH
            visible: root.rawItems.length > 0
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                x: 0
                y: 0
                width: root.extent
                height: root.chevronPx
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.expanded ? "›" : "‹"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(12)
                rotation: 90
                color: Theme.textSecondary
            }
            Item {
                x: 0
                y: root.chevronPx
                width: root.extent
                height: Math.round(root.revealExtent)
                clip: true
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
        }
        Column {
            x: Math.round((vWrap.width - root.extent) / 2)
            y: root.drawerBlockH
            spacing: 0
            Repeater {
                id: vPinnedRepeater
                model: root.pinnedItems
                delegate: TraySlot { vertical: true; slotIndex: index }
            }
        }
    }

    component TraySlot: Item {
        id: traySlot
        required property var modelData
        property bool vertical: false
        property int slotIndex: 0
        width: root.extent
        height: root.extent
        property bool entered: false
        opacity: entered ? 1 : 0
        transform: Translate {
            x: !traySlot.vertical && !traySlot.entered ? -10 : 0
            y: traySlot.vertical && !traySlot.entered ? -10 : 0
            Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            Behavior on y { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        Timer {
            id: enterTimer
            interval: Math.min(traySlot.slotIndex, 8) * Theme.animStagger
            repeat: false
            onTriggered: traySlot.entered = true
        }
        Component.onCompleted: enterTimer.restart()
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
                sourceSize.width: Math.round(root.iconPx * Screen.devicePixelRatio)
                sourceSize.height: Math.round(root.iconPx * Screen.devicePixelRatio)
                source: String(traySlot.modelData.icon || "")
                asynchronous: true
                cache: true
                visible: !root.iconIsSymbolic(traySlot.modelData.icon)
                onStatusChanged: if (status === Image.Error) source = ""
            }
            MultiEffect {
                anchors.fill: parent
                source: slotImg
                visible: root.iconIsSymbolic(traySlot.modelData.icon)
                colorization: 1.0
                colorizationColor: Theme.textPrimary
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
