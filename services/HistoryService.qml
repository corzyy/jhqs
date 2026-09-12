pragma Singleton
import QtQuick
import Quickshell

// RAM: history entries are capped and large strings truncated so 100
// notifications cannot pin MBs of markup.
// NOTE: `import Quickshell` is required — it provides the `Singleton` type.
Singleton {
    id: root
    property var history: []
    readonly property int maxHistory: 100
    // PERF: burst-coalesced adds. Notification bursts (20+ toasts) used to
    // copy the array + notify all consumers per toast. Now appends queue
    // and flush once per event loop tick.
    property var _pending: []
    property bool _flushScheduled: false
    function add(entry: var): void {
        let safe = sanitize(entry)
        if (!safe) return
        _pending.push(safe)
        if (!_flushScheduled) {
            _flushScheduled = true
            Qt.callLater(flushPending)
        }
    }
    function flushPending(): void {
        _flushScheduled = false
        if (_pending.length === 0) return
        let next = history.concat(_pending)
        _pending = []
        if (next.length > maxHistory) next = next.slice(-maxHistory)
        history = next
    }
    function sanitize(entry: var): var {
        // CRASH FIX: only plain JSON-safe types may enter history.
        // Storing notification.actions (list<NotificationAction QObjects>)
        // or other Qt objects makes the CalendarMenu Repeaters segfault
        // in QV4::fromData/fromQVariantMap on open (all recent crashes
        // share that stack). Rebuild a sanitized snapshot here so no
        // caller can smuggle a QObject into `history`.
        let safe = null
        try {
            if (!entry) return null
            let sid = Number(entry.id)
            if (!isFinite(sid)) sid = -1
            let sUrg = Number(entry.urgency)
            if (!isFinite(sUrg)) sUrg = 1
            let sTime = 0
            try {
                let t = entry.time
                if (typeof t === "number" && isFinite(t)) sTime = Math.round(t)
                else if (t instanceof Date && !isNaN(t.getTime())) sTime = t.getTime()
                else if (t !== undefined && t !== null) {
                    let d = new Date(t)
                    sTime = isNaN(d.getTime()) ? Date.now() : d.getTime()
                } else sTime = Date.now()
            } catch (e) { sTime = Date.now() }
            safe = {
                id: Math.round(sid),
                appName: String(entry.appName || "Notification").slice(0, 120),
                summary: String(entry.summary || "").slice(0, 300),
                body: String(entry.body || "").slice(0, 500),
                urgency: Math.round(sUrg),
                time: Math.round(sTime)
            }
        } catch (e) { return null }
        return safe
    }
    function remove(id: int): void {
        let before = history.length
        if (before === 0) return
        let next = history.filter(e => e.id !== id)
        if (next.length === before) return
        history = next
    }
    function clear(): void { if (history.length === 0 && _pending.length === 0) return; _pending = []; history = [] }
    // NOTE: count() removed — dead wrapper, callers use history.length.
}
