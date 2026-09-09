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
import "./jhqsmenu/categories" as Cats

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

    Process { id: sessionLockProc; command: ["bash", "-c", "quickshell ipc -c jhqs call lockscreen lock >/dev/null 2>&1 &"] }
    Process { id: sessionLogoutProc; command: ["hyprctl", "dispatch", "exit"] }
    Process { id: sessionSuspendProc; command: ["systemctl", "suspend"] }
    Process { id: sessionRebootProc; command: ["systemctl", "reboot"] }
    Process { id: sessionPoweroffProc; command: ["systemctl", "poweroff"] }
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
    Process { id: setupMonitorsProc; command: ["bash", "-c", "codium ~/.config/hypr/configs/monitors.lua 2>/dev/null || kitty --class setup-monitors --title \"Monitors\" bash -c 'nvim ~/.config/hypr/configs/monitors.lua; echo; echo \"--- Fertig ---\"; read -n1 -s' &"] }
    Process { id: setupBindsProc; command: ["bash", "-c", "codium ~/.config/hypr/configs/binds 2>/dev/null || kitty --class setup-binds --title \"Keybindings\" bash -c 'nvim ~/.config/hypr/configs/binds/system.lua; echo; echo \"--- Fertig ---\"; read -n1 -s' &"] }
    Process { id: setupAutostartProc; command: ["bash", "-c", "codium ~/.config/hypr/configs/autostart.lua 2>/dev/null || kitty --class setup-autostart --title \"Autostart\" bash -c 'nvim ~/.config/hypr/configs/autostart.lua; echo; echo \"--- Fertig ---\"; read -n1 -s' &"] }
    Process { id: setupKittyProc; command: ["bash", "-c", "codium ~/.config/kitty/kitty.conf 2>/dev/null || kitty --class setup-kitty --title \"Kitty Config\" bash -c 'nvim ~/.config/kitty/kitty.conf; echo; echo \"--- Fertig ---\"; read -n1 -s' &"] }
    Process { id: setupFishProc; command: ["bash", "-c", "kitty --class setup-fish --title \"Fish Config\" bash -c 'nvim ~/.config/fish/config.fish; echo; echo \"--- Fertig ---\"; read -n1 -s' &"] }
    Process { id: setupAppearanceProc; command: ["bash", "-c", "nwg-look 2>/dev/null || codium ~/.config/gtk-3.0/settings.ini 2>/dev/null || kitty --class setup-gtk --title \"GTK Appearance\" bash -c 'echo \"nwg-look nicht gefunden\"; echo \"GTK Settings: ~/.config/gtk-3.0/settings.ini\"; cat ~/.config/gtk-3.0/settings.ini 2>/dev/null; read -n1 -s' &"] }
    Process { id: setupAudioProc; command: ["bash", "-c", "pavucontrol 2>/dev/null || kitty --class setup-audio --title Audio bash -c 'wpctl status 2>/dev/null || pactl info; read -n1 -s' &"] }
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
            }
        }
    }
    property var fontFallbackFamilies: []
    Process {
        id: fontListProc
        command: ["bash", "-c", "fc-list : family 2>/dev/null | tr ',' '\\n' | sed 's/^ *//;s/ *$//' | grep -v '^$' | sort -u | head -n 800"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                if (out.length === 0) return
                jhqsMenuScope.fontFallbackFamilies = out.split("\n").map(s => s.trim()).filter(s => s.length > 0)
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
    function refreshFonts() { if (!fontListProc.running) fontListProc.running = true }
    function toggleFontExpanded(family) {
        if (fontExpanded === family) { fontExpanded = ""; return }
        fontExpanded = family
        if (!fontStylesCache[family] && fontStylesLoading !== family && !fontStyleProc.running) {
            fontStylesLoading = family
            fontStyleProc.command = ["bash", "-c", "fc-list \"" + escShellArg(family) + "\" : style 2>/dev/null | tr ',' '\\n' | sed 's/^ *//;s/ *$//' | grep -v '^$' | sort -u"]
            fontStyleProc.running = true
        }
    }
    function setSystemFont(family) {
        if (!family || ("" + family).trim().length === 0) return
        try { Theme.setSystemFont(("" + family).trim()) } catch(e) { console.log("[JhqsMenu] setSystemFont err", e) }
    }
    Process {
        id: packageListProc
        command: ["bash", "-c", "pacman -Sl 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                if (out.length === 0) return
                let lines = out.split("\n")
                let arr = []
                let seen = { }
                for (let i = 0; i < lines.length; i++) {
                    let ln = lines[i].trim()
                    if (ln.length === 0) continue
                    let p = ln.split(/\s+/)
                    if (p.length < 3) continue
                    if (!/^[a-z0-9@._+\-]+$/.test(p[1])) continue
                    let inst = /\[(installed|installiert)/i.test(ln)
                    if (seen[p[1]] !== undefined) { if (inst) arr[seen[p[1]]].installed = true; continue }
                    seen[p[1]] = arr.length
                    arr.push({ repo: p[0], name: p[1], version: p[2], installed: inst })
                }
                arr.sort((a, b) => a.name < b.name ? -1 : (a.name > b.name ? 1 : 0))
                jhqsMenuScope.packageList = arr
            }
        }
    }
    property var explicitPackageSet: ({ })
    property bool explicitPackagesLoaded: false
    Process {
        id: explicitListProc
        command: ["bash", "-c", "pacman -Qqe 2>/dev/null"]
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
        "base", "base-devel",
        "linux", "linux-lts", "linux-zen", "linux-hardened",
        "linux-headers", "linux-lts-headers", "linux-zen-headers",
        "linux-firmware", "intel-ucode", "amd-ucode", "sof-firmware",
        "mkinitcpio", "dracut", "booster",
        "limine", "grub", "efibootmgr", "sbctl",
        "systemd", "systemd-libs", "systemd-sysvcompat",
        "filesystem", "glibc", "lib32-glibc", "bash", "fish", "dbus",
        "pacman", "pacman-contrib", "sudo",
        "polkit", "polkit-kde-agent",
        "hyprland", "quickshell", "uwsm", "sddm",
        "xdg-desktop-portal-hyprland", "qt5-wayland", "qt6-wayland",
        "mesa", "lib32-mesa", "nvidia-open", "nvidia-utils", "libva-nvidia-driver",
        "networkmanager",
        "pipewire", "pipewire-alsa", "pipewire-pulse", "pipewire-jack", "wireplumber", "libpulse", "gst-plugin-pipewire"
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
    property var aurPackages: []
    property bool aurSearching: false
    property string aurSearchPending: ""
    property string aurSearchRunning: ""
    property var aurCache: ({ })
    Process {
        id: aurSearchProc
        command: ["bash", "-c", "echo"]
        stdout: StdioCollector {
            onStreamFinished: jhqsMenuScope.finishAurSearch(text || "")
        }
    }
    Timer {
        id: aurSearchDebounce
        interval: 250; repeat: false
        onTriggered: jhqsMenuScope.runAurSearch()
    }
    property var aurFeatured: ["anydesk-bin", "balena-etcher", "bottles", "brave-bin", "docker-desktop", "dropbox", "github-desktop-bin", "google-chrome", "heroic-games-launcher-bin", "onlyoffice-bin", "pamac-aur", "paru-bin", "postman-bin", "rustdesk-bin", "slack-desktop", "spotify", "teamviewer", "thorium-browser-bin", "visual-studio-code-bin", "wps-office", "yay", "zoom"]
    property var aurFeaturedPackages: []
    property bool aurFeaturedLoading: false
    Process {
        id: aurFeaturedProc
        command: ["bash", "-c", "echo"]
        stdout: StdioCollector {
            onStreamFinished: jhqsMenuScope.finishAurFeatured(text || "")
        }
    }
    function refreshFeatured() {
        if (aurFeaturedPackages.length > 0 || aurFeaturedProc.running) return
        aurFeaturedProc.command = ["bash", "-c", "paru -Si " + aurFeatured.map(n => "aur/" + n).join(" ") + " 2>/dev/null || true"]
        aurFeaturedLoading = true
        aurFeaturedProc.running = true
    }
    function finishAurFeatured(out) {
        aurFeaturedLoading = false
        let arr = []
        let t = (out || "").trim()
        if (t.length > 0) {
            let curName = "", curVer = ""
            let lines = t.split("\n")
            for (let i = 0; i < lines.length; i++) {
                let ln = lines[i].trim()
                if (ln === "") {
                    if (curName !== "" && curVer !== "") arr.push({ repo: "aur", name: curName, version: curVer, installed: false })
                    curName = ""; curVer = ""
                    continue
                }
                let nm = ln.match(/^Name\s*:\s*(.+)$/)
                if (nm) { curName = nm[1].trim(); continue }
                let vs = ln.match(/^Version\s*:\s*(.+)$/)
                if (vs) curVer = vs[1].trim()
            }
            if (curName !== "" && curVer !== "") arr.push({ repo: "aur", name: curName, version: curVer, installed: false })
        }
        arr.sort((a, b) => a.name < b.name ? -1 : (a.name > b.name ? 1 : 0))
        aurFeaturedPackages = arr
        if (showPackages && packageMode === "aur" && qLower() === "") {
            selectedIndex = 0
            try { if (bodyRootRef) bodyRootRef.selectedIndex = 0 } catch(e) { }
        }
    }
    function scheduleAurSearch() {
        if (!(showPackages && packageMode === "aur" && !packageOpActive)) return
        let q = qLower()
        if (q === "") {
            aurPackages = []; aurSearching = false; aurSearchPending = ""; aurSearchRunning = ""
            selectedIndex = 0
            try { if (bodyRootRef) bodyRootRef.selectedIndex = 0 } catch(e) { }
            return
        }
        aurSearchPending = q
        aurSearchDebounce.restart()
    }
    function applyAurResults(q, arr) {
        aurPackages = (arr || []).slice(0, 100)
        selectedIndex = 0
        try { if (bodyRootRef) bodyRootRef.selectedIndex = 0 } catch(e) { }
    }
    function runAurSearch() {
        let q = aurSearchPending
        if (q === "" || !showPackages || packageMode !== "aur" || packageOpActive) return
        if (aurCache[q] !== undefined) { applyAurResults(q, aurCache[q]); return }
        if (aurSearchProc.running) {
            try { aurSearchProc.running = false } catch(e) { }
            aurSearchRunning = ""
            if (aurSearchProc.running) return
        }
        aurSearchRunning = q
        aurSearching = true
        aurSearchProc.command = ["paru", "-Ss", "--aur", "--limit", "100", q]
        aurSearchProc.running = true
    }
    function finishAurSearch(out) {
        let q = aurSearchRunning
        aurSearchRunning = ""
        aurSearching = false
        let t = (out || "").trim()
        let arr = []
        if (t.length > 0) {
            let lines = t.split("\n")
            for (let i = 0; i < lines.length && arr.length < 100; i++) {
                let ln = lines[i].trim()
                if (ln.length === 0 || ln.indexOf(" ") === -1) continue
                let p = ln.split(/\s+/)
                if (p[0].indexOf("/") === -1 || p.length < 2) continue
                let nm = p[0].slice(p[0].lastIndexOf("/") + 1)
                if (!/^[a-z0-9@._+\-]+$/.test(nm)) continue
                arr.push({ repo: "aur", name: nm, version: p[1], installed: /\[install/i.test(ln) })
            }
        }
        arr.sort((a, b) => { if ((a.name === q) !== (b.name === q)) return a.name === q ? -1 : 1; return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0) })
        if (q !== "") {
            aurCache[q] = arr
            let ckeys = Object.keys(aurCache)
            if (ckeys.length > 30) delete aurCache[ckeys[0]]
        }
        if (q !== "" && q === aurSearchPending && showPackages && packageMode === "aur" && !packageOpActive) {
            applyAurResults(q, arr)
        }
        if (aurSearchPending !== "" && aurSearchPending !== q && showPackages && packageMode === "aur" && !packageOpActive) {
            runAurSearch()
        }
    }
    property var aurInstalledPackages: []
    Process {
        id: foreignListProc
        command: ["bash", "-c", "pacman -Qm 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                let arr = []
                if (out.length > 0) {
                    let lines = out.split("\n")
                    for (let i = 0; i < lines.length; i++) {
                        let ln = lines[i].trim()
                        if (ln.length === 0) continue
                        let p = ln.split(/\s+/)
                        if (p.length < 2) continue
                        if (!/^[a-z0-9@._+\-]+$/.test(p[0])) continue
                        arr.push({ repo: "aur", name: p[0], version: p[1], installed: true })
                    }
                }
                arr.sort((a, b) => a.name < b.name ? -1 : (a.name > b.name ? 1 : 0))
                jhqsMenuScope.aurInstalledPackages = arr
            }
        }
    }
    function refreshForeign() { if (!foreignListProc.running) foreignListProc.running = true }
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
                    arr.push({ repo: "flathub", name: appId, version: ver, displayName: disp, installed: false })
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
                        arr.push({ repo: "flathub", name: appId, version: ver, displayName: disp, installed: true })
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
                        next.push(e.installed === inst ? e : { repo: e.repo, name: e.name, version: e.version, displayName: e.displayName || "", installed: inst })
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
        if (n.length === 0) { webAppStatus = "Name fehlt"; webAppSuccess = false; return false }
        if (n.indexOf("/") !== -1) { webAppStatus = "Name darf kein '/' enthalten"; webAppSuccess = false; return false }
        if (u.length === 0) { webAppStatus = "URL fehlt"; webAppSuccess = false; return false }
        if (!/^[a-zA-Z][a-zA-Z0-9+.\-]*:/.test(u)) u = "https://" + u
        webAppBusy = true; webAppSuccess = false; webAppStatus = "Installiere '" + n + "'…"; webAppLog = ""
        webAppLastName = n
        webAppOpAppend("Installiere '" + n + "' (" + u + ")…")
        webAppOpProc.command = [webAppBin("install"), n, u, icon]
        if (!webAppOpProc.running) webAppOpProc.running = true
        return true
    }
    function removeWebApp(name) {
        let n = ("" + (name || "")).trim()
        if (webAppBusy) return false
        if (n.length === 0) { webAppStatus = "Keine Auswahl"; webAppSuccess = false; return false }
        webAppBusy = true; webAppSuccess = false; webAppStatus = "Entferne '" + n + "'…"
        webAppLastName = n
        webAppOpAppend("Entferne '" + n + "'…")
        webAppOpProc.command = [webAppBin("remove"), n]
        if (!webAppOpProc.running) webAppOpProc.running = true
        return true
    }
    function finishWebAppOp(code) {
        webAppBusy = false; webAppSuccess = (code === 0)
        if (code === 0) {
            webAppOpAppend("✓ Fertig (Code 0)")
            webAppStatus = webAppMode === "remove" ? "✓ Entfernt" : "✓ Installiert — findest du im App-Launcher"
            if (webAppMode !== "remove") {
                let label = webAppLastName !== "" ? " '" + webAppLastName + "'" : ""
                sendInstallNotification("✓ Web App installiert" + label, "findest du im App-Launcher")
            }
        } else if (code === 127) {
            webAppOpAppend("✗ Installations-Skript nicht gefunden (Code 127)")
            webAppStatus = "✗ Skript fehlt: scripts/webapp-install.sh prüfen"
        } else {
            webAppOpAppend("✗ Fehlgeschlagen (Code " + code + ")")
            if (webAppStatus === "" || webAppStatus.endsWith("…")) webAppStatus = "✗ Fehlgeschlagen (Code " + code + ")"
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
    property string _pendingMonetPath: ""
    Timer {
        id: monetDelayTimer
        interval: 1500; repeat: false
        onTriggered: {
            if (jhqsMenuScope._pendingMonetPath !== "") {
                let p = jhqsMenuScope._pendingMonetPath
                jhqsMenuScope._pendingMonetPath = ""
                themeEngine.applyMonetFromPath(p)
            }
        }
    }
    readonly property string currentEngine: themeEngine.currentEngine
    readonly property bool themeBusy: themeEngine.themeBusy
    readonly property var matugenTypes: themeEngine.matugenTypes
    readonly property var matugenTypeLabels: themeEngine.matugenTypeLabels
    readonly property string monetType: themeEngine.monetType
    readonly property string monetMode: themeEngine.monetMode
    function applyMonetScheme(type, mode) { themeEngine.applyMonetScheme(type, mode) }
    function setThemeEngine(id) { themeEngine.setThemeEngine(id) }

    function syncQueryInput(txt) {
        try { if (queryInputRef) queryInputRef.text = txt } catch(e) { }
        try { if (bodyRootRef) bodyRootRef.filterText = txt } catch(e) { }
    }
    function qLower(): string { return filterText.toLowerCase().trim() }
    function isSearchableCategory(title: string): bool {
        let t = (title || "").toLowerCase()
        if (t === "apps") return Theme.searchAppsEnabled
        if (t === "style") return Theme.searchStyleEnabled
        if (t === "setup") return Theme.searchSetupEnabled
        if (t === "install") return Theme.searchInstallEnabled
        if (t === "remove") return Theme.searchRemoveEnabled
        if (t === "about") return Theme.searchAboutEnabled
        if (t === "system") return Theme.searchSystemEnabled
        return true
    }
    function clearSearch() {
        filterText = ""; selectedIndex = 0; syncQueryInput("")
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
            if (e.title.toLowerCase() === q && (e.submenu || e.title === "Apps") && isSearchableCategory(e.title)) { m = e; break }
        }
        if (!m) return
        if (m.title === "Apps") { showNewAppMenu = true; clearSearch() }
        else if (m.title === "Style") { showStyle = true; clearSearch(); refreshWallpapers() }
        else if (m.title === "Setup") { showSetup = true; clearSearch() }
        else if (m.title === "Install") { showInstall = true; clearSearch() }
        else if (m.title === "Remove") { showRemove = true; clearSearch() }
        else if (m.title === "System") { showSession = true; directSystemOpen = false; clearSearch() }
    }
    function resetAllSubmenus() { showStyle = false; showWallpaper = false; showWallpaperSettings = false; showThemes = false; showFont = false; showInstall = false; showRemove = false; showSession = false; showSetup = false; showModules = false; showNewAppMenu = false; showPackages = false; showWebApp = false; directSystemOpen = false }
    function handleEsc(): bool {
        if (showWallpaperSettings) { showWallpaperSettings = false; clearSearch(); return true }
        if (showWallpaper) { showWallpaper = false; showStyle = true; clearSearch(); return true }
        if (showThemes) { showThemes = false; showStyle = true; clearSearch(); return true }
        if (showFont) { showFont = false; showStyle = true; clearSearch(); return true }
        if (showModules) { showModules = false; showStyle = true; clearSearch(); return true }
        if (showNewAppMenu) { showNewAppMenu = false; clearSearch(); return true }
        if (showPackages) {
            if (packageOpActive) { leavePackageOp(); return true }
            showPackages = false; if (packageOrigin === "Remove" || packageOrigin === "AurRemove" || packageOrigin === "FlatpakRemove") showRemove = true; else showInstall = true; clearSearch(); return true
        }
        if (showWebApp) {
            showWebApp = false; if (webAppMode === "remove") showRemove = true; else showInstall = true; clearSearch(); return true
        }
        if (showStyle || showInstall || showRemove || showSetup) { resetAllSubmenus(); clearSearch(); return true }
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
            if (showFont) { let f = filteredFonts[si]; return "font:" + (f ? f : "none") + " idx=" + si }
            if (showNewAppMenu) { let e = filteredNewApps[si]; return "newapp:" + (e ? e.name || e.id : "none") + " idx=" + si }
            if (showPackages) { let p = filteredPackages[si]; return "package:" + (p ? p.name : "none") + " idx=" + si }
            if (showWebApp) { return "webapp:" + webAppMode + " count=" + filteredWebApps.length + " idx=" + si }
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
        function getCounts(): string { return "filter=\"" + jhqsMenuScope.filterText + "\" menu=" + jhqsMenuScope.filteredMenu.length + " cats=" + jhqsMenuScope.categoryOptionsCount + " (" + jhqsMenuScope.filteredCategorySections.length + " sections) apps=" + jhqsMenuScope.filteredApps.length + " newapps=" + jhqsMenuScope.filteredNewApps.length + " packages=" + jhqsMenuScope.filteredPackages.length + " webapps=" + jhqsMenuScope.filteredWebApps.length + " wallpaper=" + jhqsMenuScope.filteredWallpapers.length + " themes=" + jhqsMenuScope.filteredThemes.length + " fonts=" + jhqsMenuScope.filteredFonts.length + " total=" + jhqsMenuScope.totalCount + " selected=" + jhqsMenuScope.selectedIndex }
        function pressEnter(): void { if (jhqsMenuScope.bodyRootRef) { jhqsMenuScope.selectedIndex = jhqsMenuScope.bodyRootRef.selectedIndex; jhqsMenuScope.bodyRootRef.activateCurrent() } }
        function pressEsc(): void { if (!jhqsMenuScope.handleEsc()) jhqsMenuScope.dismissed() }
        function moveDown(): void { if (jhqsMenuScope.totalCount === 0) return; jhqsMenuScope.selectedIndex = jhqsMenuScope.showWallpaper ? Math.min(jhqsMenuScope.selectedIndex + 3, jhqsMenuScope.totalCount - 1) : (jhqsMenuScope.selectedIndex + 1) % jhqsMenuScope.totalCount }
        function moveUp(): void { if (jhqsMenuScope.totalCount === 0) return; jhqsMenuScope.selectedIndex = jhqsMenuScope.showWallpaper ? Math.max(jhqsMenuScope.selectedIndex - 3, 0) : (jhqsMenuScope.selectedIndex - 1 + jhqsMenuScope.totalCount) % jhqsMenuScope.totalCount }
        function getSelected(): string { return jhqsMenuScope.selectedEntryInfo() }
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
                out.push({ e: a, n: ((a.name || "") + " " + (a.id || "")).toLowerCase(), c: ((a.comment || "")).toLowerCase() })
            }
        } catch (e) { }
        return out
    }
    onFilterTextChanged: { tryAutoExpandCategory(); scheduleAurSearch() }
    Cats.StyleCategory { id: styleCategoryData }
    readonly property var styleMenu: styleCategoryData.items
    readonly property var themeOptions: styleCategoryData.themeOptions
    Cats.SetupCategory { id: setupCategoryData }
    readonly property var setupMenu: setupCategoryData.items
    Cats.InstallCategory { id: installCategoryData }
    readonly property var installMenu: installCategoryData.items
    Cats.RemoveCategory { id: removeCategoryData }
    readonly property var removeMenu: removeCategoryData.items
    Cats.SystemCategory { id: systemCategoryData }
    readonly property var sessionMenu: systemCategoryData.items
    property var menuModel: [
        {title:"Apps",icon:"󰀻",arrow:"›", submenu: null},
        {title:"Style",icon:"󰏘",arrow:"›", submenu: styleMenu},
        {title:"Setup",icon:"󰒓",arrow:"›", submenu: setupMenu},
        {title:"Install",icon:"󰇚",arrow:"›", submenu: installMenu},
        {title:"Remove",icon:"󰆴",arrow:"›", submenu: removeMenu},
        {title:"About",icon:"󰋼",arrow:"", submenu: null},
        {title:"System",icon:"󰐥",arrow:"›", submenu: sessionMenu}
    ]
    property var queryInputRef: null
    property var bodyRootRef: null
    property bool showStyle: false
    property bool showWallpaper: false
    property bool showThemes: false
    property bool showFont: false
    property bool showInstall: false
    property bool showRemove: false
    property bool showSession: false
    property bool showSetup: false
    property bool showModules: false
    property bool showNewAppMenu: false
    property bool showPackages: false
    property bool directSystemOpen: false
    property bool isInSubmenu: showStyle || showWallpaper || showThemes || showFont || showInstall || showRemove || showSession || showSetup || showModules || showNewAppMenu || showPackages || showWebApp
    readonly property bool canGoBack: isInSubmenu

    property bool __triggerInitDone: false
    Component.onCompleted: __triggerInitDone = true
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
        let all = []
        try {
            let qtf = Qt.fontFamilies()
            if (qtf && qtf.length > 0) all = qtf.slice()
        } catch(e) { }
        if (all.length === 0) {
            try { all = fontFallbackFamilies.slice() } catch(e) { all = [] }
        }
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
    property var filteredNewApps: {
        if (!showNewAppMenu) return []
        let q = qLower()
        if (q === "") {
            let out = []
            for (let i = 0; i < _appSearchIndex.length && out.length < 50; i++) out.push(_appSearchIndex[i].e)
            return out
        }
        let r = []
        for (let i = 0; i < _appSearchIndex.length; i++) {
            let row = _appSearchIndex[i]
            if (row.n.includes(q) || row.c.includes(q)) { r.push(row.e); if (r.length >= 8) break }
        }
        return r
    }
    property var packageList: []
    property string packageOrigin: "Install"
    property string packageMode: "install"
    readonly property var gamingCatalog: [
        { repo: "multilib", name: "steam", version: "", displayName: "Steam", aur: false },
        { repo: "aur", name: "heroic-games-launcher-bin", version: "", displayName: "Heroic Launcher", aur: true },
        { repo: "extra", name: "prismlauncher", version: "", displayName: "Prism Launcher", aur: false }
    ]
    readonly property var browserCatalog: [
        { repo: "aur", name: "brave-bin", version: "", displayName: "Brave", aur: true },
        { repo: "aur", name: "zen-browser-bin", version: "", displayName: "Zen Browser", aur: true },
        { repo: "aur", name: "helium-browser-bin", version: "", displayName: "Helium Browser", aur: false },
        { repo: "extra", name: "chromium", version: "", displayName: "Chromium", aur: false }
    ]
    function curatedCatalog() { return packageMode === "browser" ? browserCatalog : gamingCatalog }
    function curatedTitle() { return packageMode === "browser" ? "Browser" : "Gaming" }
    function curatedSize() { return packageMode === "browser" ? browserCatalog.length : gamingCatalog.length }
    function curatedSpec(name) {
        let cat = curatedCatalog()
        for (let i = 0; i < cat.length; i++) if (cat[i].name === name) return cat[i].aur ? "aur/" + name : name
        return name
    }
    readonly property var _installedSet: {
        let s = {}
        try {
            for (let i = 0; i < packageList.length; i++) { let p = packageList[i]; if (p && p.name && p.installed) s[p.name] = true }
            for (let j = 0; j < aurInstalledPackages.length; j++) { let a = aurInstalledPackages[j]; if (a && a.name) s[a.name] = true }
        } catch (e) { }
        return s
    }
    readonly property var _versionMap: {
        let m = {}
        try {
            for (let i = 0; i < packageList.length; i++) { let p = packageList[i]; if (p && p.name && p.version) m[p.name] = p.version }
            for (let j = 0; j < aurInstalledPackages.length; j++) { let a = aurInstalledPackages[j]; if (a && a.name && a.version) m[a.name] = a.version }
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
        if ((packageMode === "remove" || packageMode === "aurremove") && isProtectedPackage(name)) return
        let i = packageSelected.indexOf(name)
        if (i === -1) packageSelected = packageSelected.concat([name])
        else packageSelected = packageSelected.slice(0, i).concat(packageSelected.slice(i + 1))
    }
    function clearPackageSelection() { packageSelected = [] }
    property int installedPackageCount: packageList.filter(p => p && p.installed && isRemovablePackage(p.name)).length
    property var filteredPackages: {
        if (!showPackages) return []
        let q = qLower()
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
        if (packageMode === "aur") {
            if (q !== "") return aurPackages.slice(0, 100)
            let fset = _installedSet
            return aurFeaturedPackages.map(p => ({ repo: "aur", name: p.name, version: p.version, installed: !!fset[p.name] }))
        }
        if (packageMode === "flatpak" || packageMode === "flatpakremove") {
            let fbase = packageMode === "flatpakremove" ? flatpakInstalledPackages : flatpakList
            if (q === "") return fbase.slice(0, 100)
            let fexact = [], fstarts = [], fsub = [], fname = []
            for (let i = 0; i < fbase.length; i++) {
                let p = fbase[i]
                if (!p || !p.name) continue
                let n = ("" + p.name).toLowerCase()
                let d = ("" + (p.displayName || "")).toLowerCase()
                if (n === q) fexact.push(p)
                else if (n.startsWith(q)) fstarts.push(p)
                else if (n.includes(q)) fsub.push(p)
                else if (d !== "" && d.includes(q)) fname.push(p)
            }
            return fexact.concat(fstarts, fsub, fname).slice(0, 100)
        }
        let base = packageMode === "remove" ? packageList.filter(p => p && p.installed && isRemovablePackage(p.name)) : (packageMode === "aurremove" ? aurInstalledPackages.filter(p => p && p.name && isRemovablePackage(p.name)) : packageList)
        if (q === "") return base.slice(0, 100)
        let exact = [], starts = [], sub = []
        for (let i = 0; i < base.length; i++) {
            let p = base[i]
            if (!p || !p.name) continue
            let n = p.name
            if (n === q) exact.push(p)
            else if (n.startsWith(q)) starts.push(p)
            else if (n.includes(q)) sub.push(p)
        }
        return exact.concat(starts, sub).slice(0, 100)
    }
    function refreshPackages() { if ((!packageList || packageList.length === 0) && !packageListProc.running) packageListProc.running = true }
    function refreshPackagesForce() { if (!packageListProc.running) packageListProc.running = true }
    function openPackages(origin) {
        packageOrigin = origin
        packageMode = (origin === "Remove") ? "remove" : (origin === "AurInstall") ? "aur" : (origin === "AurRemove" ? "aurremove" : (origin === "FlatpakInstall" ? "flatpak" : (origin === "FlatpakRemove" ? "flatpakremove" : (origin === "GamingInstall" ? "gaming" : (origin === "BrowserInstall" ? "browser" : "install")))))
        showInstall = false; showRemove = false; showWebApp = false; showPackages = true
        clearPackageSelection(); clearSearch()
        if (packageMode === "remove" || packageMode === "aurremove") refreshExplicit()
        if (packageMode === "aur") { aurPackages = []; aurSearching = false; aurSearchPending = ""; aurSearchRunning = ""; refreshFeatured(); refreshForeign() }
        else if (packageMode === "aurremove") refreshForeign()
        else if (packageMode === "flatpak" || packageMode === "flatpakremove") refreshFlatpak()
        else if (packageMode === "gaming" || packageMode === "browser") { refreshPackages(); refreshForeign() }
        else refreshPackages()
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
    function noAgentMessage(): string { return "Kein Authentifizierungs-Agent aktiv — Passwort-Dialog kann nicht erscheinen. Kurz warten (Agent meldet sich selbst an) und erneut versuchen. Falls dauerhaft: Shell neu starten, dann `sudo systemctl restart polkit`." }
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
        if (mode === "remove" || mode === "aurremove") clean = clean.filter(n => !isProtectedPackage(n))
        if (clean.length === 0) return false
        let m = (mode === "remove" || mode === "aurremove") ? "remove" : (mode === "aur" ? "aur" : (mode === "flatpak" ? "flatpak" : (mode === "flatpakremove" ? "flatpakremove" : (mode === "gaming" ? "gaming" : (mode === "browser" ? "browser" : "install")))))
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
        let inner
        {
            let tag = (mode === "aur" || mode === "aurremove") ? " (AUR)" : ((m === "flatpak" || m === "flatpakremove") ? " (Flatpak)" : (m === "gaming" ? " (Gaming)" : (m === "browser" ? " (Browser)" : "")))
            packageOpAppend(((m === "remove" || m === "flatpakremove") ? "Entferne " : "Installiere ") + clean.length + " Paket(e)" + tag + ": " + clean.join(" "))
            if (m === "remove") inner = "pacman -Rns --noconfirm " + clean.join(" ")
            else if (m === "aur") inner = "paru --sudo pkexec -S --needed --noconfirm --skipreview " + clean.map(n => "aur/" + n).join(" ")
            else if (m === "gaming" || m === "browser") inner = "paru --sudo pkexec -S --needed --noconfirm --skipreview " + clean.map(n => curatedSpec(n)).join(" ")
            else if (m === "flatpak") inner = "flatpak install -y flathub " + clean.join(" ")
            else if (m === "flatpakremove") inner = "flatpak uninstall -y " + clean.join(" ")
            else inner = "pacman -S --needed --noconfirm " + clean.join(" ")
        }
        packageOpProc.command = (m === "aur" || m === "gaming" || m === "browser" || m === "flatpak" || m === "flatpakremove")
            ? ["script", "-qec", inner, "/dev/null"]
            : ["script", "-qec", "pkexec --disable-internal-agent " + inner, "/dev/null"]
        if (!packageOpProc.running) packageOpProc.running = true
        return true
    }
    function finishPackageOp(code) {
        packageOpRunning = false; packageOpExit = code; packageOpSuccess = (code === 0)
        if (code === 0) {
            packageOpAppend("✓ Fertig (Code 0)")
            if (packageOpMode === "install" || packageOpMode === "aur" || packageOpMode === "flatpak" || packageOpMode === "gaming" || packageOpMode === "browser") {
                let names = (packageOpPkgs || []).join(", ").slice(0, 180)
                let tag = packageOpMode === "aur" ? " (AUR)" : (packageOpMode === "flatpak" ? " (Flatpak)" : (packageOpMode === "gaming" ? " (Gaming)" : (packageOpMode === "browser" ? " (Browser)" : "")))
                if (names !== "") sendInstallNotification("✓ Installiert: " + names + tag, "findest du im App-Launcher")
            }
        }
        else if (code === 127) { packageOpAppend("✗ Abgebrochen (Code 127)"); packageOpAppend("Hinweis: Authentifizierung abgebrochen oder kein Agent verfügbar.") }
        else packageOpAppend("✗ Fehlgeschlagen (Code " + code + ")")
        if (code === 0 && packageOpKernelUpdated) {
            packageOpAppend("Kernel wurde aktualisiert — Neustart empfohlen")
            packageOpAppend("System → Neustarten (oder: systemctl reboot)")
        }
        refreshPackagesForce()
        refreshFlatpakForce()
        refreshForeign()
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
    function setWallpaper(path, preview) {
        if (!path || path.length === 0) return
        if (path.includes("\n") || path.includes("\r")) return
        let esc = escShellArg(path)
        let mode = wallpaperModes.indexOf(wallpaperMode) !== -1 ? wallpaperMode : "fill"
        let wpCmd = "pkill -x swaybg 2>/dev/null || true; "
        wpCmd += "if command -v swaybg >/dev/null 2>&1; then setsid nohup swaybg -i \"" + esc + "\" -m " + mode + " >/dev/null 2>&1 < /dev/null & disown; "
        wpCmd += "else echo \"[jhqs] swaybg fehlt — Wallpaper unverändert\" >&2; fi; "
        wpCmd += "mkdir -p ~/.cache/swaybg ~/.cache/awww ~/.config/quickshell/jhqs/config 2>/dev/null; echo -n \"" + esc + "\" > ~/.cache/swaybg/current 2>/dev/null; echo -n \"" + esc + "\" > ~/.cache/awww/current 2>/dev/null; echo -n \"" + esc + "\" > ~/.config/quickshell/jhqs/config/current_wallpaper.txt 2>/dev/null; echo done"
        Quickshell.execDetached(["bash", "-c", wpCmd])
        if (currentEngine === "wallpaper") {
            themeEngine.abortMonet()
            _pendingMonetPath = esc
            monetDelayTimer.interval = 800
            monetDelayTimer.restart()
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
        showSession = true; showStyle = false; showWallpaper = false; showWallpaperSettings = false; showThemes = false; showFont = false; showInstall = false; showRemove = false; showSetup = false; showModules = false; showNewAppMenu = false; showPackages = false; showWebApp = false; directSystemOpen = true
        clearSearch()
    }

    property var filteredMenu: {
        let q = qLower()
        if (showWallpaper || showThemes || showFont || showNewAppMenu || showPackages || showWebApp) return []
        let active = null
        if (showStyle) active = styleMenu; else if (showInstall) active = installMenu; else if (showRemove) active = removeMenu; else if (showSession) active = sessionMenu; else if (showSetup) active = setupMenu
        if (active) return q === "" ? active : active.filter(m => m.title.toLowerCase().includes(q))
        let base = q === "" ? menuModel : menuModel.filter(m => m.title.toLowerCase().includes(q))
        if (q !== "") base = base.filter(m => isSearchableCategory(m.title))
        if (q !== "" && base.length > 1) {
            let sysRows = base.filter(m => m.title === "System")
            if (sysRows.length > 0 && sysRows.length < base.length) return base.filter(m => m.title !== "System").concat(sysRows)
        }
        return base
    }
    property var filteredCategorySections: {
        if (isInSubmenu) return []
        let q = qLower(); if (q === "") return []
        let sections = []
        for (let i = 0; i < menuModel.length; i++) {
            let m = menuModel[i]
            if (!isSearchableCategory(m.title)) continue
            if (!m.submenu || m.submenu.length === 0) continue
            let matched = m.submenu.filter(e => e.title.toLowerCase().includes(q))
            if (matched.length === 0 && m.title.toLowerCase().includes(q)) matched = m.submenu.slice()
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
        if (isInSubmenu || !Theme.searchAppsEnabled) return []
        let q = qLower(); if (q === "") return []
        let r = []
        for (let i = 0; i < _appSearchIndex.length; i++) {
            let row = _appSearchIndex[i]
            if (row.n.includes(q)) r.push(row.e)
        }
        r.sort((a,b)=>{ let an=(a.name||"").toLowerCase(), bn=(b.name||"").toLowerCase(); if((an===q)!==(bn===q)) return an===q?-1:1; if(an.startsWith(q)!==bn.startsWith(q)) return an.startsWith(q)?-1:1; return an.length-bn.length })
        return r.slice(0,8)
    }
    property int totalCount: showWallpaper ? filteredWallpapers.length : showThemes ? filteredThemes.length : showFont ? filteredFonts.length : showNewAppMenu ? filteredNewApps.length : showPackages ? filteredPackages.length : filteredApps.length + filteredMenu.length + categoryOptionsCount
    property int selectedIndex: 0

    function runProc(p) { if (p && !p.running) p.running = true }
    function openAbout() { Quickshell.execDetached(["bash", "-c", "kitty --class about-fastfetch --title About bash -c 'fastfetch; sleep 0.5; read -n1 -s' &"]) }

    function executeCategoryOption(category, entry) {
        let t = entry.title
        if (category === "Install") {
            if (t === "Flatpak") { openPackages("FlatpakInstall"); return }
            else if (t === "Web App") { openWebApp("install"); return }
            else if (t === "Package") { openPackages("Install"); return }
            else if (t === "AUR") { openPackages("AurInstall"); return }
            else if (t === "Gaming") { openPackages("GamingInstall"); return }
            else if (t === "Browser") { openPackages("BrowserInstall"); return }
            dismissed()
        } else if (category === "Remove") {
            if (t === "Flatpak") { openPackages("FlatpakRemove"); return }
            else if (t === "Web App") { openWebApp("remove"); return }
            else if (t === "Package") { openPackages("Remove"); return }
            else if (t === "AUR") { openPackages("AurRemove"); return }
            dismissed()
        } else if (category === "System") {
            if (t === "Sperren") runProc(sessionLockProc)
            else if (t === "Abmelden") runProc(sessionLogoutProc)
            else if (t === "Ruhezustand") runProc(sessionSuspendProc)
            else if (t === "Neustarten") runProc(sessionRebootProc)
            else if (t === "Herunterfahren") runProc(sessionPoweroffProc)
            dismissed()
        } else if (category === "Style") {
            if (t === "Wallpaper") { showStyle=false; showWallpaper=true; refreshWallpapers(); clearSearch(); return }
            if (t === "Themes") { showStyle=false; showThemes=true; clearSearch(); return }
            if (t === "Font") { showStyle=false; showFont=true; fontExpanded=""; refreshFonts(); clearSearch(); return }
            if (t === "Modules") { showStyle=false; showModules=true; clearSearch(); return }
            dismissed()
        } else if (category === "Setup") {
            if (t === "Settings") { openSettings("global"); return }
            else if (t === "Monitors") runProc(setupMonitorsProc)
            else if (t === "Keybindings") runProc(setupBindsProc)
            else if (t === "Autostart") runProc(setupAutostartProc)
            else if (t === "Audio") runProc(setupAudioProc)
            dismissed()
        } else { dismissed() }
    }

    function activateCurrent() {
        if (showWallpaper) { let p = filteredWallpapers[selectedIndex]; if (p) setWallpaper(p); return }
        if (showThemes) { let t = filteredThemes[selectedIndex]; if (t) setThemeEngine(t.id); return }
        if (showFont) { let f = filteredFonts[selectedIndex]; if (f) setSystemFont(f); return }
        if (showNewAppMenu) { let e = filteredNewApps[selectedIndex]; if (e && e.execute) { try { Theme.triggerLaunchOsd(e.name || "", e.icon || "") } catch (err) { } e.execute(); dismissed() } return }
        if (showPackages) {
            if (packageOpActive) { if (!packageOpRunning) dismissed(); return }
            let sel = packageSelected.length > 0 ? packageSelected.slice() : []
            if (sel.length === 0) { let p = filteredPackages[selectedIndex]; if (p && p.name) sel = [p.name] }
            if (sel.length > 0) startPackageOp(packageMode, sel)
            return
        }
        let m = filteredMenu[selectedIndex]
        if (showStyle || showInstall || showRemove || showSession || showSetup) {
            if (!m) return
            if (showStyle) {
                if (m.title === "Wallpaper") { showStyle=false; showWallpaper=true; refreshWallpapers(); clearSearch() }
                else if (m.title === "Themes") { showStyle=false; showThemes=true; clearSearch() }
                else if (m.title === "Font") { showStyle=false; showFont=true; fontExpanded=""; refreshFonts(); clearSearch() }
                else if (m.title === "Modules") { showStyle=false; showModules=true; clearSearch() }
                else dismissed()
                return
            }
            if (showInstall) { if (m.title==="Flatpak") { openPackages("FlatpakInstall"); return } else if (m.title==="Web App") { openWebApp("install"); return } else if (m.title==="Package") { openPackages("Install"); return } else if (m.title==="AUR") { openPackages("AurInstall"); return } else if (m.title==="Gaming") { openPackages("GamingInstall"); return } else if (m.title==="Browser") { openPackages("BrowserInstall"); return } dismissed(); return }
            if (showRemove) { if (m.title==="Flatpak") { openPackages("FlatpakRemove"); return } else if (m.title==="Web App") { openWebApp("remove"); return } else if (m.title==="Package") { openPackages("Remove"); return } else if (m.title==="AUR") { openPackages("AurRemove"); return } dismissed(); return }
            if (showSession) { if (m.title==="Sperren") runProc(sessionLockProc); else if (m.title==="Abmelden") runProc(sessionLogoutProc); else if (m.title==="Ruhezustand") runProc(sessionSuspendProc); else if (m.title==="Neustarten") runProc(sessionRebootProc); else if (m.title==="Herunterfahren") runProc(sessionPoweroffProc); dismissed(); return }
            if (showSetup) {
                if (m.title==="Settings") { openSettings("global"); return }
                else if (m.title==="Monitors") runProc(setupMonitorsProc)
                else if (m.title==="Keybindings") runProc(setupBindsProc)
                else if (m.title==="Autostart") runProc(setupAutostartProc)
                else if (m.title==="Audio") runProc(setupAudioProc)
                dismissed(); return
            }
        }
        if (totalCount === 0) return
        if (selectedIndex < filteredApps.length) {
            let e = filteredApps[selectedIndex]
            if (e && e.execute) { try { Theme.triggerLaunchOsd(e.name || "", e.icon || "") } catch (err) { } e.execute(); dismissed() }
        } else if (selectedIndex < filteredApps.length + filteredMenu.length) {
            let e = filteredMenu[selectedIndex - filteredApps.length]
            if (e.title==="Apps") { showNewAppMenu=true; clearSearch() }
            else if (e.title==="About") { openAbout(); dismissed() }
            else if (e.title==="System") { showSession=true; directSystemOpen=false; clearSearch() }
            else if (e.title==="Install") { showInstall=true; clearSearch() }
            else if (e.title==="Remove") { showRemove=true; clearSearch() }
            else if (e.title==="Style") { showStyle=true; clearSearch(); refreshWallpapers() }
            else if (e.title==="Setup") { showSetup=true; clearSearch() }
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
            visible: jhqsMenuScope._winVisible && modelData.name === "DP-1"
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
                        let isMinimal = Theme.shellTheme === "minimal"
                        let rowH = isMinimal ? 50 : 40
                        let rowGap = isMinimal ? 3 : 4
                        let n = jhqsMenuScope.menuModel ? jhqsMenuScope.menuModel.length : 8
                        if (n < 1) n = 1
                        let content = n * rowH + Math.max(0, n - 1) * rowGap
                        let overhead = isMinimal ? (18 + 34 + 6 + 18) : (10 + 36 + 8 + 1 + 4 + 8)
                        return overhead + content + 2
                    }
                    implicitWidth: (jhqsMenuScope.showWallpaper || jhqsMenuScope.showPackages || jhqsMenuScope.showWebApp) ? 760 : (Theme.shellTheme === "minimal" ? 300 : Theme.sharedMenuWidth)
                    implicitHeight: jhqsMenuScope.showWallpaper ? 820 : (jhqsMenuScope.showPackages || jhqsMenuScope.showWebApp) ? Theme.sharedMenuHeight : catDynH
                    Behavior on implicitWidth { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
                    Behavior on implicitHeight { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        id: panel
                        anchors.fill: parent
                        radius: Theme.cornerRadius; color: Theme.shellTheme === "minimal" ? Theme.bg : Theme.panelBg; border.color: Theme.shellTheme === "minimal" ? Theme.accent : Theme.panelBorderColor; border.width: Theme.shellTheme === "minimal" ? 2 : 1; clip: true
                        Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }
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
                        Connections { target: bodyRoot.scope; function onShowMenuChanged(){ if(bodyRoot.scope.showMenu){ bodyRoot.scope.resetAllSubmenus(); bodyRoot.scope.clearSearch(); if(!bodyRoot.scope.wallpaperFiles || bodyRoot.scope.wallpaperFiles.length===0) bodyRoot.scope.refreshWallpapers(); if(!bodyRoot.scope.packageList || bodyRoot.scope.packageList.length===0) bodyRoot.scope.refreshPackages(); if(!bodyRoot.scope.fontFallbackFamilies || bodyRoot.scope.fontFallbackFamilies.length===0) bodyRoot.scope.refreshFonts(); Qt.callLater(()=>{ parent.forceActiveFocus(); if(queryInput) queryInput.forceActiveFocus() }) } } }

                        Item {
                            id: searchRow
                            readonly property bool isMinimal: Theme.shellTheme === "minimal"
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.topMargin: isMinimal ? 18 : 10; anchors.leftMargin: isMinimal ? 18 : 10; anchors.rightMargin: isMinimal ? 18 : 10
                            height: isMinimal ? 34 : 36
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
                                color: searchRow.isMinimal ? "transparent" : (backBtnMouse.containsMouse ? Theme.bgSelected : Theme.panelSurface)
                                border.color: searchRow.isMinimal ? "transparent" : Theme.divider; border.width: searchRow.isMinimal ? 0 : 1
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
                            radius: searchRow.isMinimal ? 0 : Theme.cornerRadiusSmall
                            color: searchRow.isMinimal ? "transparent" : Theme.panelSurface
                            border.color: searchRow.isMinimal ? "transparent" : (queryInput.activeFocus ? Theme.accent : Theme.divider)
                            border.width: searchRow.isMinimal ? 0 : 1
                            Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: searchRow.isMinimal ? 0 : 10; anchors.rightMargin: searchRow.isMinimal ? 0 : 10; spacing: 8
                                Text { visible: !searchRow.isMinimal; text: "󰍉"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12); color: Theme.textMuted
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                                TextInput {
                                    id: queryInput
                                    Layout.fillWidth: true
                                    text: bodyRoot.filterText
                                    color: Theme.textPrimary
                                    opacity: searchRow.isMinimal ? (text.length > 0 ? 1.0 : 0.0) : 1.0
                                    font.family: searchRow.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: searchRow.isMinimal ? Theme.fs(16) : Theme.fs(13)
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
                                anchors.left: parent.left; anchors.leftMargin: searchRow.isMinimal ? 0 : 36; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                text: searchRow.isMinimal ? (bodyRoot.scope.isInSubmenu ? (bodyRoot.scope.showNewAppMenu ? "Search apps…" : bodyRoot.scope.showWallpaper ? "Wallpaper…" : bodyRoot.scope.showThemes ? "Themes…" : bodyRoot.scope.showFont ? "Fonts suchen…" : bodyRoot.scope.showModules ? "Modules…" : bodyRoot.scope.showStyle ? "Style…" : bodyRoot.scope.showSetup ? "Setup…" : bodyRoot.scope.showInstall ? "Install…" : bodyRoot.scope.showRemove ? "Remove…" : bodyRoot.scope.showSession ? "System…" : bodyRoot.scope.showWebApp ? (bodyRoot.scope.webAppMode === "remove" ? "Web Apps filtern…" : "Web App installieren…") : bodyRoot.scope.showPackages ? "Packages…" : "Go…") : "Go…") : (bodyRoot.scope.isInSubmenu ? (bodyRoot.scope.showWallpaper ? "Wallpaper..." : bodyRoot.scope.showThemes ? "Themes..." : bodyRoot.scope.showFont ? "Fonts suchen..." : bodyRoot.scope.showModules ? "Modules..." : bodyRoot.scope.showStyle ? "Style..." : bodyRoot.scope.showSetup ? "Setup..." : bodyRoot.scope.showInstall ? "Install..." : bodyRoot.scope.showRemove ? "Remove..." : bodyRoot.scope.showSession ? "System..." : bodyRoot.scope.showWebApp ? (bodyRoot.scope.webAppMode === "remove" ? "Web Apps filtern..." : "Web App installieren...") : bodyRoot.scope.showPackages ? (bodyRoot.scope.packageMode === "remove" ? "Entfernen..." : bodyRoot.scope.packageMode === "aur" ? "AUR suchen..." : bodyRoot.scope.packageMode === "aurremove" ? "AUR entfernen..." : bodyRoot.scope.packageMode === "flatpak" ? "Flatpak suchen..." : bodyRoot.scope.packageMode === "flatpakremove" ? "Flatpak entfernen..." : "Packages...") : "Search...") : "Search...")
                                color: searchRow.isMinimal ? Theme.textPrimary : Theme.textMuted; opacity: searchRow.isMinimal ? 0.58 : 1.0; font.family: searchRow.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: searchRow.isMinimal ? Theme.fs(16) : Theme.fs(13)
                                elide: Text.ElideRight
                                visible: bodyRoot.filterText.length === 0
                            }
                            }
                        }
                        Rectangle { id: searchDivider; visible: !searchRow.isMinimal; anchors.top: searchRow.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.topMargin: 8; anchors.leftMargin: 10; anchors.rightMargin: 10; height: visible ? 1 : 0; color: Theme.divider; opacity: 0.5
                            antialiasing: Theme.shapesAa
                        }

                        Item {
                            id: contentStage
                            anchors.top: searchRow.isMinimal ? searchRow.bottom : searchDivider.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                            anchors.topMargin: searchRow.isMinimal ? 6 : 4; anchors.leftMargin: searchRow.isMinimal ? 18 : 10; anchors.rightMargin: searchRow.isMinimal ? 18 : 10; anchors.bottomMargin: searchRow.isMinimal ? 18 : 10
                            clip: true
                            property bool isListView: !bodyRoot.scope.showWallpaper && !bodyRoot.scope.showThemes && !bodyRoot.scope.showFont && !bodyRoot.scope.showModules && !bodyRoot.scope.showNewAppMenu && !bodyRoot.scope.showPackages && !bodyRoot.scope.showWebApp

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
