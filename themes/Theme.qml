pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/themes/matugen.json"
        printErrors: false; watchChanges: true; blockLoading: true
        onFileChanged: colorReloadDebounce.restart()
        adapter: JsonAdapter {
            property color background: "#1E2132"
            property color error: "#ffb4ab"
            property color error_container: "#93000a"
            property color inverse_on_surface: "#303036"
            property color inverse_primary: "#585992"
            property color inverse_surface: "#e4e1e9"
            property color on_background: "#e4e1e9"
            property color on_error: "#690005"
            property color on_error_container: "#ffdad6"
            property color on_primary: "#542202"
            property color on_primary_container: "#e1e0ff"
            property color on_primary_fixed: "#13144a"
            property color on_primary_fixed_variant: "#404178"
            property color on_secondary: "#432b1e"
            property color on_secondary_container: "#e2e0f9"
            property color on_secondary_fixed: "#1a1a2c"
            property color on_secondary_fixed_variant: "#454559"
            property color on_surface: "#ECEEFF"
            property color on_surface_variant: "#A0A6C8"
            property color on_tertiary: "#46263a"
            property color on_tertiary_container: "#ffd8ec"
            property color on_tertiary_fixed: "#2e1125"
            property color on_tertiary_fixed_variant: "#5f3c51"
            property color outline: "#6E7391"
            property color outline_variant: "#34395E"
            property color primary: "#7AA2F7"
            property color primary_container: "#3B3F6E"
            property color primary_fixed: "#e1e0ff"
            property color primary_fixed_dim: "#c1c1ff"
            property color scrim: "#000000"
            property color secondary: "#8E93B3"
            property color secondary_container: "#454559"
            property color secondary_fixed: "#e2e0f9"
            property color secondary_fixed_dim: "#c6c4dd"
            property color shadow: "#000000"
            property color source_color: "#5456c0"
            property color surface: "#1E2132"
            property color surface_bright: "#39383f"
            property color surface_container: "#252A40"
            property color surface_container_high: "#2B2F4A"
            property color surface_container_highest: "#2E334E"
            property color surface_container_low: "#1b1b21"
            property color surface_container_lowest: "#0e0e13"
            property color surface_dim: "#131318"
            property color surface_tint: "#c1c1ff"
            property color surface_variant: "#52443d"
            property color tertiary: "#e9b9d3"
            property color tertiary_container: "#5f3c51"
            property color tertiary_fixed: "#ffd8ec"
            property color tertiary_fixed_dim: "#e9b9d3"
        }
    }
    Timer {
        id: colorReloadDebounce
        // Short guard against reading a half-written matugen.json; the shell
        // recolors as soon as the file settles.
        interval: 80; repeat: false
        onTriggered: colorFile.reload()
    }
    Timer {
        id: fileReloadDebounce
        interval: 250; repeat: false
        property var queue: []
        onTriggered: {
            let q = queue
            queue = []
            for (let i = 0; i < q.length; i++) {
                try { q[i].reload() } catch (e) { }
            }
            try {
                if (q.indexOf(sharedMenuFile) >= 0) {
                    let fw = sharedMenuFile.adapter.width
                    let fh = sharedMenuFile.adapter.height
                    if (fw !== undefined && fw !== sharedMenuWidth) sharedMenuWidth = fw
                    if (fh !== undefined && fh !== sharedMenuHeight) sharedMenuHeight = fh
                }
            } catch (e) { }
        }
    }
    function debouncedReload(fv: var): void {
        try {
            if (fileReloadDebounce.queue.indexOf(fv) < 0) fileReloadDebounce.queue.push(fv)
            fileReloadDebounce.restart()
        } catch (e) {
            try { fv.reload() } catch (e2) { }
        }
    }

    readonly property color background: colorFile.adapter.background
    readonly property color error: colorFile.adapter.error
    readonly property color error_container: colorFile.adapter.error_container
    readonly property color inverse_on_surface: colorFile.adapter.inverse_on_surface
    readonly property color inverse_primary: colorFile.adapter.inverse_primary
    readonly property color inverse_surface: colorFile.adapter.inverse_surface
    readonly property color on_background: colorFile.adapter.on_background
    readonly property color on_error: colorFile.adapter.on_error
    readonly property color on_error_container: colorFile.adapter.on_error_container
    readonly property color on_primary: colorFile.adapter.on_primary
    readonly property color on_primary_container: colorFile.adapter.on_primary_container
    readonly property color on_primary_fixed: colorFile.adapter.on_primary_fixed
    readonly property color on_primary_fixed_variant: colorFile.adapter.on_primary_fixed_variant
    readonly property color on_secondary: colorFile.adapter.on_secondary
    readonly property color on_secondary_container: colorFile.adapter.on_secondary_container
    readonly property color on_secondary_fixed: colorFile.adapter.on_secondary_fixed
    readonly property color on_secondary_fixed_variant: colorFile.adapter.on_secondary_fixed_variant
    readonly property color on_surface: colorFile.adapter.on_surface
    readonly property color on_surface_variant: colorFile.adapter.on_surface_variant
    readonly property color on_tertiary: colorFile.adapter.on_tertiary
    readonly property color on_tertiary_container: colorFile.adapter.on_tertiary_container
    readonly property color on_tertiary_fixed: colorFile.adapter.on_tertiary_fixed
    readonly property color on_tertiary_fixed_variant: colorFile.adapter.on_tertiary_fixed_variant
    readonly property color outline: colorFile.adapter.outline
    readonly property color outline_variant: colorFile.adapter.outline_variant
    readonly property color primary: colorFile.adapter.primary
    readonly property color primary_container: colorFile.adapter.primary_container
    readonly property color primary_fixed: colorFile.adapter.primary_fixed
    readonly property color primary_fixed_dim: colorFile.adapter.primary_fixed_dim
    readonly property color scrim: colorFile.adapter.scrim
    readonly property color secondary: colorFile.adapter.secondary
    readonly property color secondary_container: colorFile.adapter.secondary_container
    readonly property color secondary_fixed: colorFile.adapter.secondary_fixed
    readonly property color secondary_fixed_dim: colorFile.adapter.secondary_fixed_dim
    readonly property color shadow: colorFile.adapter.shadow
    readonly property color source_color: colorFile.adapter.source_color
    readonly property color surface: colorFile.adapter.surface
    readonly property color surface_bright: colorFile.adapter.surface_bright
    readonly property color surface_container: colorFile.adapter.surface_container
    readonly property color surface_container_high: colorFile.adapter.surface_container_high
    readonly property color surface_container_highest: colorFile.adapter.surface_container_highest
    readonly property color surface_container_low: colorFile.adapter.surface_container_low
    readonly property color surface_container_lowest: colorFile.adapter.surface_container_lowest
    readonly property color surface_dim: colorFile.adapter.surface_dim
    readonly property color surface_tint: colorFile.adapter.surface_tint
    readonly property color surface_variant: colorFile.adapter.surface_variant
    readonly property color tertiary: colorFile.adapter.tertiary
    readonly property color tertiary_container: colorFile.adapter.tertiary_container
    readonly property color tertiary_fixed: colorFile.adapter.tertiary_fixed
    readonly property color tertiary_fixed_dim: colorFile.adapter.tertiary_fixed_dim

    readonly property color bg: surface
    readonly property color surface2: frostFill(surface_container_high, 0.18, 0.84)
    readonly property color bgHover: frostFill(surface_container_highest, 0.14, 0.88)
    readonly property color bgSelected: frostFill(primary_container, 0.08, 0.92)
    readonly property color bgTileActive: frostFill(primary_container, 0.32, 0.70)
    readonly property color bgTileInactive: frostFill(surface_container, 0.35, 0.68)
    readonly property color cardBg: frostFill(surface_container_high, 0.45, 0.55)
    readonly property color onTileActive: on_primary_container
    readonly property color borderColor: outline_variant
    readonly property color borderOuter: scrim
    readonly property color textPrimary: on_surface
    readonly property color textSecondary: on_surface_variant
    readonly property color textMuted: outline
    readonly property color iconColor: secondary
    readonly property color iconBg: frostFill(surface_container_high, 0.16, 0.86)
    readonly property color iconBgSelected: primary
    readonly property color iconColorSelected: on_primary
    readonly property color onAccent: on_primary
    readonly property color accent: primary
    readonly property color accentDim: primary_container
    readonly property color divider: outline_variant
    readonly property color errorColor: error

    FileView {
        id: fontFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/font_settings.json"
        watchChanges: true; onFileChanged: debouncedReload(fontFile); blockLoading: true; printErrors: false
        adapter: JsonAdapter { property string fontFamily: "Adwaita Sans"; property int fontSize: 11 }
    }
    readonly property string fontFamily: (fontFile.adapter.fontFamily && fontFile.adapter.fontFamily.length > 0) ? fontFile.adapter.fontFamily : "Adwaita Sans"
    readonly property string iconFontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSize: Math.max(8, Math.min(16, Math.round(fontFile.adapter.fontSize || 11)))
    Process { id: fontApplyProc; command: ["bash", "-c", "echo"]; onExited: pumpFontApply() }
    property var _fontApplyPending: null
    function runFontApply(): void {
        // STABILITY: coalesce bursts (font picker drags). Old code dropped
        // ticks silently when running; now the latest always lands.
        _fontApplyPending = { family: fontFamily, size: String(fontSize) }
        if (!fontApplyProc.running) pumpFontApply()
    }
    function pumpFontApply(): void {
        if (_fontApplyPending === null || _fontApplyPending === undefined) return
        if (fontApplyProc.running) return
        let p = _fontApplyPending
        _fontApplyPending = null
        let script = Quickshell.env("HOME") + "/.config/quickshell/jhqs/scripts/apply-font.sh"
        fontApplyProc.command = ["bash", script, p.family, p.size]
        fontApplyProc.running = true
    }
    function setSystemFont(family: string): void {
        let f = (family || "").trim()
        if (f.length === 0 || f.indexOf("\n") !== -1 || f.indexOf("\r") !== -1) return
        if (fontFile.adapter.fontFamily !== f) {
            fontFile.adapter.fontFamily = f
            fontFile.writeAdapter()
        }
        runFontApply()
    }
    function setFontSize(v: real): void {
        let c = Math.max(8, Math.min(16, Math.round(v)))
        if (Math.round(fontFile.adapter.fontSize || 11) === c) return
        fontFile.adapter.fontSize = c
        fontFile.writeAdapter()
        runFontApply()
    }

    FileView {
        id: shellFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/topbar_settings.json"
        watchChanges: true; onFileChanged: debouncedReload(shellFile); blockLoading: true; printErrors: false
        adapter: JsonAdapter {
            property int radius: 0
            property bool animationsEnabled: true
            property string clockPosition: "center"
            property string clockFormat: "full"
            property string workspacesPosition: "left"
            property string workspaceStyle: "default"
            property int workspaceSpacing: 4
            property real workspaceScale: 1.0
            property int thickness: 30
            property real opacity: 1.0
            property string position: "top"
            property bool textBold: false
            property bool antialiasing: true
            property bool aaShapes: true
            property bool aaText: true
            property bool aaTextNative: true
            property bool aaImageSmooth: true
            property bool aaImageMipmap: false
            property real fontScale: 1.0
            property bool panelAccentBorder: false
            property real panelBlur: 0.6
            property int moduleSpacing: 8
            property int edgeDistance: 0
            property int topDistance: 0
            property int contentPadding: 12
        }
    }
    // Minimal is the only shell theme: former Modern branches deleted.
    // minimalTheme stays as a constant for SettingsService.
    readonly property bool minimalTheme: true

    // Einzige Schreibpfade für Adapter-Settings (ein Guard statt ~20x
    // kopierter clamp/compare/write-Blöcke). Alle Adapter deklarieren
    // Defaults, daher ist adapter[key] nie undefined.
    function setAdapterBool(fileView: var, key: string, v: bool): void {
        const nv = !!v
        if (!!fileView.adapter[key] === nv) return
        fileView.adapter[key] = nv
        fileView.writeAdapter()
    }
    function setAdapterInt(fileView: var, key: string, v: var, lo: int, hi: int): void {
        const c = Math.max(lo, Math.min(hi, Math.round(Number(v))))
        if (isNaN(c)) return // statt NaN in die Config zu schreiben, ignorieren
        if (Math.round(Number(fileView.adapter[key])) === c) return
        fileView.adapter[key] = c
        fileView.writeAdapter()
    }
    function setAdapterReal(fileView: var, key: string, v: var, lo: real, hi: real): void {
        let c = Math.max(lo, Math.min(hi, Number(v)))
        if (isNaN(c)) return
        c = Math.round(c * 100) / 100
        if (Math.abs(Number(fileView.adapter[key]) - c) < 0.001) return
        fileView.adapter[key] = c
        fileView.writeAdapter()
    }
    // Shell rounding (Global > Rounding). Single source for all shell
    // radii; synced to MangoWM border_radius by the Global slider.
    readonly property int cornerRadius: Math.max(0, Math.min(40, Math.round(shellFile.adapter.radius ?? 0)))
    readonly property int cornerRadiusSmall: Math.max(0, Math.min(12, Math.round(cornerRadius * 0.6)))
    function setCornerRadius(v: int): void { setAdapterInt(shellFile, "radius", v, 0, 40) }
    readonly property int barThickness: Math.max(20, Math.min(48, Math.round(shellFile.adapter.thickness !== undefined ? shellFile.adapter.thickness : 30)))
    readonly property string barPosition: {
        let p = shellFile.adapter.position
        if (p === "bottom" || p === "left" || p === "right" || p === "top") return p
        return "top"
    }
    readonly property real barOpacity: {
        let o = shellFile.adapter.opacity
        if (o === undefined || o === null || isNaN(o)) return 1.0
        return Math.max(0.0, Math.min(1.0, o))
    }
    function setBarThickness(v: int): void { setAdapterInt(shellFile, "thickness", v, 20, 48) }
    function setBarOpacity(v: real): void { setAdapterReal(shellFile, "opacity", v, 0.0, 1.0) }
    function setBarPosition(pos: string): void {
        if (pos !== "top" && pos !== "bottom" && pos !== "left" && pos !== "right") return
        if (shellFile.adapter.position === pos) return
        shellFile.adapter.position = pos
        shellFile.writeAdapter()
    }
    readonly property bool animationsEnabled: shellFile.adapter.animationsEnabled
    function setAnimationsEnabled(v: bool): void { setAdapterBool(shellFile, "animationsEnabled", v) }
    readonly property string clockPosition: (shellFile.adapter.clockPosition === "left" || shellFile.adapter.clockPosition === "right") ? shellFile.adapter.clockPosition : "center"
    // Clock label formats (right-click the clock to cycle):
    // full: "Monday 20:15" | short: "Mon 20:15" | date: "8th May 20:15" | timeOnly: "20:15"
    readonly property var clockFormats: ["full", "short", "date", "timeOnly"]
    readonly property string clockFormat: {
        let v = shellFile.adapter.clockFormat
        return clockFormats.indexOf(v) !== -1 ? v : "full"
    }
    function setClockFormat(v: string): void {
        let nv = clockFormats.indexOf(v) !== -1 ? v : "full"
        if ((shellFile.adapter.clockFormat || "full") === nv) return
        shellFile.adapter.clockFormat = nv
        shellFile.writeAdapter()
    }
    function toggleClockFormat(): void {
        let i = clockFormats.indexOf(clockFormat)
        setClockFormat(clockFormats[(i + 1) % clockFormats.length])
    }
    readonly property string workspacesPosition: (shellFile.adapter.workspacesPosition === "center" || shellFile.adapter.workspacesPosition === "right") ? shellFile.adapter.workspacesPosition : "left"
    readonly property string workspaceStyle: (shellFile.adapter.workspaceStyle === "m3") ? "m3" : (shellFile.adapter.workspaceStyle === "default2") ? "default2" : "default"
    function setWorkspaceStyle(v: string): void {
        let nv = (v === "m3") ? "m3" : (v === "default2") ? "default2" : "default"
        if ((shellFile.adapter.workspaceStyle || "default") === nv) return
        shellFile.adapter.workspaceStyle = nv
        shellFile.writeAdapter()
    }
    readonly property int workspaceSpacing: Math.max(0, Math.min(24, Math.round(shellFile.adapter.workspaceSpacing !== undefined ? shellFile.adapter.workspaceSpacing : 4)))
    function setWorkspaceSpacing(v: int): void { setAdapterInt(shellFile, "workspaceSpacing", v, 0, 24) }
    readonly property real workspaceScale: Math.max(0.5, Math.min(2.0, shellFile.adapter.workspaceScale ?? 1.0))
    function setWorkspaceScale(v: real): void { setAdapterReal(shellFile, "workspaceScale", v, 0.5, 2.0) }
    readonly property bool textBold: !!shellFile.adapter.textBold
    function setTextBold(v: bool): void { setAdapterBool(shellFile, "textBold", v) }
    readonly property real fontScale: Math.max(0.85, Math.min(1.25, shellFile.adapter.fontScale ?? 1.0))
    function setFontScale(v: real): void { setAdapterReal(shellFile, "fontScale", v, 0.85, 1.25) }
    function fs(px: real): int { return Math.max(1, Math.round(px * fontScale)) }
    // PERF: one-shot AA migration runs synchronously at startup (was an
    // 800ms Timer waking the event loop after boot for a file default).
    Component.onCompleted: {
        try {
            if (!shellFile.adapter.antialiasing
                    && shellFile.adapter.aaShapes
                    && shellFile.adapter.aaText
                    && shellFile.adapter.aaImageSmooth) {
                shellFile.adapter.aaShapes = false
                shellFile.adapter.aaText = false
                shellFile.adapter.aaImageSmooth = false
                shellFile.writeAdapter()
            }
        } catch (e) {}
    }
    readonly property bool shapesAa: shellFile.adapter.aaShapes !== undefined ? !!shellFile.adapter.aaShapes : true
    readonly property bool textAa: shellFile.adapter.aaText !== undefined ? !!shellFile.adapter.aaText : true
    readonly property bool textNative: shellFile.adapter.aaTextNative !== undefined ? !!shellFile.adapter.aaTextNative : true
    readonly property bool imageSmooth: shellFile.adapter.aaImageSmooth !== undefined ? !!shellFile.adapter.aaImageSmooth : true
    readonly property bool imageMipmap: shellFile.adapter.aaImageMipmap !== undefined ? !!shellFile.adapter.aaImageMipmap : false
    readonly property bool itemAntialiasing: shapesAa
    readonly property int textRenderType: textNative ? Text.NativeRendering : Text.QtRendering
    function setShapesAa(v: bool): void { setAdapterBool(shellFile, "aaShapes", v) }
    function setTextAa(v: bool): void { setAdapterBool(shellFile, "aaText", v) }
    function setTextNative(v: bool): void { setAdapterBool(shellFile, "aaTextNative", v) }
    function setImageSmooth(v: bool): void { setAdapterBool(shellFile, "aaImageSmooth", v) }
    function setImageMipmap(v: bool): void { setAdapterBool(shellFile, "aaImageMipmap", v) }
    property int barEffectiveWidth: 30
    property int barEffectiveHeight: 30
    property var barAnchors: ({})
    property var _pendingAnchors: ({})
    property bool _anchorFlushScheduled: false
    function setBarAnchor(id: string, x: real, y: real, w: real, h: real): void {
        let key = (id || "").trim()
        if (key.length === 0) return
        let nx = Math.round(x); let ny = Math.round(y)
        let nw = Math.max(1, Math.round(w)); let nh = Math.max(1, Math.round(h))
        let cur = _pendingAnchors[key]
        if (cur === undefined) cur = barAnchors[key]
        if (cur && cur.x === nx && cur.y === ny && cur.w === nw && cur.h === nh) return
        _pendingAnchors[key] = {x: nx, y: ny, w: nw, h: nh}
        if (_anchorFlushScheduled) return
        _anchorFlushScheduled = true
        Qt.callLater(() => {
            _anchorFlushScheduled = false
            let pend = _pendingAnchors
            _pendingAnchors = ({})
            let next = {}
            for (let k in barAnchors) next[k] = barAnchors[k]
            let changed = false
            for (let k in pend) {
                let n = pend[k], c = next[k]
                if (!c || c.x !== n.x || c.y !== n.y || c.w !== n.w || c.h !== n.h) {
                    next[k] = n
                    changed = true
                }
            }
            if (changed) barAnchors = next
        })
    }
    function barAnchor(id: string): var {
        let a = barAnchors[(id || "").trim()]
        return a ? a : null
    }
    function hasBarAnchor(id: string): bool { return barAnchor(id) !== null }
    property int anchorRefreshTrigger: 0
    Timer {
        id: anchorRefreshDebounce
        interval: 80; repeat: false
        onTriggered: anchorRefreshTrigger++
    }
    // PERF: openPanel/toggleExclusive called refreshBarAnchors() synchronously
    // per toggle, invalidating every anchor consumer. Debounce to one bump.
    function refreshBarAnchors(): void { anchorRefreshDebounce.restart() }
    property bool polkitReady: false
    function setPolkitReady(v: bool): void {
        let nv = !!v
        if (polkitReady === nv) return
        polkitReady = nv
    }
    // ---- primary display (with fallback) ----
    // Shell windows (bar, menus, dialogs, OSD) live on ONE screen. Prefer
    // DP-1 so multi-head setups stay put, but fall back to the first
    // available screen so the shell still shows up when DP-1 doesn't
    // exist (single laptop display, renamed outputs, …).
    readonly property string preferredScreenName: "DP-1"
    readonly property string primaryScreenName: {
        try {
            let v = Quickshell.screens.values
            let vals = (v && typeof v.length === "number") ? v : []
            for (let i = 0; i < vals.length; i++) {
                if (vals[i] && vals[i].name === preferredScreenName) return preferredScreenName
            }
            if (vals.length > 0 && vals[0] && vals[0].name) return "" + vals[0].name
        } catch (e) {}
        return preferredScreenName
    }
    function isPrimaryScreen(screenObj: var): bool {
        try { return !!screenObj && ("" + screenObj.name) === primaryScreenName } catch (e) { return false }
    }
    property var barWindowRect: ({x: 0, y: 0, w: 0, h: 0})
    function setBarWindowRect(x: real, y: real, w: real, h: real): void {
        let nx = Math.round(x); let ny = Math.round(y)
        let nw = Math.max(0, Math.round(w)); let nh = Math.max(0, Math.round(h))
        let cur = barWindowRect
        if (cur && cur.x === nx && cur.y === ny && cur.w === nw && cur.h === nh) return
        barWindowRect = {x: nx, y: ny, w: nw, h: nh}
    }
    readonly property int barModuleSpacing: Math.max(-12, Math.min(24, shellFile.adapter.moduleSpacing !== undefined ? shellFile.adapter.moduleSpacing : 8))
    function setBarModuleSpacing(v: int): void { setAdapterInt(shellFile, "moduleSpacing", v, -12, 24) }
    readonly property int barEdgeDistance: Math.max(0, Math.min(600, shellFile.adapter.edgeDistance !== undefined ? shellFile.adapter.edgeDistance : 0))
    function setBarEdgeDistance(v: int): void { setAdapterInt(shellFile, "edgeDistance", v, 0, 600) }
    readonly property int barTopDistance: Math.max(0, Math.min(32, shellFile.adapter.topDistance !== undefined ? shellFile.adapter.topDistance : 0))
    function setBarTopDistance(v: int): void { setAdapterInt(shellFile, "topDistance", v, 0, 32) }
    readonly property int barContentPadding: Math.max(0, Math.min(32, shellFile.adapter.contentPadding !== undefined ? shellFile.adapter.contentPadding : 12))
    function setBarContentPadding(v: int): void { setAdapterInt(shellFile, "contentPadding", v, 0, 32) }
    readonly property bool panelAccentBorder: !!shellFile.adapter.panelAccentBorder
    // Accent border on: accent outline. Off: no outline at all (fully
    // fused borderless panels, tray-menu style) — not even divider.
    readonly property color panelBorderColor: panelAccentBorder ? accent : "transparent"
    function setPanelAccentBorder(v: bool): void { setAdapterBool(shellFile, "panelAccentBorder", v) }
    readonly property real panelBlur: 0.0
    readonly property real panelBgAlpha: 1.0 - panelBlur * 0.48
    readonly property color panelBg: frostFill(bg, 0.48, 0.52)
    readonly property color panelSurface: frostFill(surface, 0.22, 0.80)
    function frostFill(c: color, strength: real, floorA: real): color {
        if (panelBlur <= 0.001) return c
        let a = 1.0 - panelBlur * strength
        if (a < floorA) a = floorA
        return withAlpha(c, a)
    }

    property int sharedMenuWidth: 360
    property int sharedMenuHeight: 444
    // PERF: resize drags fired writeAdapter() per pixel (disk write + JSON
    // churn per frame). Debounce to 500ms; in-memory props stay live.
    Timer {
        id: sharedMenuPersistDebounce
        interval: 500; repeat: false
        onTriggered: {
            try {
                if (sharedMenuFile.adapter.width !== sharedMenuWidth) sharedMenuFile.adapter.width = sharedMenuWidth
                if (sharedMenuFile.adapter.height !== sharedMenuHeight) sharedMenuFile.adapter.height = sharedMenuHeight
                sharedMenuFile.writeAdapter()
            } catch (e) { }
        }
    }
    onSharedMenuWidthChanged: sharedMenuPersistDebounce.restart()
    onSharedMenuHeightChanged: sharedMenuPersistDebounce.restart()
    FileView {
        id: sharedMenuFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/shared_menu.json"
        watchChanges: true
        onFileChanged: debouncedReload(sharedMenuFile)
        blockLoading: true
        printErrors: false
        adapter: JsonAdapter {
            property int width: 360
            property int height: 444
        }
        Component.onCompleted: {
            let fw = adapter.width
            let fh = adapter.height
            if (fw) sharedMenuWidth = fw
            if (fh) sharedMenuHeight = fh
        }
    }
    function setSharedMenuSize(w: int, h: int) {
        let cw = Math.max(200, Math.min(800, Math.round(w)))
        let ch = Math.max(200, Math.min(800, Math.round(h)))
        if (sharedMenuWidth === cw && sharedMenuHeight === ch) return
        sharedMenuWidth = cw
        sharedMenuHeight = ch
    }

    property int volumeOsdTrigger: 0
    function triggerVolumeOsd(): void { volumeOsdTrigger++ }

    property int appsRev: 0
    Timer {
        id: appsRevDebounce
        interval: 800; repeat: false
        onTriggered: root.appsRev++
    }
    function notifyAppsChanged(): void { appsRevDebounce.restart() }
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.notifyAppsChanged() }
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { root.notifyAppsChanged() }
        function onObjectInsertedPost() { root.notifyAppsChanged() }
        function onObjectRemovedPost() { root.notifyAppsChanged() }
    }
    // PERF: memoize desktop lookups per appsRev. desktopEntryFor() does
    // byId + heuristicLookup + hasThemeIcon per call; bar delegates called it
    // per delegate per appsRev change. Cache keyed on (rev + id).
    property var _desktopEntryCache: ({})
    property string _desktopEntryCacheRev: ""
    function desktopEntryFor(appId: string): var {
        let needle = (appId || "").trim()
        if (needle.length === 0) return null
        let revKey = appsRev + "|" + needle
        try {
            if (_desktopEntryCacheRev !== String(appsRev)) {
                _desktopEntryCache = ({})
                _desktopEntryCacheRev = String(appsRev)
            } else if (_desktopEntryCache[revKey] !== undefined) {
                return _desktopEntryCache[revKey]
            }
        } catch (e) {}
        let found = null
        try {
            let e = DesktopEntries.byId(needle)
            if (e) found = e
            else {
                let nodot = needle.replace(/\.desktop$/, "")
                if (nodot !== needle) { e = DesktopEntries.byId(nodot); if (e) found = e }
                if (!found) { e = DesktopEntries.heuristicLookup(needle); if (e) found = e }
            }
        } catch (err) {}
        try { _desktopEntryCache[revKey] = found } catch (e2) {}
        return found
    }
    property var _appIconCache: ({})
    property string _appIconCacheRev: ""
    function appIconFor(appId: string): string {
        let low = (appId || "").toLowerCase().trim()
        if (low.length === 0) return Quickshell.iconPath("application-x-executable")
        try {
            if (_appIconCacheRev !== String(appsRev)) {
                _appIconCache = ({})
                _appIconCacheRev = String(appsRev)
            } else if (_appIconCache[low] !== undefined) {
                return _appIconCache[low]
            }
        } catch (e) {}
        let out = ""
        try {
            let e = desktopEntryFor(low)
            if (e && e.icon) out = Quickshell.iconPath(e.icon)
        } catch (err) {}
        if (out === "") {
            try {
                if (Quickshell.hasThemeIcon(low)) out = Quickshell.iconPath(low)
            } catch (err2) {}
        }
        if (out === "") out = Quickshell.iconPath("application-x-executable")
        try { _appIconCache[low] = out } catch (e3) {}
        return out
    }

    FileView {
        id: dndFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/dnd.json"
        watchChanges: true; onFileChanged: debouncedReload(dndFile); blockLoading: true; printErrors: false
        adapter: JsonAdapter { property bool enabled: false }
    }
    readonly property bool dndEnabled: !!dndFile.adapter.enabled
    function setDndEnabled(v: bool): void { setAdapterBool(dndFile, "enabled", v) }
    function toggleDnd(): void { setDndEnabled(!dndEnabled) }

    FileView {
        id: gamemodeFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/gamemode.json"
        watchChanges: true; onFileChanged: debouncedReload(gamemodeFile); blockLoading: true; printErrors: false
        adapter: JsonAdapter { property bool enabled: false }
    }
    readonly property bool gamemodeEnabled: !!gamemodeFile.adapter.enabled
    function setGamemodeEnabled(v: bool): void { setAdapterBool(gamemodeFile, "enabled", v) }
    function toggleGamemode(): void { setGamemodeEnabled(!gamemodeEnabled) }

    FileView {
        id: notifFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/notifications.json"
        watchChanges: true; onFileChanged: debouncedReload(notifFile); blockLoading: true; printErrors: false
        adapter: JsonAdapter { property int timeout: 5; property string position: "top-right" }
    }
    readonly property int notifTimeout: Math.max(0, Math.min(30, Math.round(notifFile.adapter.timeout !== undefined ? notifFile.adapter.timeout : 5)))
    readonly property string notifPosition: {
        let p = notifFile.adapter.position
        if (p === "top-left" || p === "top-center" || p === "top-right" || p === "bottom-left" || p === "bottom-center" || p === "bottom-right") return p
        return "top-right"
    }
    function setNotifTimeout(v: int): void {
        let c = Math.max(0, Math.min(30, Math.round(v)))
        if (Math.round(notifFile.adapter.timeout) === c) return
        notifFile.adapter.timeout = c
        notifFile.writeAdapter()
    }
    function setNotifPosition(pos: string): void {
        if (pos !== "top-left" && pos !== "top-center" && pos !== "top-right" && pos !== "bottom-left" && pos !== "bottom-center" && pos !== "bottom-right") return
        if (notifFile.adapter.position === pos) return
        notifFile.adapter.position = pos
        notifFile.writeAdapter()
    }

    FileView {
        id: calendarFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/calendar.json"
        watchChanges: true; onFileChanged: debouncedReload(calendarFile); blockLoading: true; printErrors: false
        // NOTE: weekStartDay is owned by CalendarMenu/CalendarPage — it is
        // declared here only so layout writes never drop it from the file.
        adapter: JsonAdapter { property string weekStartDay: "sunday"; property string notifSide: "left" }
    }
    // Which side of the calendar popup holds notifications ("left"|"right").
    readonly property bool calendarNotifLeft: calendarFile.adapter.notifSide !== "right"
    function setCalendarNotifSide(side: string): void {
        let nv = (side === "right") ? "right" : "left"
        if ((calendarFile.adapter.notifSide || "left") === nv) return
        calendarFile.adapter.notifSide = nv
        calendarFile.writeAdapter()
    }

    readonly property var barModuleIds: ["launcher", "workspaces", "activewindow", "clock", "weather", "updates", "systemtray", "network", "volume", "bluetooth", "vitals", "controlcenter", "netanjahu"]
    readonly property var barSections: ["left", "twofifths", "center", "fourfifths", "right"]
    function barNormalizeSection(s: string): string {
        let v = (s || "").trim().toLowerCase()
        if (v === "left") return "left"
        if (v === "center") return "center"
        if (v === "right") return "right"
        if (v === "twofifths" || v === "2/5" || v === "two-fifths" || v === "two_fifths"
                || v === "leftcenter" || v === "left-center" || v === "left_center"
                || v === "centerleft" || v === "center-left" || v === "center_left") return "twofifths"
        if (v === "fourfifths" || v === "4/5" || v === "four-fifths" || v === "four_fifths"
                || v === "rightcenter" || v === "right-center" || v === "right_center"
                || v === "centerright" || v === "center-right" || v === "center_right") return "fourfifths"
        return ""
    }
    FileView {
        id: barLayoutFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/bar_layout.json"
        watchChanges: true; onFileChanged: debouncedReload(barLayoutFile); blockLoading: true; printErrors: false
        adapter: JsonAdapter {
            property var left: ["launcher", "workspaces"]
            property var twofifths: []
            property var center: ["clock", "updates"]
            property var fourfifths: []
            property var right: []
            property var hidden: []
            property int version: 0
        }
        Component.onCompleted: barMigrateTimer.restart()
    }
    // PERF: one-shot migration fires once at 250ms (was 2s + re-arm = 2
    // wakeups for a version check). No repeat cost after first boot.
    Timer {
        id: barMigrateTimer
        interval: 250
        repeat: false
        onTriggered: {
            if ((barLayoutFile.adapter.version || 0) >= 1) return
            root.migrateBarLayout()
        }
    }
    function barDefaultLayout(): var {
        return { left: ["launcher", "workspaces", "activewindow"], twofifths: [], center: ["clock", "weather", "updates"], fourfifths: [], right: ["controlcenter", "systemtray", "network", "volume", "bluetooth", "vitals"] }
    }
    function toStrArray(v: var): var {
        let out = []
        try {
            if (v === null || v === undefined) return out
            if (Array.isArray(v)) {
                for (let i = 0; i < v.length; i++) if (typeof v[i] === "string") out.push(v[i])
                return out
            }
            if (typeof v.length === "number") {
                for (let i = 0; i < v.length; i++) { let e = v[i]; if (typeof e === "string") out.push(e) }
            }
        } catch (e) {}
        return out
    }
    function cleanBarIds(arr: var): var {
        let out = []
        try {
            let ids = toStrArray(arr)
            for (let i = 0; i < ids.length; i++) {
                let id = ids[i]
                if (barModuleIds.indexOf(id) >= 0 && out.indexOf(id) < 0) out.push(id)
            }
        } catch (e) {}
        return out
    }
    function barHiddenIds(): var {
        let out = []
        try {
            let ids = toStrArray(barLayoutFile.adapter.hidden)
            for (let i = 0; i < ids.length; i++) {
                let id = ids[i]
                if (barModuleIds.indexOf(id) >= 0 && out.indexOf(id) < 0) out.push(id)
            }
        } catch (e) {}
        return out
    }
    function isBarModuleHidden(id: string): bool { return barHiddenIds().indexOf(id) >= 0 }
    function barVisibleIds(): var {
        let l = barLayout()
        return l.left.concat(l.twofifths, l.center, l.fourfifths, l.right)
    }
    function hideBarModule(id: string): string {
        if (barModuleIds.indexOf(id) < 0) return "err: unknown id " + id
        if (isBarModuleHidden(id)) return "ok: " + id + " already hidden"
        let vis = barVisibleIds()
        if (vis.indexOf(id) >= 0 && vis.length <= 1) return "err: cannot hide last module"
        let h = barHiddenIds()
        h.push(id)
        barLayoutFile.adapter.hidden = h
        barLayoutFile.writeAdapter()
        return "ok: hidden " + id
    }
    function showBarModule(id: string): string {
        if (barModuleIds.indexOf(id) < 0) return "err: unknown id " + id
        let h = barHiddenIds()
        let i = h.indexOf(id)
        if (i < 0) return "ok: " + id + " already visible"
        h.splice(i, 1)
        barLayoutFile.adapter.hidden = h
        barLayoutFile.writeAdapter()
        return "ok: visible " + id
    }
    function barLayout(): var {
        let hidden = barHiddenIds()
        let notHidden = (arr) => arr.filter(id => hidden.indexOf(id) < 0)
        let l = notHidden(cleanBarIds(barLayoutFile.adapter.left))
        let t = notHidden(cleanBarIds(barLayoutFile.adapter.twofifths))
        let c = notHidden(cleanBarIds(barLayoutFile.adapter.center))
        let f = notHidden(cleanBarIds(barLayoutFile.adapter.fourfifths))
        let r = notHidden(cleanBarIds(barLayoutFile.adapter.right))
        let seen = {}
        let dup = (arr) => arr.filter(id => { if (seen[id]) return false; seen[id] = true; return true })
        l = dup(l); t = dup(t); c = dup(c); f = dup(f); r = dup(r)
        let d = barDefaultLayout()
        for (let i = 0; i < barModuleIds.length; i++) {
            let id = barModuleIds[i]
            if (!seen[id] && hidden.indexOf(id) < 0) {
                if (d.left.indexOf(id) >= 0) l.push(id)
                else if (d.center.indexOf(id) >= 0) c.push(id)
                else r.push(id)
                seen[id] = true
            }
        }
        return { left: l, twofifths: t, center: c, fourfifths: f, right: r }
    }
    function barLayoutString(): string {
        let l = barLayout()
        return "left=" + l.left.join(",") + " twofifths=" + l.twofifths.join(",") + " center=" + l.center.join(",") + " fourfifths=" + l.fourfifths.join(",") + " right=" + l.right.join(",")
    }
    readonly property var barLayoutCached: barLayout()
    readonly property var barLayoutLeft: barLayoutCached.left
    readonly property var barLayoutTwoFifths: barLayoutCached.twofifths
    readonly property var barLayoutCenter: barLayoutCached.center
    readonly property var barLayoutFourFifths: barLayoutCached.fourfifths
    readonly property var barLayoutRight: barLayoutCached.right
    readonly property var barModuleMetaList: [
        {id: "launcher", title: "Menu", icon: "󰀻"},
        {id: "workspaces", title: "Workspaces", icon: ""},
        {id: "activewindow", title: "Active Window", icon: "󰍹"},
        {id: "clock", title: "Clock", icon: ""},
        {id: "weather", title: "Weather", icon: "\ue302"},
        {id: "updates", title: "Updates", icon: ""},
        {id: "network", title: "Network", icon: "󰤨"},
        {id: "volume", title: "Volume", icon: "󰕾"},
        {id: "bluetooth", title: "Bluetooth", icon: "󰂯"},
        {id: "vitals", title: "Vitals", icon: "󰻠"},
        {id: "systemtray", title: "System Tray", icon: "󰆍"},
        {id: "controlcenter", title: "Control Center", icon: "󰘮"},
        {id: "netanjahu", title: "Netanjahu", icon: ""}
    ]
    function setBarLayout(left: var, twofifths: var, center: var, fourfifths: var, right: var): void {
        if (right === undefined && fourfifths === undefined) {
            let legacyR = center
            let legacyC = twofifths
            let l0 = cleanBarIds(left), c0 = cleanBarIds(legacyC), r0 = cleanBarIds(legacyR)
            let t0 = cleanBarIds(barLayoutFile.adapter.twofifths)
            let f0 = cleanBarIds(barLayoutFile.adapter.fourfifths)
            setBarLayout(l0, t0, c0, f0, r0)
            return
        }
        let l = cleanBarIds(left), t = cleanBarIds(twofifths), c = cleanBarIds(center), f = cleanBarIds(fourfifths), r = cleanBarIds(right)
        let hidden = barHiddenIds()
        let seen = {}
        let all = [l, t, c, f, r]
        for (let s = 0; s < 5; s++) all[s] = all[s].filter(id => { if (seen[id] || hidden.indexOf(id) >= 0) return false; seen[id] = true; return true })
        for (let i = 0; i < barModuleIds.length; i++) {
            let id = barModuleIds[i]
            if (!seen[id] && hidden.indexOf(id) < 0) { l.push(id); seen[id] = true }
        }
        if (hidden.length > 0) {
            let old = [cleanBarIds(barLayoutFile.adapter.left), cleanBarIds(barLayoutFile.adapter.twofifths), cleanBarIds(barLayoutFile.adapter.center), cleanBarIds(barLayoutFile.adapter.fourfifths), cleanBarIds(barLayoutFile.adapter.right)]
            let fresh = [l, t, c, f, r]
            for (let h = 0; h < hidden.length; h++) {
                let id = hidden[h]
                for (let s = 0; s < 5; s++) {
                    let oi = old[s].indexOf(id)
                    if (oi >= 0) { fresh[s].splice(Math.max(0, Math.min(oi, fresh[s].length)), 0, id); break }
                }
            }
        }
        barLayoutFile.adapter.left = l
        barLayoutFile.adapter.twofifths = t
        barLayoutFile.adapter.center = c
        barLayoutFile.adapter.fourfifths = f
        barLayoutFile.adapter.right = r
        if ((barLayoutFile.adapter.version || 0) < 1) barLayoutFile.adapter.version = 1
        barLayoutFile.writeAdapter()
    }
    function barSectionOf(id: string): string {
        let l = barLayout()
        if (l.left.indexOf(id) >= 0) return "left"
        if (l.twofifths.indexOf(id) >= 0) return "twofifths"
        if (l.center.indexOf(id) >= 0) return "center"
        if (l.fourfifths.indexOf(id) >= 0) return "fourfifths"
        if (l.right.indexOf(id) >= 0) return "right"
        return ""
    }
    function barSectionArray(l: var, section: string): var {
        let s = barNormalizeSection(section)
        if (s === "left") return l.left
        if (s === "twofifths") return l.twofifths
        if (s === "center") return l.center
        if (s === "fourfifths") return l.fourfifths
        return l.right
    }
    function moveBarWidget(id: string, section: string, index: int): string {
        if (barModuleIds.indexOf(id) < 0) return "err: unknown id " + id
        let sec = barNormalizeSection(section)
        if (sec === "") return "err: section must be left|twofifths|center|fourfifths|right (aliases 2/5, 4/5)"
        if (isBarModuleHidden(id)) showBarModule(id)
        let l = barLayout()
        let from = barSectionOf(id)
        if (from.length > 0) {
            let arr = barSectionArray(l, from)
            let fi = arr.indexOf(id)
            if (fi >= 0) arr.splice(fi, 1)
        }
        let dst = barSectionArray(l, sec)
        let idx = Math.max(0, Math.min(dst.length, Math.round(index)))
        dst.splice(idx, 0, id)
        setBarLayout(l.left, l.twofifths, l.center, l.fourfifths, l.right)
        return "ok: " + id + " -> " + sec + "[" + idx + "] (" + barLayoutString() + ")"
    }
    function resetBarLayout(): void {
        barLayoutFile.adapter.hidden = []
        let d = barDefaultLayout()
        setBarLayout(d.left, d.twofifths, d.center, d.fourfifths, d.right)
    }
    function migrateBarLayout(): void {
        try {
            if ((barLayoutFile.adapter.version || 0) >= 1) return
            let l = { left: ["launcher"], twofifths: [], center: [], fourfifths: [], right: [] }
            let ws = workspacesPosition
            if (ws === "center") l.center.push("workspaces")
            else if (ws === "right") l.right.push("workspaces")
            else l.left.push("workspaces")
            let cp = clockPosition
            if (cp === "left") l.left.push("clock")
            else if (cp === "right") l.right.push("clock")
            else l.center.push("clock")
            if (cp === "left") l.left.push("updates")
            else if (cp === "right") l.right.push("updates")
            else l.center.push("updates")
            if (cp === "left") l.left.push("weather")
            else if (cp === "right") l.right.push("weather")
            else l.center.push("weather")
            if (l.right.indexOf("systemtray") < 0) l.right.unshift("systemtray")
            barLayoutFile.adapter.left = l.left
            barLayoutFile.adapter.twofifths = l.twofifths
            barLayoutFile.adapter.center = l.center
            barLayoutFile.adapter.fourfifths = l.fourfifths
            barLayoutFile.adapter.right = l.right
            barLayoutFile.adapter.version = 1
            barLayoutFile.writeAdapter()
        } catch (e) {}
    }

    // Generic per-module label visibility (future-proof).
    // Modules with their own service storage (volume/showPct, weather/
    // showLabel, vitals/showLabels, clock/clockFormat) keep it for backwards
    // compat. Everything else — updates count, activewindow title, and any
    // future module with a text label — uses this central map so a new
    // widget only needs:
    //   visible: Theme.barLabelVisible("<moduleId>") && <hasLabelData>
    //   function toggleLabel(): void { Theme.toggleBarLabel("<moduleId>") }
    // and right-click toggling works with zero BarModule changes.
    FileView {
        id: barLabelFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/bar_labels.json"
        watchChanges: true; onFileChanged: debouncedReload(barLabelFile); blockLoading: true; printErrors: false
        adapter: JsonAdapter {
            property var labels: ({})
        }
    }
    function barLabelVisible(id: string): bool {
        try {
            let key = (id || "").trim()
            if (key.length === 0) return false
            let m = barLabelFile.adapter.labels
            if (m && m[key] !== undefined) return m[key] !== false
            return true
        } catch (e) { return true }
    }
    function setBarLabelVisible(id: string, v: bool): void {
        let key = (id || "").trim()
        if (key.length === 0) return
        let nv = !!v
        if (barLabelVisible(key) === nv) {
            // Still persist explicit false so the choice survives restarts
            // even when the default would also be visible.
            try {
                let cur = barLabelFile.adapter.labels
                if (cur && cur[key] !== undefined) return
            } catch (e) {}
            if (nv) return
        }
        let m = {}
        try {
            let cur = barLabelFile.adapter.labels
            if (cur && typeof cur === "object") {
                for (let k in cur) m[k] = cur[k]
            }
        } catch (e) {}
        m[key] = nv
        barLabelFile.adapter.labels = m
        barLabelFile.writeAdapter()
    }
    function toggleBarLabel(id: string): void {
        let key = (id || "").trim()
        if (key.length === 0) return
        setBarLabelVisible(key, !barLabelVisible(key))
    }

    FileView {
        id: trayFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/tray.json"
        watchChanges: true; onFileChanged: debouncedReload(trayFile); blockLoading: true; printErrors: false
        adapter: JsonAdapter {
            property var pinned: []
            property var hidden: []
        }
    }
    function trayPinnedIds(): var { return toStrArray(trayFile.adapter.pinned) }
    function trayHiddenIds(): var { return toStrArray(trayFile.adapter.hidden) }
    function isTrayPinned(id: string): bool { return trayPinnedIds().indexOf((id || "").toString()) >= 0 }
    function isTrayHidden(id: string): bool { return trayHiddenIds().indexOf((id || "").toString()) >= 0 }
    function setTrayPinned(id: string, pinned: bool): void {
        let key = (id || "").toString()
        if (key.length === 0) return
        let p = trayPinnedIds()
        let i = p.indexOf(key)
        if (pinned && i < 0) p.push(key)
        else if (!pinned && i >= 0) p.splice(i, 1)
        else return
        trayFile.adapter.pinned = p
        if (pinned) setTrayHidden(key, false)
        trayFile.writeAdapter()
    }
    function setTrayHidden(id: string, hidden: bool): void {
        let key = (id || "").toString()
        if (key.length === 0) return
        let h = trayHiddenIds()
        let i = h.indexOf(key)
        if (hidden && i < 0) h.push(key)
        else if (!hidden && i >= 0) h.splice(i, 1)
        else return
        trayFile.adapter.hidden = h
        if (hidden) {
            let p = trayPinnedIds()
            let pi = p.indexOf(key)
            if (pi >= 0) { p.splice(pi, 1); trayFile.adapter.pinned = p }
        }
        trayFile.writeAdapter()
    }
    function toggleTrayPinned(id: string): void { setTrayPinned(id, !isTrayPinned(id)) }
    function toggleTrayHidden(id: string): void { setTrayHidden(id, !isTrayHidden(id)) }

    FileView {
        id: powerModeFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/powermode.json"
        watchChanges: true; onFileChanged: debouncedReload(powerModeFile); blockLoading: true; printErrors: false
        adapter: JsonAdapter { property string mode: "balanced" }
    }
    readonly property string powerMode: powerModeFile.adapter.mode || "balanced"
    function powerModeLabel(): string {
        let m = (powerMode || "").toLowerCase()
        if (m === "performance") return "Performance"
        if (m === "power-saver") return "Power Saver"
        return "Balanced"
    }
    function powerModeIcon(): string {
        let m = (powerMode || "").toLowerCase()
        if (m === "performance") return "󰓅"
        if (m === "power-saver") return "󰌪"
        return "󰾅"
    }
    Process { id: powerModeProc; command: ["bash", "-c", "echo"] }
    function cyclePowerMode(): void {
        let cur = (powerModeFile.adapter.mode || "balanced").toLowerCase()
        let next = "balanced"
        if (cur === "balanced") next = "performance"
        else if (cur === "performance") next = "power-saver"
        else next = "balanced"
        powerModeFile.adapter.mode = next
        powerModeFile.writeAdapter()
        // PERF: Quickshell PowerProfiles API already applies the profile
        // synchronously. The old powerprofilesctl fork duplicated the same
        // action (2 writers, race on rapid toggle). Keep API only.
        try {
            if (next === "performance") PowerProfiles.profile = PowerProfile.Performance
            else if (next === "power-saver") PowerProfiles.profile = PowerProfile.PowerSaver
            else PowerProfiles.profile = PowerProfile.Balanced
        } catch(e) {}
    }

    function withAlpha(c: color, a: real): color { return Qt.rgba(c.r, c.g, c.b, a) }

    readonly property int animMicro: animationsEnabled ? 100 : 0
    readonly property int animFast: animationsEnabled ? 150 : 0
    readonly property int animNormal: animationsEnabled ? 200 : 0
    readonly property int animSlow: animationsEnabled ? 300 : 0
    readonly property int animEmph: animationsEnabled ? 400 : 0
    readonly property int animStagger: animationsEnabled ? 30 : 0
    readonly property int animBounce: animationsEnabled ? 350 : 0
    readonly property int easingStandard: Easing.OutCubic
    readonly property int easingEmph: Easing.OutBack
    readonly property int easingBounce: Easing.OutBack
    readonly property int easingSmooth: Easing.InOutCubic
    readonly property int easingBezier: Easing.BezierSpline
    readonly property var curveEmphasized: [0.2, 0, 0, 1, 1, 1]
    readonly property var curveEmphasizedDecelerate: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var curveEmphasizedAccelerate: [0.3, 0, 0.8, 0.15, 1, 1]
    readonly property real easingOvershoot: 1.55
    readonly property real hoverOvershoot: 1.7
    readonly property real hoverScale: 1.06
    readonly property real pressScale: 0.94
    readonly property real iconPopScale: 1.08

    // ---- Caelestia-expressive motion tokens (caelestia-dots/shell) ----
    // Durations match AnimDurationTokens; curves match AnimCurves. Kept
    // separate from the legacy animFast/animNormal aliases so existing
    // call-sites keep working while new Ui/Anim primitives bind here.
    // All durations collapse to 0 when animations are disabled.
    readonly property int durSmall: animationsEnabled ? 200 : 0
    readonly property int durNormal: animationsEnabled ? 400 : 0
    readonly property int durLarge: animationsEnabled ? 600 : 0
    readonly property int durExtraLarge: animationsEnabled ? 1000 : 0
    readonly property int durFastSpatial: animationsEnabled ? 350 : 0
    readonly property int durDefaultSpatial: animationsEnabled ? 500 : 0
    readonly property int durSlowSpatial: animationsEnabled ? 650 : 0
    readonly property int durFastEffects: animationsEnabled ? 150 : 0
    readonly property int durDefaultEffects: animationsEnabled ? 200 : 0
    readonly property int durSlowEffects: animationsEnabled ? 300 : 0
    // BezierSpline control points (6 values per cubic segment). The
    // emphasized curve is two segments (12 values), everything else one.
    readonly property var curveStandard: [0.2, 0, 0, 1, 1, 1]
    readonly property var curveStandardAccel: [0.3, 0, 1, 1, 1, 1]
    readonly property var curveStandardDecel: [0, 0, 0, 1, 1, 1]
    readonly property var curveEmphasizedFull: [0.05, 0, 0.133333, 0.06, 0.166667, 0.4, 0.208333, 0.82, 0.25, 1, 1, 1]
    readonly property var curveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property var curveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property var curveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1]
    readonly property var curveFastEffects: [0.31, 0.94, 0.34, 1, 1, 1]
    readonly property var curveDefaultEffects: [0.34, 0.8, 0.34, 1, 1, 1]
    readonly property var curveSlowEffects: [0.34, 0.88, 0.34, 1, 1, 1]
    // Type ids mirror Caelestia Anim.Type so ports read 1:1.
    readonly property int animTypeStandardSmall: 0
    readonly property int animTypeStandard: 1
    readonly property int animTypeStandardLarge: 2
    readonly property int animTypeStandardExtraLarge: 3
    readonly property int animTypeEmphasizedSmall: 4
    readonly property int animTypeEmphasized: 5
    readonly property int animTypeEmphasizedLarge: 6
    readonly property int animTypeEmphasizedExtraLarge: 7
    readonly property int animTypeFastSpatial: 8
    readonly property int animTypeDefaultSpatial: 9
    readonly property int animTypeSlowSpatial: 10
    readonly property int animTypeFastEffects: 11
    readonly property int animTypeDefaultEffects: 12
    readonly property int animTypeSlowEffects: 13
    function animDurationFor(type: int): int {
        switch (type) {
        case animTypeStandardSmall: return durSmall
        case animTypeStandard: return durNormal
        case animTypeStandardLarge: return durLarge
        case animTypeStandardExtraLarge: return durExtraLarge
        case animTypeEmphasizedSmall: return durSmall
        case animTypeEmphasized: return durNormal
        case animTypeEmphasizedLarge: return durLarge
        case animTypeEmphasizedExtraLarge: return durExtraLarge
        case animTypeFastSpatial: return durFastSpatial
        case animTypeDefaultSpatial: return durDefaultSpatial
        case animTypeSlowSpatial: return durSlowSpatial
        case animTypeFastEffects: return durFastEffects
        case animTypeDefaultEffects: return durDefaultEffects
        case animTypeSlowEffects: return durSlowEffects
        default: return durNormal
        }
    }
    function animCurveFor(type: int): var {
        switch (type) {
        case animTypeFastSpatial: return curveFastSpatial
        case animTypeDefaultSpatial: return curveDefaultSpatial
        case animTypeSlowSpatial: return curveSlowSpatial
        case animTypeFastEffects: return curveFastEffects
        case animTypeDefaultEffects: return curveDefaultEffects
        case animTypeSlowEffects: return curveSlowEffects
        case animTypeEmphasizedSmall:
        case animTypeEmphasized:
        case animTypeEmphasizedLarge:
        case animTypeEmphasizedExtraLarge: return curveEmphasizedFull
        default: return curveStandard
        }
    }

    readonly property int panelAnimFade: durDefaultEffects
    // Panel slide rides DefaultSpatial (500ms): panels travel their full
    // height out from behind the bar edge (Caelestia drawer offsetScale
    // timing) — FastSpatial would rush the ~400px emerge.
    readonly property int panelAnimSlide: durDefaultSpatial
    readonly property int panelAnimScale: durNormal
    readonly property int panelAnimExit: durFastEffects
    readonly property int panelAnimCollapse: durDefaultEffects
    readonly property int expanderDur: durDefaultEffects
    readonly property int celestiaPanelDur: durDefaultSpatial
    readonly property var celestiaPanelCurve: curveDefaultSpatial
    // Windows/loaders stay mapped until the popout close run has finished:
    // Caelestia closes on the same expressive default spatial Behavior as it
    // opens (500ms, no fast exit), so the old FastEffects-based delay would
    // tear the surface down mid-flight.
    readonly property int panelHideDelay: animationsEnabled ? durDefaultSpatial + 20 : 0
    // Attached-bar morph: dropdown boxes sit flush with the bar edge
    // instead of floating detached below it. Must stay 0: the panel
    // windows are placed on the compositor's remaining area (bar bottom =
    // window top), so any overlap is clipped and only wastes the border.
    // The rounded top corners still merge into the bar for the morph look.
    readonly property int panelAttachOverlap: 0
    readonly property real panelOvershootScale: 1.35
    readonly property real panelOvershootSlide: 1.25
    readonly property int panelSlideOffset: 18
    readonly property int panelEasingFade: Easing.OutCubic
    readonly property int panelEasingSlide: Easing.OutBack
    readonly property int panelEasingScale: Easing.OutBack
    readonly property int panelEasingExit: Easing.InCubic
}
