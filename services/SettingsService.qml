pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../themes"

Singleton {
    id: root

    property int hyprGapsIn: 7
    property int hyprGapsOut: 20
    property int hyprBorder: 3
    property int hyprRounding: 11
    property bool hyprShadow: true
    property bool hyprBlur: true
    property int hyprBlurSize: 2
    property int hyprBlurPasses: 3
    property real hyprVibrancy: 3.0
    property real hyprVibrancyDarkness: 0.0
    property real hyprContrast: 1.0
    property real hyprBrightness: 1.0
    property real hyprNoise: 0.01
    property bool hyprIgnoreOpacity: true
    property bool hyprNewOpt: true
    property bool hyprSpecial: false
    property bool hyprPopups: false
    property string hyprLayout: "dwindle"
    property bool hyprTearing: false
    property bool animEnabled: true
    property real animSpeed: 1.0
    property string animBezier: "md3_standard"
    property string activeBorder: "#33ccff"
    property string inactiveBorder: "#595959"
    property int kittyPadding: 10
    property real kittyFontSize: 12.0
    property real kittyOpacity: 1.0
    property string fishPrompt: "minimal"
    property int brightness: 100
    property bool gamemode: false

    property bool _snapBlur: true
    property bool _snapShadow: true
    property bool _snapAnim: true

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/settings.json"
        watchChanges: true; blockLoading: true; printErrors: false
        onFileChanged: { reload(); syncFromFile() }
        adapter: JsonAdapter {
            property int gapsIn: 7
            property int gapsOut: 20
            property int border: 3
            property int rounding: 11
            property bool shadow: true
            property bool blur: true
            property int blurSize: 2
            property int blurPasses: 3
            property real vibrancy: 3.0
            property real vibrancyDarkness: 0.0
            property real blurContrast: 1.0
            property real blurBrightness: 1.0
            property real blurNoise: 0.01
            property bool ignoreOpacity: true
            property bool newOptimizations: true
            property bool blurSpecial: false
            property bool blurPopups: false
            property string layout: "dwindle"
            property bool tearing: false
            property bool animEnabled: true
            property real animSpeed: 1.0
            property string animBezier: "md3_standard"
            property string activeBorder: "#33ccff"
            property string inactiveBorder: "#595959"
            property int kittyPadding: 10
            property real kittyFontSize: 12.0
            property real kittyOpacity: 1.0
            property string fishPrompt: "minimal"
            property int brightness: 100
            property bool gamemode: false
        }
    }

    function syncFromFile(): void {
        hyprGapsIn = clampInt(settingsFile.adapter.gapsIn, 0, 40, 7)
        hyprGapsOut = clampInt(settingsFile.adapter.gapsOut, 0, 60, 20)
        hyprBorder = clampInt(settingsFile.adapter.border, 0, 12, 3)
        hyprRounding = clampInt(settingsFile.adapter.rounding, 0, 30, 11)
        hyprShadow = !!settingsFile.adapter.shadow
        hyprBlur = !!settingsFile.adapter.blur
        hyprBlurSize = clampInt(settingsFile.adapter.blurSize, 0, 30, 2)
        hyprBlurPasses = clampInt(settingsFile.adapter.blurPasses, 1, 6, 3)
        hyprVibrancy = clampReal(settingsFile.adapter.vibrancy, 0, 3, 3.0)
        hyprVibrancyDarkness = clampReal(settingsFile.adapter.vibrancyDarkness, 0, 1, 0.0)
        hyprContrast = clampReal(settingsFile.adapter.blurContrast, 0, 2, 1.0)
        hyprBrightness = clampReal(settingsFile.adapter.blurBrightness, 0, 2, 1.0)
        hyprNoise = clampReal(settingsFile.adapter.blurNoise, 0, 1, 0.01)
        hyprIgnoreOpacity = !!settingsFile.adapter.ignoreOpacity
        hyprNewOpt = settingsFile.adapter.newOptimizations !== false
        hyprSpecial = !!settingsFile.adapter.blurSpecial
        hyprPopups = !!settingsFile.adapter.blurPopups
        let lay = (settingsFile.adapter.layout || "dwindle") + ""
        hyprLayout = (lay === "scrolling") ? "scrolling" : "dwindle"
        hyprTearing = !!settingsFile.adapter.tearing
        animEnabled = settingsFile.adapter.animEnabled !== false
        animSpeed = clampReal(settingsFile.adapter.animSpeed, 0.2, 3.0, 1.0)
        animBezier = (settingsFile.adapter.animBezier || "md3_standard") + ""
        activeBorder = (settingsFile.adapter.activeBorder || "#33ccff") + ""
        inactiveBorder = (settingsFile.adapter.inactiveBorder || "#595959") + ""
        kittyPadding = clampInt(settingsFile.adapter.kittyPadding, 0, 40, 10)
        kittyFontSize = clampReal(settingsFile.adapter.kittyFontSize, 6, 32, 12)
        kittyOpacity = clampReal(settingsFile.adapter.kittyOpacity, 0.3, 1.0, 1.0)
        fishPrompt = (settingsFile.adapter.fishPrompt || "minimal") + ""
        brightness = clampInt(settingsFile.adapter.brightness, 5, 100, 100)
        gamemode = !!settingsFile.adapter.gamemode
    }

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
    function persist(): void { settingsFile.writeAdapter() }

    Process { id: hyprProc; command: ["bash", "-c", "echo"]; stdout: StdioCollector {} }
    Process { id: backendProc; command: ["bash", "-c", "echo"]; stdout: StdioCollector {} }
    function runHypr(cmd: string): void {
        hyprProc.command = ["bash", "-c", cmd]
        if (!hyprProc.running) hyprProc.running = true
    }
    function cfg(tables: string): string {
        return "hyprctl eval 'hl.config({" + tables + "})' >/dev/null 2>&1"
    }
    function runBackend(args: var): void {
        let script = Quickshell.env("HOME") + "/.config/quickshell/jhqs/scripts/settings-apply.py"
        backendProc.command = ["python3", script].concat(args)
        if (!backendProc.running) backendProc.running = true
    }

    Process {
        id: seedProc
        command: ["bash", "-c", "gIn=$(hyprctl getoption general:gaps_in 2>/dev/null | grep -oP 'int:\\s*\\K\\d+' | head -1); gOut=$(hyprctl getoption general:gaps_out 2>/dev/null | grep -oP 'int:\\s*\\K\\d+' | head -1); bSz=$(hyprctl getoption general:border_size 2>/dev/null | grep -oP 'int:\\s*\\K\\d+' | head -1); rnd=$(hyprctl getoption decoration:rounding 2>/dev/null | grep -oP 'int:\\s*\\K\\d+' | head -1); sh=$(hyprctl getoption decoration:shadow:enabled 2>/dev/null | grep -q 'bool: true' && echo 1 || echo 0); bl=$(hyprctl getoption decoration:blur:enabled 2>/dev/null | grep -q 'bool: true' && echo 1 || echo 0); lay=$(hyprctl getoption general:layout 2>/dev/null | grep -oP 'str:\\s*\\K\\w+' | head -1); bS=$(hyprctl getoption decoration:blur:size 2>/dev/null | grep -oP 'int:\\s*\\K\\d+' | head -1); bP=$(hyprctl getoption decoration:blur:passes 2>/dev/null | grep -oP 'int:\\s*\\K\\d+' | head -1); tr=$(hyprctl getoption general:allow_tearing 2>/dev/null | grep -q 'bool: true' && echo 1 || echo 0); an=$(hyprctl getoption animations:enabled 2>/dev/null | grep -q 'bool: false' && echo 0 || echo 1); vib=$(hyprctl getoption decoration:blur:vibrancy 2>/dev/null | grep -oP 'float:\\s*\\K[\\d.]+' | head -1); vd=$(hyprctl getoption decoration:blur:vibrancy_darkness 2>/dev/null | grep -oP 'float:\\s*\\K[\\d.]+' | head -1); ct=$(hyprctl getoption decoration:blur:contrast 2>/dev/null | grep -oP 'float:\\s*\\K[\\d.]+' | head -1); br=$(hyprctl getoption decoration:blur:brightness 2>/dev/null | grep -oP 'float:\\s*\\K[\\d.]+' | head -1); ns=$(hyprctl getoption decoration:blur:noise 2>/dev/null | grep -oP 'float:\\s*\\K[\\d.]+' | head -1); io=$(hyprctl getoption decoration:blur:ignore_opacity 2>/dev/null | grep -q 'bool: true' && echo 1 || echo 0); no=$(hyprctl getoption decoration:blur:new_optimizations 2>/dev/null | grep -q 'bool: true' && echo 1 || echo 0); sp=$(hyprctl getoption decoration:blur:special 2>/dev/null | grep -q 'bool: true' && echo 1 || echo 0); pp=$(hyprctl getoption decoration:blur:popups 2>/dev/null | grep -q 'bool: true' && echo 1 || echo 0); echo \"$gIn|$gOut|$bSz|$rnd|$sh|$bl|$lay|$bS|$bP|$tr|$an|$vib|$vd|$ct|$br|$ns|$io|$no|$sp|$pp\" | tr -d '\\n'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                if (out.length === 0) return
                let p = out.split("|")
                let gi = parseInt(p[0]); if (!isNaN(gi)) { root.hyprGapsIn = Math.max(0, Math.min(40, gi)); settingsFile.adapter.gapsIn = root.hyprGapsIn }
                let go = parseInt(p[1]); if (!isNaN(go)) { root.hyprGapsOut = Math.max(0, Math.min(60, go)); settingsFile.adapter.gapsOut = root.hyprGapsOut }
                let bs = parseInt(p[2]); if (!isNaN(bs)) { root.hyprBorder = Math.max(0, Math.min(12, bs)); settingsFile.adapter.border = root.hyprBorder }
                if (!Theme.minimalTheme) { let rd = parseInt(p[3]); if (!isNaN(rd)) { root.hyprRounding = Math.max(0, Math.min(30, rd)); settingsFile.adapter.rounding = root.hyprRounding } }
                if (p[4] === "1") { root.hyprShadow = true; settingsFile.adapter.shadow = true } else if (p[4] === "0") { root.hyprShadow = false; settingsFile.adapter.shadow = false }
                if (!Theme.minimalTheme) { if (p[5] === "1") { root.hyprBlur = true; settingsFile.adapter.blur = true } else if (p[5] === "0") { root.hyprBlur = false; settingsFile.adapter.blur = false } }
                let lay = (p[6] || "").trim().toLowerCase()
                if (lay === "dwindle" || lay === "scrolling") { root.hyprLayout = lay; settingsFile.adapter.layout = lay }
                let bS = parseInt(p[7]); if (!isNaN(bS)) { root.hyprBlurSize = Math.max(0, Math.min(30, bS)); settingsFile.adapter.blurSize = root.hyprBlurSize }
                let bP = parseInt(p[8]); if (!isNaN(bP)) { root.hyprBlurPasses = Math.max(1, Math.min(6, bP)); settingsFile.adapter.blurPasses = root.hyprBlurPasses }
                if (p[9] === "1") { root.hyprTearing = true; settingsFile.adapter.tearing = true } else if (p[9] === "0") { root.hyprTearing = false; settingsFile.adapter.tearing = false }
                if (p[10] === "1") { root.animEnabled = true; settingsFile.adapter.animEnabled = true } else if (p[10] === "0") { root.animEnabled = false; settingsFile.adapter.animEnabled = false }
                let vib = parseFloat(p[11]); if (!isNaN(vib)) { root.hyprVibrancy = Math.max(0, Math.min(3, vib)); settingsFile.adapter.vibrancy = root.hyprVibrancy }
                let vd = parseFloat(p[12]); if (!isNaN(vd)) { root.hyprVibrancyDarkness = Math.max(0, Math.min(1, vd)); settingsFile.adapter.vibrancyDarkness = root.hyprVibrancyDarkness }
                let ct = parseFloat(p[13]); if (!isNaN(ct)) { root.hyprContrast = Math.max(0, Math.min(2, ct)); settingsFile.adapter.blurContrast = root.hyprContrast }
                let br = parseFloat(p[14]); if (!isNaN(br)) { root.hyprBrightness = Math.max(0, Math.min(2, br)); settingsFile.adapter.blurBrightness = root.hyprBrightness }
                let ns = parseFloat(p[15]); if (!isNaN(ns)) { root.hyprNoise = Math.max(0, Math.min(1, ns)); settingsFile.adapter.blurNoise = root.hyprNoise }
                if (p[16] === "1") { root.hyprIgnoreOpacity = true; settingsFile.adapter.ignoreOpacity = true } else if (p[16] === "0") { root.hyprIgnoreOpacity = false; settingsFile.adapter.ignoreOpacity = false }
                if (p[17] === "1") { root.hyprNewOpt = true; settingsFile.adapter.newOptimizations = true } else if (p[17] === "0") { root.hyprNewOpt = false; settingsFile.adapter.newOptimizations = false }
                if (p[18] === "1") { root.hyprSpecial = true; settingsFile.adapter.blurSpecial = true } else if (p[18] === "0") { root.hyprSpecial = false; settingsFile.adapter.blurSpecial = false }
                if (p[19] === "1") { root.hyprPopups = true; settingsFile.adapter.blurPopups = true } else if (p[19] === "0") { root.hyprPopups = false; settingsFile.adapter.blurPopups = false }
                settingsFile.writeAdapter()
                if (Theme.minimalTheme) root.enforceMinimalHypr()
            }
        }
    }
    Component.onCompleted: Qt.callLater(() => { syncFromFile(); if (!seedProc.running) seedProc.running = true; if (Theme.minimalTheme) { root.enforceMinimalHypr(); minimalBootTimer.restart() } })
    function refresh(): void { if (!seedProc.running) seedProc.running = true }

    Process { id: minimalHyprProc; command: ["bash", "-c", "echo"] }
    property int _minimalRetries: 0
    Timer {
        id: minimalHyprTimer
        interval: 1200; repeat: false
        onTriggered: {
            if (minimalHyprProc.running) {
                if (root._minimalRetries < 10) { root._minimalRetries++; minimalHyprTimer.restart() }
                return
            }
            root._minimalRetries = 0
            minimalHyprProc.command = ["bash", "-c", cfg("decoration={blur={enabled=false}}") + "; " + cfg("decoration={rounding=0}")]
            minimalHyprProc.running = true
        }
    }
    Timer {
        id: minimalBootTimer
        interval: 25000; repeat: false
        onTriggered: { if (Theme.minimalTheme) root.enforceMinimalHypr() }
    }
    function enforceMinimalHypr(): void {
        if (!Theme.minimalTheme) return
        minimalHyprTimer.restart()
    }
    function restoreMinimalHypr(): void {
        runHypr(cfg("decoration={blur={enabled=" + (hyprBlur ? "true" : "false") + "}}") + "; " + cfg("decoration={rounding=" + hyprRounding + "}"))
    }
    Connections {
        target: Theme
        function onMinimalThemeChanged() {
            if (Theme.minimalTheme) root.enforceMinimalHypr()
            else root.restoreMinimalHypr()
        }
    }

    function previewGapsIn(v): void { let c = clampInt(v, 0, 40, hyprGapsIn); hyprGapsIn = c; runHypr(cfg("general={gaps_in=" + c + "}")) }
    function applyGapsIn(v): void { let c = clampInt(v, 0, 40, hyprGapsIn); previewGapsIn(c); settingsFile.adapter.gapsIn = c; persist(); runHypr("sed -i -E 's/(gaps_in\\s*=\\s*)[0-9]+/\\1" + c + "/' ~/.config/hypr/configs/looknfeel.lua") }
    function previewGapsOut(v): void { let c = clampInt(v, 0, 60, hyprGapsOut); hyprGapsOut = c; runHypr(cfg("general={gaps_out=" + c + "}")) }
    function applyGapsOut(v): void { let c = clampInt(v, 0, 60, hyprGapsOut); previewGapsOut(c); settingsFile.adapter.gapsOut = c; persist(); runHypr("sed -i -E 's/(gaps_out\\s*=\\s*)[0-9]+/\\1" + c + "/' ~/.config/hypr/configs/looknfeel.lua") }
    function previewBorder(v): void { let c = clampInt(v, 0, 12, hyprBorder); hyprBorder = c; runHypr(cfg("general={border_size=" + c + "}")) }
    function applyBorder(v): void { let c = clampInt(v, 0, 12, hyprBorder); previewBorder(c); settingsFile.adapter.border = c; persist(); runHypr("sed -i -E 's/(border_size\\s*=\\s*)[0-9]+/\\1" + c + "/' ~/.config/hypr/configs/looknfeel.lua") }
    function previewRounding(v): void { let c = clampInt(v, 0, 30, hyprRounding); hyprRounding = c; runHypr(cfg("decoration={rounding=" + c + "}")) }
    function applyRounding(v): void { let c = clampInt(v, 0, 30, hyprRounding); previewRounding(c); settingsFile.adapter.rounding = c; persist(); runHypr("sed -i -E 's/(rounding\\s*=\\s*)[0-9]+/\\1" + c + "/' ~/.config/hypr/configs/looknfeel.lua 2>/dev/null") }
    function applyShadow(n): void {
        hyprShadow = !!n; settingsFile.adapter.shadow = hyprShadow; persist()
        runHypr(cfg("decoration={shadow={enabled=" + (hyprShadow ? "true" : "false") + "}}") + "; sed -i -E '/shadow\\s*=\\s*\\{/,/\\}/ s/enabled\\s*=\\s*(true|false)/enabled = " + (hyprShadow ? "true" : "false") + "/' ~/.config/hypr/configs/looknfeel.lua 2>/dev/null")
    }
    function applyBlur(n): void {
        hyprBlur = !!n; settingsFile.adapter.blur = hyprBlur; persist()
        runHypr(cfg("decoration={blur={enabled=" + (hyprBlur ? "true" : "false") + "}}") + "; sed -i -E '/blur\\s*=\\s*\\{/,/\\}/ s/enabled\\s*=\\s*(true|false)/enabled = " + (hyprBlur ? "true" : "false") + "/' ~/.config/hypr/configs/looknfeel.lua 2>/dev/null")
    }
    function previewBlurSize(v): void { let c = clampInt(v, 0, 30, hyprBlurSize); hyprBlurSize = c; runHypr(cfg("decoration={blur={size=" + c + "}}")) }
    function applyBlurSize(v): void { let c = clampInt(v, 0, 30, hyprBlurSize); previewBlurSize(c); settingsFile.adapter.blurSize = c; persist(); runHypr("sed -i -E '/blur\\s*=\\s*\\{/,/\\}/ s/(size\\s*=\\s*)[0-9]+/\\1" + c + "/' ~/.config/hypr/configs/looknfeel.lua 2>/dev/null") }
    function previewBlurPasses(v): void { let c = clampInt(v, 1, 6, hyprBlurPasses); hyprBlurPasses = c; runHypr(cfg("decoration={blur={passes=" + c + "}}")) }
    function applyBlurPasses(v): void { let c = clampInt(v, 1, 6, hyprBlurPasses); previewBlurPasses(c); settingsFile.adapter.blurPasses = c; persist(); runHypr("sed -i -E '/blur\\s*=\\s*\\{/,/\\}/ s/(passes\\s*=\\s*)[0-9]+/\\1" + c + "/' ~/.config/hypr/configs/looknfeel.lua 2>/dev/null") }
    function previewVibrancy(v): void { let c = clampReal(v, 0, 3, hyprVibrancy); hyprVibrancy = Math.round(c * 100) / 100; runHypr(cfg("decoration={blur={vibrancy=" + hyprVibrancy + "}}")) }
    function applyVibrancy(v): void { previewVibrancy(v); settingsFile.adapter.vibrancy = hyprVibrancy; persist(); runBackend(["hypr-blur", "vibrancy=" + hyprVibrancy]) }
    function previewVibrancyDarkness(v): void { let c = clampReal(v, 0, 1, hyprVibrancyDarkness); hyprVibrancyDarkness = Math.round(c * 100) / 100; runHypr(cfg("decoration={blur={vibrancy_darkness=" + hyprVibrancyDarkness + "}}")) }
    function applyVibrancyDarkness(v): void { previewVibrancyDarkness(v); settingsFile.adapter.vibrancyDarkness = hyprVibrancyDarkness; persist(); runBackend(["hypr-blur", "vibrancy_darkness=" + hyprVibrancyDarkness]) }
    function previewContrast(v): void { let c = clampReal(v, 0, 2, hyprContrast); hyprContrast = Math.round(c * 100) / 100; runHypr(cfg("decoration={blur={contrast=" + hyprContrast + "}}")) }
    function applyContrast(v): void { previewContrast(v); settingsFile.adapter.blurContrast = hyprContrast; persist(); runBackend(["hypr-blur", "contrast=" + hyprContrast]) }
    function previewBlurBrightness(v): void { let c = clampReal(v, 0, 2, hyprBrightness); hyprBrightness = Math.round(c * 100) / 100; runHypr(cfg("decoration={blur={brightness=" + hyprBrightness + "}}")) }
    function applyBlurBrightness(v): void { previewBlurBrightness(v); settingsFile.adapter.blurBrightness = hyprBrightness; persist(); runBackend(["hypr-blur", "brightness=" + hyprBrightness]) }
    function previewNoise(v): void { let c = clampReal(v, 0, 1, hyprNoise); hyprNoise = Math.round(c * 1000) / 1000; runHypr(cfg("decoration={blur={noise=" + hyprNoise + "}}")) }
    function applyNoise(v): void { previewNoise(v); settingsFile.adapter.blurNoise = hyprNoise; persist(); runBackend(["hypr-blur", "noise=" + hyprNoise]) }
    function applyIgnoreOpacity(n): void { hyprIgnoreOpacity = !!n; settingsFile.adapter.ignoreOpacity = hyprIgnoreOpacity; persist(); runHypr(cfg("decoration={blur={ignore_opacity=" + (hyprIgnoreOpacity ? "true" : "false") + "}}")); runBackend(["hypr-blur", "ignore_opacity=" + (hyprIgnoreOpacity ? "true" : "false")]) }
    function applyNewOpt(n): void { hyprNewOpt = !!n; settingsFile.adapter.newOptimizations = hyprNewOpt; persist(); runHypr(cfg("decoration={blur={new_optimizations=" + (hyprNewOpt ? "true" : "false") + "}}")); runBackend(["hypr-blur", "new_optimizations=" + (hyprNewOpt ? "true" : "false")]) }
    function applyBlurSpecial(n): void { hyprSpecial = !!n; settingsFile.adapter.blurSpecial = hyprSpecial; persist(); runHypr(cfg("decoration={blur={special=" + (hyprSpecial ? "true" : "false") + "}}")); runBackend(["hypr-blur", "special=" + (hyprSpecial ? "true" : "false")]) }
    function applyBlurPopups(n): void { hyprPopups = !!n; settingsFile.adapter.blurPopups = hyprPopups; persist(); runHypr(cfg("decoration={blur={popups=" + (hyprPopups ? "true" : "false") + "}}")); runBackend(["hypr-blur", "popups=" + (hyprPopups ? "true" : "false")]) }
    function applyLayout(lay): void {
        if (lay !== "dwindle" && lay !== "scrolling") return
        hyprLayout = lay; settingsFile.adapter.layout = lay; persist()
        runHypr(cfg("general={layout=\"" + lay + "\"}") + "; sed -i -E 's/(layout\\s*=\\s*\")[^\"]+\"/\\1" + lay + "\"/' ~/.config/hypr/configs/looknfeel.lua 2>/dev/null")
    }
    function applyTearing(n): void {
        hyprTearing = !!n; settingsFile.adapter.tearing = hyprTearing; persist()
        runHypr(cfg("general={allow_tearing=" + (hyprTearing ? "true" : "false") + "}"))
    }
    function applyAnimEnabled(n): void {
        animEnabled = !!n; settingsFile.adapter.animEnabled = animEnabled; persist()
        runHypr(cfg("animations={enabled=" + (animEnabled ? "true" : "false") + "}") + "; sed -i -E 's/^animations\\s*=\\s*\\{[^}]*\\}/animations = {enabled = " + (animEnabled ? "true" : "false") + ",}/' ~/.config/hypr/configs/animations.lua 2>/dev/null")
    }
    function applyAnimBezier(b): void {
        animBezier = b; settingsFile.adapter.animBezier = b; persist()
        let safe = (b + "").replace(/[^a-zA-Z0-9_]/g, "")
        runHypr("sed -i -E 's/(hl\\.animation\\(\\{[^}]*bezier = \")[^\"]+\"/\\1" + safe + "\"/' ~/.config/hypr/configs/animations.lua 2>/dev/null; echo done")
    }
    function previewAnimSpeed(s): void { animSpeed = clampReal(s, 0.2, 3.0, 1.0) }
    function applyAnimSpeed(s): void {
        let sc = clampReal(s, 0.2, 3.0, 1.0); animSpeed = sc
        settingsFile.adapter.animSpeed = Math.round(sc * 100) / 100; persist()
        runBackend(["anim-speed", "scale=" + sc])
    }

    function applyKittyPadding(v): void { let c = clampInt(v, 0, 40, kittyPadding); kittyPadding = c; settingsFile.adapter.kittyPadding = c; persist(); runBackend(["kitty", "padding=" + c]) }
    function applyKittyFont(v): void { let c = clampReal(v, 6, 32, kittyFontSize); c = Math.round(c * 2) / 2; kittyFontSize = c; settingsFile.adapter.kittyFontSize = c; persist(); runBackend(["kitty", "font_size=" + c]) }
    function applyKittyOpacity(v): void { let c = clampReal(v, 0.3, 1.0, kittyOpacity); c = Math.round(c * 100) / 100; kittyOpacity = c; settingsFile.adapter.kittyOpacity = c; persist(); runBackend(["kitty", "opacity=" + c]) }
    function applyFishPrompt(s): void { fishPrompt = s; settingsFile.adapter.fishPrompt = s; persist(); runBackend(["fish", "prompt=" + s]) }
    function applyBrightness(v): void { let c = clampInt(v, 5, 100, brightness); brightness = c; settingsFile.adapter.brightness = c; persist(); runBackend(["brightness", "level=" + c]) }
    function applyPreset(name): void { runBackend(["preset", "name=" + name]) }

    function applyGamemode(n): void {
        let on = !!n
        if (on === gamemode) return
        if (on) { _snapBlur = hyprBlur; _snapShadow = hyprShadow; _snapAnim = animEnabled }
        gamemode = on; settingsFile.adapter.gamemode = on; persist()
        if (on) {
            runHypr(cfg("decoration={blur={enabled=false}}") + "; " + cfg("decoration={shadow={enabled=false}}") + "; " + cfg("animations={enabled=false}"))
            hyprBlur = false; hyprShadow = false; animEnabled = false
        } else {
            runHypr(cfg("decoration={blur={enabled=" + (_snapBlur ? "true" : "false") + "}}") + "; " + cfg("decoration={shadow={enabled=" + (_snapShadow ? "true" : "false") + "}}") + "; " + cfg("animations={enabled=" + (_snapAnim ? "true" : "false") + "}}"))
            hyprBlur = _snapBlur; hyprShadow = _snapShadow; animEnabled = _snapAnim
            if (Theme.minimalTheme) enforceMinimalHypr()
        }
    }
}
