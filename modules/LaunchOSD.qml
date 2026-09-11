// @ pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../themes"

Scope {
    id: launchScope

    readonly property int barT: Theme.barThickness
    readonly property string barPos: Theme.barPosition
    readonly property int quattroPad: 10
    readonly property int quattroGap: 8
    readonly property int quattroBottomMargin: 67
    readonly property int quattroMaxMessageWidth: 190

    property string appName: ""
    property string appIconName: ""
    property bool launchVisible: false
    property bool _winVisible: launchVisible
    Timer { id: launchHideTimer; interval: 0; repeat: false; onTriggered: if (!launchScope.launchVisible) launchScope._winVisible = false }
    onLaunchVisibleChanged: {
        if (launchVisible) { _winVisible = true; launchHideTimer.stop() }
        else { progressAnim.stop(); progress = 0; launchHideTimer.restart() }
    }
    property bool inited: false
    Timer {
        id: initTimer
        interval: 1500
        running: true
        repeat: false
        onTriggered: { launchScope.inited = true; launchScope.seedSeen() }
    }

    property real progress: 0
    property int progressMs: 1200
    NumberAnimation {
        id: progressAnim
        target: launchScope
        property: "progress"
        to: 1
        duration: launchScope.progressMs
        onFinished: launchScope.launchVisible = false
    }

    function showWith(name: string, icon: string, ms: int): void {
        if (!inited) return
        if (!Theme.osdLaunchEnabled) return
        appName = (name && name.length > 0) ? name : "Starting…"
        appIconName = icon || ""
        progress = 0
        progressMs = (ms && ms > 100) ? ms : 1200
        launchVisible = true
        progressAnim.stop()
        progressAnim.from = 0
        progressAnim.duration = progressMs
        progressAnim.restart()
    }

    Connections {
        target: Theme
        function onLaunchOsdTriggerChanged() { launchScope.showWith(Theme.launchOsdName, Theme.launchOsdIcon, 1000) }
    }
    IpcHandler {
        target: "launchOsd"
        function notify(name: string): void { launchScope.showWith(name || "", "", 1000) }
        function status(): string { return "visible=" + launchScope.launchVisible + " app=\"" + launchScope.appName + "\" pct=" + Math.round(launchScope.progress * 100) + " inited=" + launchScope.inited }
    }

    property var allApps: {
        Theme.appsRev
        try {
            let a = DesktopEntries.applications
            if (!a) return []
            let v = a.values
            if (typeof v === "function") v = v()
            if (!v) return []
            return v.slice ? v.slice() : [...v]
        } catch (e) {
            return []
        }
    }
    function toplevelList(): var {
        try {
            if (!Hyprland.toplevels) return []
            let v = Hyprland.toplevels.values
            let list = (typeof v === "function") ? v() : v
            return list ? list : []
        } catch (e) {
            return []
        }
    }
    function tlAppId(tl: var): string {
        try {
            if (tl.wayland && tl.wayland.appId && tl.wayland.appId.length > 0) return tl.wayland.appId
            let o = tl.lastIpcObject
            if (o) {
                if (o.class && ("" + o.class).length > 0) return "" + o.class
                if (o.initialClass && ("" + o.initialClass).length > 0) return "" + o.initialClass
            }
            if (tl.title && tl.title.length > 0) return tl.title
        } catch (e) { }
        return ""
    }
    function entryForAppId(appId: string): var {
        try {
            let low = (appId || "").toLowerCase().trim()
            if (low.length === 0) return null
            let apps = launchScope.allApps
            for (let i = 0; i < apps.length; i++) {
                let e = apps[i]
                if (!e || !e.id) continue
                let eid = ("" + e.id).toLowerCase()
                if (eid === low || eid === low + ".desktop" || eid.replace(/\.desktop$/, "") === low) return e
            }
        } catch (e) { }
        return null
    }
    property var seenAddrs: ({ })
    function seedSeen(): void {
        try {
            let cur = { }
            let list = toplevelList()
            for (let i = 0; i < list.length; i++) { let a = list[i] ? list[i].address : ""; if (a) cur[a] = true }
            seenAddrs = cur
        } catch (e) { }
    }
    Timer {
        id: winPollTimer
        interval: 1500
        running: launchScope.inited && Theme.osdLaunchEnabled
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            if (!launchScope.inited) return
            if (!Theme.osdLaunchEnabled) return
            try {
                let list = launchScope.toplevelList()
                let cur = { }
                let fresh = null
                for (let i = 0; i < list.length; i++) {
                    let t = list[i]
                    let a = (t && t.address) ? t.address : ""
                    if (!a) continue
                    cur[a] = true
                    if (!launchScope.seenAddrs[a] && !fresh) fresh = t
                }
                launchScope.seenAddrs = cur
                if (fresh) {
                    let appId = launchScope.tlAppId(fresh)
                    let e = launchScope.entryForAppId(appId)
                    launchScope.showWith(e ? (e.name || appId) : appId, e ? (e.icon || "") : "", 600)
                }
            } catch (e) { }
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: launchScope._winVisible && Theme.osdLaunchEnabled && modelData.name === "DP-1"
            color: "transparent"
            exclusiveZone: 0
            mask: Region { item: quattroWrapper }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "launchosd"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: true; left: true; right: true; bottom: true }

            Item {
                id: quattroWrapper
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: launchScope.quattroBottomMargin
                width: quattroCard.width
                height: quattroCard.height
                opacity: launchScope.launchVisible ? 1 : 0

                Rectangle {
                    id: quattroCard
                    readonly property int iconW: 32
                    width: 2 + launchScope.quattroPad + iconW + launchScope.quattroGap + launchMsg.width + launchScope.quattroPad + 2
                    height: 2 + launchScope.quattroPad + 28 + launchScope.quattroPad + 2
                    radius: Theme.cornerRadius
                    color: Theme.bg
                    border.color: Theme.accent
                    border.width: 2
                    antialiasing: Theme.shapesAa

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 2 + launchScope.quattroPad
                        anchors.rightMargin: 2 + launchScope.quattroPad
                        anchors.topMargin: 2 + launchScope.quattroPad
                        anchors.bottomMargin: 2 + launchScope.quattroPad
                        spacing: launchScope.quattroGap
                        Item {
                            width: quattroCard.iconW
                            height: parent.height
                            IconImage {
                                anchors.centerIn: parent
                                width: 28
                                height: 28
                                source: {
                                    try {
                                        if (launchScope.appIconName && launchScope.appIconName.length > 0) return Quickshell.iconPath(launchScope.appIconName)
                                    } catch (e) { }
                                    return Quickshell.iconPath("application-x-executable")
                                }
                                asynchronous: true
                                implicitSize: Qt.size(56, 56)
                            }
                        }
                        Text {
                            id: launchMsg
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(Math.ceil(launchMsgMetrics.advanceWidth), launchScope.quattroMaxMessageWidth)
                            text: launchScope.appName.length > 0 ? launchScope.appName : "Starting…"
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(14)
                            font.bold: true
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            textFormat: Text.PlainText
                        }
                        TextMetrics {
                            id: launchMsgMetrics
                            font.family: Theme.iconFontFamily
                            font.bold: true
                            font.pixelSize: Theme.fs(14)
                            text: launchScope.appName.length > 0 ? launchScope.appName : "Starting…"
                        }
                    }
                }
            }

        }
    }
}
