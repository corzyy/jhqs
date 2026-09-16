//@ pragma UseQApplication
//@ pragma IconTheme Papirus

import Quickshell
import "./themes"
import "./services"
import QtQuick
import Quickshell.Io
import Quickshell.Services.Notifications
import "./modules" as Modules
import "./modules/panels" as Panels
import "./modules/controlcenter" as Cc

ShellRoot {
    id: root

    // LOGGING: persist every runtime error/warning to logs/errors.log
    // while the shell is running (services/LogService.qml).
    QtObject { Component.onCompleted: LogService.start() }
    Connections {
        target: Quickshell
        function onReloadFailed(errorString) { LogService.record("error", errorString, "reload") }
    }

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
            // CRASH FIX: snapshot only plain types. Never store
            // notification.actions (QObjects) — dangling actions crash
            // CalendarMenu Repeaters in QV4::fromData on open.
            // HistoryService.add() sanitizes again as defense-in-depth.
            try {
                HistoryService.add({
                    id: Number(notification.id),
                    appName: String(notification.appName || "Notification"),
                    summary: String(notification.summary || ""),
                    body: String(notification.body || ""),
                    urgency: Number(notification.urgency),
                    time: Date.now()
                })
            } catch (e) { }
            if (Theme.dndEnabled) return
            notification.tracked = true
            expireOldTrackedNotifications()
        }
    }

    function expireOldTrackedNotifications() {
        // PERF: coalesce burst expiry — 20 toasts used to alloc values[] +
        // expire per notification. One deferred pass per burst instead.
        if (_expireScheduled) return
        _expireScheduled = true
        Qt.callLater(() => {
            _expireScheduled = false
            try {
                const m = notifServer.trackedNotifications
                const vals = m ? m.values : []
                if (!vals || vals.length <= 5) return
                const extra = vals.length - 5
                for (let i = 0; i < extra; i++) {
                    try { vals[i].expire() } catch (e) { }
                }
            } catch (e) { }
        })
    }
    property bool _expireScheduled: false

    QtObject {
        id: panel
        readonly property int none: 0
        readonly property int menu: 1
        readonly property int calendar: 2
        readonly property int weather: 3
        readonly property int settings: 4
        readonly property int systemTray: 5
        readonly property int network: 6
        readonly property int volume: 7
        readonly property int bluetooth: 8
        readonly property int updates: 9
        readonly property int vitals: 10
        readonly property int controlCenter: 11
        readonly property int netanjahu: 12
    }

    property int activePanel: panel.none
    property string settingsSection: "global"
    property bool menuCentered: false

    readonly property bool menuVisible: activePanel === panel.menu
    readonly property bool calendarVisible: activePanel === panel.calendar
    readonly property bool weatherVisible: activePanel === panel.weather
    readonly property bool settingsVisible: activePanel === panel.settings
    readonly property bool systemTrayVisible: activePanel === panel.systemTray
    readonly property bool networkVisible: activePanel === panel.network
    readonly property bool volumeVisible: activePanel === panel.volume
    readonly property bool bluetoothVisible: activePanel === panel.bluetooth
    readonly property bool updatesVisible: activePanel === panel.updates
    readonly property bool vitalsVisible: activePanel === panel.vitals
    readonly property bool controlCenterVisible: activePanel === panel.controlCenter
    readonly property bool netanjahuVisible: activePanel === panel.netanjahu

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

    // Geteilte Loader-Hülle für Panels (10x identisches active/async-Muster).
    // Der Loader lebt während der Exit-Animation weiter (hold): sonst würde
    // active:false das Panel sofort zerstören und die Close-Animation wäre
    // nie sichtbar. Ohne Animationen ist panelHideDelay 0, also exakt wie
    // vorher. hold wird bewusst imperativ gesetzt — ein Binding wie
    // (shown || item._winVisible) feuert über Loader.item-Erzeugung zurück
    // und meldet "Binding loop detected for property active".
    component PanelLoader: Loader {
        required property bool shown
        property bool hold: false
        active: shown || hold
        asynchronous: true
        Timer {
            id: holdTimer
            interval: Theme.panelHideDelay
            repeat: false
            onTriggered: parent.hold = false
        }
        onShownChanged: {
            if (shown) {
                hold = false
                holdTimer.stop()
            } else if (item && Theme.animationsEnabled) {
                hold = true
                holdTimer.restart()
            }
        }
    }

    // Name -> Panel-Enum (eine Tabelle für IPC-Namen und Modul-IDs statt
    // dreier kopierter Zuordnungsstellen: IpcHandler, onClosePanel, openSettings).
    readonly property var panelForName: ({
        menu: panel.menu, calendar: panel.calendar, weather: panel.weather,
        network: panel.network, volume: panel.volume, bluetooth: panel.bluetooth,
        updates: panel.updates, vitals: panel.vitals, systemtray: panel.systemTray,
        settings: panel.settings, controlcenter: panel.controlCenter,
        netanjahu: panel.netanjahu
    })
    // Bar-Modul-IDs weichen teils ab (launcher->menu, clock->calendar).
    readonly property var panelForModule: ({
        launcher: panel.menu, clock: panel.calendar, weather: panel.weather,
        network: panel.network, volume: panel.volume, bluetooth: panel.bluetooth,
        vitals: panel.vitals, systemtray: panel.systemTray, updates: panel.updates,
        settings: panel.settings, controlcenter: panel.controlCenter,
        netanjahu: panel.netanjahu
    })

    function toggleNamedPanel(name: string): void {
        const p = panelForName[name]
        if (p !== undefined) toggleExclusive(p)
    }
    function showNamedPanel(name: string): void {
        const p = panelForName[name]
        if (p !== undefined) openPanel(p)
    }

    function openPanel(p: int) {
        refreshBarAnchors()
        activePanel = p
    }

    function toggleExclusive(p: int) {
        refreshBarAnchors()
        activePanel = (activePanel === p) ? panel.none : p
    }

    function toggleMenuCentered(): void {
        menuCentered = true
        toggleExclusive(panel.menu)
    }

    function toggleMenuAtBar(): void {
        menuCentered = false
        toggleExclusive(panel.menu)
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

    // RAM: dead aliases removed (jhqsMenu/settingsPanel were never read).
    // Panel visibility is derived from a single activePanel int to avoid
    // 13 independent booleans fanning out through TopBar.

    Modules.TopBar {
        id: topBar
        menuOpen: root.menuVisible
        calendarOpen: root.calendarVisible
        weatherOpen: root.weatherVisible
        networkOpen: root.networkVisible
        volumeOpen: root.volumeVisible
        bluetoothOpen: root.bluetoothVisible
        vitalsOpen: root.vitalsVisible
        trayOpen: root.systemTrayVisible
        updatesOpen: root.updatesVisible
        controlCenterOpen: root.controlCenterVisible
        netanjahuOpen: root.netanjahuVisible

        onToggleMenu: root.toggleMenuCentered()
        onToggleCalendar: root.toggleExclusive(panel.calendar)
        onToggleWeather: root.toggleExclusive(panel.weather)
        onToggleNetwork: root.toggleExclusive(panel.network)
        onToggleVolume: root.toggleExclusive(panel.volume)
        onToggleBluetooth: root.toggleExclusive(panel.bluetooth)
        onToggleVitals: root.toggleExclusive(panel.vitals)
        onToggleSystemTray: root.toggleExclusive(panel.systemTray)
        onToggleControlCenter: root.toggleExclusive(panel.controlCenter)
        onToggleNetanjahu: root.toggleExclusive(panel.netanjahu)
        onOpenUpdates: root.toggleUpdates()

        // CPU: table-driven close — replaces if/else chain so
        // closePanel is O(1) and cannot drift out of sync with panel enum.
        // PERF: switch instead of per-signal object alloc + 10 prop reads.
        onClosePanel: moduleId => {
            const p = panelForModule[moduleId]
            if (p !== undefined && root.activePanel === p) root.closeAll()
        }
    }

    function openSettings(section: string): void {
        let s = (section || "global").trim() || "global"
        if (s === "modules") s = "vitals"
        let valid = ["global", "mango", "audio", "apps", "bar", "vitals", "workspaces", "calendar", "notif", "search", "weather"]
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
                + " calendar=" + root.calendarVisible
            + " weather=" + root.weatherVisible
            + " network=" + root.networkVisible
            + " volume=" + root.volumeVisible
            + " bluetooth=" + root.bluetoothVisible
            + " vitals=" + root.vitalsVisible
            + " updates=" + root.updatesVisible
            + " settings=" + root.settingsVisible
            + " systemtray=" + root.systemTrayVisible
            + " controlcenter=" + root.controlCenterVisible
            + " netanjahu=" + root.netanjahuVisible
        }
        function toggleCalendar(): void { root.toggleNamedPanel("calendar") }
        function showCalendar(): void { root.showNamedPanel("calendar") }
        function hideCalendar(): void { root.closeAll() }
        function toggleWeather(): void { root.toggleNamedPanel("weather") }
        function showWeather(): void { root.showNamedPanel("weather") }
        function hideWeather(): void { root.closeAll() }
        function toggleNetwork(): void { root.toggleNamedPanel("network") }
        function showNetwork(): void { root.showNamedPanel("network") }
        function hideNetwork(): void { root.closeAll() }
        function toggleVolume(): void { root.toggleNamedPanel("volume") }
        function showVolume(): void { root.showNamedPanel("volume") }
        function hideVolume(): void { root.closeAll() }
        function toggleBluetooth(): void { root.toggleNamedPanel("bluetooth") }
        function showBluetooth(): void { root.showNamedPanel("bluetooth") }
        function hideBluetooth(): void { root.closeAll() }
        function toggleVitals(): void { root.toggleNamedPanel("vitals") }
        function showVitals(): void { root.showNamedPanel("vitals") }
        function hideVitals(): void { root.closeAll() }
        function toggleControlCenter(): void { root.toggleNamedPanel("controlcenter") }
        function showControlCenter(): void { root.showNamedPanel("controlcenter") }
        function hideControlCenter(): void { root.closeAll() }
        function toggleNetanjahu(): void { root.toggleNamedPanel("netanjahu") }
        function showNetanjahu(): void { root.showNamedPanel("netanjahu") }
        function hideNetanjahu(): void { root.closeAll() }
        function toggleSystemTray(): void { root.toggleNamedPanel("systemtray") }
        function showSystemTray(): void { root.showNamedPanel("systemtray") }
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

    PanelLoader {
        id: menuLoader
        shown: root.menuVisible
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

    PanelLoader { id: calLoader; shown: root.calendarVisible; sourceComponent: calComp }
    Component {
        id: calComp
        Panels.CalendarMenu {
            showCalendar: root.calendarVisible
            notifServer: root.notifServer
            onDismissed: root.closeAll()
        }
    }

    PanelLoader { id: weatherLoader; shown: root.weatherVisible; sourceComponent: weatherComp }
    Component {
        id: weatherComp
        Panels.WeatherPanel {
            showWeather: root.weatherVisible
            onDismissed: root.closeAll()
        }
    }

    PanelLoader { id: trayLoader; shown: root.systemTrayVisible; sourceComponent: trayComp }
    Component {
        id: trayComp
        Panels.SystemTrayPanel {
            showTray: root.systemTrayVisible
            onDismissed: root.closeAll()
        }
    }

    PanelLoader { id: netLoader; shown: root.networkVisible; sourceComponent: netComp }
    Component {
        id: netComp
        Panels.NetworkPanel {
            showNetwork: root.networkVisible
            onDismissed: root.closeAll()
        }
    }

    PanelLoader { id: volLoader; shown: root.volumeVisible; sourceComponent: volComp }
    Component {
        id: volComp
        Panels.VolumePanel {
            showVolume: root.volumeVisible
            onDismissed: root.closeAll()
        }
    }

    PanelLoader { id: btLoader; shown: root.bluetoothVisible; sourceComponent: btPanelComp }
    Component {
        id: btPanelComp
        Panels.BluetoothPanel {
            showBluetooth: root.bluetoothVisible
            onDismissed: root.closeAll()
        }
    }

    PanelLoader { id: updLoader; shown: root.updatesVisible; sourceComponent: updPanelComp }
    Component {
        id: updPanelComp
        Panels.UpdateCenterPanel {
            showUpdates: root.updatesVisible
            onDismissed: root.closeAll()
        }
    }

    PanelLoader { id: vitalsLoader; shown: root.vitalsVisible; sourceComponent: vitalsPanelComp }
    Component {
        id: vitalsPanelComp
        Panels.VitalsPanel {
            showVitals: root.vitalsVisible
            onDismissed: root.closeAll()
        }
    }

    PanelLoader { id: ccLoader; shown: root.controlCenterVisible; sourceComponent: ccComp }
    Component {
        id: ccComp
        Cc.ControlCenterPanel {
            showControlCenter: root.controlCenterVisible
            onDismissed: root.closeAll()
            onSettingsRequested: root.openSettings("global")
            onPowerRequested: root.openSystem()
        }
    }

    PanelLoader { id: bibiLoader; shown: root.netanjahuVisible; sourceComponent: bibiComp }
    Component {
        id: bibiComp
        Panels.NetanjahuPanel {
            showNetanjahu: root.netanjahuVisible
            onDismissed: root.closeAll()
        }
    }

    PanelLoader {
        id: settingsLoader
        shown: root.settingsVisible
        sourceComponent: settingsComp
        onLoaded: if (item) item.section = root.settingsSection
    }
    Component {
        id: settingsComp
        Panels.SettingsPanel {
            showSettings: root.settingsVisible
            Component.onCompleted: section = root.settingsSection
            onDismissed: root.closeAll()
        }
    }

    // NOTE: VolumeOSD/Lockscreen/Polkit stay resident on purpose:
    // they are trigger listeners (Theme.volumeOsdTrigger,
    // lock IPC, polkit agent). Gating them on a visible flag would break
    // the trigger itself. Their windows already render nothing when hidden
    // (_winVisible=false -> visible:false), so steady-state cost is one
    // Scope + timers, not a scene tree. Real RAM wins are the 14 panel
    // Loaders above, which ARE correctly gated.
    Modules.VolumeOSD { }
    Modules.Lockscreen { }

    Modules.Polkit { }
}
