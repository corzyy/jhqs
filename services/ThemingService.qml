pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ThemingService — Application theming settings backend.
// Ported from DankMaterialShell's Theme & Colors → Applications / Cursor /
// Icon / Matugen Templates / System App Theming, adapted to jhqs:
//   - matugen runs directly (no dms Go binary)
//   - Hyprland-only (env.lua + autostart.lua for cursor, gsettings + gtk.ini)
//   - qt theming via qt5ct/qt6ct matugen.conf (QT_QPA_PLATFORMTHEME=qt6ct)
Singleton {
    id: root

    property bool syncModeWithPortal: true
    property bool terminalsAlwaysDark: false
    property string iconTheme: "System Default"
    property string iconThemeLight: "System Default"
    property bool iconThemePerMode: false
    property string cursorTheme: "System Default"
    property int cursorSize: 24
    property bool runUserTemplates: true

    property bool templateGtk3: true
    property bool templateGtk4: true
    property bool templateQt5ct: true
    property bool templateQt6ct: true
    property bool templateQtColorscheme: true
    property bool templateKitty: true
    property bool templateGhostty: false
    property bool templateFcitx5: false
    property bool templateFirefox: false
    property bool templateVscode: true
    property bool templateNeovim: false
    property bool templateBtop: true
    property bool templateVesktop: true
    property bool templateObs: true
    property bool templateOpencode: true
    property bool templatePapirus: true
    property bool templatePrismlauncher: true

    property var availableIconThemes: ["System Default"]
    // NOTE: systemDefaultIconTheme/CursorTheme removed — write-only, never read.
    property var availableCursorThemes: ["System Default"]
    property bool matugenAvailable: false
    property string lastApplyMessage: ""
    property bool lastApplyOk: true
    // "app-id" -> true when the target app binary was found on PATH.
    // Used to render "· Not detected" like DMS does.
    property var appPresence: ({})

    FileView {
        id: themingFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/theming_settings.json"
        watchChanges: true; blockLoading: true; printErrors: false
        onFileChanged: { reload(); syncFromFile() }
        adapter: JsonAdapter {
            property bool syncModeWithPortal: true
            property bool terminalsAlwaysDark: false
            property string iconTheme: "System Default"
            property string iconThemeLight: "System Default"
            property bool iconThemePerMode: false
            property string cursorTheme: "System Default"
            property int cursorSize: 24
            property bool runUserTemplates: true
            property bool templateGtk3: true
            property bool templateGtk4: true
            property bool templateQt5ct: true
            property bool templateQt6ct: true
            property bool templateQtColorscheme: true
            property bool templateKitty: true
            property bool templateGhostty: false
            property bool templateFcitx5: false
            property bool templateFirefox: false
            property bool templateVscode: true
            property bool templateNeovim: false
            property bool templateBtop: true
            property bool templateVesktop: true
            property bool templateObs: true
            property bool templateOpencode: true
            property bool templatePapirus: true
            property bool templatePrismlauncher: true
        }
    }

    function syncFromFile(): void {
        syncModeWithPortal = !!themingFile.adapter.syncModeWithPortal
        terminalsAlwaysDark = !!themingFile.adapter.terminalsAlwaysDark
        iconTheme = (themingFile.adapter.iconTheme || "System Default") + ""
        iconThemeLight = (themingFile.adapter.iconThemeLight || "System Default") + ""
        iconThemePerMode = !!themingFile.adapter.iconThemePerMode
        cursorTheme = (themingFile.adapter.cursorTheme || "System Default") + ""
        cursorSize = clampInt(themingFile.adapter.cursorSize, 12, 128, 24)
        runUserTemplates = themingFile.adapter.runUserTemplates !== false
        templateGtk3 = themingFile.adapter.templateGtk3 !== false
        templateGtk4 = themingFile.adapter.templateGtk4 !== false
        templateQt5ct = themingFile.adapter.templateQt5ct !== false
        templateQt6ct = themingFile.adapter.templateQt6ct !== false
        templateQtColorscheme = themingFile.adapter.templateQtColorscheme !== false
        templateKitty = themingFile.adapter.templateKitty !== false
        templateGhostty = !!themingFile.adapter.templateGhostty
        templateFcitx5 = !!themingFile.adapter.templateFcitx5
        templateFirefox = !!themingFile.adapter.templateFirefox
        templateVscode = themingFile.adapter.templateVscode !== false
        templateNeovim = !!themingFile.adapter.templateNeovim
        templateBtop = themingFile.adapter.templateBtop !== false
        templateVesktop = themingFile.adapter.templateVesktop !== false
        templateObs = themingFile.adapter.templateObs !== false
        templateOpencode = themingFile.adapter.templateOpencode !== false
        templatePapirus = themingFile.adapter.templatePapirus !== false
        templatePrismlauncher = themingFile.adapter.templatePrismlauncher !== false
    }

    function clampInt(v, lo, hi, fb): int {
        let n = parseInt(v)
        if (isNaN(n)) return fb
        return Math.max(lo, Math.min(hi, Math.round(n)))
    }
    function persist(): void { themingFile.writeAdapter() }

    // RAM: backendProc produces no consumed stdout — drop the collector so
    // output isn't buffered in memory per apply.
    Process { id: backendProc; command: ["bash", "-c", "echo"] }
    Process { id: detectProc; command: ["bash", "-c", "echo"]; stdout: StdioCollector {
        onStreamFinished: {
            let out = (text || "").trim()
            if (out.length === 0) return
            let lines = out.split("\n")
            let icons = ["System Default"]
            let cursors = ["System Default"]
            let mode = ""
            for (let i = 0; i < lines.length; i++) {
                let l = lines[i].trim()
                if (l === "@@ICONS@@") { mode = "icons"; continue }
                if (l === "@@CURSORS@@") { mode = "cursors"; continue }
                if (l === "@@APPS@@") { mode = "apps"; continue }
                // NOTE: SYSDEFAULT_* lines skipped — no consumer ever read them.
                if (l.indexOf("SYSDEFAULT_ICON:") === 0) continue
                if (l.indexOf("SYSDEFAULT_CURSOR:") === 0) continue
                if (mode === "icons") { if (l.length > 0) icons.push(l) }
                else if (mode === "cursors") { if (l.length > 0) cursors.push(l) }
                else if (mode === "apps") {
                    let p = l.split("=")
                    if (p.length === 2) {
                        // CPU: copy-on-write only when the value actually
                        // changes — the old mutate-then-reassign forced every
                        // isAppDetected dependent to re-evaluate per refresh.
                        let nv = (p[1] === "1")
                        if (root.appPresence[p[0]] !== nv) {
                            let m = Object.assign({}, root.appPresence)
                            m[p[0]] = nv
                            root.appPresence = m
                        }
                    }
                }
            }
            root.availableIconThemes = icons
            root.availableCursorThemes = cursors
        }
    } }
    Process { id: matugenCheckProc; command: ["bash", "-c", "command -v matugen >/dev/null 2>&1 && echo yes || echo no"]; stdout: StdioCollector {
        onStreamFinished: root.matugenAvailable = ((text || "").trim() === "yes")
    } }

    function runBackend(args: var): void {
        let script = Quickshell.env("HOME") + "/.config/quickshell/jhqs/scripts/theming-apply.py"
        backendProc.command = ["python3", script].concat(args)
        if (!backendProc.running) backendProc.running = true
    }

    function refresh(): void {
        syncFromFile()
        if (!matugenCheckProc.running) matugenCheckProc.running = true
        let script = "echo '@@ICONS@@';"
        script += " echo \"SYSDEFAULT_ICON:$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d \\\"'\\\")\";"
        script += " for d in /usr/share/icons /usr/local/share/icons \"$HOME/.local/share/icons\" \"$HOME/.icons\"; do [ -d \"$d\" ] || continue; for t in \"$d\"/*/; do [ -d \"$t\" ] || continue; basename \"$t\"; done; done | grep -v '^icons$' | grep -v '^default$' | grep -v '^hicolor$' | grep -v '^locolor$' | sort -u;"
        script += " echo '@@CURSORS@@';"
        script += " echo \"SYSDEFAULT_CURSOR:$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d \\\"'\\\")\";"
        script += " for d in /usr/share/icons /usr/local/share/icons \"$HOME/.local/share/icons\" \"$HOME/.icons\"; do [ -d \"$d\" ] || continue; for t in \"$d\"/*/; do [ -d \"$t\" ] || continue; [ -d \"$t/cursors\" ] || continue; basename \"$t\"; done; done | grep -v '^icons$' | grep -v '^default$' | sort -u;"
        script += " echo '@@APPS@@';"
        script += " for a in qt5ct qt6ct kitty ghostty foot alacritty wezterm fcitx5 firefox zen-browser code code-oss nvim vesktop btop obs prismlauncher papirus-folders gsettings hyprctl adw-gtk3; do"
        script += " n=$(echo \"$a\" | tr '-' '_');"
        script += " if [ \"$a\" = \"adw-gtk3\" ]; then [ -d /usr/share/themes/adw-gtk3 ] || [ -d \"$HOME/.local/share/themes/adw-gtk3\" ] && echo \"${n}=1\" || echo \"${n}=0\";"
        script += " else command -v \"$a\" >/dev/null 2>&1 && echo \"${n}=1\" || echo \"${n}=0\"; fi; done"
        detectProc.command = ["bash", "-c", script]
        if (!detectProc.running) detectProc.running = true
    }

    Component.onCompleted: Qt.callLater(() => { syncFromFile(); refresh() })

    // NOTE: effectiveIconTheme() removed — dead (callers read iconTheme /
    // iconThemeLight directly). Inlining avoids an extra binding hop.

    function setSyncMode(v: bool): void {
        syncModeWithPortal = !!v; themingFile.adapter.syncModeWithPortal = syncModeWithPortal; persist()
        runBackend(["portal", "enabled=" + (syncModeWithPortal ? "true" : "false")])
    }
    function setTerminalsAlwaysDark(v: bool): void {
        terminalsAlwaysDark = !!v; themingFile.adapter.terminalsAlwaysDark = terminalsAlwaysDark; persist()
        runBackend(["terminals", "always_dark=" + (terminalsAlwaysDark ? "true" : "false")])
    }
    function setRunUserTemplates(v: bool): void {
        runUserTemplates = !!v; themingFile.adapter.runUserTemplates = runUserTemplates; persist()
    }
    function setIconTheme(v: string): void {
        iconTheme = v; themingFile.adapter.iconTheme = v; persist()
        runBackend(["icon", "theme=" + v])
    }
    function setIconThemeLight(v: string): void {
        iconThemeLight = v; themingFile.adapter.iconThemeLight = v; persist()
        runBackend(["icon", "theme_light=" + v])
    }
    function setIconThemePerMode(v: bool): void {
        iconThemePerMode = !!v; themingFile.adapter.iconThemePerMode = iconThemePerMode; persist()
        runBackend(["icon", "per_mode=" + (iconThemePerMode ? "true" : "false")])
    }
    function setCursorTheme(v: string): void {
        cursorTheme = v; themingFile.adapter.cursorTheme = v; persist()
        runBackend(["cursor", "theme=" + v, "size=" + cursorSize])
    }
    function setCursorSize(v: int): void {
        let c = clampInt(v, 12, 128, 24)
        cursorSize = c; themingFile.adapter.cursorSize = c; persist()
        runBackend(["cursor", "theme=" + cursorTheme, "size=" + c])
    }
    function setTemplate(key: string, v: bool): void {
        let on = !!v
        if (key === "gtk3") { templateGtk3 = on; themingFile.adapter.templateGtk3 = on }
        else if (key === "gtk4") { templateGtk4 = on; themingFile.adapter.templateGtk4 = on }
        else if (key === "qt5ct") { templateQt5ct = on; themingFile.adapter.templateQt5ct = on }
        else if (key === "qt6ct") { templateQt6ct = on; themingFile.adapter.templateQt6ct = on }
        else if (key === "qt-colorscheme") { templateQtColorscheme = on; themingFile.adapter.templateQtColorscheme = on }
        else if (key === "kitty") { templateKitty = on; themingFile.adapter.templateKitty = on }
        else if (key === "ghostty") { templateGhostty = on; themingFile.adapter.templateGhostty = on }
        else if (key === "fcitx5") { templateFcitx5 = on; themingFile.adapter.templateFcitx5 = on }
        else if (key === "firefox") { templateFirefox = on; themingFile.adapter.templateFirefox = on }
        else if (key === "vscode") { templateVscode = on; themingFile.adapter.templateVscode = on }
        else if (key === "neovim") { templateNeovim = on; themingFile.adapter.templateNeovim = on }
        else if (key === "btop") { templateBtop = on; themingFile.adapter.templateBtop = on }
        else if (key === "vesktop") { templateVesktop = on; themingFile.adapter.templateVesktop = on }
        else if (key === "obs") { templateObs = on; themingFile.adapter.templateObs = on }
        else if (key === "opencode") { templateOpencode = on; themingFile.adapter.templateOpencode = on }
        else if (key === "papirus") { templatePapirus = on; themingFile.adapter.templatePapirus = on }
        else if (key === "prismlauncher") { templatePrismlauncher = on; themingFile.adapter.templatePrismlauncher = on }
        else return
        persist()
        runBackend(["template", "key=" + key, "enabled=" + (on ? "true" : "false")])
    }

    function applyGtkColors(): void {
        lastApplyMessage = "Applying GTK colors…"; lastApplyOk = true
        runBackend(["gtk", "action=apply"])
    }
    function applyQtColors(): void {
        if (Quickshell.env("QT_QPA_PLATFORMTHEME") !== "qt6ct" && Quickshell.env("QT_QPA_PLATFORMTHEME") !== "gtk3" && Quickshell.env("QT_QPA_PLATFORMTHEME_QT6") !== "qt6ct" && Quickshell.env("QT_QPA_PLATFORMTHEME") !== "qtengine" && Quickshell.env("QT_QPA_PLATFORMTHEME") !== "kde") {
            lastApplyMessage = "Set QT_QPA_PLATFORMTHEME=qt6ct (or gtk3) and relogin, then Apply Qt Colors."; lastApplyOk = false
            return
        }
        lastApplyMessage = "Applying Qt colors…"; lastApplyOk = true
        runBackend(["qt", "action=apply"])
    }

    function isAppDetected(appId: string): bool {
        if (appId === "gtk") return appPresence["adw_gtk3"] === true
        if (appPresence[appId] === undefined) return true
        return appPresence[appId] === true
    }
}
