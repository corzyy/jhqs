pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// MangoService — MangoWM (mangowm/mango, dwl-based) compatibility layer.
//
// The bar's Workspaces/ActiveWindow widgets read their state from here via
// the `mmsg` CLI. This
// singleton mirrors the small subset jhqs needs via the `mmsg` CLI:
//
//   mmsg get all-monitors   -> tags per monitor + active_client title/appid
//   mmsg get focusing-client -> focused title/appid/fullscreen/floating
//   mmsg get all-clients     -> fullscreen map per monitor (TopBar hide)
//   mmsg dispatch view,<i>,0 -> activate tag i (1-based, like binds-system.conf)
//   mmsg dispatch viewtoleft_have_client,0 / viewtoright_have_client,0 -> cycle
//   mmsg dispatch setoption,<key>,<value> -> live look preview
//
// Look persistence lives in config/mango.json (FileView) and is written to
// ~/.config/mango/configs/looknfeel.conf via scripts/mango-apply.py
// (atomic, idempotent). Polls only run when isMango is true.
Singleton {
    id: root

    // ---- compositor detection (env only, no process spawn) ----
    readonly property string _mangoSig: (Quickshell.env("MANGO_INSTANCE_SIGNATURE") || "")
    readonly property string _xdgDesktop: ((Quickshell.env("XDG_CURRENT_DESKTOP") || "") + " " + (Quickshell.env("XDG_SESSION_DESKTOP") || "")).toLowerCase()
    readonly property bool isMango: _mangoSig.length > 0 || _xdgDesktop.indexOf("mango") !== -1
    readonly property string compositor: isMango ? "mango" : "unknown"

    // ---- live state (mango only) ----
    property int tagCount: 10
    // Preferred display: DP-1 when present, else the first Quickshell
    // screen — so machines without DP-1 start on a real display. The
    // first parseMonitors poll keeps this live afterwards (assignment
    // replaces this initial binding, which is intended).
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
    property string focusedMonitor: preferredMonitorName()
    // tags for the focused monitor: [{index, active, urgent, clients, layout}]
    property var tags: []
    // all monitors raw (name -> {active, activeTags, tags, activeClient})
    property var monitors: ({})
    property string focusedTitle: ""
    property string focusedAppId: ""
    property bool focusedFullscreen: false
    property bool focusedFloating: false
    // monitor name -> bool (any *visible* client fullscreen/fakefullscreen).
    // Hidden tags / minimized clients stay listed in all-clients, so
    // is_visible must be checked or the bar keeps zone 0 after switching
    // to a workspace without fullscreen.
    property var fullscreenByScreen: ({})
    // Tag indices with no_hide:1 in workspaces.conf (pinned, always shown in
    // dynamic mode). Not exposed via mmsg, so parsed from the file.
    property var pinnedTags: []
    function isPinned(idx: int): bool {
        try { return pinnedTags.indexOf(idx) >= 0 } catch (e) { return false }
    }
    property string lastError: ""

    function status(): string {
        return "compositor=" + compositor + " isMango=" + isMango
            + " monitor=" + focusedMonitor + " tags=" + tags.length
            + " focused=" + focusedAppId + "/" + focusedTitle
            + " fullscreen=" + focusedFullscreen
    }
    function refresh(): void {
        if (!isMango) return
        if (!monitorsProc.running) monitorsProc.running = true
        if (!clientsProc.running) clientsProc.running = true
        if (!pinProc.running) pinProc.running = true
    }

    Process {
        id: monitorsProc
        command: ["bash", "-c", "mmsg get all-monitors 2>/dev/null || mmsg -g 2>/dev/null | head -c 65536"]
        stdout: StdioCollector {
            onStreamFinished: root.parseMonitors(text || "")
        }
    }
    Process {
        id: clientsProc
        command: ["bash", "-c", "mmsg get all-clients 2>/dev/null | head -c 131072"]
        stdout: StdioCollector {
            onStreamFinished: root.parseClients(text || "")
        }
    }
    Process {
        id: focusProc
        command: ["bash", "-c", "mmsg get focusing-client 2>/dev/null | head -c 8192"]
        stdout: StdioCollector {
            onStreamFinished: root.parseFocus(text || "")
        }
    }
    Process {
        id: pinProc
        // NOTE: kept the grep chain (every 30s — negligible). Correctness over
        // micro-perf here; the win is compare-before-assign below.
        command: ["bash", "-c", "grep -E '^tagrule=' ~/.config/mango/configs/workspaces.conf 2>/dev/null | grep -E 'no_hide\\s*:\\s*1(\\s*,|\\s*$)' | grep -oE 'id\\s*:\\s*[0-9]+' | grep -oE '[0-9]+'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let out = (text || "").trim()
                    let next = out.length === 0 ? [] : out.split(/\s+/).map(s => parseInt(s)).filter(n => !isNaN(n))
                    // PERF: compare-before-assign (isPinned() fans out to all
                    // workspace delegates on every poll).
                    let cur = root.pinnedTags
                    if (cur.length !== next.length) { root.pinnedTags = next; return }
                    for (let i = 0; i < next.length; i++) {
                        if (cur[i] !== next[i]) { root.pinnedTags = next; return }
                    }
                } catch (e) {}
            }
        }
    }
    Timer {
        id: pinTimer
        interval: 30000; running: root.isMango; repeat: true; triggeredOnStart: true
        onTriggered: { if (!pinProc.running) pinProc.running = true }
    }
    // ---- live watches (instant updates, no poll lag) ----
    // `mmsg watch` pushes one JSON object per line on every compositor
    // change (~5ms). The old 2.5s poll made the workspace indicator visibly
    // lag behind tag switches; watches fix that. One-shot pollTimer below
    // stays as a safety net for dropped watch events / reconnects.
    Process {
        id: monitorsWatch
        running: root.isMango
        command: ["mmsg", "watch", "all-monitors"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.parseMonitors(data)
        }
        onExited: (code, status) => { if (root.isMango) monitorsWatchRestart.restart() }
    }
    Timer {
        id: monitorsWatchRestart
        interval: 1000; repeat: false
        onTriggered: { if (root.isMango && !monitorsWatch.running) monitorsWatch.running = true }
    }
    Process {
        id: clientsWatch
        running: root.isMango
        command: ["mmsg", "watch", "all-clients"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.parseClients(data)
        }
        onExited: (code, status) => { if (root.isMango) clientsWatchRestart.restart() }
    }
    Timer {
        id: clientsWatchRestart
        interval: 1000; repeat: false
        onTriggered: { if (root.isMango && !clientsWatch.running) clientsWatch.running = true }
    }
    Process {
        id: focusWatch
        running: root.isMango
        command: ["mmsg", "watch", "focusing-client"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.parseFocus(data)
        }
        onExited: (code, status) => { if (root.isMango) focusWatchRestart.restart() }
    }
    Timer {
        id: focusWatchRestart
        interval: 1000; repeat: false
        onTriggered: { if (root.isMango && !focusWatch.running) focusWatch.running = true }
    }
    Timer {
        id: pollTimer
        // Safety net only — watches are the primary source now.
        // 10s (was 2.5s): each tick forks mmsg + JSON.parse on the GUI
        // thread, so keep it rare.
        interval: 10000; running: root.isMango; repeat: true; triggeredOnStart: true
        onTriggered: {
            if (!root.isMango) return
            if (!monitorsProc.running) monitorsProc.running = true
            // Alternate heavyweight polls: clients (fullscreen) then focus.
            if (pollTimer._flip) { if (!clientsProc.running) clientsProc.running = true }
            else { if (!focusProc.running) focusProc.running = true }
            pollTimer._flip = !pollTimer._flip
        }
        property bool _flip: false
    }

    function tagsEqual(a: var, b: var): bool {
        try {
            if (!a || !b || a.length !== b.length) return false
            for (let i = 0; i < a.length; i++) {
                if (a[i].index !== b[i].index || !!a[i].active !== !!b[i].active
                    || !!a[i].urgent !== !!b[i].urgent || a[i].clients !== b[i].clients
                    || a[i].layout !== b[i].layout) return false
            }
            return true
        } catch (e) { return false }
    }
    // Per-screen tags in the same shape as `tags`:
    // [{index, active, urgent, clients, layout}], sorted by index.
    // The bar lives on one screen (the Theme primary screen) while `tags`
    // tracks the focused monitor — Workspaces must use tagsFor(screenName)
    // or the highlight follows the wrong screen / lags behind focus changes.
    function tagsFor(screenName: string): var {
        try {
            let name = ((screenName || "") + "").trim() || focusedMonitor
            let m = monitors[name]
            if (!m) {
                if (name !== focusedMonitor && monitors[focusedMonitor]) m = monitors[focusedMonitor]
                else return tags
            }
            if (!m) return tags
            let tl = m.tags || []
            let arr = []
            for (let ti = 0; ti < tl.length; ti++) {
                let tg = tl[ti]
                arr.push({
                    index: tg.index,
                    active: !!tg.is_active,
                    urgent: !!tg.is_urgent,
                    clients: tg.client_count || 0,
                    layout: (tg.layout || "") + ""
                })
            }
            arr.sort((a, b) => a.index - b.index)
            return arr
        } catch (e) { try { return tags } catch (e2) { return [] } }
    }
    function tagCountFor(screenName: string): int {
        try {
            let tl = tagsFor(screenName)
            if (tl && tl.length > 0) return tl.length
            let name = ((screenName || "") + "").trim() || focusedMonitor
            let m = monitors[name]
            if (m && m.tag_num) return Math.max(1, Math.min(20, parseInt(m.tag_num) || 10))
        } catch (e) {}
        return tagCount
    }
    function parseMonitors(out: string): void {
        try {
            let t = (out || "").trim()
            if (t.length === 0) return
            let j = JSON.parse(t)
            let mons = j.monitors || j.all_monitors || []
            if (!Array.isArray(mons) || mons.length === 0) return
            let mmap = {}
            let focused = focusedMonitor
            for (let i = 0; i < mons.length; i++) {
                let m = mons[i]
                if (!m || !m.name) continue
                mmap[m.name] = m
                if (m.active) focused = m.name
            }
            // Fall back to the preferred display when nothing claims active.
            if (!mmap[focused]) {
                let pref = preferredMonitorName()
                if (mmap[pref]) focused = pref
                else for (let k in mmap) { focused = k; break }
            }
            // Live watches push every change (~5ms); missed-event safety poll
            // runs every 10s. Always publish the fresh map so per-screen
            // readers (tagsFor) never go stale. Duplicate watch lines are
            // cheap: downstream `tags` still uses compare-before-assign.
            monitors = mmap
            if (focusedMonitor !== focused) focusedMonitor = focused
            let fm = mmap[focused]
            if (fm) {
                let tl = fm.tags || []
                let arr = []
                for (let ti = 0; ti < tl.length; ti++) {
                    let tg = tl[ti]
                    arr.push({
                        index: tg.index,
                        active: !!tg.is_active,
                        urgent: !!tg.is_urgent,
                        clients: tg.client_count || 0,
                        layout: (tg.layout || "") + ""
                    })
                }
                arr.sort((a, b) => a.index - b.index)
                if (!tagsEqual(tags, arr)) tags = arr
                if (arr.length > 0) tagCount = arr.length
                else if (fm.tag_num) tagCount = Math.max(1, Math.min(20, parseInt(fm.tag_num) || 10))
                try {
                    let ac = fm.active_client
                    if (ac) {
                        if ((ac.title || "").length > 0 && focusedTitle !== ("" + ac.title)) focusedTitle = "" + ac.title
                        if ((ac.appid || "").length > 0 && focusedAppId !== ("" + ac.appid)) focusedAppId = "" + ac.appid
                    }
                } catch (e2) {}
            }
        } catch (e) { lastError = "monitors: " + e }
    }

    function parseFocus(out: string): void {
        try {
            let t = (out || "").trim()
            if (t.length === 0) return
            let c = JSON.parse(t)
            if (!c || typeof c !== "object") return
            if (c.title !== undefined) { let nt = "" + (c.title || ""); if (focusedTitle !== nt) focusedTitle = nt }
            if (c.appid !== undefined) { let na = "" + (c.appid || ""); if (focusedAppId !== na) focusedAppId = na }
            if (c.monitor) {
                // Trust focusing-client monitor over all-monitors active flag.
                if (monitors[c.monitor] !== undefined && focusedMonitor !== c.monitor) focusedMonitor = c.monitor
            }
            let nfs = !!(c.is_fullscreen || c.is_fakefullscreen || c.is_maximized)
            if (focusedFullscreen !== nfs) focusedFullscreen = nfs
            let nfl = !!c.is_floating
            if (focusedFloating !== nfl) focusedFloating = nfl
        } catch (e) { lastError = "focus: " + e }
    }

    function parseClients(out: string): void {
        try {
            let t = (out || "").trim()
            if (t.length === 0) return
            let j = JSON.parse(t)
            let list = j.clients || []
            if (!Array.isArray(list)) return
            let m = {}
            for (let i = 0; i < list.length; i++) {
                let c = list[i]
                if (!c || !c.monitor) continue
                // Only visible fullscreen counts: mmsg lists hidden-tag and
                // minimized clients too, which must not hold the bar hidden
                // (zone 0) after switching workspaces. Missing is_visible
                // defaults to counted for forward-compat.
                if ((c.is_fullscreen || c.is_fakefullscreen) && c.is_visible !== false) m[c.monitor] = true
                // Focused client doubles as ActiveWindow source when
                // all-monitors active_client lags one poll behind.
                try {
                    if (c.is_focused) {
                        if ((c.title || "").length > 0 && focusedTitle !== ("" + c.title)) focusedTitle = "" + c.title
                        if ((c.appid || "").length > 0 && focusedAppId !== ("" + c.appid)) focusedAppId = "" + c.appid
                        if (c.monitor && focusedMonitor !== c.monitor) focusedMonitor = c.monitor
                        let nfs2 = !!(c.is_fullscreen || c.is_fakefullscreen || c.is_maximized)
                        if (focusedFullscreen !== nfs2) focusedFullscreen = nfs2
                        let nfl2 = !!c.is_floating
                        if (focusedFloating !== nfl2) focusedFloating = nfl2
                    }
                } catch (e2) {}
            }
            // PERF: fullscreen map churn re-evaluates TopBar hide each poll.
            let ck = Object.keys(m), fk = Object.keys(fullscreenByScreen)
            if (ck.length !== fk.length) {
                fullscreenByScreen = m
            } else {
                let same = true
                for (let i = 0; i < ck.length; i++) {
                    if (!fullscreenByScreen[ck[i]]) { same = false; break }
                }
                if (!same) fullscreenByScreen = m
            }
        } catch (e) { lastError = "clients: " + e }
    }

    function isFullscreenOn(screenName: string): bool {
        try { return !!(fullscreenByScreen[screenName]) } catch (e) { return false }
    }

    // ---- dispatch helpers ----
    // Slider drags fire preview() at pointer-event rate while one mmsg round
    // trip costs ~50ms: a fire-and-forget slot would silently drop almost
    // every tick. Coalesce to the latest pending func instead — intermediate
    // values are obsolete the moment a newer one arrives.
    Process {
        id: dispatchProc
        command: ["bash", "-c", "echo"]
        onExited: root.pumpDispatch()
    }
    property var _dispatchPending: null
    function dispatch(func: string, skipRefresh: bool): void {
        let f = (func || "").trim()
        if (f.length === 0 || !isMango) return
        if (dispatchProc.running) { _dispatchPending = { f: f, nr: !!skipRefresh }; return }
        runDispatch(f)
        if (!skipRefresh) Qt.callLater(refresh)
    }
    function runDispatch(f: string): void {
        dispatchProc.command = ["bash", "-c", "mmsg dispatch " + f + " >/dev/null 2>&1"]
        dispatchProc.running = true
    }
    function pumpDispatch(): void {
        if (_dispatchPending === null || _dispatchPending === undefined) return
        let p = _dispatchPending
        _dispatchPending = null
        if (dispatchProc.running) { _dispatchPending = p; return }
        runDispatch(p.f)
        if (!p.nr) Qt.callLater(refresh)
    }
    // Optimistic local echo so the highlight moves on click, not on the
    // next compositor round-trip. The live watch (~5ms) corrects it right
    // after; tagsEqual guards keep no-op echoes cheap.
    function optimisticView(idx: int, screenName: string): void {
        try {
            let i = Math.max(1, Math.min(20, Math.round(idx)))
            let target = ((screenName || "") + "").trim()
            if (target.length > 0 && target !== focusedMonitor && monitors[target]) {
                let nm = {}
                for (let k in monitors) nm[k] = monitors[k]
                let m = nm[target]
                if (m) {
                    let ntl = []
                    let tl = m.tags || []
                    for (let ti = 0; ti < tl.length; ti++) {
                        let tg = tl[ti]
                        ntl.push({
                            index: tg.index,
                            is_active: tg.index === i,
                            is_urgent: !!tg.is_urgent,
                            client_count: tg.client_count || 0,
                            layout: (tg.layout || "") + ""
                        })
                    }
                    let nmm = {}
                    for (let fk in m) nmm[fk] = m[fk]
                    nmm.tags = ntl
                    nmm.active_tags = [i]
                    nm[target] = nmm
                    monitors = nm
                }
                return
            }
            if (!tags || tags.length === 0) return
            let nt = []
            for (let j = 0; j < tags.length; j++) {
                let t = tags[j]
                nt.push({ index: t.index, active: t.index === i, urgent: !!t.urgent, clients: t.clients || 0, layout: (t.layout || "") + "" })
            }
            if (!tagsEqual(tags, nt)) tags = nt
        } catch (e) {}
    }
    function activateTag(idx: int, screenName: string): void {
        let n = tagCountFor(screenName)
        let i = Math.max(1, Math.min(n, Math.round(idx)))
        optimisticView(i, screenName)
        let target = ((screenName || "") + "").trim()
        // `view,i,0` = focused monitor; `view,i,<name>` targets a screen.
        // The bar lives on the primary screen, so clicks must switch that
        // screen even when focus is on another monitor.
        if (target.length > 0) dispatch("view," + i + "," + target)
        else dispatch("view," + i + ",0")
    }
    function nextTag(screenName: string): void {
        let target = ((screenName || "") + "").trim()
        if (target.length > 0) dispatch("viewtoright_have_client," + target)
        else dispatch("viewtoright_have_client,0")
    }
    function prevTag(screenName: string): void {
        let target = ((screenName || "") + "").trim()
        if (target.length > 0) dispatch("viewtoleft_have_client," + target)
        else dispatch("viewtoleft_have_client,0")
    }
    function cycleLayout(): void { dispatch("switch_layout") }
    function setLayout(name: string): void {
        let n = (name || "").trim()
        if (n.length === 0) return
        dispatch("setlayout," + n)
    }

    // ================= look config =================
    // Mirrors ~/.config/mango/configs/looknfeel.conf. Persisted to
    // config/mango.json; live preview via `mmsg dispatch setoption,k,v`;
    // file persistence via scripts/mango-apply.py (atomic key=value upsert).
    FileView {
        id: mangoFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/mango.json"
        watchChanges: true; blockLoading: true; printErrors: false
        onFileChanged: mangoReloadDebounce.restart()
        adapter: JsonAdapter {
            property int gappih: 5
            property int gappiv: 5
            property int gappoh: 10
            property int gappov: 10
            property int borderpx: 4
            property int borderRadius: 6
            property real focusedOpacity: 1.0
            property real unfocusedOpacity: 1.0
            property bool smartgaps: false
            property bool noBorderWhenSingle: false
            property bool noRadiusWhenSingle: false
            property bool blur: false
            property bool blurLayer: false
            property int blurRadius: 5
            property int blurPasses: 2
            property real blurNoise: 0.02
            property real blurBrightness: 0.9
            property real blurContrast: 0.9
            property real blurSaturation: 1.2
            property bool shadows: false
            property bool shadowOnlyFloating: true
            property int shadowSize: 10
            property int shadowBlur: 15
            property string shadowColor: "#000000"
            property bool animations: true
            property string animOpen: "slide"
            property string animClose: "slide"
            property int animDurationOpen: 400
            property int animDurationClose: 800
            property int animDurationMove: 500
            property int animDurationTag: 350
            property string rootColor: "#201b14"
            property string borderColor: "#444444"
            property string focusColor: "#c9b890"
            property string urgentColor: "#ad401f"
            property string layout: "scroller"
            property int cursorSize: 32
            property bool dynamicTags: true
        }
    }

    // STABILITY: coalesce editor save bursts (30 assigns in syncFromFile
    // used to run twice per save).
    Timer {
        id: mangoReloadDebounce
        interval: 250; repeat: false
        onTriggered: { try { mangoFile.reload() } catch (e) { } try { syncFromFile() } catch (e2) { } }
    }

    property int mangoGappih: 5
    property int mangoGappiv: 5
    property int mangoGappoh: 10
    property int mangoGappov: 10
    property int mangoBorderpx: 4
    property int mangoBorderRadius: 6
    property real mangoFocusedOpacity: 1.0
    property real mangoUnfocusedOpacity: 1.0
    property bool mangoSmartgaps: false
    property bool mangoNoBorderSingle: false
    property bool mangoNoRadiusSingle: false
    property bool mangoBlur: false
    property bool mangoBlurLayer: false
    property int mangoBlurRadius: 5
    property int mangoBlurPasses: 2
    property real mangoBlurNoise: 0.02
    property real mangoBlurBrightness: 0.9
    property real mangoBlurContrast: 0.9
    property real mangoBlurSaturation: 1.2
    property bool mangoShadows: false
    property bool mangoShadowOnlyFloating: true
    property int mangoShadowSize: 10
    property int mangoShadowBlur: 15
    property string mangoShadowColor: "#000000"
    property bool mangoAnimations: true
    property string mangoAnimOpen: "slide"
    property string mangoAnimClose: "slide"
    property int mangoAnimDurOpen: 400
    property int mangoAnimDurClose: 800
    property int mangoAnimDurMove: 500
    property int mangoAnimDurTag: 350
    property string mangoRootColor: "#201b14"
    property string mangoBorderColor: "#444444"
    property string mangoFocusColor: "#c9b890"
    property string mangoUrgentColor: "#ad401f"
    property string mangoLayout: "scroller"
    property int mangoCursorSize: 32
    // Display-side only: hide empty inactive tags.
    property bool mangoDynamicTags: true

    readonly property var mangoLayouts: ["tile", "scroller", "grid", "deck", "monocle", "center_tile", "right_tile", "vertical_tile", "vertical_scroller", "vertical_grid", "vertical_deck", "dwindle", "fair", "vertical_fair"]

    function clampInt(v, lo, hi, fb): int {
        let n = parseInt(v)
        if (isNaN(n)) return fb
        return Math.max(lo, Math.min(hi, Math.round(n)))
    }
    function clampReal(v, lo, hi, fb): real {
        let n = parseFloat(v)
        if (isNaN(n)) return fb
        return Math.max(lo, Math.min(hi, n))
    }
    function clampColor(v, fb): string {
        let s = ((v || "") + "").trim()
        if (/^#[0-9a-fA-F]{6}$/.test(s)) return s.toLowerCase()
        if (/^#[0-9a-fA-F]{3}$/.test(s)) {
            return ("#" + s[1] + s[1] + s[2] + s[2] + s[3] + s[3]).toLowerCase()
        }
        return fb
    }
    // mango config uses 0xRRGGBBAA; jhqs stores #RRGGBB (alpha ff assumed).
    function mangoToHex(v, fb): string {
        let s = ((v || "") + "").trim().toLowerCase()
        let m = s.match(/^0x([0-9a-f]{6})([0-9a-f]{2})?$/)
        if (m) return ("#" + m[1]).toLowerCase()
        m = s.match(/^#([0-9a-f]{6})([0-9a-f]{2})?$/)
        if (m) return ("#" + m[1]).toLowerCase()
        return fb
    }
    function hexToMango(v): string {
        let s = clampColor(v, "#000000")
        return "0x" + s.substring(1).toLowerCase() + "ff"
    }

    function syncFromFile(): void {
        mangoGappih = clampInt(mangoFile.adapter.gappih, 0, 60, 5)
        mangoGappiv = clampInt(mangoFile.adapter.gappiv, 0, 60, 5)
        mangoGappoh = clampInt(mangoFile.adapter.gappoh, 0, 100, 10)
        mangoGappov = clampInt(mangoFile.adapter.gappov, 0, 100, 10)
        mangoBorderpx = clampInt(mangoFile.adapter.borderpx, 0, 20, 4)
        mangoBorderRadius = clampInt(mangoFile.adapter.borderRadius, 0, 40, 6)
        mangoFocusedOpacity = clampReal(mangoFile.adapter.focusedOpacity, 0.2, 1.0, 1.0)
        mangoUnfocusedOpacity = clampReal(mangoFile.adapter.unfocusedOpacity, 0.2, 1.0, 1.0)
        mangoSmartgaps = !!mangoFile.adapter.smartgaps
        mangoNoBorderSingle = !!mangoFile.adapter.noBorderWhenSingle
        mangoNoRadiusSingle = !!mangoFile.adapter.noRadiusWhenSingle
        mangoBlur = !!mangoFile.adapter.blur
        mangoBlurLayer = !!mangoFile.adapter.blurLayer
        mangoBlurRadius = clampInt(mangoFile.adapter.blurRadius, 1, 20, 5)
        mangoBlurPasses = clampInt(mangoFile.adapter.blurPasses, 1, 4, 2)
        mangoBlurNoise = clampReal(mangoFile.adapter.blurNoise, 0, 0.2, 0.02)
        mangoBlurBrightness = clampReal(mangoFile.adapter.blurBrightness, 0.2, 1.5, 0.9)
        mangoBlurContrast = clampReal(mangoFile.adapter.blurContrast, 0.2, 1.5, 0.9)
        mangoBlurSaturation = clampReal(mangoFile.adapter.blurSaturation, 0.2, 2.0, 1.2)
        mangoShadows = !!mangoFile.adapter.shadows
        mangoShadowOnlyFloating = mangoFile.adapter.shadowOnlyFloating !== false
        mangoShadowSize = clampInt(mangoFile.adapter.shadowSize, 0, 40, 10)
        mangoShadowBlur = clampInt(mangoFile.adapter.shadowBlur, 0, 60, 15)
        mangoShadowColor = clampColor(mangoFile.adapter.shadowColor, "#000000")
        mangoAnimations = mangoFile.adapter.animations !== false
        let ao = ((mangoFile.adapter.animOpen || "slide") + "").toLowerCase()
        mangoAnimOpen = (ao === "zoom" || ao === "fade" || ao === "none") ? ao : "slide"
        let ac = ((mangoFile.adapter.animClose || "slide") + "").toLowerCase()
        mangoAnimClose = (ac === "zoom" || ac === "fade" || ac === "none") ? ac : "slide"
        mangoAnimDurOpen = clampInt(mangoFile.adapter.animDurationOpen, 0, 2000, 400)
        mangoAnimDurClose = clampInt(mangoFile.adapter.animDurationClose, 0, 2000, 800)
        mangoAnimDurMove = clampInt(mangoFile.adapter.animDurationMove, 0, 2000, 500)
        mangoAnimDurTag = clampInt(mangoFile.adapter.animDurationTag, 0, 2000, 350)
        mangoRootColor = clampColor(mangoFile.adapter.rootColor, "#201b14")
        mangoBorderColor = clampColor(mangoFile.adapter.borderColor, "#444444")
        mangoFocusColor = clampColor(mangoFile.adapter.focusColor, "#c9b890")
        mangoUrgentColor = clampColor(mangoFile.adapter.urgentColor, "#ad401f")
        let lay = ((mangoFile.adapter.layout || "scroller") + "").toLowerCase()
        if (lay === "scrolling") lay = "scroller"
        mangoLayout = mangoLayouts.indexOf(lay) >= 0 ? lay : "scroller"
        mangoCursorSize = clampInt(mangoFile.adapter.cursorSize, 8, 64, 32)
        mangoDynamicTags = mangoFile.adapter.dynamicTags !== false
    }
    function persist(): void { persistDebounce.restart() }
    function persistNow(): void { try { mangoFile.writeAdapter() } catch (e) { } }
    // PERF: slider drags call apply* per tick — each used to write mango.json
    // + fork mango-apply.py. Coalesce writes to 300ms; live feedback stays
    // instant via preview() throttle above.
    Timer {
        id: persistDebounce
        interval: 300; repeat: false
        onTriggered: { try { mangoFile.writeAdapter() } catch (e) { } pumpBackendApply() }
    }
    property var _backendApplyPending: null
    function pumpBackendApply(): void {
        if (_backendApplyPending === null || _backendApplyPending === undefined) return
        let args = _backendApplyPending
        _backendApplyPending = null
        runBackendNow(args)
    }

    Process {
        id: mangoApplyProc
        command: ["bash", "-c", "echo"]
        stdout: StdioCollector {}
        onExited: pumpBackendApply()
    }
    function runBackend(args: var): void {
        // Coalesce to latest — intermediate drag ticks are obsolete.
        _backendApplyPending = args
        if (!mangoApplyProc.running && !persistDebounce.running) pumpBackendApply()
    }
    function runBackendNow(args: var): void {
        let script = Quickshell.env("HOME") + "/.config/quickshell/jhqs/scripts/mango-apply.py"
        mangoApplyProc.command = ["python3", script].concat(args)
        if (!mangoApplyProc.running) mangoApplyProc.running = true
    }
    function preview(key: string, value: string): void {
        if (!isMango) return
        let k = ((key || "").trim()).toLowerCase().replace(/[^a-z_]/g, "")
        if (k.length === 0) return
        _previewLatest[k] = value
        // First tick of a burst goes out immediately (no added latency);
        // the timer then paces follow-ups (see flushPreview).
        if (!previewTimer.running) flushPreview()
    }
    // ---- live preview throttle ----
    // Slider drags produce ticks far faster than one mmsg round trip (~55ms).
    // Draining every tick would lag seconds behind the finger, so only the
    // latest value per key is kept and pushed at most every 30ms (all pending
    // keys ride in a single shell call). The release apply() always lands:
    // it previews last, after the drag ticks stopped.
    Timer {
        id: previewTimer
        interval: 30; repeat: false
        onTriggered: root.flushPreview()
    }
    property var _previewLatest: ({})
    function flushPreview(): void {
        if (dispatchProc.running) { previewTimer.restart(); return }
        let keys = []
        try { for (let k in _previewLatest) keys.push(k) } catch (e) {}
        if (keys.length === 0) { previewTimer.stop(); return }
        let cmd = ""
        for (let i = 0; i < keys.length; i++) {
            cmd += "mmsg dispatch setoption," + keys[i] + "," + _previewLatest[keys[i]] + " >/dev/null 2>&1;"
        }
        _previewLatest = ({})
        dispatchProc.command = ["bash", "-c", cmd]
        dispatchProc.running = true
        previewTimer.restart()
    }

    // Seed from looknfeel.conf once at boot so the panel reflects the
    // compositor's real values even before mango.json exists.
    Process {
        id: seedProc
        command: ["bash", "-c", "cat ~/.config/mango/configs/looknfeel.conf 2>/dev/null | head -c 32768"]
        stdout: StdioCollector {
            onStreamFinished: root.parseSeed(text || "")
        }
    }
    function parseSeed(out: string): void {
        try {
            let t = (out || "")
            if (t.trim().length === 0) return
            let get = (key, fb) => {
                let m = t.match(new RegExp("^\\s*" + key + "\\s*=\\s*([^\\n#]+)", "m"))
                if (!m) return fb
                return (m[1] || "").trim()
            }
            let gi = (key, lo, hi, fb) => {
                let n = parseInt(get(key, ""))
                if (isNaN(n)) return fb
                return Math.max(lo, Math.min(hi, Math.round(n)))
            }
            let gf = (key, lo, hi, fb) => {
                let n = parseFloat(get(key, ""))
                if (isNaN(n)) return fb
                return Math.max(lo, Math.min(hi, n))
            }
            let gb = (key, fb) => {
                let s = get(key, "").toLowerCase()
                if (s === "1" || s === "true" || s === "yes") return true
                if (s === "0" || s === "false" || s === "no") return false
                return fb
            }
            let dirty = false
            let set = (prop, val) => { if (mangoFile.adapter[prop] !== val) { mangoFile.adapter[prop] = val; dirty = true } }
            // Only seed keys that differ from adapter defaults AND adapter still
            // holds its default (i.e. user never saved). mango.json is the
            // source of truth once written; never overwrite user values here.
            set("gappih", gi("gappih", 0, 60, mangoFile.adapter.gappih))
            set("gappiv", gi("gappiv", 0, 60, mangoFile.adapter.gappiv))
            set("gappoh", gi("gappoh", 0, 100, mangoFile.adapter.gappoh))
            set("gappov", gi("gappov", 0, 100, mangoFile.adapter.gappov))
            set("borderpx", gi("borderpx", 0, 20, mangoFile.adapter.borderpx))
            set("borderRadius", gi("border_radius", 0, 40, mangoFile.adapter.borderRadius))
            set("smartgaps", gb("smartgaps", mangoFile.adapter.smartgaps))
            set("noBorderWhenSingle", gb("no_border_when_single", mangoFile.adapter.noBorderWhenSingle))
            set("noRadiusWhenSingle", gb("no_radius_when_single", mangoFile.adapter.noRadiusWhenSingle))
            set("blur", gb("blur", mangoFile.adapter.blur))
            set("blurLayer", gb("blur_layer", mangoFile.adapter.blurLayer))
            set("animations", gb("animations", mangoFile.adapter.animations))
            let rc = mangoToHex(get("rootcolor", ""), null)
            if (rc) set("rootColor", rc)
            let bc = mangoToHex(get("bordercolor", ""), null)
            if (bc) set("borderColor", bc)
            let fc = mangoToHex(get("focuscolor", ""), null)
            if (fc) set("focusColor", fc)
            let uc = mangoToHex(get("urgentcolor", ""), null)
            if (uc) set("urgentColor", uc)
            let sc = mangoToHex(get("shadowscolor", ""), null)
            if (sc) set("shadowColor", sc)
            if (dirty) { mangoFile.writeAdapter(); syncFromFile() }
        } catch (e) {}
    }

    Component.onCompleted: Qt.callLater(() => { syncFromFile(); if (!seedProc.running) seedProc.running = true })

    // ---- gaps ----
    function applyInnerGap(v): void { let c = clampInt(v, 0, 60, mangoGappih); mangoGappih = c; mangoGappiv = c; mangoFile.adapter.gappih = c; mangoFile.adapter.gappiv = c; persist(); preview("gappih", c); preview("gappiv", c); runBackend(["gappih=" + c, "gappiv=" + c]) }
    function applyOuterGap(v): void { let c = clampInt(v, 0, 100, mangoGappoh); mangoGappoh = c; mangoGappov = c; mangoFile.adapter.gappoh = c; mangoFile.adapter.gappov = c; persist(); preview("gappoh", c); preview("gappov", c); runBackend(["gappoh=" + c, "gappov=" + c]) }
    function previewGaps(ih, iv, oh, ov): void {
        mangoGappih = clampInt(ih, 0, 60, mangoGappih)
        mangoGappiv = clampInt(iv, 0, 60, mangoGappiv)
        mangoGappoh = clampInt(oh, 0, 100, mangoGappoh)
        mangoGappov = clampInt(ov, 0, 100, mangoGappov)
        preview("gappih", mangoGappih); preview("gappiv", mangoGappiv)
        preview("gappoh", mangoGappoh); preview("gappov", mangoGappov)
    }
    // ---- borders / radius / opacity ----
    function applyBorderpx(v): void { let c = clampInt(v, 0, 20, mangoBorderpx); mangoBorderpx = c; mangoFile.adapter.borderpx = c; persist(); preview("borderpx", c); runBackend(["borderpx=" + c]) }
    function applyBorderRadius(v): void { let c = clampInt(v, 0, 40, mangoBorderRadius); mangoBorderRadius = c; mangoFile.adapter.borderRadius = c; persist(); preview("border_radius", c); runBackend(["border_radius=" + c]) }
    function applyFocusedOpacity(v): void { let c = Math.round(clampReal(v, 0.2, 1.0, mangoFocusedOpacity) * 100) / 100; mangoFocusedOpacity = c; mangoFile.adapter.focusedOpacity = c; persist(); preview("focused_opacity", c); runBackend(["focused_opacity=" + c]) }
    function applyUnfocusedOpacity(v): void { let c = Math.round(clampReal(v, 0.2, 1.0, mangoUnfocusedOpacity) * 100) / 100; mangoUnfocusedOpacity = c; mangoFile.adapter.unfocusedOpacity = c; persist(); preview("unfocused_opacity", c); runBackend(["unfocused_opacity=" + c]) }
    function applySmartgaps(n): void { mangoSmartgaps = !!n; mangoFile.adapter.smartgaps = mangoSmartgaps; persist(); preview("smartgaps", mangoSmartgaps ? 1 : 0); runBackend(["smartgaps=" + (mangoSmartgaps ? 1 : 0)]) }
    function applyNoBorderSingle(n): void { mangoNoBorderSingle = !!n; mangoFile.adapter.noBorderWhenSingle = mangoNoBorderSingle; persist(); preview("no_border_when_single", mangoNoBorderSingle ? 1 : 0); runBackend(["no_border_when_single=" + (mangoNoBorderSingle ? 1 : 0)]) }
    function applyNoRadiusSingle(n): void { mangoNoRadiusSingle = !!n; mangoFile.adapter.noRadiusWhenSingle = mangoNoRadiusSingle; persist(); preview("no_radius_when_single", mangoNoRadiusSingle ? 1 : 0); runBackend(["no_radius_when_single=" + (mangoNoRadiusSingle ? 1 : 0)]) }
    // ---- blur ----
    function applyBlur(n): void { mangoBlur = !!n; mangoFile.adapter.blur = mangoBlur; persist(); preview("blur", mangoBlur ? 1 : 0); runBackend(["blur=" + (mangoBlur ? 1 : 0)]) }
    function applyBlurLayer(n): void { mangoBlurLayer = !!n; mangoFile.adapter.blurLayer = mangoBlurLayer; persist(); preview("blur_layer", mangoBlurLayer ? 1 : 0); runBackend(["blur_layer=" + (mangoBlurLayer ? 1 : 0)]) }
    function applyBlurRadius(v): void { let c = clampInt(v, 1, 20, mangoBlurRadius); mangoBlurRadius = c; mangoFile.adapter.blurRadius = c; persist(); preview("blur_params_radius", c); runBackend(["blur_params_radius=" + c]) }
    function applyBlurPasses(v): void { let c = clampInt(v, 1, 4, mangoBlurPasses); mangoBlurPasses = c; mangoFile.adapter.blurPasses = c; persist(); preview("blur_params_num_passes", c); runBackend(["blur_params_num_passes=" + c]) }
    // ---- shadows ----
    function applyShadows(n): void { mangoShadows = !!n; mangoFile.adapter.shadows = mangoShadows; persist(); preview("shadows", mangoShadows ? 1 : 0); runBackend(["shadows=" + (mangoShadows ? 1 : 0)]) }
    function applyShadowOnlyFloating(n): void { mangoShadowOnlyFloating = !!n; mangoFile.adapter.shadowOnlyFloating = mangoShadowOnlyFloating; persist(); preview("shadow_only_floating", mangoShadowOnlyFloating ? 1 : 0); runBackend(["shadow_only_floating=" + (mangoShadowOnlyFloating ? 1 : 0)]) }
    function applyShadowSize(v): void { let c = clampInt(v, 0, 40, mangoShadowSize); mangoShadowSize = c; mangoFile.adapter.shadowSize = c; persist(); preview("shadows_size", c); runBackend(["shadows_size=" + c]) }
    function applyShadowBlur(v): void { let c = clampInt(v, 0, 60, mangoShadowBlur); mangoShadowBlur = c; mangoFile.adapter.shadowBlur = c; persist(); preview("shadows_blur", c); runBackend(["shadows_blur=" + c]) }
    function applyShadowColor(v): void { let c = clampColor(v, mangoShadowColor); mangoShadowColor = c; mangoFile.adapter.shadowColor = c; persist(); preview("shadowscolor", hexToMango(c)); runBackend(["shadowscolor=" + hexToMango(c)]) }
    // ---- colors ----
    function applyRootColor(v): void { let c = clampColor(v, mangoRootColor); mangoRootColor = c; mangoFile.adapter.rootColor = c; persist(); preview("rootcolor", hexToMango(c)); runBackend(["rootcolor=" + hexToMango(c)]) }
    function applyBorderColor(v): void { let c = clampColor(v, mangoBorderColor); mangoBorderColor = c; mangoFile.adapter.borderColor = c; persist(); preview("bordercolor", hexToMango(c)); runBackend(["bordercolor=" + hexToMango(c)]) }
    function applyFocusColor(v): void { let c = clampColor(v, mangoFocusColor); mangoFocusColor = c; mangoFile.adapter.focusColor = c; persist(); preview("focuscolor", hexToMango(c)); runBackend(["focuscolor=" + hexToMango(c)]) }
    function applyUrgentColor(v): void { let c = clampColor(v, mangoUrgentColor); mangoUrgentColor = c; mangoFile.adapter.urgentColor = c; persist(); preview("urgentcolor", hexToMango(c)); runBackend(["urgentcolor=" + hexToMango(c)]) }
    // ---- animations ----
    function applyAnimations(n): void { mangoAnimations = !!n; mangoFile.adapter.animations = mangoAnimations; persist(); preview("animations", mangoAnimations ? 1 : 0); runBackend(["animations=" + (mangoAnimations ? 1 : 0)]) }
    function applyAnimType(which, name): void {
        let n = ((name || "") + "").toLowerCase()
        if (["slide", "zoom", "fade", "none"].indexOf(n) < 0) return
        if (which === "close") { mangoAnimClose = n; mangoFile.adapter.animClose = n; persist(); preview("animation_type_close", n); runBackend(["animation_type_close=" + n]) }
        else { mangoAnimOpen = n; mangoFile.adapter.animOpen = n; persist(); preview("animation_type_open", n); runBackend(["animation_type_open=" + n]) }
    }
    function applyAnimDur(which, v): void {
        let c = clampInt(v, 0, 2000, 400)
        if (which === "close") { mangoAnimDurClose = c; mangoFile.adapter.animDurationClose = c; persist(); preview("animation_duration_close", c); runBackend(["animation_duration_close=" + c]) }
        else if (which === "move") { mangoAnimDurMove = c; mangoFile.adapter.animDurationMove = c; persist(); preview("animation_duration_move", c); runBackend(["animation_duration_move=" + c]) }
        else if (which === "tag") { mangoAnimDurTag = c; mangoFile.adapter.animDurationTag = c; persist(); preview("animation_duration_tag", c); runBackend(["animation_duration_tag=" + c]) }
        else { mangoAnimDurOpen = c; mangoFile.adapter.animDurationOpen = c; persist(); preview("animation_duration_open", c); runBackend(["animation_duration_open=" + c]) }
    }
    // ---- layout / cursor ----
    function applyLayout(name): void {
        let n = ((name || "") + "").toLowerCase()
        if (n === "scrolling") n = "scroller"
        if (mangoLayouts.indexOf(n) < 0) return
        mangoLayout = n; mangoFile.adapter.layout = n; persist()
        setLayout(n)
        runBackend(["__layout=" + n])
    }
    function applyCursorSize(v): void { let c = clampInt(v, 8, 64, mangoCursorSize); mangoCursorSize = c; mangoFile.adapter.cursorSize = c; persist(); preview("cursor_size", c); runBackend(["cursor_size=" + c]) }
    function applyDynamicTags(n): void {
        mangoDynamicTags = !!n; mangoFile.adapter.dynamicTags = mangoDynamicTags; persist()
    }

    IpcHandler {
        target: "mango"
        function status(): string { return root.status() }
        function refresh(): string { root.refresh(); return root.status() }
        function view(tag: int): string { root.activateTag(tag); return "view=" + tag }
    }
}
