pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: engine

    // PERF: mkdir+jq init used to run 650ms after EVERY menu open (ThemeEngine
    // lives in the menu Loader, re-created per open). Adapter defaults already
    // cover a missing file; the file is created on first writeAdapter. No boot
    // fork needed.
    FileView {
        id: themeEngineFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/themes/theme_engine.json"
        watchChanges: true; onFileChanged: engineReloadDebounce.restart(); blockLoading: true; printErrors: false
        adapter: JsonAdapter { property string engine: "wallpaper" }
    }
    Timer {
        id: engineReloadDebounce
        interval: 250; repeat: false
        onTriggered: {
            try { themeEngineFile.reload() } catch (e) { }
            try { matugenSettingsFile.reload() } catch (e2) { }
            try { currentWallpaperFile.reload() } catch (e3) { }
        }
    }
    readonly property string currentEngine: {
        let e = themeEngineFile.adapter.engine
        if (e === "everforest" || e === "tokyonight" || e === "petrichor" || e === "monochrome" || e === "catppuccin" || e === "gruvbox") return e
        return "wallpaper"
    }

    FileView {
        id: matugenSettingsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/themes/matugen_settings.json"
        watchChanges: true; onFileChanged: engineReloadDebounce.restart(); blockLoading: true; printErrors: false
        adapter: JsonAdapter { property string type: "scheme-tonal-spot"; property string mode: "dark"; property real contrast: 0.0 }
    }
    readonly property var matugenTypes: ["scheme-tonal-spot", "scheme-content", "scheme-expressive", "scheme-fidelity", "scheme-fruit-salad", "scheme-monochrome", "scheme-neutral", "scheme-rainbow", "scheme-vibrant", "scheme-smart"]
    readonly property var matugenTypeLabels: ({"scheme-tonal-spot": "Tonal Spot", "scheme-content": "Content", "scheme-expressive": "Expressive", "scheme-fidelity": "Fidelity", "scheme-fruit-salad": "Fruit Salad", "scheme-monochrome": "Monochrome", "scheme-neutral": "Neutral", "scheme-rainbow": "Rainbow", "scheme-vibrant": "Vibrant", "scheme-smart": "Smart (Auto)"})
    readonly property string monetType: { try { let v = matugenSettingsFile.adapter.type; if (v && v.length>0) return v; return "scheme-tonal-spot" } catch(e) { return "scheme-tonal-spot" } }
    readonly property string monetMode: { try { let m = matugenSettingsFile.adapter.mode; if (m==="light"||m==="dark") return m; return "dark" } catch(e){ return "dark" } }

    property bool themeBusy: false
    property string _pendingSpec: ""
    property bool _pendingSilent: false
    Process {
        id: themeSerialProc
        command: ["bash", "-c", "echo"]
        onExited: (code) => engine.finishThemeApply(code)
    }
    Timer {
        id: themeNextTimer
        // Minimal gap between a finished apply and a coalesced pending one:
        // lets file watchers settle so the next run reads fresh inputs.
        interval: 100; repeat: false
        onTriggered: engine.tryRunPending()
    }
    function enqueueThemeApply(spec: string, silent: bool) {
        if (themeBusy || themeSerialProc.running) { _pendingSpec = spec; _pendingSilent = !!silent; return }
        runThemeSpec(spec, !!silent)
    }
    function runThemeSpec(spec: string, silent: bool) {
        if (spec.indexOf("preset:") === 0) runPresetApply(spec.substring(7), !!silent)
        else if (spec.indexOf("monet:") === 0) runMonetApply(spec.substring(6))
        else if (spec === "monetCurrent") runMonetApply("")
        else return
        themeBusy = true
    }
    function tryRunPending() {
        if (themeBusy || themeSerialProc.running) return
        if (_pendingSpec === "") return
        let s = _pendingSpec
        let sl = _pendingSilent
        _pendingSpec = ""
        _pendingSilent = false
        runThemeSpec(s, sl)
    }
    function finishThemeApply(code) {
        themeBusy = false
        if (code !== 0) console.log("[ThemeEngine] apply exited with code", code)
        if (_pendingSpec !== "") themeNextTimer.restart()
    }

    FileView {
        id: currentWallpaperFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/current_wallpaper.txt"
        watchChanges: true; onFileChanged: engineReloadDebounce.restart(); blockLoading: true; printErrors: false
    }
    function currentWallpaperText(): string {
        try { return currentWallpaperFile.text().trim() } catch(e) { return "" }
    }

    Timer {
        id: themeEngineApplyTimer
        interval: 950; running: true; repeat: false
        // Re-sync apply: ThemeEngine is re-created on every menu open (the
        // menu lives in a Loader), so this must stay silent — otherwise a
        // "Theme" notification pops up ~1s after opening the menu whenever
        // it stays open past this timer (e.g. while scrolling).
        onTriggered: {
            if (engine.currentEngine === "everforest") applyPreset("everforest", true)
            else if (engine.currentEngine === "tokyonight") applyPreset("tokyonight", true)
            else if (engine.currentEngine === "petrichor") applyPreset("petrichor", true)
            else if (engine.currentEngine === "monochrome") applyPreset("monochrome", true)
            else if (engine.currentEngine === "catppuccin") applyPreset("catppuccin", true)
            else if (engine.currentEngine === "gruvbox") applyPreset("gruvbox", true)
        }
    }

    function resolveWallpaper(overridePath: string, fallbackPath: string): string {
        let w = (overridePath && overridePath.length > 0) ? overridePath : ""
        if (w === "") w = currentWallpaperText()
        if (w === "") w = (fallbackPath && fallbackPath.length > 0) ? fallbackPath : ""
        return w
    }

    function applyMonetScheme(type, mode) {
        if (!type || type.length === 0) type = matugenSettingsFile.adapter.type
        if (!mode || mode.length === 0) mode = matugenSettingsFile.adapter.mode
        if (type.indexOf("scheme-") !== 0) type = "scheme-tonal-spot"
        if (mode !== "dark" && mode !== "light") mode = "dark"
        matugenSettingsFile.adapter.type = type
        matugenSettingsFile.adapter.mode = mode
        matugenSettingsFile.writeAdapter()
        if (currentEngine !== "wallpaper") {
            themeEngineFile.adapter.engine = "wallpaper"
            themeEngineFile.writeAdapter()
        }
        enqueueThemeApply("monetCurrent")
    }

    function matugenBin(): string {
        // jhqs Application Theming: route through matugen-run.sh so template
        // toggles (theming_settings.json) + terminals-always-dark are honored.
        // Provides a "${MATUGEN[@]}" argv array: [bash matugen-run.sh] when
        // executable, else the plain matugen binary.
        return "RUN=\"$HOME/.config/quickshell/jhqs/scripts/matugen-run.sh\"; if [ -x \"$RUN\" ]; then MATUGEN=(bash \"$RUN\"); else [ -x \"$HOME/.cargo/bin/matugen\" ] && MATUGEN=(\"$HOME/.cargo/bin/matugen\") || MATUGEN=(matugen); fi;"
    }

    function runMonetApply(wallPath: string) {
        // Fast path: TYPE/MODE come straight from the QML adapter (no jq
        // subprocesses) and WALL travels as argv $1 (no shell escaping, no
        // find(1) directory scan). matugen-run.sh keeps the synchronous part
        // to ~0.3s (papirus icons + gtk re-apply run detached).
        let type = "scheme-tonal-spot", mode = "dark"
        try {
            let t = matugenSettingsFile.adapter.type
            if (t && matugenTypes.indexOf(t) >= 0) type = t
            let m = matugenSettingsFile.adapter.mode
            if (m === "light" || m === "dark") mode = m
        } catch (e) {}
        let wall = (wallPath && wallPath.length > 0) ? wallPath : ""
        if (wall === "") wall = resolveWallpaper("", "")
        let cmd = matugenBin()
        cmd += "WALL=\"$1\"; TYPE=\"$2\"; MODE=\"$3\";"
        cmd += " [ -f \"$WALL\" ] || WALL=\"$(cat ~/.cache/swaybg/current 2>/dev/null | tr -d '\\r\\n')\";"
        cmd += " [ -f \"$WALL\" ] || WALL=\"$(cat ~/.config/quickshell/jhqs/config/current_wallpaper.txt 2>/dev/null | tr -d '\\r\\n')\";"
        cmd += " case \"$TYPE\" in scheme-*) ;; *) TYPE=\"scheme-tonal-spot\";; esac; [ \"$MODE\" = \"light\" ] || MODE=\"dark\";"
        cmd += " if [ -f \"$WALL\" ]; then"
        cmd += " \"${MATUGEN[@]}\" image \"$WALL\" -t \"$TYPE\" -m \"$MODE\" --prefer saturation 2>&1 | logger -t matugen;"
        // btop/kitty/gtk reloads are matugen post_hooks — no duplicate sed here.
        // GTK settings.ini/css catch-up runs detached: the serial proc
        // returns as soon as matugen is done (~0.3s).
        cmd += " (bash \"$HOME/.config/quickshell/jhqs/scripts/apply-gtk.sh\" \"$MODE\" 2>&1 | logger -t gtk) >/dev/null 2>&1 < /dev/null &"
        cmd += " notify-send -u low \"Monet\" \"Farbschema $TYPE • $MODE\" 2>/dev/null || true;"
        cmd += " else echo \"[ThemeEngine] no wallpaper found, Monet skipped\" | logger -t monet; notify-send -u critical \"Monet\" \"Kein Wallpaper gefunden — Farben unverändert\" 2>/dev/null || true; fi; echo done"
        if (themeSerialProc.running) { _pendingSpec = "monet:" + wall; return }
        themeSerialProc.command = ["bash", "-c", cmd, "jhqs-monet", wall, type, mode]
        themeSerialProc.running = true
    }

    function runPresetApply(id: string, silent: bool) {
        let mode = "dark"
        try { let m = matugenSettingsFile.adapter.mode; if (m === "light" || m === "dark") mode = m } catch(e) { mode = "dark" }
        let nameMap = { everforest: "everforest-soft", tokyonight: "tokyonight", petrichor: "petrichor", monochrome: "monochrome", catppuccin: "catppuccin-mocha", gruvbox: "gruvbox" }
        let key = nameMap[id] || id
        // SRC/DST/RENDER travel as argv ($1..$3): no quote-escaping bugs with
        // exotic $HOME values. The shell colors update instantly via the
        // atomic DST swap; the slow per-app render runs detached.
        let src = Quickshell.env("HOME") + "/.config/quickshell/jhqs/themes/" + key + "-" + mode + ".json"
        let dst = Quickshell.env("HOME") + "/.config/quickshell/jhqs/themes/matugen.json"
        let render = Quickshell.env("HOME") + "/.config/quickshell/jhqs/scripts/render-everforest.py"
        let label = id.charAt(0).toUpperCase() + id.slice(1)
        label = label.replace(/[^A-Za-z0-9 -]/g, "")
        if (label.length === 0) label = "Theme"
        let cmd = "SRC=\"$1\"; DST=\"$2\"; RENDER=\"$3\"; MODE=\"$4\"; SILENT=\"$5\"; TAG=\"" + id.replace(/[^a-z0-9-]/g, "") + "\"; LBL=\"" + label + "\";"
        cmd += " if [ -f \"$SRC\" ]; then if cmp -s \"$SRC\" \"$DST\" 2>/dev/null; then echo \"[$LBL] $MODE already active, skip\" | logger -t \"$TAG\";"
        cmd += " else TMP=\"$DST.tmp.$$\"; cp -f \"$SRC\" \"$TMP\" && mv -f \"$TMP\" \"$DST\"; rm -f \"$TMP\";"
        cmd += " (python3 \"$RENDER\" \"$MODE\" \"$SRC\" 2>&1 | logger -t \"$TAG\"; bash \"$HOME/.config/quickshell/jhqs/scripts/apply-gtk.sh\" \"$MODE\" 2>&1 | logger -t gtk) >/dev/null 2>&1 < /dev/null &"
        cmd += " echo \"[$LBL] $MODE applied from $SRC (shell instant, apps in background)\" | logger -t \"$TAG\"; fi;"
        cmd += " else echo \"[$LBL] source missing $SRC\" | logger -t \"$TAG\"; fi;"
        cmd += " if [ \"$SILENT\" != \"1\" ]; then notify-send -u low \"Theme\" \"$LBL (" + mode + ")\" 2>/dev/null || true; fi; echo done"
        if (themeSerialProc.running) { _pendingSpec = "preset:" + id; _pendingSilent = !!silent; return }
        themeSerialProc.command = ["bash", "-c", cmd, "jhqs-preset", src, dst, render, mode, silent ? "1" : "0"]
        themeSerialProc.running = true
    }

    function applyPreset(id: string, silent: bool) { enqueueThemeApply("preset:" + id, !!silent) }

    function setThemeEngine(id: string) {
        let nid = "wallpaper"
        if (id === "everforest" || id === "tokyonight" || id === "petrichor" || id === "monochrome" || id === "catppuccin" || id === "gruvbox") nid = id
        if (themeEngineFile.adapter.engine === nid) {
            applyEngine(nid)
            return
        }
        themeEngineFile.adapter.engine = nid
        themeEngineFile.writeAdapter()
        applyEngine(nid)
    }
    function applyEngine(nid: string) {
        if (nid === "wallpaper") applyThemeFromWallpaper("", "")
        else applyPreset(nid)
    }

    function abortMonet() { if (_pendingSpec.indexOf("monet:") === 0 || _pendingSpec === "monetCurrent") _pendingSpec = "" }
    function applyMonetFromPath(rawPath: string) {
        enqueueThemeApply("monet:" + (rawPath || ""))
    }

    function applyThemeFromWallpaper(overridePath: string, fallbackPath: string) {
        let wallpaper = resolveWallpaper(overridePath, fallbackPath)
        enqueueThemeApply("monet:" + wallpaper)
    }
}
