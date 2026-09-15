pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import "../themes"
import "../services"
import "../Ui"
import "./jhqsmenu" as JHQ
import "./jhqsmenu/views" as Views

Scope {
    id: jhqsMenuScope
    property bool showMenu: false
    signal dismissed()
    signal openSettings(string section)
    property bool centered: false
    readonly property int screenGap: 6
    property int panelGap: screenGap - Theme.barThickness
    property bool _winVisible: showMenu
    Timer { id: menuHideTimer; interval: Theme.animSlow + 20; repeat: false; onTriggered: if (!jhqsMenuScope.showMenu) jhqsMenuScope._winVisible = false }
    onShowMenuChanged: {
        if (showMenu) { _winVisible = true; menuHideTimer.stop() } else menuHideTimer.restart()
    }

    // NOTE: session actions intentionally use Quickshell.execDetached in
    // doSessionAction() — never Process.running here. This Scope lives inside
    // a Loader that is destroyed on dismissed(), which would kill a freshly
    // started Process before it can exec. Same applies to Shell Update
    // (runShellUpdate()) for the identical reason.
    property bool showWebApp: false
    property string webAppMode: "install"
    property var webAppList: []
    property bool webAppLoading: false
    property bool webAppBusy: false
    property bool webAppSuccess: false
    property string webAppStatus: ""
    property string webAppLog: ""
    property string webAppLastName: ""
    Process {
        id: webAppListProc
        command: ["bash", "-c", "echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                jhqsMenuScope.webAppLoading = false
                let out = (text || "").trim()
                if (out.length === 0) { jhqsMenuScope.webAppList = []; return }
                let lines = out.split("\n")
                let arr = []
                for (let i = 0; i < lines.length; i++) {
                    let ln = lines[i]
                    if (ln.trim().length === 0) continue
                    let cols = ln.split("\t")
                    if (cols.length < 2) continue
                    let fname = (cols[0] || "").trim()
                    let file = (cols[1] || "").trim()
                    let dname = (cols[2] || "").trim()
                    let exec = (cols[3] || "").trim()
                    let icon = (cols[4] || "").trim()
                    if (fname.length === 0) continue
                    let url = ""
                    let m = exec.match(/launch-webapp\s+(\S+)/)
                    if (m) url = m[1]
                    else {
                        let q = exec.match(/webapp-launch\.sh"\s+"([^"]+)/)
                        if (q) url = q[1]
                        else {
                            let a = exec.match(/--app=("[^"]+"|\S+)/)
                            if (a) url = ("" + a[1]).replace(/^"|"$/g, "")
                            else {
                                let h = exec.match(/https?:\/\/[^\s"']+/)
                                if (h) url = h[0]
                            }
                        }
                    }
                    arr.push({ name: fname, displayName: dname !== "" ? dname : fname, file: file, exec: exec, icon: icon, url: url })
                }
                arr.sort((a, b) => ("" + a.name).toLowerCase() < ("" + b.name).toLowerCase() ? -1 : 1)
                jhqsMenuScope.webAppList = arr
            }
        }
        onExited: (code) => {
            if (code === 127 && !jhqsMenuScope.webAppListRetried) {
                jhqsMenuScope.webAppListRetried = true
                jhqsMenuScope.webAppLoading = true
                webAppListProc.command = ["bash", "-c", "DESKTOP_DIR=\"$HOME/.local/share/applications\"; find \"$DESKTOP_DIR\" -maxdepth 3 -name '*.desktop' -print0 2>/dev/null | while IFS= read -r -d '' f; do if grep -q -E '^Exec=.*(launch-webapp|webapp-handler|webapp-launch|jhqs-webapp|--app=)' \"$f\" 2>/dev/null; then base=$(basename \"$f\" .desktop); dname=$(grep -m1 '^Name=' \"$f\" 2>/dev/null | cut -d= -f2-); exec=$(grep -m1 '^Exec=' \"$f\" 2>/dev/null | cut -d= -f2-); icon=$(grep -m1 '^Icon=' \"$f\" 2>/dev/null | cut -d= -f2-); printf '%s\\t%s\\t%s\\t%s\\t%s\\n' \"$base\" \"$f\" \"$dname\" \"$exec\" \"$icon\"; fi; done"]
                if (!webAppListProc.running) webAppListProc.running = true
            } else {
                jhqsMenuScope.webAppListRetried = false
            }
        }
    }
    Process {
        id: webAppRepairProc
        command: ["bash", "-c", "echo"]
        onExited: () => jhqsMenuScope.refreshWebApps()
    }
    Process {
        id: webAppOpProc
        command: ["bash", "-c", "echo"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => jhqsMenuScope.webAppOpAppend(data)
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => jhqsMenuScope.webAppOpAppend(data)
        }
        onExited: (code) => jhqsMenuScope.finishWebAppOp(code)
    }
    // Setup targets open the matching mango config in the default editor
    // (VSCodium, with xdg-open/nvim fallbacks). Bindings point at the user
    // file; monitors at the active monitors.conf.
    Process { id: setupMonitorsProc; command: ["bash", "-c", "codium \"$HOME/.config/mango/configs/monitors.conf\" 2>/dev/null || xdg-open \"$HOME/.config/mango/configs/monitors.conf\" 2>/dev/null || kitty --class setup-monitors --title \"Monitors\" bash -c 'nvim \"$HOME/.config/mango/configs/monitors.conf\"; echo; echo \"--- Done ---\"; read -n1 -s' &"] }
    Process { id: setupBindsProc; command: ["bash", "-c", "codium \"$HOME/.config/mango/configs/binds-user.conf\" 2>/dev/null || xdg-open \"$HOME/.config/mango/configs/binds-user.conf\" 2>/dev/null || kitty --class setup-binds --title \"Keybindings\" bash -c 'nvim \"$HOME/.config/mango/configs/binds-user.conf\"; echo; echo \"--- Done ---\"; read -n1 -s' &"] }
    Process { id: setupAutostartProc; command: ["bash", "-c", "codium ~/.config/mango/configs/autostart.conf 2>/dev/null || kitty --class setup-autostart --title \"Autostart\" bash -c 'nvim ~/.config/mango/configs/autostart.conf; echo; echo \"--- Done ---\"; read -n1 -s' &"] }
    Process { id: setupKittyProc; command: ["bash", "-c", "codium ~/.config/kitty/kitty.conf 2>/dev/null || kitty --class setup-kitty --title \"Kitty Config\" bash -c 'nvim ~/.config/kitty/kitty.conf; echo; echo \"--- Done ---\"; read -n1 -s' &"] }
    Process { id: setupFishProc; command: ["bash", "-c", "kitty --class setup-fish --title \"Fish Config\" bash -c 'nvim ~/.config/fish/config.fish; echo; echo \"--- Done ---\"; read -n1 -s' &"] }
    Process { id: setupAppearanceProc; command: ["bash", "-c", "nwg-look 2>/dev/null || codium ~/.config/gtk-3.0/settings.ini 2>/dev/null || kitty --class setup-gtk --title \"GTK Appearance\" bash -c 'echo \"nwg-look not found\"; echo \"GTK Settings: ~/.config/gtk-3.0/settings.ini\"; cat ~/.config/gtk-3.0/settings.ini 2>/dev/null; read -n1 -s' &"] }
    Process { id: setupAudioProc; command: ["bash", "-c", "pavucontrol 2>/dev/null || kitty --class setup-audio --title Audio bash -c 'wpctl status 2>/dev/null || pactl info; read -n1 -s' &"] }
    // Runs the shell updater (git clone over the live install, keeping
    // config/) in a terminal so progress is visible; the script restarts the
    // shell itself on success. Must use execDetached (see NOTE above): the
    // menu Loader is destroyed on dismissed(), which would kill a Process
    // before kitty can spawn.
    function runShellUpdate() {
        Quickshell.execDetached(["bash", "-c", "kitty --class jhqs-shell-update --title \"Shell Update\" bash -lc 'bash \"$HOME/.config/quickshell/jhqs/scripts/update-shell.sh\"; echo; echo \"--- Done ---\"; read -n1 -s' &"])
    }
    // Live MangoWM keybinding menu (Learn > Keybindings/Apps/Windows/
    // Workspaces, rendered by Views.KeybindsView). Parsed from
    // scripts/mango-keybinds.sh TSV rows (kind \t combo \t action \t src).
    // The FileViews below re-run the parser whenever the mango configs
    // change, so the cheatsheet is always current while the menu is open;
    // the list is also (re)loaded on menu open and on entering the view.
    FileView { id: keybindUserFile; path: Quickshell.env("HOME") + "/.config/mango/configs/binds-user.conf"; watchChanges: true; blockLoading: true; printErrors: false; onFileChanged: keybindWatchDebounce.restart() }
    FileView { id: keybindSystemFile; path: Quickshell.env("HOME") + "/.config/mango/configs/binds-system.conf"; watchChanges: true; blockLoading: true; printErrors: false; onFileChanged: keybindWatchDebounce.restart() }
    FileView { id: keybindMainFile; path: Quickshell.env("HOME") + "/.config/mango/config.conf"; watchChanges: true; blockLoading: true; printErrors: false; onFileChanged: keybindWatchDebounce.restart() }
    Timer { id: keybindWatchDebounce; interval: 300; repeat: false; onTriggered: jhqsMenuScope.refreshKeybindsForce() }
    Process {
        id: keybindProc
        command: ["bash", "-c", "echo"]
        stdout: StdioCollector {
            onStreamFinished: jhqsMenuScope.finishKeybinds(text || "")
        }
    }
    property var keybindList: []
    property bool keybindLoading: false
    property string keybindUpdated: ""
    property string keybindTopic: "all"
    function refreshKeybinds() { if (keybindList.length === 0) refreshKeybindsForce() }
    function refreshKeybindsForce() {
        if (keybindProc.running) return
        keybindLoading = true
        keybindProc.command = ["bash", Quickshell.env("HOME") + "/.config/quickshell/jhqs/scripts/mango-keybinds.sh"]
        keybindProc.running = true
    }
    function finishKeybinds(out) {
        keybindLoading = false
        let arr = parseKeybindText(out || "")
        // A failed/empty run never wipes good data (same rule as the DNF cache).
        if (arr.length === 0 && keybindList.length > 0) return
        keybindList = arr
        if (arr.length > 0) {
            try {
                let d = new Date()
                let p = n => (n < 10 ? "0" + n : "" + n)
                keybindUpdated = p(d.getHours()) + ":" + p(d.getMinutes()) + ":" + p(d.getSeconds())
            } catch (e) { keybindUpdated = "" }
        }
        if (showKeybinds) {
            selectedIndex = 0
            try { if (bodyRootRef) bodyRootRef.selectedIndex = 0 } catch (e) { }
        }
    }
    function parseKeybindText(t: string): var {
        let out = []
        let lines = (t || "").split("\n")
        for (let i = 0; i < lines.length; i++) {
            let ln = lines[i].trim()
            if (ln.length === 0) continue
            let cols = ln.split("\t")
            if (cols.length < 3) continue
            let kind = (cols[0] || "key").trim()
            let combo = (cols[1] || "").trim()
            let action = (cols[2] || "").trim()
            let src = (cols[3] || "").trim()
            if (combo === "" || action === "") continue
            let parts = combo.split("+").map(s => s.trim()).filter(s => s.length > 0)
            if (parts.length === 0) continue
            let kindLabel = kind === "mouse" ? "Mouse" : kind === "scroll" ? "Scroll" : "Keyboard"
            let label = action.replace(/_/g, " ")
            // Humanize jhqs shortcuts: "spawn jhqs module launcher toggle"
            // reads poorly, so show "Open Menu" / "Open System" instead.
            let jm = label.match(/^spawn jhqs module (\S+) toggle$/i)
            if (jm) {
                let mod = (jm[1] || "").toLowerCase()
                if (mod === "launcher") mod = "menu"
                mod = mod.charAt(0).toUpperCase() + mod.slice(1)
                label = "open " + mod
            } else if (/^spawn jhqs lock$/i.test(label)) {
                label = "lock screen"
            } else if (/^spawn jhqs reload$/i.test(label)) {
                label = "reload shell"
            } else if (/grim|slurp/i.test(label)) {
                label = "take Screenshot"
            }
            label = label.replace(/^spawn\b/i, "open")
            label = label.charAt(0).toUpperCase() + label.slice(1)
            let hay = (combo + " " + action + " " + src + " " + kind + " " + label).toLowerCase()
            out.push({ kind: kind, kindLabel: kindLabel, combo: combo, parts: parts, action: action, label: label, src: src, hay: hay })
        }
        return out
    }
    function keybindTopicMatch(hayLower: string): bool {
        if (keybindTopic === "apps") return /spawn|launch|kitty|nautilus|helium|opencode|launcher|lock|reload|quit/.test(hayLower || "")
        if (keybindTopic === "windows") return /focus|move|exchange|float|fullscreen|maximize|kill|minimiz|scratchpad|gaps|resize|layout|proportion|scroller|dwindle|toggleglobal|togglejump/.test(hayLower || "")
        if (keybindTopic === "workspaces") return /view|tag|monitor|workspace|axisbind|scroll/.test(hayLower || "")
        return true
    }
    function openKeybinds(topic) {
        let t = ("" + (topic || "")).trim().toLowerCase()
        keybindTopic = (t === "apps" || t === "windows" || t === "workspaces") ? t : "all"
        showLearn = false
        showKeybinds = true
        clearSearch()
        refreshKeybindsForce()
    }
    property var filteredKeybinds: {
        if (!showKeybinds) return []
        let q = qLower()
        let words = q === "" ? [] : queryWordsFor(q)
        let out = []
        for (let i = 0; i < keybindList.length; i++) {
            let k = keybindList[i]
            if (!k || !k.hay) continue
            if (!keybindTopicMatch(k.hay)) continue
            if (words.length > 0 && !matchesAll(k.hay, words)) continue
            out.push(k)
        }
        return out
    }
    readonly property string shellPosition: Theme.barPosition
    FileView {
        id: wallpaperSettingsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/wallpaper_settings.json"
        watchChanges: true; onFileChanged: reload(); blockLoading: true; printErrors: false
        adapter: JsonAdapter {
            property string transitionType: "grow"
            property real transitionDuration: 1.5
            property int transitionFps: 60
            property string mode: "fill"
            property string directory: ""
        }
    }
    function expandWallpaperDir(p) {
        let s = ("" + (p || "")).trim()
        if (s === "~" || s.startsWith("~/")) {
            try { s = Quickshell.env("HOME") + s.slice(1) } catch (e) { }
        }
        return s
    }
    readonly property string wallpaperDirectoryConfigured: {
        try { return expandWallpaperDir(wallpaperSettingsFile.adapter.directory) } catch (e) { return "" }
    }
    property string wallpaperResolvedDir: ""
    readonly property string wallpaperDirDisplay: {
        let d = wallpaperResolvedDir !== "" ? wallpaperResolvedDir : wallpaperDirectoryConfigured
        if (d === "") d = "~/Bilder/wallpapers"
        try {
            let h = Quickshell.env("HOME")
            if (h && d.startsWith(h)) d = "~" + d.slice(h.length)
        } catch (e) { }
        return d
    }
    function setWallpaperDirectory(path) {
        let s = ("" + (path || "")).trim()
        if (s.includes("\n") || s.includes("\r")) return
        if (s !== "" && !(s.startsWith("/") || s.startsWith("~/") || s === "~")) return
        if (s.length > 1 && s.endsWith("/")) s = s.slice(0, -1)
        try {
            if ((wallpaperSettingsFile.adapter.directory || "") === s) return
            wallpaperSettingsFile.adapter.directory = s
            wallpaperSettingsFile.writeAdapter()
        } catch (e) { }
        refreshWallpapers()
    }
    readonly property var wallpaperModes: ["stretch", "fit", "fill", "center", "tile"]
    readonly property string wallpaperMode: {
        try { let v = wallpaperSettingsFile.adapter.mode; return wallpaperModes.indexOf(v) !== -1 ? v : "fill" } catch(e) { return "fill" }
    }
    function setWallpaperMode(m) { if (wallpaperModes.indexOf(m) === -1) return; wallpaperSettingsFile.adapter.mode = m; wallpaperSettingsFile.writeAdapter() }
    readonly property var wallpaperTransTypes: ["none", "simple", "fade", "left", "right", "top", "bottom", "wipe", "grow", "center", "outer", "wave", "random"]
    readonly property var wallpaperTransFpsOptions: [30, 48, 60, 72, 120]
    readonly property string wallpaperTransType: {
        try { let v = wallpaperSettingsFile.adapter.transitionType; return wallpaperTransTypes.indexOf(v) !== -1 ? v : "grow" } catch(e) { return "grow" }
    }
    readonly property real wallpaperTransDuration: {
        try { let v = wallpaperSettingsFile.adapter.transitionDuration; if (v === undefined || isNaN(v)) return 1.5; return Math.round(Math.max(0.2, Math.min(3.0, v)) * 10) / 10 } catch(e) { return 1.5 }
    }
    readonly property int wallpaperTransFps: {
        try { let v = wallpaperSettingsFile.adapter.transitionFps; return wallpaperTransFpsOptions.indexOf(v) !== -1 ? v : 60 } catch(e) { return 60 }
    }
    property bool showWallpaperSettings: false
    Process {
        id: wallpaperListProc
        command: ["bash", "-c", "D=\"\"; for c in \"$HOME/Bilder/wallpapers\" \"$HOME/Pictures/wallpapers\" \"$HOME/Wallpapers\" \"${XDG_PICTURES_DIR:-$HOME/Pictures}/wallpapers\" \"$HOME/wallpapers\"; do if [ -d \"$c\" ]; then D=\"$c\"; break; fi; done; echo \"#DIR=$D\"; if [ -n \"$D\" ] && [ -d \"$D\" ]; then find \"$D\" -mindepth 1 -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' -o -iname '*.tiff' \\) 2>/dev/null | sort | head -n 500; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                if (out.length === 0) { jhqsMenuScope.wallpaperFiles = []; jhqsMenuScope.wallpaperResolvedDir = ""; return }
                let lines = out.split("\n").map(s => s.trim()).filter(s => s.length > 0)
                if (lines.length > 0 && lines[0].startsWith("#DIR=")) {
                    jhqsMenuScope.wallpaperResolvedDir = lines[0].slice(5).trim()
                    lines = lines.slice(1)
                }
                jhqsMenuScope.wallpaperFiles = lines
                jhqsMenuScope.ensureThemeWallpapers()
            }
        }
    }
    property var fontFallbackFamilies: []
    property int fontRevision: 0
    property bool fontLoading: false
    property bool fontRescanning: false
    Process {
        id: fontListProc
        command: ["bash", "-c", "fc-list : family 2>/dev/null | tr ',' '\\n' | sed 's/^ *//;s/ *$//' | grep -v '^$' | grep -i -E 'JetBrains ?Mono|Geist ?Mono|Inter' | sort -u | head -n 800"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                if (out.length === 0) jhqsMenuScope.fontFallbackFamilies = []
                else jhqsMenuScope.fontFallbackFamilies = out.split("\n").map(s => s.trim()).filter(s => s.length > 0)
                jhqsMenuScope.fontLoading = fontRescanProc.running
                jhqsMenuScope.fontRevision++
            }
        }
        onExited: {
            // Ensure loading flag clears even if stdout was empty
            jhqsMenuScope.fontLoading = fontRescanProc.running
        }
    }
    Process {
        id: fontRescanProc
        command: ["bash", "-c", "fc-cache -f >/dev/null 2>&1; echo done"]
        stdout: StdioCollector {
            onStreamFinished: { }
        }
        onExited: {
            jhqsMenuScope.fontRescanning = false
            // Chain into a fresh fc-list query
            if (!fontListProc.running) {
                jhqsMenuScope.fontLoading = true
                fontListProc.running = true
            } else {
                jhqsMenuScope.fontLoading = true
            }
        }
    }
    property string fontExpanded: ""
    property var fontStylesCache: ({ })
    property string fontStylesLoading: ""
    Process {
        id: fontStyleProc
        command: ["bash", "-c", "echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                let fam = jhqsMenuScope.fontStylesLoading
                jhqsMenuScope.fontStylesLoading = ""
                let out = (text || "").trim()
                let styles = []
                if (out.length > 0) {
                    let seen = { }
                    let parts = out.split("\n")
                    for (let i = 0; i < parts.length; i++) {
                        let s = parts[i].trim()
                        if (s.length === 0 || seen[s]) continue
                        seen[s] = true
                        styles.push(s)
                    }
                    styles.sort()
                }
                if (fam !== "") {
                    let next = { }
                    for (let k in jhqsMenuScope.fontStylesCache) next[k] = jhqsMenuScope.fontStylesCache[k]
                    next[fam] = styles
                    let keys = Object.keys(next)
                    while (keys.length > 20) { delete next[keys.shift()]; keys = Object.keys(next) }
                    jhqsMenuScope.fontStylesCache = next
                }
            }
        }
    }
    function refreshFonts() {
        if (fontListProc.running || fontRescanProc.running) return
        fontLoading = true
        fontRevision++
        fontListProc.running = true
    }
    function rescanFonts() {
        if (fontListProc.running || fontRescanProc.running) return
        fontLoading = true
        fontRescanning = true
        fontRescanProc.running = true
    }
    function toggleFontExpanded(groupTitle) {
        if (fontExpanded === groupTitle) { fontExpanded = ""; return }
        fontExpanded = groupTitle
    }
    function setSystemFont(family) {
        if (!family || ("" + family).trim().length === 0) return
        try { Theme.setSystemFont(("" + family).trim()) } catch(e) { console.log("[JhqsMenu] setSystemFont err", e) }
    }
    // DNF/Fedora package backend (this system is Fedora; no Arch tooling).
    // - Install: `dnf list --available` catalog (~72k pkgs), parsed + compacted
    //   to name|version|repo in bash (awk/sort) so only ~3MB reaches QML
    //   (raw `dnf list` table is ~13MB of padded text and stalls the UI).
    //   NOTE: the flag form `--available` must be used, not the positional
    //   `dnf list available` (dnf5 returns an empty list for that form while
    //   repo metadata is degraded).
    //   A persistent cache (~/.cache/jhqs/dnf-available.cache) makes the menu
    //   instant: the menu Loader is destroyed on dismiss, so every open shows
    //   `cat` of the cache first, then refreshes via dnf in the background.
    // - Remove: local rpmdb via `rpm -qa` (fast, offline) for the full
    //   installed list, plus `dnf repoquery --userinstalled` (pacman -Qqe
    //   equivalent) to limit removal to explicitly installed packages.
    // Flags matter: -y answers the repo GPG-import prompt (broken Terra key
    // would otherwise block on stdin forever under the shell's Process),
    // < /dev/null guarantees EOF for any residual prompt, timeout bounds it.
    Process {
        id: installedListProc
        command: ["bash", "-c", "rpm -qa --queryformat '%{NAME}\\t%{VERSION}-%{RELEASE}\\t%{ARCH}\\n' 2>/dev/null | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                let arr = []
                if (out.length > 0) {
                    let lines = out.split("\n")
                    let seen = { }
                    for (let i = 0; i < lines.length; i++) {
                        let ln = lines[i].trim()
                        if (ln.length === 0) continue
                        let p = ln.split("\t")
                        if (p.length < 2) continue
                        let nm = (p[0] || "").trim()
                        if (!/^[A-Za-z0-9@._+\-]+$/.test(nm)) continue
                        if (seen[nm] !== undefined) continue
                        seen[nm] = true
                        arr.push({ repo: (p[2] || "").trim() || "rpm", name: nm, nl: nm.toLowerCase(), version: (p[1] || "").trim(), installed: true })
                    }
                }
                arr.sort((a, b) => a.name < b.name ? -1 : (a.name > b.name ? 1 : 0))
                jhqsMenuScope.installedList = arr
                jhqsMenuScope.restampAvailableInstalled()
            }
        }
    }
    property var installedList: []
    function refreshInstalled() { if (!installedListProc.running) installedListProc.running = true }
    // Re-stamp installed flags on the preloaded catalog when the rpmdb list
    // lands after it (both load in parallel on menu open). Object identity
    // is preserved for unchanged rows so dependent Repeaters don't rebuild.
    function restampAvailableInstalled() {
        if (!availableList || availableList.length === 0) return
        if (!installedList || installedList.length === 0) return
        let iset = { }
        try {
            for (let i = 0; i < installedList.length; i++) { let p = installedList[i]; if (p && p.name) iset[p.name] = true }
        } catch (e) { return }
        let next = []
        for (let i = 0; i < availableList.length; i++) {
            let e = availableList[i]
            if (!e || !e.name) continue
            let inst = !!iset[e.name]
            next.push(e.installed === inst ? e : { repo: e.repo, name: e.name, nl: e.nl || e.name.toLowerCase(), version: e.version, installed: inst })
        }
        availableList = next
    }
    property var explicitPackageSet: ({ })
    property bool explicitPackagesLoaded: false
    Process {
        id: explicitListProc
        command: ["bash", "-c", "timeout 60 dnf -y repoquery --cacheonly --userinstalled --queryformat '%{NAME}\\n' -q < /dev/null 2>/dev/null | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                let next = { }
                if (out.length > 0) {
                    let lines = out.split("\n")
                    for (let i = 0; i < lines.length; i++) {
                        let n = lines[i].trim().split(/\s+/)[0] || ""
                        if (n.length > 0) next[n] = true
                    }
                }
                jhqsMenuScope.explicitPackageSet = next
                jhqsMenuScope.explicitPackagesLoaded = true
            }
        }
    }
    function refreshExplicit() { if (!explicitListProc.running) explicitListProc.running = true }
    readonly property var protectedPackages: [
        "kernel", "kernel-core", "kernel-modules", "kernel-modules-core", "kernel-modules-extra",
        "kernel-headers", "linux-firmware",
        "grub2-common", "grub2-efi-x64", "grub2-pc", "grub2-tools", "shim-x64", "efibootmgr",
        "systemd", "systemd-libs", "systemd-udev", "systemd-boot-unsigned",
        "filesystem", "glibc", "bash", "dbus", "dbus-broker",
        "dnf", "dnf5", "libdnf5", "rpm", "rpm-libs", "sudo",
        "polkit",
        "mangowm", "quickshell", "sddm",
        "xdg-desktop-portal", "xdg-desktop-portal-gtk", "qt6-qtwayland", "qt5-qtwayland",
        "mesa-dri-drivers", "mesa-filesystem", "mesa-libGL", "mesa-libEGL", "mesa-vulkan-drivers",
        "NetworkManager",
        "pipewire", "pipewire-alsa", "pipewire-pulseaudio", "pipewire-jack-audio-connection-kit", "wireplumber", "pulseaudio-libs", "gst-plugin-pipewire"
    ]
    function isProtectedPackage(name) {
        if (!name) return false
        let n = ("" + name).toLowerCase()
        for (let i = 0; i < protectedPackages.length; i++) {
            if (protectedPackages[i] === n) return true
        }
        return false
    }
    function isRemovablePackage(name) {
        if (!name || isProtectedPackage(name)) return false
        if (!explicitPackagesLoaded) return true
        try { return !!explicitPackageSet["" + name] } catch (e) { return true }
    }
    // Preloaded DNF catalog for Install > Package (~72k rows).
    // Source is `dnf list --available` ("name.arch version repo" rows plus a
    // localized header). bash (awk) strips the .arch suffix, keeps
    // x86_64/noarch, strips epoch prefixes, validates names, and `sort -u`
    // dedupes — QML receives compact `name|version|repo` lines, already
    // sorted. QML dedupes by name (last wins). Filtering is
    // local + instant (debounced _q). Warmed on menu open; refreshed after
    // install/remove ops.
    // Speed design:
    // - File cache: a menu open `cat`s the cache (~20ms) and parses it in one
    //   synchronous pass (~150ms for 72k rows) instead of waiting ~1.5s for
    //   dnf. A background dnf run refreshes the cache only when it is older
    //   than 6h (__JHQS_CACHE_FRESH__ marker = no work). The cache is only
    //   replaced when the fresh output has >1000 lines, so a failed dnf run
    //   (lock/contention/empty) never wipes good data.
    // - The parse uses indexOf (no regex, no re-sort: the pipeline already
    //   sorted). split+regex+sort over 72k rows measured ~830ms.
    // - NOTE: an earlier revision pumped the parse through an `interval: 0`
    //   Timer. Timers with a zero interval do NOT repeat in Quickshell, so the
    //   catalog was never published and Install > Package stayed empty.
    // - --cacheonly first: never touches the network, immune to slow /
    //   broken-repo metadata refreshes which used to stall the menu for tens
    //   of seconds. Empty result (unusable cache) -> exactly one refresh run
    //   without --cacheonly, which repopulates the cache for a long time.
    property var availableList: []
    property bool availableLoading: false
    property double availableLoadStart: 0
    property bool availableRefreshTried: false
    // Marker printed by the refresh command when the on-disk cache is fresh
    // (<=6h): QML keeps showing the instantly-loaded cache, no re-parse.
    readonly property string availableFreshMarker: "__JHQS_CACHE_FRESH__"
    Process {
        id: availableListProc
        command: ["bash", "-c", "echo"]
        stdout: StdioCollector {
            onStreamFinished: jhqsMenuScope.finishAvailable(text || "")
        }
    }
    // Instant path: plain `cat` of the cache file (~20ms, no dnf startup).
    Process {
        id: availableCacheProc
        command: ["bash", "-c", "echo"]
        stdout: StdioCollector {
            onStreamFinished: jhqsMenuScope.finishAvailableCache(text || "")
        }
    }
    function availableCacheFile(): string {
        return "${XDG_CACHE_HOME:-$HOME/.cache}/jhqs/dnf-available.cache"
    }
    // Compact `dnf list` pipeline: arch-filter + epoch-strip + validate in
    // awk, dedupe via sort. Writes through a temp file so a failed/empty dnf
    // run never corrupts the cache; stdout is always the cache content.
    function availableDnfPipeline(cacheFlag: string): string {
        return "LC_ALL=C timeout 120 dnf -y list --available " + cacheFlag + "-q < /dev/null 2>/dev/null | awk 'NF<3{next} {na=$1; ver=$2; repo=$3; sub(/^[0-9]+:/,\"\",ver); dot=match(na,/\\.[^\\.]*$/); if(dot==0)next; nm=substr(na,1,dot-1); arch=substr(na,dot+1); if(arch!=\"x86_64\"&&arch!=\"noarch\")next; if(nm!~/^[A-Za-z0-9@._+\\-]+$/)next; print nm\"|\"ver\"|\"repo}' | sort -u > \"$TMP\"; if [ -s \"$TMP\" ] && [ \"$(wc -l < \"$TMP\")\" -gt 1000 ]; then mv -f \"$TMP\" \"$CACHE\"; else rm -f \"$TMP\"; fi; cat \"$CACHE\" 2>/dev/null || true"
    }
    function availableCommand(cached: bool): string {
        return "CACHE=\"" + availableCacheFile() + "\"; mkdir -p \"${XDG_CACHE_HOME:-$HOME/.cache}/jhqs\"; TMP=\"$CACHE.tmp\"; " + availableDnfPipeline(cached ? "--cacheonly " : "")
    }
    function availableCacheCommand(): string {
        return "cat \"" + availableCacheFile() + "\" 2>/dev/null || true"
    }
    // Background refresh: no-op marker when the cache is fresh (<=6h old and
    // >1000 lines), otherwise the same dnf pipeline (refreshes the cache).
    function availableRefreshCommand(): string {
        return "CACHE=\"" + availableCacheFile() + "\"; mkdir -p \"${XDG_CACHE_HOME:-$HOME/.cache}/jhqs\"; TMP=\"$CACHE.tmp\"; if [ -s \"$CACHE\" ] && [ \"$(wc -l < \"$CACHE\")\" -gt 1000 ] && [ -z \"$(find \"$CACHE\" -mmin +360 2>/dev/null)\" ]; then echo \"" + availableFreshMarker + "\"; else " + availableDnfPipeline("--cacheonly ") + "; fi"
    }
    function startAvailableBgRefresh() {
        if (availableListProc.running) return
        availableListProc.command = ["bash", "-c", availableRefreshCommand()]
        availableListProc.running = true
    }
    // One synchronous parse of compact `name|version|repo` rows. The pipeline
    // guarantees exactly 3 fields and a valid name, so no regex/validation is
    // needed here. Object insertion order preserves the pre-sorted order;
    // dedupe by name (last repo wins).
    function parseAvailableText(t: string): var {
        let lines = t.split("\n")
        let byName = { }
        let iset = { }
        try {
            for (let i = 0; i < installedList.length; i++) { let p = installedList[i]; if (p && p.name) iset[p.name] = true }
        } catch (e) { }
        for (let i = 0; i < lines.length; i++) {
            let ln = lines[i]
            if (ln.length === 0) continue
            let i1 = ln.indexOf("|")
            if (i1 < 0) continue
            let i2 = ln.indexOf("|", i1 + 1)
            if (i2 < 0) continue
            let nm = ln.slice(0, i1)
            byName[nm] = { repo: ln.slice(i2 + 1) || "dnf", name: nm, nl: nm.toLowerCase(), version: ln.slice(i1 + 1, i2), installed: !!iset[nm] }
        }
        let arr = []
        for (let k in byName) arr.push(byName[k])
        return arr
    }
    // Parse + publish. Returns false (leaving state untouched) when there is
    // nothing usable, so callers can fall back to a dnf run.
    function applyAvailable(t: string): bool {
        if (t.length === 0) return false
        let arr = parseAvailableText(t)
        if (arr.length === 0) return false
        availableList = arr
        availableLoading = false
        try { console.log("[JhqsMenu] available catalog: " + arr.length + " packages in " + Math.round(Date.now() - availableLoadStart) + "ms") } catch (e) { }
        if (showPackages && packageMode === "install") {
            selectedIndex = 0
            try { if (bodyRootRef) bodyRootRef.selectedIndex = 0 } catch(e) { }
        }
        return true
    }
    function refreshAvailable() {
        if (availableList.length > 0 || availableListProc.running || availableCacheProc.running) return
        availableRefreshTried = false
        availableLoading = true
        availableLoadStart = Date.now()
        availableCacheProc.command = ["bash", "-c", availableCacheCommand()]
        availableCacheProc.running = true
    }
    function refreshAvailableForce() {
        if (availableListProc.running || availableCacheProc.running) return
        availableRefreshTried = false
        availableListProc.command = ["bash", "-c", availableCommand(true)]
        availableLoading = true
        availableLoadStart = Date.now()
        availableListProc.running = true
    }
    // Instant path: valid cache shows immediately, then a background dnf
    // refresh tops it up. Cache miss/invalid -> dnf directly.
    function finishAvailableCache(out) {
        let t = (out || "").trim()
        if (applyAvailable(t)) { startAvailableBgRefresh(); return }
        if (!availableListProc.running) {
            availableListProc.command = ["bash", "-c", availableCommand(true)]
            availableListProc.running = true
        }
    }
    function finishAvailable(out) {
        let t = (out || "").trim()
        if (t === availableFreshMarker) { availableLoading = false; return }
        if (applyAvailable(t)) return
        availableLoading = false
        if (!availableRefreshTried) {
            // Cache-only miss (wiped/expired cache): single refresh run.
            availableRefreshTried = true
            availableListProc.command = ["bash", "-c", availableCommand(false)]
            availableLoading = true
            availableLoadStart = Date.now()
            availableListProc.running = true
        }
    }
    property var flatpakList: []
    property var flatpakInstalledPackages: []
    property bool flatpakLoading: false
    property bool flatpakInstalledLoading: false
    Process {
        id: flatpakListProc
        command: ["bash", "-c", "flatpak remote-ls --app --columns=application,name,version flathub 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                jhqsMenuScope.flatpakLoading = false
                let out = (text || "").trim()
                if (out.length === 0) return
                let lines = out.split("\n")
                let arr = []
                let seen = { }
                for (let i = 0; i < lines.length; i++) {
                    let ln = lines[i].trim()
                    if (ln.length === 0) continue
                    let cols = ln.split("\t")
                    let appId = (cols[0] || "").trim()
                    if (!/^[A-Za-z0-9_.\-]+$/.test(appId)) continue
                    if (seen[appId] !== undefined) continue
                    seen[appId] = true
                    let disp = (cols[1] || "").trim()
                    let ver = (cols[2] || "").trim()
                    arr.push({ repo: "flathub", name: appId, nl: appId.toLowerCase(), version: ver, displayName: disp, dl: disp.toLowerCase(), installed: false })
                }
                arr.sort((a, b) => a.name < b.name ? -1 : (a.name > b.name ? 1 : 0))
                let iset = { }
                for (let j = 0; j < jhqsMenuScope.flatpakInstalledPackages.length; j++) {
                    let fn = jhqsMenuScope.flatpakInstalledPackages[j] && jhqsMenuScope.flatpakInstalledPackages[j].name
                    if (fn) iset[fn] = true
                }
                for (let k = 0; k < arr.length; k++) if (iset[arr[k].name]) arr[k].installed = true
                jhqsMenuScope.flatpakList = arr
            }
        }
    }
    Process {
        id: flatpakInstalledProc
        command: ["bash", "-c", "flatpak list --app --columns=application,name,version 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                jhqsMenuScope.flatpakInstalledLoading = false
                let out = (text || "").trim()
                let arr = []
                if (out.length > 0) {
                    let lines = out.split("\n")
                    let seen = { }
                    for (let i = 0; i < lines.length; i++) {
                        let ln = lines[i].trim()
                        if (ln.length === 0) continue
                        let cols = ln.split("\t")
                        let appId = (cols[0] || "").trim()
                        if (!/^[A-Za-z0-9_.\-]+$/.test(appId)) continue
                        if (seen[appId] !== undefined) continue
                        seen[appId] = true
                        let disp = (cols[1] || "").trim()
                        let ver = (cols[2] || "").trim()
                        arr.push({ repo: "flathub", name: appId, nl: appId.toLowerCase(), version: ver, displayName: disp, dl: disp.toLowerCase(), installed: true })
                    }
                    arr.sort((a, b) => a.name < b.name ? -1 : (a.name > b.name ? 1 : 0))
                }
                jhqsMenuScope.flatpakInstalledPackages = arr
                if (jhqsMenuScope.flatpakList.length > 0) {
                    let iset = { }
                    for (let j = 0; j < arr.length; j++) if (arr[j] && arr[j].name) iset[arr[j].name] = true
                    let cur = jhqsMenuScope.flatpakList
                    let next = []
                    for (let k = 0; k < cur.length; k++) {
                        let e = cur[k]
                        let inst = !!iset[e.name]
                        next.push(e.installed === inst ? e : { repo: e.repo, name: e.name, nl: e.nl || ("" + e.name).toLowerCase(), version: e.version, displayName: e.displayName || "", dl: e.dl || ("" + (e.displayName || "")).toLowerCase(), installed: inst })
                    }
                    jhqsMenuScope.flatpakList = next
                }
            }
        }
    }
    function refreshFlatpak() {
        if (flatpakList.length === 0 && !flatpakListProc.running) { flatpakLoading = true; flatpakListProc.running = true }
        if (!flatpakInstalledProc.running) { flatpakInstalledLoading = true; flatpakInstalledProc.running = true }
    }
    function refreshFlatpakForce() {
        if (!flatpakListProc.running) { flatpakLoading = true; flatpakListProc.running = true }
        if (!flatpakInstalledProc.running) { flatpakInstalledLoading = true; flatpakInstalledProc.running = true }
    }
    readonly property string webAppScriptsDir: Quickshell.env("HOME") + "/.config/quickshell/jhqs/scripts"
    function webAppBin(kind: string): string {
        if (kind === "remove") return webAppScriptsDir + "/webapp-remove.sh"
        if (kind === "list") return webAppScriptsDir + "/webapp-list.sh"
        return webAppScriptsDir + "/webapp-install.sh"
    }
    property bool webAppListRetried: false
    function refreshWebApps() {
        if (webAppListProc.running) return
        webAppLoading = true
        webAppListProc.command = [webAppBin("list")]
        webAppListProc.running = true
    }
    property var filteredWebApps: {
        let q = qLower()
        if (!showWebApp || webAppMode !== "remove") return []
        if (q === "") return webAppList
        return webAppList.filter(w => {
            let n = ("" + (w.name || "")).toLowerCase()
            let d = ("" + (w.displayName || "")).toLowerCase()
            let u = ("" + (w.url || "")).toLowerCase()
            return n.includes(q) || d.includes(q) || u.includes(q)
        })
    }
    function openWebApp(mode) {
        let m = (mode === "remove") ? "remove" : "install"
        webAppMode = m
        showInstall = false; showRemove = false; showPackages = false
        showWebApp = true
        webAppBusy = false; webAppSuccess = false; webAppStatus = ""; webAppLog = ""
        clearSearch()
        if (m === "remove") repairWebApps()
    }
    function repairWebApps() {
        if (webAppRepairProc.running || webAppListProc.running) { refreshWebApps(); return }
        webAppLoading = true
        webAppRepairProc.command = [webAppBin("install"), "--repair"]
        webAppRepairProc.running = true
    }
    function clearWebAppStatus() { webAppStatus = ""; webAppLog = ""; webAppSuccess = false }
    function webAppOpAppend(line) {
        let parts = ("" + (line || "")).split("\n")
        let lines = []
        for (let i = 0; i < parts.length; i++) {
            let s = parts[i]
            if (s.charAt(s.length - 1) === "\r") s = s.slice(0, -1)
            let ci = s.lastIndexOf("\r")
            if (ci !== -1) s = s.slice(ci + 1)
            s = s.replace(/\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)/g, "")
                .replace(/\x1b\[[0-9;?]*[ -/]*[@-~]/g, "")
                .replace(/\x1b[()][0-9A-B]/g, "")
                .replace(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/g, "")
                .replace(/\s+$/, "")
            if (s.length === 0) continue
            lines.push(s)
        }
        if (lines.length === 0) return
        let cur = webAppLog.length > 0 ? webAppLog.split("\n") : []
        cur = cur.concat(lines)
        if (cur.length > 60) cur = cur.slice(cur.length - 60)
        webAppLog = cur.join("\n")
    }
    function installWebApp(name, url, iconRef) {
        let n = ("" + (name || "")).trim()
        let u = ("" + (url || "")).trim()
        let icon = ("" + (iconRef || "")).trim()
        if (webAppBusy) return false
        if (n.length === 0) { webAppStatus = "Name missing"; webAppSuccess = false; return false }
        if (n.indexOf("/") !== -1) { webAppStatus = "Name must not contain '/'"; webAppSuccess = false; return false }
        if (u.length === 0) { webAppStatus = "URL missing"; webAppSuccess = false; return false }
        if (!/^[a-zA-Z][a-zA-Z0-9+.\-]*:/.test(u)) u = "https://" + u
        webAppBusy = true; webAppSuccess = false; webAppStatus = "Installing '" + n + "'…"; webAppLog = ""
        webAppLastName = n
        webAppOpAppend("Installing '" + n + "' (" + u + ")…")
        webAppOpProc.command = [webAppBin("install"), n, u, icon]
        if (!webAppOpProc.running) webAppOpProc.running = true
        return true
    }
    function removeWebApp(name) {
        let n = ("" + (name || "")).trim()
        if (webAppBusy) return false
        if (n.length === 0) { webAppStatus = "No selection"; webAppSuccess = false; return false }
        webAppBusy = true; webAppSuccess = false; webAppStatus = "Removing '" + n + "'…"
        webAppLastName = n
        webAppOpAppend("Removing '" + n + "'…")
        webAppOpProc.command = [webAppBin("remove"), n]
        if (!webAppOpProc.running) webAppOpProc.running = true
        return true
    }
    function finishWebAppOp(code) {
        webAppBusy = false; webAppSuccess = (code === 0)
        if (code === 0) {
            webAppOpAppend("✓ Done (code 0)")
            webAppStatus = webAppMode === "remove" ? "✓ Removed" : "✓ Installed — find it in the app launcher"
            if (webAppMode !== "remove") {
                let label = webAppLastName !== "" ? " '" + webAppLastName + "'" : ""
                sendInstallNotification("✓ Web App installed" + label, "find it in the app launcher")
            }
        } else if (code === 127) {
            webAppOpAppend("✗ Install script not found (code 127)")
            webAppStatus = "✗ Script missing: check scripts/webapp-install.sh"
        } else {
            webAppOpAppend("✗ Failed (code " + code + ")")
            if (webAppStatus === "" || webAppStatus.endsWith("…")) webAppStatus = "✗ Failed (code " + code + ")"
        }
        refreshWebApps()
        try { Theme.notifyAppsChanged() } catch (e) { }
    }
    Process {
        id: packageOpProc
        command: ["bash", "-c", "echo"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => jhqsMenuScope.packageOpAppend(data)
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => jhqsMenuScope.packageOpAppend(data)
        }
        onExited: (code) => jhqsMenuScope.finishPackageOp(code)
    }
    Process { id: installNotifyProc; command: ["bash", "-c", "echo"] }
    function sendInstallNotification(title, body) {
        let t = ("" + (title || "")).slice(0, 120)
        let b = ("" + (body || "")).slice(0, 240)
        if (t === "") return
        installNotifyProc.command = ["bash", "-c", "notify-send -u normal -a jhqs \"" + escShellArg(t) + "\" \"" + escShellArg(b) + "\" 2>/dev/null || true"]
        if (!installNotifyProc.running) installNotifyProc.running = true
    }
    JHQ.ThemeEngine { id: themeEngine }
    Connections {
        target: themeEngine
        function onWallpaperDisplayRequested(path) { jhqsMenuScope.setWallpaperDisplay(path) }
    }
    // No debounce timer: wallpaper clicks apply immediately. Coalescing of
    // rapid clicks happens in ThemeEngine.enqueueThemeApply (a busy worker
    // keeps only the latest pending path, intermediate ones are skipped).
    readonly property string currentEngine: themeEngine.currentEngine
    readonly property bool themeBusy: themeEngine.themeBusy
    readonly property var matugenTypes: themeEngine.matugenTypes
    readonly property var matugenTypeLabels: themeEngine.matugenTypeLabels
    readonly property string monetType: themeEngine.monetType
    readonly property string monetMode: themeEngine.monetMode
    function applyMonetScheme(type, mode) { themeEngine.applyMonetScheme(type, mode) }
    function setThemeEngine(id) {
        // No remembered wallpaper for this theme yet => fall back to its first.
        if (themeEngine.wallpaperForTheme(id) === "") {
            let first = firstWallpaperForTheme(id)
            if (first !== "") themeEngine.rememberWallpaper(id, first)
        }
        themeEngine.setThemeEngine(id)
    }

    function syncQueryInput(txt) {
        try { if (queryInputRef) queryInputRef.text = txt } catch(e) { }
        try { if (bodyRootRef) bodyRootRef.filterText = txt } catch(e) { }
    }
    function qLower(): string { return filterText.toLowerCase().trim() }
    // PERF: only the 72k-row DNF package catalog is debounced. Everything
    // else (apps, menus, categories, wallpapers, fonts, webapps: a few
    // hundred rows max) filters instantly on every keystroke (<1ms).
    // Previously they all shared a 120ms debounce, so top-level results
    // visibly lagged behind typing.
    property string _q: ""
    function _qLower(): string { return _q.toLowerCase().trim() }
    Timer {
        id: filterDebounce
        interval: 50; repeat: false
        onTriggered: jhqsMenuScope._q = jhqsMenuScope.filterText
    }
    // STABILITY: clamp selection when the debounced package list lands (it
    // can shrink after the keystroke that changed the query).
    on_QChanged: {
        try {
            if (selectedIndex >= totalCount) selectedIndex = Math.max(0, totalCount - 1)
            if (bodyRootRef && bodyRootRef.selectedIndex >= totalCount) bodyRootRef.selectedIndex = Math.max(0, totalCount - 1)
        } catch (e) { }
    }
    function queryWordsFor(q: string): var {
        if (q === "") return []
        return q.split(/\s+/).filter(w => w.length > 0)
    }
    function queryWords(): var {
        return queryWordsFor(qLower())
    }
    // Multi-word match: every query word must occur (any order).
    function matchesAll(hayLower: string, words: var): bool {
        for (let i = 0; i < words.length; i++) if ((hayLower || "").indexOf(words[i]) === -1) return false
        return true
    }
    // Match tier for best-first section ordering: 0 exact, 1 prefix, 2 all-words.
    function matchTier(primary: string, full: string, q: string, words: var): int {
        let p = (primary || "").toLowerCase(), f = (full || "").toLowerCase()
        if (p === q) return 0
        if (q.length > 0 && p.startsWith(q)) return 1
        if (matchesAll(f, words)) return 2
        return -1
    }
    function clearSearch() {
        filterText = ""; _q = ""; filterDebounce.stop(); selectedIndex = 0; syncQueryInput("")
        try { if (bodyRootRef) bodyRootRef.selectedIndex = 0 } catch(e) { }
    }
    function tryAutoExpandCategory(): void {
        if (isInSubmenu) return
        let q = qLower()
        if (q === "") return
        let m = null
        for (let i = 0; i < menuModel.length; i++) {
            let e = menuModel[i]
            if (!e || !e.title) continue
            if (e.title.toLowerCase() === q && (e.submenu || e.title === "Apps")) { m = e; break }
        }
        if (!m) return
        if (m.title === "Apps") { showNewAppMenu = true; clearSearch() }
        else if (m.title === "Style") { showStyle = true; clearSearch(); refreshWallpapers() }
        else if (m.title === "Setup") { showSetup = true; clearSearch() }
        else if (m.title === "Learn") { showLearn = true; clearSearch() }
        else if (m.title === "Install") { showInstall = true; clearSearch() }
        else if (m.title === "Remove") { showRemove = true; clearSearch() }
        else if (m.title === "System") { showSession = true; directSystemOpen = false; clearSearch() }
    }
    function resetAllSubmenus() { showStyle = false; showWallpaper = false; showWallpaperSettings = false; showThemes = false; showFont = false; showInstall = false; showRemove = false; showSession = false; showSetup = false; showLearn = false; showKeybinds = false; showModules = false; modulesSubview = "root"; showNewAppMenu = false; showPackages = false; showWebApp = false; directSystemOpen = false }
    function handleEsc(): bool {
        if (showWallpaperSettings) { showWallpaperSettings = false; clearSearch(); return true }
        if (showWallpaper) { showWallpaper = false; showStyle = true; clearSearch(); return true }
        if (showThemes) { showThemes = false; showStyle = true; clearSearch(); return true }
        if (showFont) { showFont = false; showStyle = true; clearSearch(); return true }
        if (showModules) { showModules = false; modulesSubview = "root"; showStyle = true; clearSearch(); return true }
        if (showNewAppMenu) { showNewAppMenu = false; clearSearch(); return true }
        if (showPackages) {
            if (packageOpActive) { leavePackageOp(); return true }
            showPackages = false; if (packageOrigin === "Remove" || packageOrigin === "FlatpakRemove") showRemove = true; else showInstall = true; clearSearch(); return true
        }
        if (showWebApp) {
            showWebApp = false; if (webAppMode === "remove") showRemove = true; else showInstall = true; clearSearch(); return true
        }
        if (showKeybinds) { showKeybinds = false; showLearn = true; clearSearch(); return true }
        if (showStyle || showInstall || showRemove || showSetup || showLearn) { resetAllSubmenus(); clearSearch(); return true }
        if (showSession) {
            if (filterText.length > 0) { clearSearch(); return true }
            let isDirect = directSystemOpen
            resetAllSubmenus(); clearSearch(); return isDirect ? false : true
        }
        if (filterText.length > 0) { clearSearch(); return true }
        return false
    }
    function selectedEntryInfo(): string {
        try {
            let si = selectedIndex
            if (showWallpaper) { let p = filteredWallpapers[si]; return "wallpaper:" + (p ? p.split("/").pop() : "none") + " idx=" + si }
            if (showThemes) { let t = filteredThemes[si]; return "theme:" + (t ? t.title : "none") + " idx=" + si }
            if (showFont) { let g = filteredFontGroups[si]; return "fontgroup:" + (g ? g.title : "none") + " idx=" + si }
            if (showNewAppMenu) { let e = filteredNewApps[si]; return "newapp:" + (e ? e.name || e.id : "none") + " idx=" + si }
            if (showPackages) { let p = filteredPackages[si]; return "package:" + (p ? p.name : "none") + " idx=" + si }
            if (showWebApp) { return "webapp:" + webAppMode + " count=" + filteredWebApps.length + " idx=" + si }
            if (showKeybinds) { let k = filteredKeybinds[si]; return "keybind:" + (k ? k.combo + " => " + k.action : "none") + " idx=" + si }
            let q = qLower()
            let inSub = showStyle || showInstall || showRemove || showSession || showSetup || showLearn || showKeybinds
            if (q !== "" && !inSub) {
                let r = searchRows[si]
                if (!r) return "none idx=" + si
                if (r.row === "app") { let e = r.entry; return "app:" + (e ? e.name || e.id : "none") + " idx=" + si }
                if (r.row === "menu") return "menu:" + (r.entry ? r.entry.title : "none") + " idx=" + si
                if (r.row === "cat") return "cat:" + r.category + "->" + (r.entry ? r.entry.title : "none") + " idx=" + si
                return "none idx=" + si
            }
            if (si < filteredApps.length) { let e = filteredApps[si]; return "app:" + (e ? e.name || e.id : "none") + " idx=" + si }
            if (si < filteredApps.length + filteredMenu.length) return "menu:" + filteredMenu[si - filteredApps.length].title + " idx=" + si
            let f = flattenedCategoryOptions[si - filteredApps.length - filteredMenu.length]
            if (!f) return "none idx=" + si
            return "cat:" + f.category + "->" + f.entry.title + " idx=" + si
        } catch(e) { return "err:" + e }
    }

    IpcHandler {
        target: "jhqsMenu"
        function setQuery(t: string): void { jhqsMenuScope.filterText = t; jhqsMenuScope.selectedIndex = 0; jhqsMenuScope.syncQueryInput(jhqsMenuScope.filterText) }
        function getCounts(): string { return "filter=\"" + jhqsMenuScope.filterText + "\" menu=" + jhqsMenuScope.filteredMenu.length + " cats=" + jhqsMenuScope.categoryOptionsCount + " (" + jhqsMenuScope.filteredCategorySections.length + " sections) apps=" + jhqsMenuScope.filteredApps.length + " newapps=" + jhqsMenuScope.filteredNewApps.length + " packages=" + jhqsMenuScope.filteredPackages.length + " webapps=" + jhqsMenuScope.filteredWebApps.length + " wallpaper=" + jhqsMenuScope.filteredWallpapers.length + " themes=" + jhqsMenuScope.filteredThemes.length + " fonts=" + jhqsMenuScope.filteredFontGroups.length + " total=" + jhqsMenuScope.totalCount + " selected=" + jhqsMenuScope.selectedIndex }
        function pressEnter(): void { if (jhqsMenuScope.bodyRootRef) { jhqsMenuScope.selectedIndex = jhqsMenuScope.bodyRootRef.selectedIndex; jhqsMenuScope.bodyRootRef.activateCurrent() } }
        function pressEsc(): void { if (!jhqsMenuScope.handleEsc()) jhqsMenuScope.dismissed() }
        function moveDown(): void { if (jhqsMenuScope.totalCount === 0) return; jhqsMenuScope.selectedIndex = jhqsMenuScope.showWallpaper ? Math.min(jhqsMenuScope.selectedIndex + 3, jhqsMenuScope.totalCount - 1) : (jhqsMenuScope.selectedIndex + 1) % jhqsMenuScope.totalCount }
        function moveUp(): void { if (jhqsMenuScope.totalCount === 0) return; jhqsMenuScope.selectedIndex = jhqsMenuScope.showWallpaper ? Math.max(jhqsMenuScope.selectedIndex - 3, 0) : (jhqsMenuScope.selectedIndex - 1 + jhqsMenuScope.totalCount) % jhqsMenuScope.totalCount }
        function getSelected(): string { return jhqsMenuScope.selectedEntryInfo() }
        function preloadPackages(): string { jhqsMenuScope.refreshAvailable(); jhqsMenuScope.refreshPackages(); return "preload started" }
        function packageStatus(): string { return "available=" + jhqsMenuScope.availableList.length + " loading=" + jhqsMenuScope.availableLoading + " installed=" + jhqsMenuScope.installedList.length }
    }

    function isHiddenLauncherApp(e): bool {
        let nm = ((e && e.name) || "").toLowerCase()
        if (nm.startsWith("avahi") || nm.startsWith("bluetooth")) return true
        let id = ((e && e.id) || "").toLowerCase()
        if (id.startsWith("avahi-") || id.indexOf("blueman") !== -1) return true
        return false
    }
    property var allApps: {
        Theme.appsRev
        try {
            let a = DesktopEntries.applications
            if (!a) return []
            let v = a.values
            if (typeof v === "function") v = v()
            if (!v) return []
            let arr = v.slice ? v.slice() : [...v]
            arr = arr.filter(e => !isHiddenLauncherApp(e))
            arr.sort((a, b) => {
                let an = (a.name || "").toLowerCase(), bn = (b.name || "").toLowerCase()
                if (an === "" && bn !== "") return 1
                if (bn === "" && an !== "") return -1
                return an.localeCompare(bn)
            })
            return arr
        } catch(e) {
            console.log("[JhqsMenu] DesktopEntries load err", e)
            return []
        }
    }
    property string filterText: ""
    readonly property var _appSearchIndex: {
        let src = allApps ? (typeof allApps === "function" ? allApps() : allApps) : []
        let out = []
        try {
            for (let i = 0; i < src.length; i++) {
                let a = src[i]
                if (!a) continue
                // Pre-lower once here (menu open), not per keystroke: nl is the
                // name for exact/prefix tiers, n is the full haystack.
                let nm = (a.name || ""), aid = (a.id || "")
                let nl = ("" + nm).toLowerCase()
                out.push({ e: a, nl: nl, n: (nm + " " + aid).toLowerCase(), c: ((a.comment || "")).toLowerCase() })
            }
        } catch (e) { }
        return out
    }
    onFilterTextChanged: {
        tryAutoExpandCategory()
        // Empty query clears the debounced package filter instantly instead
        // of waiting out the timer.
        if (filterText === "") { _q = ""; filterDebounce.stop() }
        else filterDebounce.restart()
    }
    JHQ.MenuCategories { id: menuCategories }
    readonly property var styleMenu: menuCategories.styleMenu
    readonly property var themeOptions: menuCategories.themeOptions
    readonly property var setupMenu: menuCategories.setupMenu
    readonly property var learnMenu: menuCategories.learnMenu
    readonly property var installMenu: menuCategories.installMenu
    readonly property var removeMenu: menuCategories.removeMenu
    readonly property var sessionMenu: menuCategories.sessionMenu
    property var menuModel: [
        {title:"Apps",icon:"󰀻",arrow:"›", submenu: null},
        {title:"Learn",icon:"󰌵",arrow:"›", submenu: learnMenu},
        {title:"Style",icon:"󰏘",arrow:"›", submenu: styleMenu},
        {title:"Setup",icon:"󰒓",arrow:"›", submenu: setupMenu},
        {title:"Install",icon:"󰇚",arrow:"›", submenu: installMenu},
        {title:"Remove",icon:"󰆴",arrow:"›", submenu: removeMenu},
        {title:"About",icon:"󰋼",arrow:"", submenu: null},
        {title:"System",icon:"󰐥",arrow:"›", submenu: sessionMenu}
    ]
    property var queryInputRef: null
    property var bodyRootRef: null
    // Deep-link targets into the Modules view: exposed to top-level search
    // as virtual Style-category entries ("Module enable" / "Module remove").
    property var moduleSubviewOptions: [
        {title: "Module enable", icon: "󰐕", modulesSubview: "add"},
        {title: "Module remove", icon: "󰐖", modulesSubview: "remove"}
    ]
    property string modulesSubview: "root"
    function moduleSubviewHaystack(entry): string {
        let s = ("" + (entry.title || "") + " " + (entry.modulesSubview || "")).toLowerCase()
        s += entry.modulesSubview === "remove" ? " delete remove uninstall disable" : " add enable install"
        return s + " module modules"
    }
    function openModules(sub) {
        modulesSubview = (sub === "remove") ? "remove" : ((sub === "root") ? "root" : "add")
        showStyle = false; showWallpaper = false; showWallpaperSettings = false; showThemes = false; showFont = false
        showInstall = false; showRemove = false; showSession = false; showSetup = false; showLearn = false; showKeybinds = false
        showNewAppMenu = false; showPackages = false; showWebApp = false; directSystemOpen = false
        showModules = true
        clearSearch()
    }
    property bool showStyle: false
    property bool showWallpaper: false
    property bool showThemes: false
    property bool showFont: false
    property bool showInstall: false
    property bool showRemove: false
    property bool showSession: false
    property bool showSetup: false
    property bool showLearn: false
    property bool showKeybinds: false
    property bool showModules: false
    property bool showNewAppMenu: false
    property bool showPackages: false
    property bool directSystemOpen: false
    property bool isInSubmenu: showStyle || showWallpaper || showThemes || showFont || showInstall || showRemove || showSession || showSetup || showLearn || showKeybinds || showModules || showNewAppMenu || showPackages || showWebApp
    readonly property bool canGoBack: isInSubmenu

    property bool __triggerInitDone: false
    Component.onCompleted: { __triggerInitDone = true; _q = filterText }
    property int systemTrigger: 0
    onSystemTriggerChanged: { if (!__triggerInitDone) return; if (systemTrigger > 0) openSystem() }
    property var wallpaperFiles: []
    function normThemeName(s) {
        try { return ("" + (s || "")).toLowerCase().replace(/[^a-z0-9]/g, "") } catch(e) { return "" }
    }
    function wallpaperThemeFolder(p) {
        try {
            let s = "" + p
            let root = wallpaperResolvedDir
            if (root !== "" && s.startsWith(root + "/")) {
                let rest = s.slice(root.length + 1)
                let slash = rest.indexOf("/")
                if (slash === -1) return ""
                return rest.slice(0, slash)
            }
            let parts = s.split("/")
            if (parts.length >= 3) return parts[parts.length - 2]
            return ""
        } catch(e) { return "" }
    }
    property var engineWallpapers: {
        let out = []
        try {
            let eng = normThemeName(currentEngine)
            for (let i = 0; i < wallpaperFiles.length; i++) {
                let p = wallpaperFiles[i]
                let folder = wallpaperThemeFolder(p)
                if (folder === "") { out.push(p); continue }
                let n = normThemeName(folder)
                if (n === "") continue
                if (n === "nonthemed" && eng !== "wallpaper") continue
                if (eng === "wallpaper" || n === eng) out.push(p)
            }
        } catch(e) { }
        return out
    }
    // First wallpaper belonging to a theme, using the same folder rules as
    // engineWallpapers (root files count for every theme, "nonthemed" only
    // for the wallpaper/monet engine).
    function firstWallpaperForTheme(id) {
        try {
            let eng = normThemeName(id)
            for (let i = 0; i < wallpaperFiles.length; i++) {
                let p = wallpaperFiles[i]
                let folder = wallpaperThemeFolder(p)
                if (folder === "") return p
                let n = normThemeName(folder)
                if (n === "") continue
                if (n === "nonthemed" && eng !== "wallpaper") continue
                if (eng === "wallpaper" || n === eng) return p
            }
        } catch (e) { }
        return ""
    }
    // Seed every theme that has no remembered wallpaper with the first
    // wallpaper of its folder, so switching themes always lands on one.
    function ensureThemeWallpapers() {
        if (!wallpaperFiles || wallpaperFiles.length === 0) return
        let ids = themeOptions || []
        for (let i = 0; i < ids.length; i++) {
            let id = ids[i] && ids[i].id
            if (!id) continue
            if (themeEngine.wallpaperForTheme(id) !== "") continue
            // The active theme keeps whatever wallpaper is on screen; the
            // remaining themes start with the first wallpaper of their folder.
            let seed = (id === currentEngine) ? themeEngine.currentWallpaperText() : firstWallpaperForTheme(id)
            if (seed !== "") themeEngine.rememberWallpaper(id, seed)
        }
    }

    property var filteredWallpapers: {
        if (!showWallpaper) return []
        let files = engineWallpapers
        let q = qLower()
        if (q === "") return files
        return files.filter(p => p.toLowerCase().split("/").pop().includes(q))
    }
    property var filteredThemes: {
        if (!showThemes) return []
        let q = qLower()
        if (q === "") return themeOptions
        return themeOptions.filter(t => t.title.toLowerCase().includes(q) || (t.subtitle && t.subtitle.toLowerCase().includes(q)))
    }
    property var fontAllFamilies: {
        if (!showFont) return []
        // Depend on revision so manual reload re-queries Qt.fontFamilies() + fc-list merge
        let _rev = fontRevision
        let all = []
        try {
            let qtf = Qt.fontFamilies()
            if (qtf && qtf.length > 0) all = qtf.slice()
        } catch(e) { }
        // Merge fresh fc-list results so newly installed fonts show without restart
        try {
            let fb = fontFallbackFamilies
            if (fb && fb.length > 0) {
                let seen = { }
                for (let i = 0; i < all.length; i++) seen["" + all[i]] = true
                for (let j = 0; j < fb.length; j++) {
                    let f = "" + fb[j]
                    if (!seen[f]) { seen[f] = true; all.push(fb[j]) }
                }
            }
        } catch(e) { }
        // Only show JetBrains Mono, Geist Mono and Inter
        let allowed = ["jetbrainsmono", "geistmono", "inter"]
        all = all.filter(f => {
            try {
                let n = ("" + f).toLowerCase().replace(/[\s_\-]+/g, "")
                for (let i = 0; i < allowed.length; i++) if (n.includes(allowed[i])) return true
                return false
            } catch(e) { return false }
        })
        all.sort((a, b) => ("" + a).toLowerCase() < ("" + b).toLowerCase() ? -1 : 1)
        return all
    }
    property var filteredFonts: {
        if (!showFont) return []
        let q = qLower()
        let all = fontAllFamilies
        if (q === "") return all
        return all.filter(f => ("" + f).toLowerCase().includes(q)).slice(0, 100)
    }
    // Merge weight variants (Regular/Medium/Bold/...) into one group per typeface,
    // e.g. "JetBrains Mono" + "Geist Mono" + "Inter". Only the Regular (400) cut is kept.
    function fontGroupTitleFor(family: string): string {
        try {
            let n = ("" + family).toLowerCase().replace(/[\s_\-]+/g, "")
            if (n.includes("jetbrainsmono")) return "JetBrains Mono"
            if (n.includes("geistmono")) return "Geist Mono"
            if (n.startsWith("inter")) return "Inter"
        } catch(e) { }
        return ("" + family).trim()
    }
    function fontWeightRank(family: string): int {
        try {
            let n = ("" + family).toLowerCase()
            if (n.includes("thin")) return 1
            if (n.includes("extralight")) return 2
            if (n.includes("light")) return 3
            if (n.includes("medium")) return 5
            if (n.includes("semibold")) return 6
            if (n.includes("extrabold")) return 8
            if (n.includes("bold")) return 7
            if (n.includes("black")) return 9
        } catch(e) { }
        return 4
    }
    function fontWeightName(family: string): string {
        let r = fontWeightRank(family)
        if (r === 1) return "Thin"
        if (r === 2) return "ExtraLight"
        if (r === 3) return "Light"
        if (r === 5) return "Medium"
        if (r === 6) return "SemiBold"
        if (r === 7) return "Bold"
        if (r === 8) return "ExtraBold"
        if (r === 9) return "Black"
        return "Regular"
    }
    function fontVariantLabel(variant: string, group: string): string {
        try {
            let f = ("" + variant).trim()
            let g = ("" + group).trim()
            if (f.toLowerCase() === g.toLowerCase()) return "Regular"
            if (f.toLowerCase().startsWith(g.toLowerCase())) {
                let rest = f.slice(g.length).trim().replace(/^[-_\s]+/, "")
                return rest === "" ? "Regular" : rest
            }
            let rest2 = f.replace(/^(JetBrains\s?Mono|Geist\s?Mono|GeistMono|JetBrainsMono|Inter(\s?(Display|Variable))?)\s*/i, "").trim()
            return rest2 === "" ? "Regular" : rest2
        } catch(e) { return ("" + variant).trim() }
    }
    function fontGroupActiveVariant(group): string {
        try {
            let cur = ("" + Theme.fontFamily).trim()
            let vs = (group && group.variants) || []
            for (let i = 0; i < vs.length; i++) if (("" + vs[i]).trim() === cur) return ("" + vs[i])
            if (cur === ("" + (group && group.title)).trim()) return cur
        } catch(e) { }
        return ""
    }
    property var fontGrouped: {
        if (!showFont) return []
        let _r = fontRevision
        let all = []
        try { all = fontAllFamilies.slice() } catch(e) { all = [] }
        let map = { }
        let order = []
        for (let i = 0; i < all.length; i++) {
            let fam = "" + all[i]
            let g = fontGroupTitleFor(fam)
            if (!map[g]) { map[g] = []; order.push(g) }
            if (map[g].indexOf(fam) === -1) map[g].push(fam)
        }
        order.sort((a, b) => {
            let ra = a === "JetBrains Mono" ? 0 : a === "Geist Mono" ? 1 : a === "Inter" ? 2 : 3
            let rb = b === "JetBrains Mono" ? 0 : b === "Geist Mono" ? 1 : b === "Inter" ? 2 : 3
            if (ra !== rb) return ra - rb
            return ("" + a).toLowerCase() < ("" + b).toLowerCase() ? -1 : 1
        })
        let out = []
        for (let k = 0; k < order.length; k++) {
            let g = order[k]
            let variants = map[g].slice()
            variants.sort((a, b) => {
                let ra = fontWeightRank(a), rb = fontWeightRank(b)
                if (ra !== rb) return ra - rb
                return ("" + a).toLowerCase() < ("" + b).toLowerCase() ? -1 : 1
            })
            let preview = g
            if (variants.indexOf(g) !== -1) preview = g
            else if (variants.length > 0) {
                preview = variants[0]
                for (let v = 0; v < variants.length; v++) {
                    if (fontWeightRank(variants[v]) === 4) { preview = variants[v]; break }
                }
            }
            // Only keep the preferred cut, drop every other weight/style variant
            if (preview === "") continue
            out.push({ title: g, preview: preview, variants: [preview] })
        }
        return out
    }
    property var filteredFontGroups: {
        if (!showFont) return []
        let q = qLower()
        let groups = fontGrouped
        if (q === "") return groups
        return groups.filter(g => {
            try {
                if (("" + g.title).toLowerCase().includes(q)) return true
                let vs = g.variants || []
                for (let i = 0; i < vs.length; i++) if (("" + vs[i]).toLowerCase().includes(q)) return true
                return false
            } catch(e) { return false }
        })
    }
    property var filteredNewApps: {
        if (!showNewAppMenu) return []
        let q = qLower()
        if (q === "") {
            let out = []
            for (let i = 0; i < _appSearchIndex.length && out.length < 50; i++) out.push(_appSearchIndex[i].e)
            return out
        }
        let words = queryWordsFor(q)
        let multi = words.length > 1
        let r = []
        for (let i = 0; i < _appSearchIndex.length; i++) {
            let row = _appSearchIndex[i]
            if (multi) {
                if (!matchesAll(row.n, words) && !matchesAll(row.c, words)) continue
            } else if (row.n.indexOf(q) === -1 && row.c.indexOf(q) === -1) continue
            r.push(row.e); if (r.length >= 8) break
        }
        return r
    }
    property string packageOrigin: "Install"
    property string packageMode: "install"
    // Curated Fedora (DNF) catalogs. Names must be installable via
    // `dnf install` on Fedora (+RPM Fusion/COPR where noted).
    readonly property var gamingCatalog: [
        { repo: "rpmfusion", name: "steam", version: "", displayName: "Steam" },
        { repo: "fedora", name: "lutris", version: "", displayName: "Lutris" },
        { repo: "fedora", name: "prismlauncher", version: "", displayName: "Prism Launcher" },
        { repo: "fedora", name: "heroic-games-launcher", version: "", displayName: "Heroic Launcher" }
    ]
    readonly property var browserCatalog: [
        { repo: "fedora", name: "firefox", version: "", displayName: "Firefox" },
        { repo: "fedora", name: "chromium", version: "", displayName: "Chromium" },
        { repo: "rpmfusion", name: "brave-browser", version: "", displayName: "Brave" },
        { repo: "copr", name: "helium-bin", version: "", displayName: "Helium Browser" }
    ]
    function curatedCatalog() { return packageMode === "browser" ? browserCatalog : gamingCatalog }
    function curatedTitle() { return packageMode === "browser" ? "Browser" : "Gaming" }
    function curatedSize() { return packageMode === "browser" ? browserCatalog.length : gamingCatalog.length }
    function curatedSpec(name) {
        return name
    }
    readonly property var _installedSet: {
        let s = {}
        try {
            for (let i = 0; i < installedList.length; i++) { let p = installedList[i]; if (p && p.name && p.installed) s[p.name] = true }
        } catch (e) { }
        return s
    }
    readonly property var _versionMap: {
        let m = {}
        try {
            for (let i = 0; i < installedList.length; i++) { let p = installedList[i]; if (p && p.name && p.version) m[p.name] = p.version }
        } catch (e) { }
        return m
    }
    function curatedListWithInstalled() {
        let iset = _installedSet, vmap = _versionMap
        let out = []
        let cat = curatedCatalog()
        for (let k = 0; k < cat.length; k++) {
            let g = cat[k]
            out.push({ repo: g.repo, name: g.name, version: vmap[g.name] || g.version, displayName: g.displayName, installed: !!iset[g.name] })
        }
        return out
    }
    property var packageSelected: []
    function isPackageSelected(name) { try { return packageSelected.indexOf(name) !== -1 } catch(e) { return false } }
    function togglePackageSelected(name) {
        if (!name) return
        if (packageMode === "remove" && isProtectedPackage(name)) return
        let i = packageSelected.indexOf(name)
        if (i === -1) packageSelected = packageSelected.concat([name])
        else packageSelected = packageSelected.slice(0, i).concat(packageSelected.slice(i + 1))
    }
    function clearPackageSelection() { packageSelected = [] }
    property int installedPackageCount: installedList.filter(p => p && p.installed && isRemovablePackage(p.name)).length
    // The only debounced filter (see filterDebounce): a single pass over the
    // 72k-row DNF catalog per keystroke would drop frames, so this settles
    // 50ms after typing stops. All comparisons use pre-lowered fields.
    property var filteredPackages: {
        if (!showPackages) return []
        let q = _qLower()
        if (packageMode === "gaming" || packageMode === "browser") {
            let gbase = curatedListWithInstalled()
            if (q === "") return gbase
            let gexact = [], gstarts = [], gsub = [], gname = []
            for (let gi = 0; gi < gbase.length; gi++) {
                let gp = gbase[gi]
                if (!gp || !gp.name) continue
                let gn = ("" + gp.name).toLowerCase()
                let gd = ("" + (gp.displayName || "")).toLowerCase()
                if (gn === q) gexact.push(gp)
                else if (gn.startsWith(q)) gstarts.push(gp)
                else if (gn.includes(q)) gsub.push(gp)
                else if (gd !== "" && gd.includes(q)) gname.push(gp)
            }
            return gexact.concat(gstarts, gsub, gname)
        }
        if (packageMode === "install") {
            if (q === "") return availableList.slice(0, 100)
            let exact = [], starts = [], sub = []
            for (let i = 0; i < availableList.length; i++) {
                let p = availableList[i]
                if (!p || !p.name) continue
                let n = p.nl || ("" + p.name).toLowerCase()
                if (n === q) exact.push(p)
                else if (n.startsWith(q)) starts.push(p)
                else if (n.includes(q)) sub.push(p)
            }
            return exact.concat(starts, sub).slice(0, 100)
        }
        if (packageMode === "flatpak" || packageMode === "flatpakremove") {
            let fbase = packageMode === "flatpakremove" ? flatpakInstalledPackages : flatpakList
            if (q === "") return fbase.slice(0, 100)
            let fexact = [], fstarts = [], fsub = [], fname = []
            for (let i = 0; i < fbase.length; i++) {
                let p = fbase[i]
                if (!p || !p.name) continue
                let n = p.nl || ("" + p.name).toLowerCase()
                let d = p.dl || ("" + (p.displayName || "")).toLowerCase()
                if (n === q) fexact.push(p)
                else if (n.startsWith(q)) fstarts.push(p)
                else if (n.indexOf(q) !== -1) fsub.push(p)
                else if (d !== "" && d.indexOf(q) !== -1) fname.push(p)
            }
            return fexact.concat(fstarts, fsub, fname).slice(0, 100)
        }
        let base = packageMode === "remove" ? installedList.filter(p => p && p.installed && isRemovablePackage(p.name)) : installedList
        if (q === "") return base.slice(0, 100)
        let exact = [], starts = [], sub = []
        for (let i = 0; i < base.length; i++) {
            let p = base[i]
            if (!p || !p.name) continue
            let n = p.nl || ("" + p.name).toLowerCase()
            if (n === q) exact.push(p)
            else if (n.startsWith(q)) starts.push(p)
            else if (n.indexOf(q) !== -1) sub.push(p)
        }
        return exact.concat(starts, sub).slice(0, 100)
    }
    // installedList (rpmdb) backs Remove mode + installed flags everywhere.
    // availableList (DNF catalog) backs Install mode; warmed on menu open.
    function refreshPackages() { if ((!installedList || installedList.length === 0) && !installedListProc.running) installedListProc.running = true }
    function refreshPackagesForce() { if (!installedListProc.running) installedListProc.running = true }
    function openPackages(origin) {
        packageOrigin = origin
        packageMode = (origin === "Remove") ? "remove" : (origin === "FlatpakInstall" ? "flatpak" : (origin === "FlatpakRemove" ? "flatpakremove" : (origin === "GamingInstall" ? "gaming" : (origin === "BrowserInstall" ? "browser" : "install"))))
        showInstall = false; showRemove = false; showWebApp = false; showPackages = true
        clearPackageSelection(); clearSearch()
        if (packageMode === "remove") { refreshExplicit(); refreshPackagesForce() }
        else if (packageMode === "flatpak" || packageMode === "flatpakremove") refreshFlatpak()
        else if (packageMode === "gaming" || packageMode === "browser") refreshPackages()
        else { refreshAvailable(); refreshPackages() }
        packageOpActive = packageOpRunning
    }
    function installPackage(name) {
        if (!name) return
        startPackageOp(packageMode, [name])
    }
    function polkitReadyFor(m: string): bool {
        if (m === "flatpak" || m === "flatpakremove") return true
        try { return !!Theme.polkitReady } catch (e) { return false }
    }
    function noAgentMessage(): string { return "No authentication agent is active — the password dialog cannot appear. Wait a moment (the agent registers itself) and try again. If it persists: restart the shell, then run `sudo systemctl restart polkit`." }
    property bool packageOpActive: false
    property string packageOpMode: "install"
    property var packageOpPkgs: []
    property var packageOpLines: []
    property string packageOpLog: ""
    property bool packageOpRunning: false
    property bool packageOpSuccess: false
    property int packageOpExit: -1
    property bool packageOpKernelUpdated: false
    function packageOpAppend(line) {
        if (("" + (line || "")).split("\n").some(p => p.trim() === "__JHQS_KERNEL_UPDATED__")) packageOpKernelUpdated = true
        let parts = ("" + (line || "")).split("\n")
        let lines = []
        for (let i = 0; i < parts.length; i++) {
            let s = parts[i]
            if (s.trim() === "__JHQS_KERNEL_UPDATED__") continue
            if (s.charAt(s.length - 1) === "\r") s = s.slice(0, -1)
            let ci = s.lastIndexOf("\r")
            if (ci !== -1) s = s.slice(ci + 1)
            s = s.replace(/\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)/g, "")
                .replace(/\x1b\[[0-9;?]*[ -/]*[@-~]/g, "")
                .replace(/\x1b[()][0-9A-B]/g, "")
                .replace(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/g, "")
                .replace(/\s+$/, "")
            if (s.length === 0) continue
            lines.push(s)
        }
        if (lines.length === 0) return
        let l = packageOpLines.concat(lines)
        if (l.length > 60) l = l.slice(l.length - 60)
        packageOpLines = l
        packageOpLog = l.join("\n")
    }
    function startPackageOp(mode, pkgs) {
        if (packageOpRunning) return false
        if (!pkgs || pkgs.length === 0) return false
        let clean = []
        for (let i = 0; i < pkgs.length; i++) { let n = pkgs[i]; if (n && /^[A-Za-z0-9@._+\-]+$/.test(n) && clean.indexOf(n) === -1) clean.push(n) }
        if (mode === "remove") clean = clean.filter(n => !isProtectedPackage(n))
        if (clean.length === 0) return false
        let m = (mode === "remove") ? "remove" : (mode === "flatpak" ? "flatpak" : (mode === "flatpakremove" ? "flatpakremove" : (mode === "gaming" ? "gaming" : (mode === "browser" ? "browser" : "install"))))
        if (!polkitReadyFor(m)) {
            packageOpMode = m; packageOpPkgs = []
            packageOpLines = []; packageOpLog = ""; packageOpExit = -1; packageOpSuccess = false
            packageOpKernelUpdated = false
            packageOpRunning = false; packageOpActive = true
            packageOpAppend("✗ " + noAgentMessage())
            return false
        }
        packageOpMode = m; packageOpPkgs = clean.slice()
        packageOpLines = []; packageOpLog = ""; packageOpExit = -1; packageOpSuccess = false
        packageOpKernelUpdated = false
        packageOpRunning = true; packageOpActive = true
        clearPackageSelection(); clearSearch()
        // Direct argv, no shell string and no `script` pty wrapper:
        // `script` lives in util-linux-script (not installed by default),
        // so the old ["script", "-qec", ...] never spawned (exit 127) and
        // nothing installed. Plain pipes give line-based live output.
        {
            let tag = ((m === "flatpak" || m === "flatpakremove") ? " (Flatpak)" : (m === "gaming" ? " (Gaming)" : (m === "browser" ? " (Browser)" : " (DNF)")))
            packageOpAppend(((m === "remove" || m === "flatpakremove") ? "Removing " : "Installing ") + clean.length + " package(s)" + tag + ": " + clean.join(" "))
            if (m === "remove") packageOpProc.command = ["pkexec", "--disable-internal-agent", "dnf", "remove", "-y"].concat(clean)
            else if (m === "gaming" || m === "browser") packageOpProc.command = ["pkexec", "--disable-internal-agent", "dnf", "install", "-y"].concat(clean.map(n => curatedSpec(n)))
            else if (m === "flatpak") packageOpProc.command = ["flatpak", "install", "-y", "flathub"].concat(clean)
            else if (m === "flatpakremove") packageOpProc.command = ["flatpak", "uninstall", "-y"].concat(clean)
            else packageOpProc.command = ["pkexec", "--disable-internal-agent", "dnf", "install", "-y"].concat(clean)
        }
        if (!packageOpProc.running) packageOpProc.running = true
        return true
    }
    function finishPackageOp(code) {
        packageOpRunning = false; packageOpExit = code; packageOpSuccess = (code === 0)
        if (code === 0) {
            packageOpAppend("✓ Done (code 0)")
            if (packageOpMode === "install" || packageOpMode === "flatpak" || packageOpMode === "gaming" || packageOpMode === "browser") {
                let names = (packageOpPkgs || []).join(", ").slice(0, 180)
                let tag = (packageOpMode === "flatpak" ? " (Flatpak)" : (packageOpMode === "gaming" ? " (Gaming)" : (packageOpMode === "browser" ? " (Browser)" : " (DNF)")))
                if (names !== "") sendInstallNotification("✓ Installed: " + names + tag, "find it in the app launcher")
            }
        }
        else if (code === 127) { packageOpAppend("✗ Cancelled (code 127)"); packageOpAppend("Note: authentication was cancelled or no agent is available.") }
        else packageOpAppend("✗ Failed (code " + code + ")")
        if (code === 0 && packageOpKernelUpdated) {
            packageOpAppend("Kernel was updated — restart recommended")
            packageOpAppend("System → Restart (or: systemctl reboot)")
        }
        refreshPackagesForce()
        refreshAvailableForce()
        refreshFlatpakForce()
        refreshExplicit()
        try { Theme.notifyAppsChanged() } catch (e) { }
        try { UpdateService.checkNow() } catch (e) { }
    }
    function leavePackageOp() {
        packageOpActive = false
        clearSearch()
    }

    function escShellArg(path: string): string {
        return path.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"").replace(/\$/g, "\\$").replace(/`/g, "\\`")
    }
    // Display-only wallpaper switch (swaybg + current-file pointers), used by
    // setWallpaper and by design-snapshot restores. Never triggers theming.
    function setWallpaperDisplay(path) {
        if (!path || path.length === 0) return false
        if (path.includes("\n") || path.includes("\r")) return false
        let mode = wallpaperModes.indexOf(wallpaperMode) !== -1 ? wallpaperMode : "fill"
        // Path travels as argv ($1): filenames with quotes/$/`/spaces are safe.
        // Start-then-reap: the new swaybg maps first, old instances are killed
        // only after the new one proves alive — no black flash, and a broken
        // image never kills the working wallpaper. printf (not echo -n) so
        // backslashes survive. awww/current is kept for shell.qml's guard.
        let wpCmd = "WALL=\"$1\"; MODE=\"$2\";"
        wpCmd += "if command -v swaybg >/dev/null 2>&1 && [ -f \"$WALL\" ]; then nohup swaybg -i \"$WALL\" -m \"$MODE\" >/dev/null 2>&1 < /dev/null & NEW=$!; sleep 0.5;"
        wpCmd += " if kill -0 \"$NEW\" 2>/dev/null; then for p in $(pgrep -x swaybg 2>/dev/null); do [ \"$p\" = \"$NEW\" ] || kill \"$p\" 2>/dev/null || true; done;"
        wpCmd += " else echo \"[jhqs] swaybg start failed, keeping current wallpaper\" >&2; fi; "
        wpCmd += "else echo \"[jhqs] swaybg missing or wallpaper invalid — wallpaper unchanged\" >&2; fi; "
        wpCmd += "mkdir -p ~/.cache/swaybg ~/.cache/awww ~/.config/quickshell/jhqs/config 2>/dev/null; printf '%s' \"$WALL\" > ~/.cache/swaybg/current 2>/dev/null; printf '%s' \"$WALL\" > ~/.cache/awww/current 2>/dev/null; printf '%s' \"$WALL\" > ~/.config/quickshell/jhqs/config/current_wallpaper.txt 2>/dev/null"
        Quickshell.execDetached(["bash", "-c", wpCmd, "jhqs-wallpaper", path, mode])
        return true
    }
    function setWallpaper(path, preview) {
        if (!setWallpaperDisplay(path)) return
        themeEngine.rememberWallpaper(currentEngine, path)
        if (currentEngine === "wallpaper") {
            themeEngine.applyMonetFromPath(path)
        }
        if (!preview) dismissed()
    }
    function previewWallpaperTrans() {
        let list = filteredWallpapers
        if (!list || list.length === 0) return
        let i = Math.max(0, Math.min(selectedIndex, list.length - 1))
        if (list[i]) setWallpaper(list[i], true)
    }
    function refreshWallpapers() {
        if (wallpaperListProc.running) return
        let cfg = ""
        try { cfg = expandWallpaperDir(wallpaperSettingsFile.adapter.directory) } catch (e) { cfg = "" }
        let cmd = "CFG=\"" + escShellArg(cfg) + "\"; D=\"\";"
        cmd += " if [ -n \"$CFG\" ]; then D=\"$CFG\";"
        cmd += " else for c in \"$HOME/Bilder/wallpapers\" \"$HOME/Pictures/wallpapers\" \"$HOME/Wallpapers\" \"${XDG_PICTURES_DIR:-$HOME/Pictures}/wallpapers\" \"$HOME/wallpapers\"; do if [ -d \"$c\" ]; then D=\"$c\"; break; fi; done; fi;"
        cmd += " echo \"#DIR=$D\";"
        cmd += " if [ -n \"$D\" ] && [ -d \"$D\" ]; then find \"$D\" -mindepth 1 -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' -o -iname '*.tiff' \\) 2>/dev/null | sort | head -n 500; fi"
        wallpaperListProc.command = ["bash", "-c", cmd]
        wallpaperListProc.running = true
    }
    function openSystem() {
        // Idempotent deep-link: always land on a clean System list, never on
        // a stale filter/selection from a previous submenu.
        try {
            showStyle = false; showWallpaper = false; showWallpaperSettings = false
            showThemes = false; showFont = false; showInstall = false
            showRemove = false; showSetup = false; showLearn = false; showKeybinds = false; showModules = false
            showNewAppMenu = false; showPackages = false; showWebApp = false
            showSession = true
            directSystemOpen = true
        } catch (e) {
            console.log("[JhqsMenu] openSystem err", e)
            showSession = true
            directSystemOpen = true
        }
        clearSearch()
    }

    property var filteredMenu: {
        let q = qLower()
        if (showWallpaper || showThemes || showFont || showNewAppMenu || showPackages || showWebApp || showKeybinds) return []
        let active = null
        if (showStyle) active = styleMenu; else if (showInstall) active = installMenu; else if (showRemove) active = removeMenu; else if (showSession) active = sessionMenu; else if (showSetup) active = setupMenu; else if (showLearn) active = learnMenu
        if (active) return q === "" ? active : active.filter(m => matchesAll(m.title.toLowerCase(), queryWords()))
        let base = q === "" ? menuModel : menuModel.filter(m => matchesAll(m.title.toLowerCase(), queryWords()))
        if (q !== "" && base.length > 1) {
            let sysRows = base.filter(m => m.title === "System")
            if (sysRows.length > 0 && sysRows.length < base.length) return base.filter(m => m.title !== "System").concat(sysRows)
        }
        return base
    }
    property var filteredCategorySections: {
        if (isInSubmenu) return []
        let q = qLower(); if (q === "") return []
        let words = queryWords()
        let sections = []
        for (let i = 0; i < menuModel.length; i++) {
            let m = menuModel[i]
            if (!m.submenu || m.submenu.length === 0) continue
            let matched = m.submenu.filter(e => matchesAll(e.title.toLowerCase(), words))
            if (matched.length === 0 && matchesAll(m.title.toLowerCase(), words)) matched = m.submenu.slice()
            if (m.title === "Style") {
                for (let k = 0; k < moduleSubviewOptions.length; k++) {
                    let ve = moduleSubviewOptions[k]
                    if (matchesAll(moduleSubviewHaystack(ve), words)) matched = matched.concat([ve])
                }
            }
            if (matched.length > 0) sections.push({ category: m.title, options: matched })
        }
        if (sections.length > 1) {
            let sysSecs = sections.filter(s => s.category === "System")
            if (sysSecs.length > 0 && sysSecs.length < sections.length) return sections.filter(s => s.category !== "System").concat(sysSecs)
        }
        return sections
    }
    property int categoryOptionsCount: { let c = 0; for (let i = 0; i < filteredCategorySections.length; i++) c += filteredCategorySections[i].options.length; return c }
    property var flattenedCategoryOptions: {
        let out = []
        for (let i = 0; i < filteredCategorySections.length; i++) for (let j = 0; j < filteredCategorySections[i].options.length; j++) out.push({ category: filteredCategorySections[i].category, entry: filteredCategorySections[i].options[j] })
        return out
    }
    property var filteredApps: {
        if (isInSubmenu) return []
        let q = qLower(); if (q === "") return []
        let words = queryWordsFor(q)
        let multi = words.length > 1
        // _appSearchIndex is already alphabetical, so bucketing preserves
        // order with no re-sort (the old localeCompare sort over all hits
        // was the main per-keystroke cost). All comparisons use the
        // pre-lowered index fields — zero toLowerCase() per keystroke.
        let exact = [], prefix = [], sub = []
        for (let i = 0; i < _appSearchIndex.length; i++) {
            let row = _appSearchIndex[i]
            if (row.nl === q) exact.push(row.e)
            else if (row.nl.indexOf(q) === 0) prefix.push(row.e)
            else if (sub.length < 8) {
                if (multi) {
                    if (matchesAll(row.n, words) || matchesAll(row.c, words)) sub.push(row.e)
                } else if (row.n.indexOf(q) !== -1 || row.c.indexOf(q) !== -1) sub.push(row.e)
            }
            // Safe early exit: scan is alphabetical, so once 8 top-tier
            // (exact+prefix) hits are found, later rows can only be
            // lower-ranked or beyond the 8-cut.
            if (exact.length + prefix.length >= 8) break
        }
        return exact.concat(prefix, sub).slice(0, 8)
    }
    // Best-first section order for top-level search: the section containing
    // the best-matching item comes first (ties keep apps/menu/categories).
    // All inputs here are already-filtered tiny lists (<=8 apps, <=7 menus,
    // <=~30 categories), so per-keystroke cost is negligible.
    property var searchGroupOrder: {
        let q = qLower(); if (q === "") return ["apps", "menu", "cats"]
        let words = queryWordsFor(q)
        let apps = filteredApps, menus = filteredMenu, flats = flattenedCategoryOptions
        function best(items, getTitle): int {
            let b = 99
            for (let i = 0; i < items.length; i++) {
                let t = matchTier(getTitle(items[i]), getTitle(items[i]), q, words)
                if (t >= 0 && t < b) { b = t; if (b === 0) break }
            }
            return b
        }
        let s = [
            { k: "apps", s: best(apps, e => (e.name || "")), n: apps.length },
            { k: "menu", s: best(menus, m => (m.title || "")), n: menus.length },
            { k: "cats", s: best(flats, f => (f.entry.title || "")), n: flats.length }
        ]
        let rank = { apps: 0, menu: 1, cats: 2 }
        s.sort((a, b) => (a.s - b.s) || (rank[a.k] - rank[b.k]))
        let out = []
        for (let i = 0; i < s.length; i++) if (s[i].n > 0) out.push(s[i].k)
        return out
    }
    // Flat ordered search model for the list view. Submenu roots and the
    // empty query keep the single menu group; top-level search follows
    // searchGroupOrder. `section` drives ListView section headers ("" = none).
    property var searchRows: {
        let q = qLower()
        if (q === "" || showStyle || showInstall || showRemove || showSession || showSetup || showLearn || showKeybinds) {
            let items = filteredMenu
            let out = []
            for (let i = 0; i < items.length; i++) out.push({ row: "menu", section: "", entry: items[i] })
            return out
        }
        let groups = searchGroupOrder
        let out = []
        for (let g = 0; g < groups.length; g++) {
            if (groups[g] === "apps") {
                let apps = filteredApps
                for (let i = 0; i < apps.length; i++) out.push({ row: "app", section: "Anwendungen", entry: apps[i] })
            } else if (groups[g] === "menu") {
                let ms = filteredMenu
                for (let i = 0; i < ms.length; i++) out.push({ row: "menu", section: "", entry: ms[i] })
            } else {
                let secs = filteredCategorySections
                for (let i = 0; i < secs.length; i++) {
                    for (let j = 0; j < secs[i].options.length; j++) out.push({ row: "cat", section: secs[i].category, category: secs[i].category, entry: secs[i].options[j] })
                }
            }
        }
        return out
    }
    property int totalCount: showWallpaper ? filteredWallpapers.length : showThemes ? filteredThemes.length : showFont ? filteredFontGroups.length : showNewAppMenu ? filteredNewApps.length : showPackages ? filteredPackages.length : showKeybinds ? filteredKeybinds.length : searchRows.length
    property int selectedIndex: 0
    // Stability: filtering (e.g. typing inside System) shrinks the list while
    // selectedIndex keeps its old value. Clamp immediately so Enter/mouse can
    // never index out of range (previously a silent no-op / TypeError).
    onTotalCountChanged: {
        if (totalCount <= 0) {
            if (selectedIndex !== 0) selectedIndex = 0
        } else if (selectedIndex > totalCount - 1) {
            selectedIndex = totalCount - 1
        } else if (selectedIndex < 0) {
            selectedIndex = 0
        }
    }

    function runProc(p) { if (p && !p.running) p.running = true }
    function openAbout() { Quickshell.execDetached(["bash", "-c", "kitty -o initial_window_width=113c -o initial_window_height=29c --class about-fastfetch --title About bash -c 'fastfetch; sleep 0.5; read -n1 -s' &"]) }
    // Session actions must use execDetached (not Process.running) because the
    // menu Loader is destroyed on dismissed(), which would kill a freshly
    // started Process before it can exec.
    // Returns true when a known action was dispatched, false otherwise (caller
    // keeps the menu open so an unknown title can never silently close it).
    function doSessionAction(t: string): bool {
        let title = ("" + (t || "")).trim()
        if (title === "") return false
        try {
            if (title === "Lock") {
                Quickshell.execDetached(["bash", "-c", "quickshell ipc -c jhqs call lockscreen lock >/dev/null 2>&1 || loginctl lock-session >/dev/null 2>&1 || true"])
                return true
            } else if (title === "Log Out") {
                Quickshell.execDetached(["bash", "-c", "mmsg dispatch quit >/dev/null 2>&1; loginctl terminate-user \"$USER\" >/dev/null 2>&1 || true"])
                return true
            } else if (title === "Suspend") {
                Quickshell.execDetached(["bash", "-c", "systemctl suspend >/dev/null 2>&1 || loginctl suspend >/dev/null 2>&1 || true"])
                return true
            } else if (title === "Restart") {
                Quickshell.execDetached(["bash", "-c", "systemctl reboot >/dev/null 2>&1 || loginctl reboot >/dev/null 2>&1 || true"])
                return true
            } else if (title === "Shut Down") {
                Quickshell.execDetached(["bash", "-c", "systemctl poweroff >/dev/null 2>&1 || loginctl poweroff >/dev/null 2>&1 || true"])
                return true
            }
        } catch (e) {
            console.log("[JhqsMenu] doSessionAction err", title, e)
            return false
        }
        console.log("[JhqsMenu] doSessionAction unknown title", title)
        return false
    }

    function executeCategoryOption(category, entry) {
        if (!entry || !entry.title) return
        let t = entry.title
        if (category === "Install") {
            if (t === "Flatpak") { openPackages("FlatpakInstall"); return }
            else if (t === "Web App") { openWebApp("install"); return }
            else if (t === "Package") { openPackages("Install"); return }
            else if (t === "Gaming") { openPackages("GamingInstall"); return }
            else if (t === "Browser") { openPackages("BrowserInstall"); return }
            dismissed()
        } else if (category === "Remove") {
            if (t === "Flatpak") { openPackages("FlatpakRemove"); return }
            else if (t === "Web App") { openWebApp("remove"); return }
            else if (t === "Package") { openPackages("Remove"); return }
            dismissed()
        } else if (category === "System") {
            if (entry && doSessionAction(entry.title)) dismissed()
            return
        } else if (category === "Style") {
            if (t === "Wallpaper") { showStyle=false; showWallpaper=true; refreshWallpapers(); clearSearch(); return }
            if (t === "Themes") { showStyle=false; showThemes=true; clearSearch(); return }
            if (t === "Font") { showStyle=false; showFont=true; fontExpanded=""; refreshFonts(); clearSearch(); return }
            if (t === "Modules") { openModules("root"); return }
            if (entry && entry.modulesSubview) { openModules(entry.modulesSubview); return }
            dismissed()
        } else if (category === "Setup") {
            if (t === "Settings") { openSettings("global"); return }
            else if (t === "Monitors") runProc(setupMonitorsProc)
            else if (t === "Keybindings") runProc(setupBindsProc)
            else if (t === "Autostart") runProc(setupAutostartProc)
            else if (t === "Audio") runProc(setupAudioProc)
            else if (t === "Shell Update") runShellUpdate()
            dismissed()
        } else if (category === "Learn") {
            openKeybinds(t)
            return
        } else { dismissed() }
    }

    // Top-level menu rows (menuModel entries), shared by mouse, keyboard and search.
    // Only handles root titles — submenu rows must go through activateCurrent().
    function activateRootMenuRow(m): void {
        if (!m || !m.title) return
        if (m.title === "Apps") { showNewAppMenu = true; clearSearch() }
        else if (m.title === "About") { openAbout(); dismissed() }
        else if (m.title === "System") { showSession = true; directSystemOpen = false; clearSearch() }
        else if (m.title === "Install") { showInstall = true; clearSearch() }
        else if (m.title === "Remove") { showRemove = true; clearSearch() }
        else if (m.title === "Style") { showStyle = true; clearSearch(); refreshWallpapers() }
        else if (m.title === "Setup") { showSetup = true; clearSearch() }
        else if (m.title === "Learn") { showLearn = true; clearSearch() }
    }
    function launchAppEntry(e): void {
        if (e && e.execute) { e.execute(); dismissed() }
    }
    function activateCurrent() {
        if (showWallpaper) { let p = filteredWallpapers[selectedIndex]; if (p) setWallpaper(p); return }
        if (showThemes) { let t = filteredThemes[selectedIndex]; if (t) setThemeEngine(t.id); return }
        if (showFont) { let g = filteredFontGroups[selectedIndex]; if (g) setSystemFont(g.preview || g.title); return }
        if (showNewAppMenu) { let e = filteredNewApps[selectedIndex]; if (e && e.execute) { e.execute(); dismissed() } return }
        if (showPackages) {
            if (packageOpActive) { if (!packageOpRunning) dismissed(); return }
            let sel = packageSelected.length > 0 ? packageSelected.slice() : []
            if (sel.length === 0) { let p = filteredPackages[selectedIndex]; if (p && p.name) sel = [p.name] }
            if (sel.length > 0) startPackageOp(packageMode, sel)
            return
        }
        // Keybind rows are display-only (selection just highlights).
        if (showKeybinds) return
        // Submenu rows (Style/Install/Remove/System/Setup/Learn): index into the
        // filtered submenu list. Guarded so an out-of-range index (e.g. list
        // shrank while filtering) is a no-op instead of a TypeError, and an
        // unknown title never closes the menu silently.
        if (showStyle || showInstall || showRemove || showSession || showSetup || showLearn) {
            let m = filteredMenu[selectedIndex]
            if (!m || !m.title) return
            if (showStyle) {
                if (m.title === "Wallpaper") { showStyle=false; showWallpaper=true; refreshWallpapers(); clearSearch() }
                else if (m.title === "Themes") { showStyle=false; showThemes=true; clearSearch() }
                else if (m.title === "Font") { showStyle=false; showFont=true; fontExpanded=""; refreshFonts(); clearSearch() }
                else if (m.title === "Modules") { openModules("root") }
                else dismissed()
                return
            }
            if (showInstall) { if (m.title==="Flatpak") { openPackages("FlatpakInstall"); return } else if (m.title==="Web App") { openWebApp("install"); return }             else if (m.title==="Package") { openPackages("Install"); return } else if (m.title==="Gaming") { openPackages("GamingInstall"); return } else if (m.title==="Browser") { openPackages("BrowserInstall"); return } dismissed(); return }
            if (showRemove) { if (m.title==="Flatpak") { openPackages("FlatpakRemove"); return } else if (m.title==="Web App") { openWebApp("remove"); return } else if (m.title==="Package") { openPackages("Remove"); return } dismissed(); return }
            if (showSession) { if (doSessionAction(m.title)) dismissed(); return }
            if (showSetup) {
                if (m.title==="Settings") { openSettings("global"); return }
                else if (m.title==="Monitors") runProc(setupMonitorsProc)
                else if (m.title==="Keybindings") runProc(setupBindsProc)
                else if (m.title==="Autostart") runProc(setupAutostartProc)
                else if (m.title==="Audio") runProc(setupAudioProc)
                else if (m.title==="Shell Update") runShellUpdate()
                dismissed(); return
            }
            if (showLearn) { openKeybinds(m.title); return }
        }
        if (totalCount === 0) return
        let q = qLower()
        let inSub = showStyle || showInstall || showRemove || showSession || showSetup || showLearn || showKeybinds
        if (q !== "" && !inSub) {
            let r = searchRows[selectedIndex]
            if (!r) return
            if (r.row === "app") { launchAppEntry(r.entry); return }
            if (r.row === "menu") { activateRootMenuRow(r.entry); return }
            if (r.row === "cat") { if (r.entry) executeCategoryOption(r.category, r.entry); return }
            return
        }
        if (selectedIndex < filteredApps.length) {
            launchAppEntry(filteredApps[selectedIndex])
        } else if (selectedIndex < filteredApps.length + filteredMenu.length) {
            activateRootMenuRow(filteredMenu[selectedIndex - filteredApps.length])
        } else if (selectedIndex < filteredApps.length + filteredMenu.length + categoryOptionsCount) {
            let flat = flattenedCategoryOptions[selectedIndex - filteredApps.length - filteredMenu.length]
            if (flat) executeCategoryOption(flat.category, flat.entry)
        } else {
            return
        }
    }

    Item {
        id: bodyRoot
        Component.onCompleted: jhqsMenuScope.bodyRootRef = bodyRoot
        Component.onDestruction: if (jhqsMenuScope.bodyRootRef === bodyRoot) jhqsMenuScope.bodyRootRef = null
        implicitWidth: Theme.sharedMenuWidth
        implicitHeight: Theme.sharedMenuHeight
        property var scope: jhqsMenuScope
        property alias filterText: jhqsMenuScope.filterText
        property alias filteredMenu: jhqsMenuScope.filteredMenu
        property alias filteredApps: jhqsMenuScope.filteredApps
        property alias filteredCategorySections: jhqsMenuScope.filteredCategorySections
        property alias categoryOptionsCount: jhqsMenuScope.categoryOptionsCount
        property alias flattenedCategoryOptions: jhqsMenuScope.flattenedCategoryOptions
        property alias totalCount: jhqsMenuScope.totalCount
        property alias selectedIndex: jhqsMenuScope.selectedIndex
        property var menuModel: jhqsMenuScope.menuModel
        property color bg: Theme.bg
        property color surface: Theme.panelSurface
        property color surface2: Theme.surface2
        property color bgHover: Theme.bgHover
        property color bgSelected: Theme.bgSelected
        property color borderColor: Theme.borderColor
        property color textPrimary: Theme.textPrimary
        property color textSecondary: Theme.textSecondary
        property color textMuted: Theme.textMuted
        property color iconColor: Theme.iconColor
        property color iconBg: Theme.iconBg
        property color iconBgSelected: Theme.iconBgSelected
        property color iconColorSelected: Theme.iconColorSelected
        property color onAccent: Theme.onAccent
        property color accent: Theme.accent
        property color divider: Theme.divider
        function activateCurrent(){ jhqsMenuScope.activateCurrent() }
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: jhqsMenuScope._winVisible && Theme.isPrimaryScreen(modelData)
            color: "transparent"; exclusiveZone: 0
            anchors { top: true; left: true; right: true; bottom: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "menu"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            MouseArea { anchors.fill: parent; onClicked: jhqsMenuScope.dismissed() }
            Loader {
                id: menuLoader
                active: true
                BarAnchor {
                    id: menuAnchor
                    moduleId: "launcher"
                    barPos: jhqsMenuScope.shellPosition
                    panelWidth: menuLoader.width
                    panelHeight: menuLoader.height
                    screenWidth: menuLoader.parent.width
                    screenHeight: menuLoader.parent.height
                    gap: jhqsMenuScope.panelGap
                    fallbackX: (menuLoader.parent.width - menuLoader.width) / 2
                    fallbackY: (menuLoader.parent.height - menuLoader.height) / 2
                }
                x: jhqsMenuScope.centered ? (parent.width - width) / 2 : menuAnchor.panelX
                y: jhqsMenuScope.centered ? (parent.height - height) / 2 : menuAnchor.panelY
                PanelSpring {
                    id: menuSpring
                    slideFade: true
                    shown: jhqsMenuScope.showMenu
                    hiddenX: jhqsMenuScope.shellPosition === "left" ? -(menuLoader.width + 5) : jhqsMenuScope.shellPosition === "right" ? (menuLoader.width + 5) : 0
                    hiddenY: jhqsMenuScope.shellPosition === "top" ? -(menuLoader.height + 5) : jhqsMenuScope.shellPosition === "bottom" ? (menuLoader.height + 5) : 0
                }
                visible: menuSpring.boxVisible
                opacity: menuSpring.fade
                scale: menuSpring.zoom
                transformOrigin: jhqsMenuScope.centered ? Item.Center : menuAnchor.origin
                transform: Translate { x: menuSpring.slideX; y: menuSpring.slideY }
                width: item ? item.implicitWidth : implicitWidth
                height: item ? item.implicitHeight : implicitHeight
                sourceComponent: Item {
                    property int catDynH: {
                        let rowH = 50
                        let rowGap = 3
                        let n = jhqsMenuScope.menuModel ? jhqsMenuScope.menuModel.length : 8
                        if (n < 1) n = 1
                        let content = n * rowH + Math.max(0, n - 1) * rowGap
                        let overhead = (18 + 34 + 7 + 18)
                        return overhead + content + 2
                    }
                    implicitWidth: jhqsMenuScope.showWallpaper ? 760 : (jhqsMenuScope.showPackages || jhqsMenuScope.showWebApp || jhqsMenuScope.showKeybinds) ? Theme.sharedMenuWidth : 300
                    implicitHeight: jhqsMenuScope.showWallpaper ? 820 : (jhqsMenuScope.showPackages || jhqsMenuScope.showWebApp || jhqsMenuScope.showKeybinds) ? Theme.sharedMenuHeight : catDynH
                    // PERF: layout Behaviors ran on every view switch even with
                    // animations off or menu hidden. Gate them.
                    Behavior on implicitWidth { enabled: Theme.animationsEnabled && jhqsMenuScope.showMenu; NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
                    Behavior on implicitHeight { enabled: Theme.animationsEnabled && jhqsMenuScope.showMenu; NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        id: panel
                        anchors.fill: parent
                        radius: Theme.cornerRadius; color: Theme.bg; border.color: Theme.panelBorderColor; border.width: 1; clip: true
                        Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }
                    }
                    Item {
                        id: menuBody
                        anchors.fill: parent
                        focus: true
                        function goBack() {
                            if (bodyRoot.scope.showWallpaperSettings) { bodyRoot.scope.showWallpaperSettings = false; bodyRoot.scope.clearSearch(); return }
                            if (bodyRoot.scope.showFont && bodyRoot.scope.fontExpanded !== "") { bodyRoot.scope.fontExpanded = ""; return }
                            if (bodyRoot.scope.showThemes && themesView && themesView.showMonetSettings) { themesView.showMonetSettings = false; themesView.selectedIndex = themesView.navIndex("preset-wallpaper"); return }
                            if (bodyRoot.scope.showModules && modulesView) { modulesView.goBack(); return }
                            if (bodyRoot.scope.showNewAppMenu && appMenu && appMenu.contextMenuVisible) { appMenu.hideContextMenu(); return }
                            if (!bodyRoot.scope.handleEsc()) bodyRoot.scope.dismissed()
                        }
                        Keys.onPressed: event => {
                            if (jhqsMenuScope.showModules && modulesView && modulesView.handleKey(event)) { event.accepted = true; return }
                            if (jhqsMenuScope.showThemes && themesView && themesView.handleKey(event)) { event.accepted = true; return }
                            if (jhqsMenuScope.showFont && fontView && fontView.handleKey(event)) { event.accepted = true; return }
                            if (jhqsMenuScope.showPackages && !jhqsMenuScope.packageOpActive && packageView && packageView.handleKey(event)) { event.accepted = true; return }
                            if (jhqsMenuScope.showKeybinds && keybindsView && keybindsView.handleKey(event)) { event.accepted = true; return }
                            if (jhqsMenuScope.showWebApp && webAppView && webAppView.handleKey(event)) { event.accepted = true; return }
                            let n=bodyRoot.totalCount
                            if((event.modifiers & Qt.MetaModifier) && event.key===Qt.Key_M){ if(event.modifiers & Qt.ShiftModifier) { bodyRoot.scope.showNewAppMenu=true; bodyRoot.scope.clearSearch() } else bodyRoot.scope.dismissed(); event.accepted=true }
                            else if((event.modifiers & Qt.MetaModifier) && event.key===Qt.Key_Escape){ bodyRoot.scope.dismissed(); event.accepted=true }
                            else if(event.key===Qt.Key_Down){ if(n>0){ bodyRoot.selectedIndex = bodyRoot.scope.showWallpaper ? Math.min(bodyRoot.selectedIndex+3, n-1) : (bodyRoot.selectedIndex+1)%n } event.accepted=true }
                            else if(event.key===Qt.Key_Up){ if(n>0){ bodyRoot.selectedIndex = bodyRoot.scope.showWallpaper ? Math.max(bodyRoot.selectedIndex-3, 0) : (bodyRoot.selectedIndex-1+n)%n } event.accepted=true }
                            else if(event.key===Qt.Key_Right){ if(bodyRoot.scope.showWallpaper && n>0){ bodyRoot.selectedIndex=Math.min(bodyRoot.selectedIndex+1, n-1); event.accepted=true } }
                            else if(event.key===Qt.Key_Left){ if(bodyRoot.scope.showWallpaper && n>0){ bodyRoot.selectedIndex=Math.max(bodyRoot.selectedIndex-1, 0); event.accepted=true } }
                            else if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter){ bodyRoot.activateCurrent(); event.accepted=true }
                            else if(event.key===Qt.Key_Escape){ if(!bodyRoot.scope.handleEsc()) bodyRoot.scope.dismissed(); event.accepted=true }
                        }
                        Component.onCompleted: { bodyRoot.scope.queryInputRef = queryInput; forceActiveFocus(); if(queryInput) queryInput.forceActiveFocus() }
                        Connections { target: bodyRoot.scope; function onShowMenuChanged(){ if(bodyRoot.scope.showMenu){ bodyRoot.scope.resetAllSubmenus(); bodyRoot.scope.clearSearch(); if(!bodyRoot.scope.wallpaperFiles || bodyRoot.scope.wallpaperFiles.length===0) bodyRoot.scope.refreshWallpapers(); if(!bodyRoot.scope.installedList || bodyRoot.scope.installedList.length===0) bodyRoot.scope.refreshPackages(); if(!bodyRoot.scope.availableList || bodyRoot.scope.availableList.length===0) bodyRoot.scope.refreshAvailable(); if(!bodyRoot.scope.fontFallbackFamilies || bodyRoot.scope.fontFallbackFamilies.length===0) bodyRoot.scope.refreshFonts(); if(!bodyRoot.scope.keybindList || bodyRoot.scope.keybindList.length===0) bodyRoot.scope.refreshKeybinds(); Qt.callLater(()=>{ parent.forceActiveFocus(); if(queryInput) queryInput.forceActiveFocus() }) } } }

                        Item {
                            id: searchRow
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.topMargin: 18; anchors.leftMargin: 18; anchors.rightMargin: 18
                            height: 34
                            Rectangle {
                                antialiasing: Theme.shapesAa
                                id: backBtn
                                property bool shown: bodyRoot.scope.canGoBack
                                visible: opacity > 0.01
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                width: shown ? 36 : 0
                                Behavior on width { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
                                height: 36
                                clip: true
                                opacity: shown ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                                scale: shown ? 1 : 0.7
                                transformOrigin: Item.Left
                                Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
                                radius: Theme.cornerRadiusSmall
                                color: "transparent"
                                border.color: "transparent"; border.width: 0
                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingSmooth } }
                                Text { anchors.centerIn: parent; anchors.verticalCenterOffset: -1; width: 36; height: 24; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: "‹"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16); color: backBtnMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                                MouseArea { id: backBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: menuBody.goBack() }
                            }
                            Rectangle {
                                antialiasing: Theme.shapesAa
                            id: searchBox
                            anchors.left: backBtn.right; anchors.right: parent.right
                            anchors.top: parent.top; anchors.bottom: parent.bottom
                            anchors.leftMargin: 8 * (backBtn.width / 36)
                            radius: 0
                            color: "transparent"
                            border.color: "transparent"
                            border.width: 0
                            Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 0; anchors.rightMargin: 0; spacing: 8
                                TextInput {
                                    id: queryInput
                                    Layout.fillWidth: true
                                    text: bodyRoot.filterText
                                    color: Theme.textPrimary
                                    opacity: (text.length > 0 ? 1.0 : 0.0)
                                    font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16)
                                    clip: true; focus: true; activeFocusOnTab: true; selectByMouse: true
                                    selectionColor: Theme.accent
                                    onTextChanged: {
                                        if (bodyRoot.scope.showPackages && !bodyRoot.scope.packageOpActive && text.indexOf(" ") !== -1) {
                                            text = text.replace(/ /g, "")
                                            return
                                        }
                                        bodyRoot.scope.filterText = text
                                    }
                                    Keys.onPressed: event => {
                                        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Up || event.key === Qt.Key_Down
                                            || event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                            || event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                                            event.accepted = false
                                        } else if (bodyRoot.scope.showPackages && !bodyRoot.scope.packageOpActive
                                            && event.key === Qt.Key_Space && event.modifiers === Qt.NoModifier
                                            && !event.isAutoRepeat) {
                                            if (packageView) packageView.toggleCurrent()
                                            event.accepted = true
                                        }
                                    }
                                }
                                Text {
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                    visible: bodyRoot.filterText.length > 0
                                    text: "󰅖"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12)
                                    color: clearMouse.containsMouse ? Theme.textPrimary : Theme.textMuted
                                    MouseArea { id: clearMouse; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bodyRoot.scope.clearSearch() }
                                }
                                Rectangle {
                                    antialiasing: Theme.shapesAa
                                    visible: bodyRoot.scope.showWallpaper
                                    Layout.preferredWidth: 26; Layout.preferredHeight: 26
                                    radius: Theme.cornerRadiusSmall
                                    color: bodyRoot.scope.showWallpaperSettings ? Theme.bgSelected : (gearMouse.containsMouse ? Theme.bgSelected : Theme.iconBg)
                                    border.color: bodyRoot.scope.showWallpaperSettings ? Theme.accent : "transparent"; border.width: bodyRoot.scope.showWallpaperSettings ? 1 : 0
                                    Text { anchors.centerIn: parent; text: "󰒓"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13); color: (bodyRoot.scope.showWallpaperSettings || gearMouse.containsMouse) ? Theme.textPrimary : Theme.textSecondary
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                    MouseArea { id: gearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { bodyRoot.scope.showWallpaperSettings = !bodyRoot.scope.showWallpaperSettings; bodyRoot.scope.clearSearch() } }
                                }
                            }
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                anchors.left: parent.left; anchors.leftMargin: 0; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                text: (bodyRoot.scope.isInSubmenu ? (bodyRoot.scope.showNewAppMenu ? "Search apps…" : bodyRoot.scope.showWallpaper ? "Wallpaper…" : bodyRoot.scope.showThemes ? "Themes…" : bodyRoot.scope.showFont ? "Search fonts…" : bodyRoot.scope.showModules ? "Modules…" : bodyRoot.scope.showStyle ? "Style…" : bodyRoot.scope.showSetup ? "Setup…" : bodyRoot.scope.showLearn ? "Learn…" : bodyRoot.scope.showKeybinds ? "Keybinds…" : bodyRoot.scope.showInstall ? "Install…" : bodyRoot.scope.showRemove ? "Remove…" : bodyRoot.scope.showSession ? "System…" : bodyRoot.scope.showWebApp ? (bodyRoot.scope.webAppMode === "remove" ? "Filter Web Apps…" : "Install Web App…") : bodyRoot.scope.showPackages ? "Packages…" : "Go…") : "Go…")
                                color: Theme.textPrimary; opacity: 0.58; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16)
                                elide: Text.ElideRight
                                visible: bodyRoot.filterText.length === 0
                            }
                            }
                        }

                    Item {
                        id: headerDivider
                        anchors.top: searchRow.bottom; anchors.left: parent.left; anchors.right: parent.right
                        anchors.leftMargin: 18; anchors.rightMargin: 18
                        height: 7
                        Rectangle {
                            anchors.left: parent.left; anchors.right: parent.right
                            y: 3; height: 1
                            color: bodyRoot.filterText.length > 0 ? Theme.accent : Theme.divider; opacity: 0.5
                        }
                    }

                    Item {
                        id: contentStage
                        anchors.top: headerDivider.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                        anchors.topMargin: 0; anchors.leftMargin: 18; anchors.rightMargin: 18; anchors.bottomMargin: 18
                        property bool isListView: !bodyRoot.scope.showWallpaper && !bodyRoot.scope.showThemes && !bodyRoot.scope.showFont && !bodyRoot.scope.showModules && !bodyRoot.scope.showNewAppMenu && !bodyRoot.scope.showPackages && !bodyRoot.scope.showWebApp && !bodyRoot.scope.showKeybinds

                            Views.RootListView {
                                scope: jhqsMenuScope
                                bodyRoot: bodyRoot
                                isListView: contentStage.isListView
                            }
                            Views.WallpaperView {
                                scope: jhqsMenuScope
                                bodyRoot: bodyRoot
                            }
                            Views.ThemesView {
                                id: themesView
                                scope: jhqsMenuScope
                                bodyRoot: bodyRoot
                            }
                            Views.FontView {
                                id: fontView
                                scope: jhqsMenuScope
                                bodyRoot: bodyRoot
                            }
                            Views.ModulesView {
                                id: modulesView
                                scope: jhqsMenuScope
                                bodyRoot: bodyRoot
                            }
                            Views.AppMenu {
                                id: appMenu
                                scope: jhqsMenuScope
                                bodyRoot: bodyRoot
                            }
                            Views.PackageView {
                                id: packageView
                                scope: jhqsMenuScope
                                bodyRoot: bodyRoot
                            }
                            Views.WebAppView {
                                id: webAppView
                                scope: jhqsMenuScope
                                bodyRoot: bodyRoot
                            }
                            Views.KeybindsView {
                                id: keybindsView
                                scope: jhqsMenuScope
                                bodyRoot: bodyRoot
                            }
                            Views.PackageOpView {
                                scope: jhqsMenuScope
                                bodyRoot: bodyRoot
                            }
                    }
                    }
                }
            }
        }
    }
}
