pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// UmbrielService — Umbriel (wlroots-based) compatibility layer for the bar's
// Workspaces and ActiveWindow widgets. Exposes the workspace API shape
// (tags / tagsFor / activateTag / nextTag / prevTag) plus focused window
// identity (focusedAppId / focusedTitle), so widgets stay backend-agnostic.
//
// Data/actions used here:
//   umbriel subscribe workspaces  -> {"data":[{id,name,named,index,output,
//                                    active,focused,layout,occupied}],
//                                    "event":"workspaces"} per JSON line
//   umbriel workspaces --json     -> same array, one-shot (safety poll)
//   umbriel subscribe windows     -> {"data":[{app_id,title,focused,floating,
//                                    workspace,...}],"event":"windows"}
//   umbriel msg workspace-switch:<i>[/<output>] -> activate workspace i
//   umbriel msg workspace-next|workspace-previous -> cycle focused output
//
// Workspaces always exist (static inventory / dynamic inventory with
// sentinels), so there is nothing to pin locally.
Singleton {
    id: root

    // ---- compositor detection (env only, no process spawn) ----
    readonly property string _desktopSig: ((Quickshell.env("XDG_CURRENT_DESKTOP") || "") + " "
        + (Quickshell.env("XDG_SESSION_DESKTOP") || "") + " "
        + (Quickshell.env("DESKTOP_SESSION") || "")).toLowerCase()
    readonly property bool isUmbriel: _desktopSig.indexOf("umbriel") !== -1
    readonly property string compositor: isUmbriel ? "umbriel" : "unknown"

    // ---- live state (umbriel only) ----
    property int tagCount: 10
    // Preferred display: DP-1 when present, else the first Quickshell screen
    // so machines without DP-1 start on a real display.
    function preferredMonitorName(): string {
        try {
            let v = Quickshell.screens.values
            let vals = (v && typeof v.length === "number") ? v : []
            for (let i = 0; i < vals.length; i++) {
                if (vals[i] && vals[i].name === "DP-1") return "DP-1"
            }
            if (vals.length > 0 && vals[0] && vals[0].name) return "" + vals[0].name
        } catch (e) {}
        return "DP-1"
    }
    // Output of the globally targeted workspace (umbriel marks it focused).
    property string focusedMonitor: preferredMonitorName()
    // Workspaces for the focused output: [{index, active, urgent, clients,
    // layout, name}] — canonical workspace shape.
    property var tags: []
    // output -> {tags: [raw workspace entries from the subscription]}
    property var monitors: ({})
    // Focused window identity (umbriel subscribe windows), used by the bar's
    // ActiveWindow widget. `focused` is per-output workspace focus, so the
    // entry matching focusedMonitor wins.
    property string focusedAppId: ""
    property string focusedTitle: ""
    property bool focusedFloating: false
    // Umbriel keeps configured workspaces alive, so the bar shows the full
    // inventory by default; hide-empty stays opt-in.
    property bool dynamicTags: false
    property string lastError: ""

    function status(): string {
        return "compositor=" + compositor + " isUmbriel=" + isUmbriel
            + " monitor=" + focusedMonitor + " tags=" + tags.length
    }
    function refresh(): void {
        if (!isUmbriel) return
        if (!pollProc.running) pollProc.running = true
        if (!persistDebounce.running && !applyProc.running) syncAppearance()
    }

    // ---- live watch (instant updates) + one-shot poll safety net ----
    // The subscription pushes one JSON line per change, including the current
    // state right after connecting. The 10s poll covers dropped connections
    // and reconnects without a shell restart.
    Process {
        id: workspacesWatch
        running: root.isUmbriel
        command: ["umbriel", "subscribe", "workspaces"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.parseWorkspaces(data)
        }
        onExited: (code, status) => { if (root.isUmbriel) workspacesWatchRestart.restart() }
    }
    Timer {
        id: workspacesWatchRestart
        interval: 1000; repeat: false
        onTriggered: { if (root.isUmbriel && !workspacesWatch.running) workspacesWatch.running = true }
    }
    Process {
        id: pollProc
        command: ["umbriel", "workspaces", "--json"]
        stdout: StdioCollector {
            onStreamFinished: root.parseWorkspaces(text || "")
        }
    }
    Timer {
        id: pollTimer
        interval: 10000; running: root.isUmbriel; repeat: true; triggeredOnStart: true
        onTriggered: { if (root.isUmbriel && !pollProc.running) pollProc.running = true }
    }
    // Window focus/title stream for ActiveWindow; pushes the current state on
    // connect, so no separate one-shot poll is needed.
    Process {
        id: windowsWatch
        running: root.isUmbriel
        command: ["umbriel", "subscribe", "windows"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.parseWindows(data)
        }
        onExited: (code, status) => { if (root.isUmbriel) windowsWatchRestart.restart() }
    }
    Timer {
        id: windowsWatchRestart
        interval: 1000; repeat: false
        onTriggered: { if (root.isUmbriel && !windowsWatch.running) windowsWatch.running = true }
    }

    function tagsEqual(a: var, b: var): bool {
        try {
            if (!a || !b || a.length !== b.length) return false
            for (let i = 0; i < a.length; i++) {
                if (a[i].index !== b[i].index || !!a[i].active !== !!b[i].active
                    || a[i].clients !== b[i].clients || a[i].layout !== b[i].layout
                    || ("" + a[i].name) !== ("" + b[i].name)) return false
            }
            return true
        } catch (e) { return false }
    }

    // Raw workspace entries -> canonical tag shape (ui order, 1-based index).
    function projectTags(list: var): var {
        const arr = []
        for (let i = 0; i < (list || []).length; i++) {
            const w = list[i]
            if (!w) continue
            const idx = parseInt(w.index)
            const name = (w.name !== undefined && w.name !== null && ("" + w.name).length > 0)
                ? ("" + w.name) : ("" + (isNaN(idx) ? i + 1 : idx))
            arr.push({
                index: isNaN(idx) ? i + 1 : idx,
                active: !!w.active,
                urgent: false,
                clients: w.occupied ? 1 : 0,
                layout: (w.layout || "") + "",
                name: name
            })
        }
        arr.sort((a, b) => a.index - b.index)
        return arr
    }
    function tagsFor(screenName: string): var {
        try {
            let name = ((screenName || "") + "").trim() || focusedMonitor
            let m = monitors[name]
            if (!m) {
                if (name !== focusedMonitor && monitors[focusedMonitor]) m = monitors[focusedMonitor]
                else return tags
            }
            if (!m) return tags
            return projectTags(m.tags || [])
        } catch (e) { try { return tags } catch (e2) { return [] } }
    }
    function tagCountFor(screenName: string): int {
        try {
            let tl = tagsFor(screenName)
            if (tl && tl.length > 0) return tl.length
        } catch (e) {}
        return tagCount
    }
    function isPinned(idx: int): bool {
        return false
    }

    function parseWorkspaces(out: string): void {
        try {
            let t = (out || "").trim()
            if (t.length === 0) return
            let j = JSON.parse(t)
            let list = Array.isArray(j) ? j : (j.data || [])
            if (!Array.isArray(list) || list.length === 0) return
            let mmap = {}
            let focused = focusedMonitor
            for (let i = 0; i < list.length; i++) {
                let w = list[i]
                if (!w || !w.output) continue
                let m = mmap[w.output]
                if (!m) {
                    m = { tags: [] }
                    mmap[w.output] = m
                }
                m.tags.push(w)
                if (w.focused) focused = w.output
            }
            // Fall back to the preferred display when nothing claims focus.
            if (!mmap[focused]) {
                let pref = preferredMonitorName()
                if (mmap[pref]) focused = pref
                else for (let k in mmap) { focused = k; break }
            }
            // Always publish the fresh map so per-screen readers never stale.
            monitors = mmap
            if (focusedMonitor !== focused) focusedMonitor = focused
            let fm = mmap[focused]
            const arr = fm ? projectTags(fm.tags) : []
            if (!tagsEqual(tags, arr)) tags = arr
            if (arr.length > 0) tagCount = arr.length
            watchLayoutSwitch(fm)
        } catch (e) { lastError = "workspaces: " + e }
    }

    // Window list -> focused window identity. `focused` is workspace-local
    // remembered focus, so several outputs can report one; prefer the entry
    // on focusedMonitor's workspace.
    function parseWindows(out: string): void {
        try {
            let t = (out || "").trim()
            if (t.length === 0) return
            let j = JSON.parse(t)
            let list = Array.isArray(j) ? j : (j.data || [])
            if (!Array.isArray(list)) return
            let prefix = focusedMonitor + ":"
            let win = null
            for (let i = 0; i < list.length; i++) {
                let w = list[i]
                if (!w || !w.focused) continue
                if (("" + (w.workspace || "")).indexOf(prefix) === 0) { win = w; break }
                if (!win) win = w
            }
            let na = win ? ("" + (win.app_id || "")) : ""
            let nt = win ? ("" + (win.title || "")) : ""
            let nf = win ? !!win.floating : false
            if (focusedAppId !== na) focusedAppId = na
            if (focusedTitle !== nt) focusedTitle = nt
            if (focusedFloating !== nf) focusedFloating = nf
        } catch (e) { lastError = "windows: " + e }
    }

    // ---- layout switch notification ----
    // `workspace-set-layout:toggle` (Mod+N) changes the active workspace's
    // layout; the subscription line carries it. Same workspace + new layout =
    // a switch. Focusing another workspace with a different layout stays
    // silent. notify-send lands in the shell's own notification server.
    property string _activeLayoutKey: ""
    property string _activeLayout: ""
    property string _pendingLayoutNotify: ""
    function watchLayoutSwitch(fm: var): void {
        let active = null
        let tl = fm ? (fm.tags || []) : []
        for (let i = 0; i < tl.length; i++) {
            if (tl[i] && tl[i].active) { active = tl[i]; break }
        }
        if (!active) { _activeLayoutKey = ""; return }
        let key = ("" + active.output) + ":" + active.index
        let lay = ("" + (active.layout || "")).toLowerCase()
        if (key === _activeLayoutKey && lay.length > 0 && lay !== _activeLayout)
            notifyLayoutChanged(lay)
        _activeLayoutKey = key
        _activeLayout = lay
    }
    Process {
        id: layoutNotifyProc
        command: ["notify-send", "-u", "low", "-a", "jhqs", "Layout", ""]
        onExited: {
            if (root._pendingLayoutNotify.length === 0) return
            let l = root._pendingLayoutNotify
            root._pendingLayoutNotify = ""
            root.sendLayoutNotification(l)
        }
    }
    function sendLayoutNotification(layout: string): void {
        layoutNotifyProc.command = ["notify-send", "-u", "low", "-a", "jhqs", "Layout",
            layout.substring(0, 1).toUpperCase() + layout.substring(1)]
        layoutNotifyProc.running = true
    }
    function notifyLayoutChanged(layout: string): void {
        let l = (layout || "").trim().toLowerCase()
        if (l.length === 0) return
        if (layoutNotifyProc.running) { _pendingLayoutNotify = l; return }
        sendLayoutNotification(l)
    }

    // ---- dispatch helpers ----
    // Clicks/wheel are sparse but can burst: keep a FIFO so no step of a
    // wheel cycle is dropped, and run one `umbriel msg` at a time.
    Process {
        id: dispatchProc
        command: ["umbriel", "msg", "noop"]
        onExited: root.pumpDispatch()
    }
    property var _queue: []
    function dispatch(action: string): void {
        if (!isUmbriel) return
        let a = (action || "").trim()
        if (a.length === 0) return
        _queue.push(a)
        pumpDispatch()
    }
    function pumpDispatch(): void {
        if (dispatchProc.running) return
        if (_queue.length === 0) return
        dispatchProc.command = ["umbriel", "msg", _queue.shift()]
        dispatchProc.running = true
    }
    // Optimistic local echo so the highlight moves on click, not on the next
    // subscription line. The live watch (~5ms) corrects it right after.
    function optimisticView(idx: int, screenName: string): void {
        try {
            let i = Math.max(1, Math.min(64, Math.round(idx)))
            let target = ((screenName || "") + "").trim() || focusedMonitor
            let m = monitors[target]
            if (!m) return
            let ntl = []
            let tl = m.tags || []
            for (let ti = 0; ti < tl.length; ti++) {
                let w = tl[ti]
                ntl.push({
                    index: w.index, output: w.output, name: w.name, layout: w.layout,
                    active: parseInt(w.index) === i, focused: !!w.focused, occupied: !!w.occupied
                })
            }
            let nmm = {}
            for (let k in monitors) nmm[k] = monitors[k]
            nmm[target] = { tags: ntl }
            monitors = nmm
            if (target === focusedMonitor) {
                const arr = projectTags(ntl)
                if (!tagsEqual(tags, arr)) tags = arr
            }
        } catch (e) {}
    }
    // `workspace-switch:<i>/<output>` targets the bar's screen explicitly;
    // without an output it acts on the output under the pointer.
    function activateTag(idx: int, screenName: string): void {
        let i = Math.max(1, Math.min(64, Math.round(idx)))
        optimisticView(i, screenName)
        let target = ((screenName || "") + "").trim()
        dispatch("workspace-switch:" + i + (target.length > 0 ? "/" + target : ""))
    }
    // next/prev act on the output Umbriel targets for actions.
    function nextTag(screenName: string): void {
        dispatch("workspace-next")
    }
    function prevTag(screenName: string): void {
        dispatch("workspace-previous")
    }

    // ---- appearance settings (shell-managed configs/shell.toml) ----
    // The Appearance > Umbriel settings page edits these. Persistence goes
    // through scripts/umbriel-apply.py, which rewrites the optional include
    // configs/shell.toml and asks Umbriel to reload. Defaults match the
    // hand-written configs; syncAppearance() loads the effective values.
    property bool umbAppearanceLoaded: false
    property string umbLayout: "dwindle"
    property int umbGap: 10
    property int umbBorderWidth: 3
    property int umbCornerRadius: 10
    property bool umbBlurEnabled: true
    property bool umbBlurOptimized: true
    // Shell layer override (configs/shell.toml): one cached backdrop shared by
    // the bar and panels. Off = per-surface blur, which samples the bar behind
    // the panel's top edge and can show an edge at the fused joint.
    property bool umbShellBlurOptimized: true
    property bool umbShadowEnabled: false
    property bool umbAnimations: true
    property string umbAnimOpen: "slide"
    property string umbAnimClose: "slide"
    property int umbAnimDurOpen: 400
    property int umbAnimDurClose: 800
    property int umbAnimDurMove: 500
    property int umbAnimDurWorkspace: 400

    readonly property string _applyScript: Quickshell.env("HOME") + "/.config/quickshell/jhqs/scripts/umbriel-apply.py"

    function _clampInt(v: var, lo: int, hi: int, fb: int): int {
        let n = Math.round(Number(v))
        if (!isFinite(n)) return fb
        return Math.max(lo, Math.min(hi, n))
    }

    function syncAppearance(): void {
        if (!isUmbriel || dumpProc.running) return
        dumpProc.running = true
    }
    Process {
        id: dumpProc
        command: ["python3", root._applyScript, "dump"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let j = JSON.parse((text || "").trim() || "{}")
                    root.umbLayout = ("" + (j.layout || root.umbLayout))
                    root.umbGap = root._clampInt(j.gap, 0, 500, root.umbGap)
                    root.umbBorderWidth = root._clampInt(j.borderWidth, 0, 100, root.umbBorderWidth)
                    root.umbCornerRadius = root._clampInt(j.cornerRadius, 0, 100, root.umbCornerRadius)
                    root.umbBlurEnabled = j.blur !== false
                    root.umbBlurOptimized = j.blurOptimized !== false
                    root.umbShellBlurOptimized = j.shellBlurOptimized !== false
                    root.umbShadowEnabled = j.shadows === true
                    root.umbAnimations = j.animations !== false
                    root.umbAnimOpen = ("" + (j.animOpen || root.umbAnimOpen))
                    root.umbAnimClose = ("" + (j.animClose || root.umbAnimClose))
                    root.umbAnimDurOpen = root._clampInt(j.animDurOpen, 1, 10000, root.umbAnimDurOpen)
                    root.umbAnimDurClose = root._clampInt(j.animDurClose, 1, 10000, root.umbAnimDurClose)
                    root.umbAnimDurMove = root._clampInt(j.animDurMove, 1, 10000, root.umbAnimDurMove)
                    root.umbAnimDurWorkspace = root._clampInt(j.animDurWorkspace, 1, 10000, root.umbAnimDurWorkspace)
                    root.umbAppearanceLoaded = true
                } catch (e) { root.lastError = "appearance: " + e }
            }
        }
    }

    Timer { id: persistDebounce; interval: 200; repeat: false; onTriggered: root.persist() }
    property string _pendingPayload: ""
    Process {
        id: applyProc
        onExited: (code, status) => {
            if (root._pendingPayload.length > 0) {
                let p = root._pendingPayload
                root._pendingPayload = ""
                root._runApply(p)
            }
        }
    }
    function _runApply(payload: string): void {
        applyProc.command = ["python3", root._applyScript, "apply", payload]
        applyProc.running = true
    }
    function persist(): void {
        if (!isUmbriel) return
        let payload = JSON.stringify({
            layout: umbLayout,
            gap: umbGap,
            borderWidth: umbBorderWidth,
            cornerRadius: umbCornerRadius,
            blur: umbBlurEnabled,
            blurOptimized: umbBlurOptimized,
            shellBlurOptimized: umbShellBlurOptimized,
            shadows: umbShadowEnabled,
            animations: umbAnimations,
            animOpen: umbAnimOpen,
            animClose: umbAnimClose,
            animDurOpen: umbAnimDurOpen,
            animDurClose: umbAnimDurClose,
            animDurMove: umbAnimDurMove,
            animDurWorkspace: umbAnimDurWorkspace
        })
        if (applyProc.running) { _pendingPayload = payload; return }
        _runApply(payload)
    }
    function _flushPersist(): void { persistDebounce.stop(); persist() }

    // Slider drags preview through here (debounced write); apply* flushes.
    function preview(key: string, value: var): void {
        if (!isUmbriel) return
        switch (key) {
        case "gap": umbGap = _clampInt(value, 0, 500, umbGap); break
        case "borderWidth": umbBorderWidth = _clampInt(value, 0, 100, umbBorderWidth); break
        case "cornerRadius": umbCornerRadius = _clampInt(value, 0, 100, umbCornerRadius); break
        case "animDurOpen": umbAnimDurOpen = _clampInt(value, 1, 10000, umbAnimDurOpen); break
        case "animDurClose": umbAnimDurClose = _clampInt(value, 1, 10000, umbAnimDurClose); break
        case "animDurMove": umbAnimDurMove = _clampInt(value, 1, 10000, umbAnimDurMove); break
        case "animDurWorkspace": umbAnimDurWorkspace = _clampInt(value, 1, 10000, umbAnimDurWorkspace); break
        default: return
        }
        persistDebounce.restart()
    }
    function applyLayout(mode: string): void { umbLayout = mode; _flushPersist() }
    function applyGap(v: var): void { umbGap = _clampInt(v, 0, 500, umbGap); _flushPersist() }
    function applyBorderWidth(v: var): void { umbBorderWidth = _clampInt(v, 0, 100, umbBorderWidth); _flushPersist() }
    function applyCornerRadius(v: var): void { umbCornerRadius = _clampInt(v, 0, 100, umbCornerRadius); _flushPersist() }
    function applyAnimations(on: bool): void { umbAnimations = !!on; _flushPersist() }
    function applyAnimType(which: string, style: string): void {
        if (which === "close") umbAnimClose = style
        else umbAnimOpen = style
        _flushPersist()
    }
    function applyAnimDur(which: string, ms: var): void {
        if (which === "close") umbAnimDurClose = _clampInt(ms, 1, 10000, umbAnimDurClose)
        else if (which === "move") umbAnimDurMove = _clampInt(ms, 1, 10000, umbAnimDurMove)
        else if (which === "workspace") umbAnimDurWorkspace = _clampInt(ms, 1, 10000, umbAnimDurWorkspace)
        else umbAnimDurOpen = _clampInt(ms, 1, 10000, umbAnimDurOpen)
        _flushPersist()
    }
    function applyBlur(on: bool): void { umbBlurEnabled = !!on; _flushPersist() }
    function applyBlurOptimized(on: bool): void { umbBlurOptimized = !!on; _flushPersist() }
    function applyShellBlurOptimized(on: bool): void { umbShellBlurOptimized = !!on; _flushPersist() }
    function applyShadows(on: bool): void { umbShadowEnabled = !!on; _flushPersist() }

    Component.onCompleted: syncAppearance()

    IpcHandler {
        target: "umbriel"
        function status(): string { return root.status() }
        function refresh(): string { root.refresh(); return root.status() }
        function view(tag: int): string { root.activateTag(tag, ""); return "view=" + tag }
        function appearance(): string {
            return JSON.stringify({
                loaded: root.umbAppearanceLoaded,
                layout: root.umbLayout,
                gap: root.umbGap,
                borderWidth: root.umbBorderWidth,
                cornerRadius: root.umbCornerRadius,
                blur: root.umbBlurEnabled,
                blurOptimized: root.umbBlurOptimized,
                shellBlurOptimized: root.umbShellBlurOptimized,
                shadows: root.umbShadowEnabled,
                animations: root.umbAnimations,
                animOpen: root.umbAnimOpen,
                animClose: root.umbAnimClose,
                animDurOpen: root.umbAnimDurOpen,
                animDurClose: root.umbAnimDurClose,
                animDurMove: root.umbAnimDurMove,
                animDurWorkspace: root.umbAnimDurWorkspace
            })
        }
    }
}
