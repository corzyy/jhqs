pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: engine

    Process { id: themeEngineInitProc; command: ["bash", "-c", "echo"] }
    Timer {
        id: themeEngineInitTimer
        interval: 650; running: true; repeat: false
        onTriggered: {
            if (!themeEngineInitProc.running) {
                themeEngineInitProc.command = ["bash", "-c", "mkdir -p ~/.config/quickshell/jhqs/themes; if [ ! -f ~/.config/quickshell/jhqs/themes/theme_engine.json ]; then echo '{\"engine\":\"wallpaper\"}' > ~/.config/quickshell/jhqs/themes/theme_engine.json; fi; jq '.engine //= \"wallpaper\"' ~/.config/quickshell/jhqs/themes/theme_engine.json > /tmp/th_engine.json 2>/dev/null && mv /tmp/th_engine.json ~/.config/quickshell/jhqs/themes/theme_engine.json; echo init_done"]
                themeEngineInitProc.running = true
            }
        }
    }
    FileView {
        id: themeEngineFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/themes/theme_engine.json"
        watchChanges: true; onFileChanged: reload(); blockLoading: true; printErrors: false
        adapter: JsonAdapter { property string engine: "wallpaper" }
    }
    readonly property string currentEngine: {
        let e = themeEngineFile.adapter.engine
        if (e === "everforest" || e === "tokyonight" || e === "petrichor" || e === "monochrome" || e === "catppuccin") return e
        return "wallpaper"
    }

    FileView {
        id: matugenSettingsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/themes/matugen_settings.json"
        watchChanges: true; onFileChanged: reload(); blockLoading: true; printErrors: false
        adapter: JsonAdapter { property string type: "scheme-tonal-spot"; property string mode: "dark"; property real contrast: 0.0 }
    }
    readonly property var matugenTypes: ["scheme-tonal-spot", "scheme-content", "scheme-expressive", "scheme-fidelity", "scheme-fruit-salad", "scheme-monochrome", "scheme-neutral", "scheme-rainbow", "scheme-vibrant", "scheme-smart"]
    readonly property var matugenTypeLabels: ({"scheme-tonal-spot": "Tonal Spot", "scheme-content": "Content", "scheme-expressive": "Expressive", "scheme-fidelity": "Fidelity", "scheme-fruit-salad": "Fruit Salad", "scheme-monochrome": "Monochrome", "scheme-neutral": "Neutral", "scheme-rainbow": "Rainbow", "scheme-vibrant": "Vibrant", "scheme-smart": "Smart (Auto)"})
    readonly property string monetType: { try { let v = matugenSettingsFile.adapter.type; if (v && v.length>0) return v; return "scheme-tonal-spot" } catch(e) { return "scheme-tonal-spot" } }
    readonly property string monetMode: { try { let m = matugenSettingsFile.adapter.mode; if (m==="light"||m==="dark") return m; return "dark" } catch(e){ return "dark" } }

    property bool themeBusy: false
    property string _pendingSpec: ""
    Process {
        id: themeSerialProc
        command: ["bash", "-c", "echo"]
        onExited: (code) => engine.finishThemeApply(code)
    }
    Timer {
        id: themeNextTimer
        interval: 400; repeat: false
        onTriggered: engine.tryRunPending()
    }
    function enqueueThemeApply(spec: string) {
        if (themeBusy || themeSerialProc.running) { _pendingSpec = spec; return }
        runThemeSpec(spec)
    }
    function runThemeSpec(spec: string) {
        if (spec.indexOf("preset:") === 0) runPresetApply(spec.substring(7))
        else if (spec.indexOf("monet:") === 0) runMonetApply(spec.substring(6))
        else if (spec === "monetCurrent") runMonetApply(escShellArg(resolveWallpaper("", "")))
        else return
        themeBusy = true
    }
    function tryRunPending() {
        if (themeBusy || themeSerialProc.running) return
        if (_pendingSpec === "") return
        let s = _pendingSpec
        _pendingSpec = ""
        runThemeSpec(s)
    }
    function finishThemeApply(code) {
        themeBusy = false
        if (code !== 0) console.log("[ThemeEngine] apply exited with code", code)
        if (_pendingSpec !== "") themeNextTimer.restart()
    }

    FileView {
        id: currentWallpaperFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/current_wallpaper.txt"
        watchChanges: true; onFileChanged: reload(); blockLoading: true; printErrors: false
    }
    function currentWallpaperText(): string {
        try { return currentWallpaperFile.text().trim() } catch(e) { return "" }
    }

    Timer {
        id: themeEngineApplyTimer
        interval: 950; running: true; repeat: false
        onTriggered: {
            if (engine.currentEngine === "everforest") applyPreset("everforest")
            else if (engine.currentEngine === "tokyonight") applyPreset("tokyonight")
            else if (engine.currentEngine === "petrichor") applyPreset("petrichor")
            else if (engine.currentEngine === "monochrome") applyPreset("monochrome")
            else if (engine.currentEngine === "catppuccin") applyPreset("catppuccin")
        }
    }

    function escShellArg(path: string): string {
        return path.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"").replace(/\$/g, "\\$").replace(/`/g, "\\`")
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
        return "MATUGEN_RUN=\"$HOME/.config/quickshell/jhqs/scripts/matugen-run.sh\"; if [ ! -x \"$MATUGEN_RUN\" ]; then [ -x \"$HOME/.cargo/bin/matugen\" ] && MATUGEN_RUN=\"$HOME/.cargo/bin/matugen\" || MATUGEN_RUN=\"matugen\"; fi;"
    }

    function runMonetApply(escPath: string) {
        let cmd = matugenBin()
        cmd += " WALL=\"" + escPath + "\";"
        cmd += " [ -f \"$WALL\" ] || WALL=\"$(cat ~/.cache/swaybg/current 2>/dev/null | tr -d '\\r\\n')\";"
        cmd += " [ -f \"$WALL\" ] || WALL=\"$(cat ~/.cache/awww/current 2>/dev/null | tr -d '\\r\\n')\";"
        cmd += " if [ ! -f \"$WALL\" ]; then for d in \"$HOME/Bilder/wallpapers\" \"$HOME/Pictures/wallpapers\" \"$HOME/Wallpapers\" \"${XDG_PICTURES_DIR:-$HOME/Pictures}/wallpapers\" \"$HOME/wallpapers\"; do if [ -d \"$d\" ]; then WALL=\"$(find \"$d\" -mindepth 1 -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' -o -iname '*.tiff' \\) 2>/dev/null | sort | head -1)\"; [ -f \"$WALL\" ] && break; fi; done; fi;"
        cmd += " TYPE=$(jq -r '.type // \"scheme-tonal-spot\"' \"$HOME/.config/quickshell/jhqs/themes/matugen_settings.json\" 2>/dev/null); MODE=$(jq -r '.mode // \"dark\"' \"$HOME/.config/quickshell/jhqs/themes/matugen_settings.json\" 2>/dev/null);"
        cmd += " if ! echo \"$TYPE\" | grep -q \"^scheme-\"; then TYPE=\"scheme-tonal-spot\"; fi; if [ \"$MODE\" != \"dark\" ] && [ \"$MODE\" != \"light\" ]; then MODE=\"dark\"; fi;"
        cmd += " if [ -f \"$WALL\" ]; then if [ -x \"$MATUGEN_RUN\" ] && [ \"$(basename \"$MATUGEN_RUN\")\" = \"matugen-run.sh\" ]; then bash \"$MATUGEN_RUN\" image \"$WALL\" -t \"$TYPE\" -m \"$MODE\" --prefer saturation 2>&1 | logger -t matugen; else \"$MATUGEN_RUN\" image \"$WALL\" -t \"$TYPE\" -m \"$MODE\" --prefer saturation 2>&1 | logger -t matugen; fi; sed -i -E 's/^color_theme *= *\".*\"/color_theme = \"matugen\"/; s/^theme_background *= *.*/theme_background = False/' ~/.config/btop/btop.conf 2>/dev/null; bash \"$HOME/.config/quickshell/jhqs/scripts/apply-gtk.sh\" \"$MODE\" 2>&1 | logger -t gtk; hyprctl eval 'package.loaded[\"matugen-colors\"]=nil; pcall(require, \"matugen-colors\")' 2>&1 | logger -t hyprctl; notify-send -u low \"Monet\" \"Farbschema $TYPE • $MODE\" 2>/dev/null || true;"
        cmd += " else echo \"[ThemeEngine] no wallpaper found, Monet skipped\" | logger -t monet; notify-send -u critical \"Monet\" \"Kein Wallpaper gefunden — Farben unverändert\" 2>/dev/null || true; fi; echo done"
        if (themeSerialProc.running) { _pendingSpec = "monet:" + escPath; return }
        themeSerialProc.command = ["bash", "-c", cmd]
        themeSerialProc.running = true
    }

    function runPresetApply(id: string) {
        let mode = "dark"
        try { let m = matugenSettingsFile.adapter.mode; if (m === "light" || m === "dark") mode = m } catch(e) { mode = "dark" }
        let nameMap = { everforest: "everforest-soft", tokyonight: "tokyonight", petrichor: "petrichor", monochrome: "monochrome", catppuccin: "catppuccin-mocha" }
        let key = nameMap[id] || id
        let src = Quickshell.env("HOME") + "/.config/quickshell/jhqs/themes/" + key + "-" + mode + ".json"
        let dst = Quickshell.env("HOME") + "/.config/quickshell/jhqs/themes/matugen.json"
        let render = Quickshell.env("HOME") + "/.config/quickshell/jhqs/scripts/render-everforest.py"
        let label = id.charAt(0).toUpperCase() + id.slice(1)
        let cmd = "SRC=\"" + src.replace(/\"/g,"\\\"") + "\"; DST=\"" + dst.replace(/\"/g,"\\\"") + "\"; RENDER=\"" + render.replace(/\"/g,"\\\"") + "\"; TMP=\"$DST.tmp.$$\";"
        cmd += " if [ -f \"$SRC\" ]; then cp -f \"$SRC\" \"$TMP\" 2>&1 | logger -t " + id + " && mv -f \"$TMP\" \"$DST\" 2>&1 | logger -t " + id + "; rm -f \"$TMP\"; python3 \"$RENDER\" " + mode + " \"$SRC\" 2>&1 | logger -t " + id + "; echo \"[" + label + "] " + mode + " applied from $SRC (all apps)\" | logger -t " + id + ";"
        cmd += " else echo \"[" + label + "] source missing $SRC\" | logger -t " + id + "; fi; bash \"$HOME/.config/quickshell/jhqs/scripts/apply-gtk.sh\" \"" + mode + "\" 2>&1 | logger -t gtk; hyprctl eval 'package.loaded[\"matugen-colors\"]=nil; pcall(require, \"matugen-colors\")' 2>&1 | logger -t hyprctl; notify-send -u low \"Theme\" \"" + label + " (" + mode + ") — alle Programme aktualisiert\" 2>/dev/null || true; echo done"
        if (themeSerialProc.running) { _pendingSpec = "preset:" + id; return }
        themeSerialProc.command = ["bash", "-c", cmd]
        themeSerialProc.running = true
    }

    function applyPreset(id: string) { enqueueThemeApply("preset:" + id) }

    function setThemeEngine(id: string) {
        let nid = "wallpaper"
        if (id === "everforest" || id === "tokyonight" || id === "petrichor" || id === "monochrome" || id === "catppuccin") nid = id
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
    function applyMonetFromPath(escPath: string) {
        enqueueThemeApply("monet:" + escPath)
    }

    function applyThemeFromWallpaper(overridePath: string, fallbackPath: string) {
        let wallpaper = resolveWallpaper(overridePath, fallbackPath)
        enqueueThemeApply("monet:" + escShellArg(wallpaper))
    }
}
