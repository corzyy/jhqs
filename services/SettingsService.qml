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
        }
    }

    function syncFromFile(): void {
        kittyPadding = clampInt(settingsFile.adapter.kittyPadding, 0, 40, 10)
        kittyFontSize = clampReal(settingsFile.adapter.kittyFontSize, 6, 32, 12)
        kittyOpacity = clampReal(settingsFile.adapter.kittyOpacity, 0.3, 1.0, 1.0)
        fishPrompt = (settingsFile.adapter.fishPrompt || "minimal") + ""
        brightness = clampInt(settingsFile.adapter.brightness, 5, 100, 100)
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

    function applyKittyPadding(v): void { let c = clampInt(v, 0, 40, kittyPadding); kittyPadding = c; settingsFile.adapter.kittyPadding = c; persist(); runBackend(["kitty", "padding=" + c]) }
    function applyKittyFont(v): void { let c = clampReal(v, 6, 32, kittyFontSize); c = Math.round(c * 2) / 2; kittyFontSize = c; settingsFile.adapter.kittyFontSize = c; persist(); runBackend(["kitty", "font_size=" + c]) }
    function applyKittyOpacity(v): void { let c = clampReal(v, 0.3, 1.0, kittyOpacity); c = Math.round(c * 100) / 100; kittyOpacity = c; settingsFile.adapter.kittyOpacity = c; persist(); runBackend(["kitty", "opacity=" + c]) }
    function applyFishPrompt(s): void { fishPrompt = s; settingsFile.adapter.fishPrompt = s; persist(); runBackend(["fish", "prompt=" + s]) }
    function applyBrightness(v): void { let c = clampInt(v, 5, 100, brightness); brightness = c; settingsFile.adapter.brightness = c; persist(); runBackend(["brightness", "level=" + c]) }
}
