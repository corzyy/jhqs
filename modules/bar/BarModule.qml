import QtQuick
import Quickshell.Hyprland
import Quickshell.Services.SystemTray as TrayService
import "../../themes"
import "../../services"

Item {
    id: root
    signal requestMenu()
    signal requestCalendar()
    signal requestWeather()
    signal requestUpdates()
    signal requestNetwork()
    signal requestVolume()
    signal requestBluetooth()
    signal requestVitals()
    signal requestSystemTray()
    required property string moduleId
    property bool vertical: false
    // Kept for interface compat (DraggableModule assigns monitor:). Unused
    // internally — no widget reads it — but removing it would break the
    // assignment in DraggableModule.qml:116.
    property var monitor: null
    property bool slotHovered: false

    readonly property bool activeVisible: (moduleId !== "weather" || WeatherService.hasData)
                                       && (moduleId !== "systemtray" || trayCount > 0)
    readonly property int trayCount: {
        let n = 0
        try {
            let vals = TrayService.SystemTray.items.values
            for (let i = 0; i < vals.length; i++) {
                let it = vals[i]
                if (it && it.status !== TrayService.Status.Passive) n++
            }
        } catch (e) { }
        return n
    }

    function hoverAt(mx: real, my: real): void {
        if (moduleId !== "workspaces") return
        try {
            let w = widgetLoader.item
            if (!w) return
            let inner = w.wsInnerItem ?? w
            let p = inner.mapFromItem(root, mx, my)
            if (w.setHoverAt) w.setHoverAt(p.x, p.y)
            else if (inner.setHoverAt) inner.setHoverAt(p.x, p.y)
        } catch (e) { }
    }
    function hoverLeft(): void {
        if (moduleId !== "workspaces") return
        try { widgetLoader.item?.clearHover?.() } catch (e) { }
    }

    function click(button: int, x: real, y: real): void {
        if (moduleId === "launcher") {
            if (button === Qt.LeftButton) requestMenu()
        } else if (moduleId === "clock") {
            if (button === Qt.RightButton) Theme.toggleClockFormat()
            else if (button === Qt.LeftButton) requestCalendar()
        } else if (moduleId === "weather") {
            if (button === Qt.LeftButton) requestWeather()
            else if (button === Qt.RightButton || button === Qt.MiddleButton) WeatherService.refresh()
        } else if (moduleId === "network") {
            if (button === Qt.LeftButton) requestNetwork()
        } else if (moduleId === "volume") {
            if (button === Qt.RightButton) VolumeService.toggleMute()
            else if (button === Qt.LeftButton) requestVolume()
        } else if (moduleId === "bluetooth") {
            if (button === Qt.RightButton) BluetoothService.togglePower()
            else if (button === Qt.LeftButton) requestBluetooth()
        } else if (moduleId === "vitals") {
            if (button === Qt.LeftButton) requestVitals()
        } else if (moduleId === "updates") {
            if (button === Qt.MiddleButton) UpdateService.checkNow()
            else if (button === Qt.LeftButton) requestUpdates()
        } else if (moduleId === "systemtray") {
            try {
                let t = widgetLoader.item
                if (!t || !t.click) return
                let p = t.mapFromItem(root, x, y)
                t.click(button, p.x, p.y)
            } catch (e) { }
        } else if (moduleId === "workspaces") {
            if (button !== Qt.LeftButton) return
            try {
                let w = widgetLoader.item
                if (!w) return
                let inner = w.wsInnerItem ?? w
                let p = inner.mapFromItem(root, x, y)
                if (w.activateAt) w.activateAt(p.x, p.y)
                else if (inner.activateAt) inner.activateAt(p.x, p.y)
            } catch (e) { }
        }
    }

    function wheel(dy: real): bool {
        if (moduleId === "workspaces") {
            Hyprland.dispatch(dy > 0 ? "workspace m-1" : "workspace m+1")
            return true
        }
        if (moduleId === "volume") {
            if (dy > 0) VolumeService.stepUp()
            else VolumeService.stepDown()
            return true
        }
        if (moduleId === "systemtray") {
            try { return widgetLoader.item?.wheel?.(dy) ?? false } catch (e) { return false }
        }
        return false
    }

    implicitWidth: activeVisible ? widgetLoader.implicitWidth : 0
    implicitHeight: activeVisible ? widgetLoader.implicitHeight : 0

    readonly property var currentItem: widgetLoader.item

    Loader {
        id: widgetLoader
        anchors.centerIn: parent
        asynchronous: false
        // RAM: unload collapsed widgets instead of keeping them alive at
        // width 0 (weather with no data, empty tray). Destroying the item
        // frees its bindings, timers and images; it reloads on next show.
        active: root.activeVisible
        sourceComponent: {
            switch (root.moduleId) {
            case "launcher": return launcherComp
            case "workspaces": return wsComp
            case "clock": return clockComp
            case "weather": return weatherComp
            case "updates": return updatesComp
            case "network": return networkComp
            case "volume": return volumeComp
            case "bluetooth": return btComp
            case "vitals": return vitalsComp
            case "systemtray": return trayComp
            case "activewindow": return activeComp
            }
            return null
        }
    }

    Component {
        id: launcherComp
        Item {
            implicitWidth: launcherInner.implicitWidth + 12
            implicitHeight: launcherInner.implicitHeight + 10
            Launcher { id: launcherInner; anchors.centerIn: parent; onClicked: root.requestMenu() }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }
    Component {
        id: wsComp
        Item {
            property alias wsInnerItem: wsInner
            implicitWidth: wsInner.implicitWidth + (Theme.workspaceStyle === "default2" ? 0 : 6)
            implicitHeight: wsInner.implicitHeight + (Theme.workspaceStyle === "default2" ? 0 : 6)
            Workspaces { id: wsInner; anchors.centerIn: parent; vertical: root.vertical }
            function setHoverAt(px: real, py: real): void { wsInner.setHoverAt(px, py) }
            function clearHover(): void { wsInner.clearHover() }
            function activateAt(px: real, py: real): bool { return wsInner.activateAt(px, py) }
        }
    }
    Component {
        id: clockComp
        Item {
            implicitWidth: clockInner.implicitWidth + 12
            implicitHeight: clockInner.implicitHeight + 8
            Clock { id: clockInner; anchors.centerIn: parent; vertical: root.vertical; onClicked: root.requestCalendar() }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }
    Component { id: weatherComp; WeatherWidget { vertical: root.vertical; onClicked: root.requestWeather() } }
    Component { id: updatesComp; UpdatesIndicator { vertical: root.vertical; onClicked: root.requestUpdates() } }
    Component { id: networkComp; NetworkWidget { vertical: root.vertical; onClicked: root.requestNetwork() } }
    Component {
        id: volumeComp
        VolumeWidget { vertical: root.vertical; onClicked: root.requestVolume(); onRightClicked: VolumeService.toggleMute() }
    }
    Component {
        id: btComp
        BluetoothWidget { vertical: root.vertical; onClicked: root.requestBluetooth(); onRightClicked: BluetoothService.togglePower() }
    }
    Component { id: vitalsComp; VitalsWidget { vertical: root.vertical; onClicked: root.requestVitals() } }
    Component {
        id: trayComp
        SystemTray { vertical: root.vertical; hoverExpand: root.slotHovered; onRequestManage: root.requestSystemTray() }
    }
    Component { id: activeComp; ActiveWindow { vertical: root.vertical } }
}
