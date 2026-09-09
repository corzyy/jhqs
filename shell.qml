//@ pragma UseQApplication
//@ pragma IconTheme Papirus

import Quickshell
import "./themes"
import "./services"
import QtQuick
import Quickshell.Io
import Quickshell.Services.Notifications
import "./modules" as Modules

ShellRoot {
    id: root

    Process {
        id: wallpaperGuardProc
        command: ["bash", "-c", "echo"]
    }
    Timer {
        id: wallpaperGuardTimer
        interval: 1200; running: true; repeat: false
        onTriggered: {
            if (wallpaperGuardProc.running) return
            let cmd = "pgrep -x swaybg >/dev/null 2>&1 && exit 0;"
            cmd += " WALL=\"$(cat ~/.config/quickshell/jhqs/config/current_wallpaper.txt 2>/dev/null | tr -d '\\r\\n')\";"
            cmd += " [ -f \"$WALL\" ] || WALL=\"$(cat ~/.cache/swaybg/current 2>/dev/null | tr -d '\\r\\n')\";"
            cmd += " [ -f \"$WALL\" ] || WALL=\"$(cat ~/.cache/awww/current 2>/dev/null | tr -d '\\r\\n')\";"
            cmd += " if [ ! -f \"$WALL\" ]; then for d in \"$HOME/Bilder/wallpapers\" \"$HOME/Pictures/wallpapers\" \"$HOME/Wallpapers\" \"${XDG_PICTURES_DIR:-$HOME/Pictures}/wallpapers\" \"$HOME/wallpapers\"; do if [ -d \"$d\" ]; then WALL=\"$(find \"$d\" -mindepth 1 -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' -o -iname '*.tiff' \\) 2>/dev/null | sort | head -1)\"; [ -f \"$WALL\" ] && break; fi; done; fi;"
            cmd += " [ -f \"$WALL\" ] || exit 0;"
            cmd += " MODE=$(jq -r '.mode // \"fill\"' \"$HOME/.config/quickshell/jhqs/config/wallpaper_settings.json\" 2>/dev/null); case \"$MODE\" in stretch|fit|fill|center|tile) ;; *) MODE=fill;; esac;"
            cmd += " setsid nohup swaybg -i \"$WALL\" -m \"$MODE\" >/dev/null 2>&1 < /dev/null & disown; echo restored"
            wallpaperGuardProc.command = ["bash", "-c", cmd]
            wallpaperGuardProc.running = true
        }
    }

    property alias notifServer: notifServer
    NotificationServer {
        id: notifServer
        keepOnReload: true
        persistenceSupported: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true
        inlineReplySupported: true
        onNotification: notification => {
            HistoryService.add({
                id: notification.id,
                appName: notification.appName,
                summary: notification.summary,
                body: notification.body,
                appIcon: notification.appIcon,
                image: notification.image,
                urgency: notification.urgency,
                time: new Date(),
                actions: notification.actions,
                hasInlineReply: notification.hasInlineReply,
                inlineReplyPlaceholder: notification.inlineReplyPlaceholder,
                resident: notification.resident
            })
            if (Theme.dndEnabled) return
            notification.tracked = true
            expireOldTrackedNotifications()
        }
    }

    function expireOldTrackedNotifications() {
        try {
            const m = notifServer.trackedNotifications
            const vals = m ? m.values : []
            if (!vals || vals.length <= 5) return
            const extra = vals.length - 5
            for (let i = 0; i < extra; i++) {
                try { vals[i].expire() } catch (e) { }
            }
        } catch (e) { }
    }

    QtObject {
        id: panel
        readonly property int none: 0
        readonly property int menu: 1
        readonly property int controlCenter: 2
        readonly property int calendar: 3
        readonly property int media: 4
        readonly property int weather: 5
        readonly property int settings: 6
        readonly property int systemTray: 7
        readonly property int notifCenter: 8
        readonly property int network: 9
        readonly property int volume: 10
        readonly property int bluetooth: 11
        readonly property int updates: 12
        readonly property int vitals: 13
    }

    property int activePanel: panel.none
    property string settingsSection: "global"
    property bool menuCentered: false

    readonly property bool menuVisible: activePanel === panel.menu
    readonly property bool controlCenterVisible: activePanel === panel.controlCenter
    readonly property bool calendarVisible: activePanel === panel.calendar
    readonly property bool mediaVisible: activePanel === panel.media
    readonly property bool weatherVisible: activePanel === panel.weather
    readonly property bool settingsVisible: activePanel === panel.settings
    readonly property bool systemTrayVisible: activePanel === panel.systemTray
    readonly property bool notifCenterVisible: activePanel === panel.notifCenter
    readonly property bool networkVisible: activePanel === panel.network
    readonly property bool volumeVisible: activePanel === panel.volume
    readonly property bool bluetoothVisible: activePanel === panel.bluetooth
    readonly property bool updatesVisible: activePanel === panel.updates
    readonly property bool vitalsVisible: activePanel === panel.vitals

    property int systemTrigger: 0
    property int consumedSystemTrigger: 0
    onSystemTriggerChanged: if (menuLoader.item) consumedSystemTrigger = systemTrigger

    property bool _anchorsDirty: false
    function refreshBarAnchors() {
        if (_anchorsDirty) return
        _anchorsDirty = true
        Qt.callLater(() => {
            _anchorsDirty = false
            Theme.refreshBarAnchors()
        })
    }

    function closeAll() { activePanel = panel.none }

    function openPanel(p: int) {
        refreshBarAnchors()
        activePanel = p
    }

    function toggleExclusive(p: int) {
        refreshBarAnchors()
        activePanel = (activePanel === p) ? panel.none : p
    }

    function openSystem(): void {
        menuCentered = true
        openPanel(panel.menu)
        systemTrigger++
    }

    function openUpdates(): void {
        openPanel(panel.updates)
    }

    function toggleUpdates(): void {
        toggleExclusive(panel.updates)
    }

    readonly property var jhqsMenu: menuLoader.item
    readonly property var settingsPanel: settingsLoader.item

    Modules.TopBar {
        id: topBar
        menuOpen: root.menuVisible
        ccOpen: root.controlCenterVisible
        calendarOpen: root.calendarVisible
        mediaOpen: root.mediaVisible
        weatherOpen: root.weatherVisible
        notifOpen: root.notifCenterVisible
        networkOpen: root.networkVisible
        volumeOpen: root.volumeVisible
        bluetoothOpen: root.bluetoothVisible
        vitalsOpen: root.vitalsVisible
        trayOpen: root.systemTrayVisible
        updatesOpen: root.updatesVisible

        onToggleMenu: { root.menuCentered = true; root.toggleExclusive(panel.menu) }
        onToggleControlCenter: root.toggleExclusive(panel.controlCenter)
        onToggleCalendar: root.toggleExclusive(panel.calendar)
        onToggleMedia: root.toggleExclusive(panel.media)
        onToggleWeather: root.toggleExclusive(panel.weather)
        onToggleNotif: root.toggleExclusive(panel.notifCenter)
        onToggleNetwork: root.toggleExclusive(panel.network)
        onToggleVolume: root.toggleExclusive(panel.volume)
        onToggleBluetooth: root.toggleExclusive(panel.bluetooth)
        onToggleVitals: root.toggleExclusive(panel.vitals)
        onToggleSystemTray: root.toggleExclusive(panel.systemTray)
        onOpenUpdates: root.toggleUpdates()

        onClosePanel: moduleId => {
            if (moduleId === "launcher" && root.menuVisible) root.closeAll()
            else if (moduleId === "controlcenter" && root.controlCenterVisible) root.closeAll()
            else if (moduleId === "clock" && root.calendarVisible) root.closeAll()
            else if (moduleId === "media" && root.mediaVisible) root.closeAll()
            else if (moduleId === "weather" && root.weatherVisible) root.closeAll()
            else if (moduleId === "notif" && root.notifCenterVisible) root.closeAll()
            else if (moduleId === "network" && root.networkVisible) root.closeAll()
            else if (moduleId === "volume" && root.volumeVisible) root.closeAll()
            else if (moduleId === "bluetooth" && root.bluetoothVisible) root.closeAll()
            else if (moduleId === "vitals" && root.vitalsVisible) root.closeAll()
            else if (moduleId === "systemtray" && root.systemTrayVisible) root.closeAll()
            else if (moduleId === "updates" && root.updatesVisible) root.closeAll()
            else if (moduleId === "settings" && root.settingsVisible) root.closeAll()
        }
    }

    function openSettings(section: string): void {
        let s = (section || "global").trim() || "global"
        let valid = ["global", "hypr", "bar", "modules", "workspaces", "notif", "osd", "search"]
        if (valid.indexOf(s) === -1) s = "global"
        settingsSection = s
        if (settingsLoader.item) settingsLoader.item.section = s
        openPanel(panel.settings)
    }

    IpcHandler {
        target: "dnd"
        function toggle(): string { Theme.toggleDnd(); return "dnd=" + Theme.dndEnabled }
        function enable(): string { Theme.setDndEnabled(true); return "dnd=true" }
        function disable(): string { Theme.setDndEnabled(false); return "dnd=false" }
        function status(): string { return "dnd=" + Theme.dndEnabled }
    }
    IpcHandler {
        target: "gamemode"
        function toggle(): string { Theme.toggleGamemode(); return "gamemode=" + Theme.gamemodeEnabled }
        function enable(): string { Theme.setGamemodeEnabled(true); return "gamemode=true" }
        function disable(): string { Theme.setGamemodeEnabled(false); return "gamemode=false" }
        function status(): string { return "gamemode=" + Theme.gamemodeEnabled }
    }
    IpcHandler {
        target: "notif"
        function count(): string {
            try {
                let h = HistoryService.history.length
                let t = 0
                try { t = notifServer && notifServer.trackedNotifications ? notifServer.trackedNotifications.values.length : 0 } catch (e) { }
                return "history=" + h + " tracked=" + t
            } catch (e) { return "history=? tracked=?" }
        }
        function list(): string {
            try {
                let hist = HistoryService.history.slice(-10)
                let out = hist.map(h => (h.appName || "?") + ": " + (h.summary || ""))
                return out.length > 0 ? out.join("\n") : "(empty)"
            } catch (e) { return "(error)" }
        }
    }

    IpcHandler {
        target: "jhqs"
        function toggleMenu(): void { root.menuCentered = true; root.toggleExclusive(panel.menu) }
        function toggleMenuAtBar(): void { root.menuCentered = false; root.toggleExclusive(panel.menu) }
        function showMenu(): void { root.menuCentered = false; root.openPanel(panel.menu) }
        function showMenuCentered(): void { root.menuCentered = true; root.openPanel(panel.menu) }
        function hideMenu(): void { root.closeAll() }
        function state(): string {
            return "menu=" + root.menuVisible
                + " centered=" + root.menuCentered
                + " controlCenter=" + root.controlCenterVisible
                + " calendar=" + root.calendarVisible
                + " media=" + root.mediaVisible
            + " weather=" + root.weatherVisible
            + " notifcenter=" + root.notifCenterVisible
            + " network=" + root.networkVisible
            + " volume=" + root.volumeVisible
            + " bluetooth=" + root.bluetoothVisible
            + " vitals=" + root.vitalsVisible
            + " updates=" + root.updatesVisible
            + " settings=" + root.settingsVisible
            + " systemtray=" + root.systemTrayVisible
        }
        function toggleControlCenter(): void { root.toggleExclusive(panel.controlCenter) }
        function showControlCenter(): void { root.openPanel(panel.controlCenter) }
        function hideControlCenter(): void { root.closeAll() }
        function toggleCalendar(): void { root.toggleExclusive(panel.calendar) }
        function showCalendar(): void { root.openPanel(panel.calendar) }
        function hideCalendar(): void { root.closeAll() }
        function toggleMedia(): void { root.toggleExclusive(panel.media) }
        function showMedia(): void { root.openPanel(panel.media) }
        function hideMedia(): void { root.closeAll() }
        function toggleWeather(): void { root.toggleExclusive(panel.weather) }
        function showWeather(): void { root.openPanel(panel.weather) }
        function hideWeather(): void { root.closeAll() }
        function toggleNotif(): void { root.toggleExclusive(panel.notifCenter) }
        function showNotif(): void { root.openPanel(panel.notifCenter) }
        function hideNotif(): void { root.closeAll() }
        function toggleNetwork(): void { root.toggleExclusive(panel.network) }
        function showNetwork(): void { root.openPanel(panel.network) }
        function hideNetwork(): void { root.closeAll() }
        function toggleVolume(): void { root.toggleExclusive(panel.volume) }
        function showVolume(): void { root.openPanel(panel.volume) }
        function hideVolume(): void { root.closeAll() }
        function toggleBluetooth(): void { root.toggleExclusive(panel.bluetooth) }
        function showBluetooth(): void { root.openPanel(panel.bluetooth) }
        function hideBluetooth(): void { root.closeAll() }
        function toggleVitals(): void { root.toggleExclusive(panel.vitals) }
        function showVitals(): void { root.openPanel(panel.vitals) }
        function hideVitals(): void { root.closeAll() }
        function toggleSystemTray(): void { root.toggleExclusive(panel.systemTray) }
        function showSystemTray(): void { root.openPanel(panel.systemTray) }
        function hideSystemTray(): void { root.closeAll() }
        function toggleSettings(): void { if (root.settingsVisible) root.closeAll(); else root.openSettings("global") }
        function showSettings(s: string): void { root.openSettings(s || "global") }
        function hideSettings(): void { root.closeAll() }
        function openSystem(): void { root.openSystem() }
        function openUpdates(): void { root.openUpdates() }
        function toggleUpdates(): void { root.toggleUpdates() }
        function toggleSystem(): void {
            if (root.menuVisible && (menuLoader.item?.showSession ?? false)) root.closeAll()
            else root.openSystem()
        }
        function reload(): void { Quickshell.reload(true) }
    }

    Modules.Notifications {
        notifServer: root.notifServer
    }

    Loader {
        id: menuLoader
        active: root.menuVisible
        asynchronous: true
        sourceComponent: menuComp
    }
    Component {
        id: menuComp
        Modules.JhqsMenu {
            showMenu: root.menuVisible
            centered: root.menuCentered
            systemTrigger: root.systemTrigger
            onDismissed: root.closeAll()
            onOpenSettings: section => root.openSettings(section || "global")
            Component.onCompleted: {
                let wantSystem = root.systemTrigger > root.consumedSystemTrigger
                root.consumedSystemTrigger = root.systemTrigger
                if (wantSystem) openSystem()
            }
        }
    }

    Loader { id: ccLoader; active: root.controlCenterVisible; asynchronous: true; sourceComponent: ccComp }
    Component {
        id: ccComp
        Modules.ControlCenter {
            showControlCenter: root.controlCenterVisible
            onDismissed: root.closeAll()
            onOpenSettings: section => root.openSettings(section || "global")
        }
    }

    Loader { id: calLoader; active: root.calendarVisible; asynchronous: true; sourceComponent: calComp }
    Component {
        id: calComp
        Modules.CalendarMenu {
            showCalendar: root.calendarVisible
            onDismissed: root.closeAll()
        }
    }

    Loader { id: mediaLoader; active: root.mediaVisible; asynchronous: true; sourceComponent: mediaComp }
    Component {
        id: mediaComp
        Modules.MediaPanel {
            showMedia: root.mediaVisible
            onDismissed: root.closeAll()
        }
    }

    Loader { id: weatherLoader; active: root.weatherVisible; asynchronous: true; sourceComponent: weatherComp }
    Component {
        id: weatherComp
        Modules.WeatherPanel {
            showWeather: root.weatherVisible
            onDismissed: root.closeAll()
        }
    }

    Loader { id: notifCenterLoader; active: root.notifCenterVisible; asynchronous: true; sourceComponent: notifCenterComp }
    Component {
        id: notifCenterComp
        Modules.NotificationCenter {
            showNotif: root.notifCenterVisible
            notifServer: root.notifServer
            onDismissed: root.closeAll()
        }
    }

    Loader { id: trayLoader; active: root.systemTrayVisible; asynchronous: true; sourceComponent: trayComp }
    Component {
        id: trayComp
        Modules.SystemTrayPanel {
            showTray: root.systemTrayVisible
            onDismissed: root.closeAll()
        }
    }

    Loader { id: netLoader; active: root.networkVisible; asynchronous: true; sourceComponent: netComp }
    Component {
        id: netComp
        Modules.NetworkPanel {
            showNetwork: root.networkVisible
            onDismissed: root.closeAll()
        }
    }

    Loader { id: volLoader; active: root.volumeVisible; asynchronous: true; sourceComponent: volComp }
    Component {
        id: volComp
        Modules.VolumePanel {
            showVolume: root.volumeVisible
            onDismissed: root.closeAll()
        }
    }

    Loader { id: btLoader; active: root.bluetoothVisible; asynchronous: true; sourceComponent: btPanelComp }
    Component {
        id: btPanelComp
        Modules.BluetoothPanel {
            showBluetooth: root.bluetoothVisible
            onDismissed: root.closeAll()
        }
    }

    Loader { id: updLoader; active: root.updatesVisible; asynchronous: true; sourceComponent: updPanelComp }
    Component {
        id: updPanelComp
        Modules.UpdateCenterPanel {
            showUpdates: root.updatesVisible
            onDismissed: root.closeAll()
        }
    }

    Loader { id: vitalsLoader; active: root.vitalsVisible; asynchronous: true; sourceComponent: vitalsPanelComp }
    Component {
        id: vitalsPanelComp
        Modules.VitalsPanel {
            showVitals: root.vitalsVisible
            onDismissed: root.closeAll()
        }
    }

    Loader {
        id: settingsLoader
        active: root.settingsVisible
        asynchronous: true
        sourceComponent: settingsComp
        onLoaded: if (item) item.section = root.settingsSection
    }
    Component {
        id: settingsComp
        Modules.SettingsPanel {
            showSettings: root.settingsVisible
            Component.onCompleted: section = root.settingsSection
            onDismissed: root.closeAll()
        }
    }

    Modules.VolumeOSD { }
    Modules.LaunchOSD { }
    Modules.Lockscreen { }

    Modules.Polkit { }
}
