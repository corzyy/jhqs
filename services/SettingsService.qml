pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../themes"

// SettingsService — compositor-agnostic app settings (kitty, fish prompt,
// brightness). Window-manager look lives in MangoService.
Singleton {
    id: root

    property int kittyPadding: 10
    property real kittyFontSize: 12.0
    property real kittyOpacity: 1.0
    property string fishPrompt: "minimal"
    property int brightness: 100

    // Menu search result toggles (Settings > Search). All default true so
    // older settings.json files without these keys keep full search.
    property bool searchApps: true
    property bool searchMenu: true
    property bool searchLearn: true
    property bool searchStyle: true
    property bool searchSetup: true
    property bool searchInstall: true
    property bool searchRemove: true
    property bool searchSystem: true
    property bool searchMath: true
    property bool searchUnits: true
    property bool searchGen: true
    property bool searchEmoji: true

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/settings.json"
        watchChanges: true; blockLoading: true; printErrors: false
        onFileChanged: settingsReloadDebounce.restart()
        adapter: JsonAdapter {
            property int kittyPadding: 10
            property real kittyFontSize: 12.0
            property real kittyOpacity: 1.0
            property string fishPrompt: "minimal"
            property int brightness: 100
            property bool searchApps: true
            property bool searchMenu: true
            property bool searchLearn: true
            property bool searchStyle: true
            property bool searchSetup: true
            property bool searchInstall: true
            property bool searchRemove: true
            property bool searchSystem: true
            property bool searchMath: true
            property bool searchUnits: true
            property bool searchGen: true
            property bool searchEmoji: true
        }
    }

    function syncFromFile(): void {
        kittyPadding = clampInt(settingsFile.adapter.kittyPadding, 0, 40, 10)
        kittyFontSize = clampReal(settingsFile.adapter.kittyFontSize, 6, 32, 12)
        kittyOpacity = clampReal(settingsFile.adapter.kittyOpacity, 0.3, 1.0, 1.0)
        fishPrompt = (settingsFile.adapter.fishPrompt || "minimal") + ""
        brightness = clampInt(settingsFile.adapter.brightness, 5, 100, 100)
        searchApps = settingsFile.adapter.searchApps !== false
        searchMenu = settingsFile.adapter.searchMenu !== false
        searchLearn = settingsFile.adapter.searchLearn !== false
        searchStyle = settingsFile.adapter.searchStyle !== false
        searchSetup = settingsFile.adapter.searchSetup !== false
        searchInstall = settingsFile.adapter.searchInstall !== false
        searchRemove = settingsFile.adapter.searchRemove !== false
        searchSystem = settingsFile.adapter.searchSystem !== false
        searchMath = settingsFile.adapter.searchMath !== false
        searchUnits = settingsFile.adapter.searchUnits !== false
        searchGen = settingsFile.adapter.searchGen !== false
        searchEmoji = settingsFile.adapter.searchEmoji !== false
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
    // STABILITY + PERF: coalesce editor save bursts; debounce disk writes
    // and backend forks (slider drags used to write+fork per tick).
    Timer {
        id: settingsReloadDebounce
        interval: 250; repeat: false
        onTriggered: { try { settingsFile.reload() } catch (e) { } try { syncFromFile() } catch (e2) { } }
    }
    Timer {
        id: persistDebounce
        interval: 300; repeat: false
        onTriggered: { try { settingsFile.writeAdapter() } catch (e) { } pumpBackend() }
    }
    property var _backendPending: null
    function persist(): void { persistDebounce.restart() }
    function persistNow(): void { try { settingsFile.writeAdapter() } catch (e) { } }

    Process {
        id: backendProc
        command: ["bash", "-c", "echo"]
        stdout: StdioCollector {}
        onExited: pumpBackend()
    }
    function runBackend(args: var): void {
        // Coalesce to latest — intermediate slider ticks are obsolete.
        _backendPending = args
        if (!backendProc.running && !persistDebounce.running) pumpBackend()
    }
    function pumpBackend(): void {
        if (_backendPending === null || _backendPending === undefined) return
        if (backendProc.running) return
        let args = _backendPending
        _backendPending = null
        let script = Quickshell.env("HOME") + "/.config/quickshell/jhqs/scripts/settings-apply.py"
        backendProc.command = ["python3", script].concat(args)
        backendProc.running = true
    }

    Component.onCompleted: Qt.callLater(() => { syncFromFile() })
    function refresh(): void { syncFromFile() }

    // Einziger Schreibpfad: clampen -> Property -> Adapter -> persistieren -> Backend.
    // (Vorher 5x kopiert für kitty/fish/brightness.)
    function applySetting(key: string, value: var, backend: var): void {
        settingsFile.adapter[key] = value
        root[key] = value
        persist()
        runBackend(backend)
    }

    function applyKittyPadding(v): void { const c = clampInt(v, 0, 40, kittyPadding); applySetting("kittyPadding", c, ["kitty", "padding=" + c]) }
    function applyKittyFont(v): void { const c = Math.round(clampReal(v, 6, 32, kittyFontSize) * 2) / 2; applySetting("kittyFontSize", c, ["kitty", "font_size=" + c]) }
    function applyKittyOpacity(v): void { const c = Math.round(clampReal(v, 0.3, 1.0, kittyOpacity) * 100) / 100; applySetting("kittyOpacity", c, ["kitty", "opacity=" + c]) }
    function applyFishPrompt(s): void { applySetting("fishPrompt", s, ["fish", "prompt=" + s]) }
    function applyBrightness(v): void { const c = clampInt(v, 5, 100, brightness); applySetting("brightness", c, ["brightness", "level=" + c]) }

    // Frontend-only write path for search toggles: no backend process.
    // Unknown keys are ignored so a typo can never pollute settings.json.
    readonly property var searchKeys: ["searchApps", "searchMenu", "searchLearn", "searchStyle", "searchSetup", "searchInstall", "searchRemove", "searchSystem", "searchMath", "searchUnits", "searchGen", "searchEmoji"]
    function setSearchEnabled(key: string, v: bool): void {
        if (searchKeys.indexOf(key) === -1) return
        const nv = !!v
        if (!!root[key] === nv && !!settingsFile.adapter[key] === nv) return
        settingsFile.adapter[key] = nv
        root[key] = nv
        persist()
    }
    function searchEnabledForCategory(category: string): bool {
        const c = (category || "").trim()
        if (c === "Learn") return searchLearn
        if (c === "Style") return searchStyle
        if (c === "Setup") return searchSetup
        if (c === "Install") return searchInstall
        if (c === "Remove") return searchRemove
        if (c === "System") return searchSystem
        return true
    }
}
