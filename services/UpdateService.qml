pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

Singleton {
    id: root
    property var updates: []
    property bool checking: false
    property var lastCheckedAt: null
    property var knownUpdateKeys: ({})
    property bool hasCompletedFirstCheck: false

    // DRY: updateCount was an exact duplicate of totalCount and isVisible was
    // never read (callers use displayCount). Keep one canonical count.
    readonly property int totalCount: updates.length
    readonly property bool hasUpdates: updates.length > 0
    property bool debugForce: false
    property int debugCount: 5
    property int displayCount: debugForce ? debugCount : updates.length
    // NOTE: isVisible removed — dead (callers use displayCount > 0).

    readonly property string checkSchedule: settingsFile.adapter.checkSchedule !== undefined ? settingsFile.adapter.checkSchedule : "Every 6 hours"
    readonly property bool offerShutdownAction: {
        let v = settingsFile.adapter.offerShutdownAction
        return v === true || String(v) === "true"
    }
    readonly property int checkIntervalMs: {
        if (checkSchedule === "Every 30 minutes") return 30 * 60 * 1000
        if (checkSchedule === "Every 2 hours") return 2 * 60 * 60 * 1000
        if (checkSchedule === "Every 12 hours") return 12 * 60 * 60 * 1000
        if (checkSchedule === "Every 24 hours") return 24 * 60 * 60 * 1000
        if (checkSchedule === "Every 6 hours") return 6 * 60 * 60 * 1000
        return 0
    }

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/update_center.json"
        watchChanges: true; blockLoading: true; printErrors: false
        onFileChanged: settingsReloadDebounce.restart()
        adapter: JsonAdapter {
            property string checkSchedule: "Every 6 hours"
            property bool offerShutdownAction: true
        }
    }
    // STABILITY: coalesce editor save bursts (create+write = 2 reloads).
    // FileView defaults already cover missing keys, so no boot mkdir+jq fork.
    Timer {
        id: settingsReloadDebounce
        interval: 300; repeat: false
        onTriggered: { try { settingsFile.reload() } catch (e) { } }
    }

    function setCheckSchedule(schedule: string): void {
        if (schedule === checkSchedule) return
        settingsFile.adapter.checkSchedule = schedule
        settingsFile.writeAdapter()
        checkNow()
    }
    function setOfferShutdownAction(v: bool): void {
        let nv = !!v
        if (offerShutdownAction === nv) return
        settingsFile.adapter.offerShutdownAction = nv
        settingsFile.writeAdapter()
    }

    function checkNow(): void {
        // PERF: coalesce boot + net-flap + rpm-touch storms. All 5 timer
        // sources funnel here; without this 3 check-updates.sh runs queue up.
        checkCoalesce.restart()
    }
    Timer {
        id: checkCoalesce
        interval: 2000; repeat: false
        onTriggered: {
            if (updProc.running) return
            checking = true
            updProc.running = true
        }
    }
    function status(): string {
        return "system=" + _counts.system + " flatpak=" + _counts.flatpak
            + " total=" + totalCount + " hasUpdates=" + hasUpdates
            + " checking=" + checking + " schedule=\"" + checkSchedule + "\""
            + " debugForce=" + debugForce + " display=" + displayCount
    }
    function setDebug(arg: string): string {
        let a = (arg || "").trim().toLowerCase()
        if (a === "on" || a === "true" || a === "1" || a === "show") { debugForce = true; return "debugForce=ON display=" + displayCount }
        if (a === "off" || a === "false" || a === "0" || a === "hide") { debugForce = false; return "debugForce=OFF hasUpdates=" + hasUpdates }
        if (a === "toggle") { debugForce = !debugForce; return "debugForce=" + debugForce }
        if (a.startsWith("count")) { let parts = a.split(/\s+/); let n = parseInt(parts[1]); if (!isNaN(n)) { debugCount = n; debugForce = true; return "debugCount=" + n } }
        let n = parseInt(a); if (!isNaN(n)) { debugCount = n; debugForce = true; return "debugCount=" + n }
        return "usage: debug on|off|toggle|count <n> | debug 5"
    }

    // CPU: status() used to scan updates 2x (system+flatpak). Single pass.
    function count(source: string): int {
        let total = 0
        for (let i = 0; i < updates.length; i++) if (updates[i].source === source) total++
        return total
    }
    // Cached per-updates-change breakdown so status()/panel header don't
    // re-scan the list on every binding evaluation.
    readonly property var _counts: {
        let s = 0, f = 0
        for (let i = 0; i < updates.length; i++) {
            let src = updates[i].source
            if (src === "system") s++
            else if (src === "flatpak") f++
        }
        return { system: s, flatpak: f }
    }

    function parseUpdates(raw: string): void {
        let parsed = []
        let nextKeys = ({})
        let newlyAvailable = 0
        let lines = String(raw || "").trim().split("\n")
        for (let i = 0; i < lines.length; i++) {
            if (!lines[i]) continue
            let fields = lines[i].split("\t")
            if (fields.length < 3) continue
            if (fields[0] !== "system" && fields[0] !== "flatpak") continue
            if ((fields[1] || "").trim().length === 0) continue
            let item = { source: fields[0], name: fields[1], detail: fields.slice(2).join("\t") }
            let key = item.source + "\t" + item.name
            nextKeys[key] = true
            if (hasCompletedFirstCheck && !knownUpdateKeys[key]) newlyAvailable++
            parsed.push(item)
        }
        // PERF: compare-before-assign. Identical check results (the common
        // case) must not reset panel Repeaters + _counts bindings.
        let same = parsed.length === updates.length
        if (same) {
            let oldKeys = knownUpdateKeys
            let newCount = 0, oldCount = 0
            for (let k in nextKeys) newCount++
            for (let k in oldKeys) oldCount++
            same = newCount === oldCount
            if (same) {
                for (let k in nextKeys) {
                    if (!oldKeys[k]) { same = false; break }
                }
            }
            if (same) {
                for (let i = 0; i < parsed.length; i++) {
                    let a = parsed[i], b = updates[i]
                    if (!b || a.source !== b.source || a.name !== b.name || a.detail !== b.detail) {
                        same = false; break
                    }
                }
            }
        }
        lastCheckedAt = new Date()
        hasCompletedFirstCheck = true
        if (same) return
        updates = parsed
        knownUpdateKeys = nextKeys
        if (newlyAvailable > 0) notifyNewUpdates(newlyAvailable)
    }

    function notifyNewUpdates(n: int): void {
        let message = n === 1 ? "1 new update is available." : n + " new updates are available."
        notifyProc.command = ["notify-send", "Update Center", message]
        if (!notifyProc.running) notifyProc.running = true
    }
    Process { id: notifyProc; command: ["notify-send", "Update Center", ""] }

    Process {
        id: updProc
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/jhqs/scripts/check-updates.sh"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseUpdates(text)
        }
        onExited: root.checking = false
    }

    Timer {
        id: pollTimer
        interval: root.checkIntervalMs > 0 ? root.checkIntervalMs : 60000
        running: root.checkIntervalMs > 0
        repeat: true
        onTriggered: root.checkNow()
    }
    Timer { id: startupTimer; interval: 60000; running: true; repeat: false; onTriggered: root.checkNow() }

    Timer { id: netActiveTimer; interval: 8000; repeat: false; onTriggered: root.checkNow() }
    Connections { target: NetworkService; function onNetActiveChanged() { if (NetworkService.netActive) netActiveTimer.restart() } }

    property double _lastDnfMtime: 0
    Process {
        id: dnfMtimeProc
        command: ["bash", "-c", "stat -c %Y /var/log/dnf5.log 2>/dev/null | tr -d '\\n'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let n = parseInt(((text || "").trim() || "0"))
                if (isNaN(n)) return
                if (root._lastDnfMtime === 0) { root._lastDnfMtime = n; return }
                if (n !== root._lastDnfMtime) { root._lastDnfMtime = n; externalTimer.restart() }
            }
        }
    }
    Timer { id: dnfMtimeTimer; interval: 1800000; running: true; repeat: true; triggeredOnStart: false; onTriggered: if (!dnfMtimeProc.running) dnfMtimeProc.running = true }
    Timer { id: externalTimer; interval: 4000; repeat: false; onTriggered: root.checkNow() }
}
