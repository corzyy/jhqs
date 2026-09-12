pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// DesignService — save / restore full visual designs (snapshots).
// A snapshot captures wallpaper, theme engine, matugen scheme + mode and
// the style settings, so designs can be tried freely and revoked at any
// time. File copying lives in scripts/design-snapshots.py; this service
// exposes the reactive snapshot list plus save/restore/delete actions.
// Applying a restored design is done by the caller via restoreReady(meta),
// because only the menu scope knows how to switch wallpaper + engine.
Singleton {
    id: root

    signal restoreReady(var meta)
    signal restoreFailed(string reason)
    signal saveFinished(string id)
    signal actionFailed(string reason)

    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/quickshell/jhqs/scripts/design-snapshots.py"

    FileView {
        id: indexFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/themes/snapshots/index.json"
        watchChanges: true; onFileChanged: indexReloadDebounce.restart(); blockLoading: true; printErrors: false
        adapter: JsonAdapter { property var snapshots: [] }
    }
    Timer {
        id: indexReloadDebounce
        interval: 300; repeat: false
        onTriggered: { try { indexFile.reload() } catch (e) { } }
    }
    readonly property var snapshots: {
        let s = []
        try {
            let v = indexFile.adapter.snapshots
            if (v && typeof v.length === "number") {
                for (let i = 0; i < v.length; i++) {
                    let e = v[i]
                    if (e && e.id) s.push(e)
                }
            }
        } catch (e) {}
        return s
    }

    Process {
        id: saveProc
        command: ["bash", "-c", "echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                let id = (text || "").trim().split("\n").pop().trim()
                if (id.length > 0) root.saveFinished(id)
            }
        }
        onExited: (code) => { if (code !== 0) root.actionFailed("Design konnte nicht gesichert werden.") }
    }
    Process {
        id: restoreProc
        command: ["bash", "-c", "echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                let line = (text || "").trim().split("\n").pop().trim()
                if (line.length === 0) { root.restoreFailed("Leere Antwort vom Backend."); return }
                try {
                    let meta = JSON.parse(line)
                    if (meta && meta.id) root.restoreReady(meta)
                    else root.restoreFailed("Ungültige Snapshot-Daten.")
                } catch (e) { root.restoreFailed("Ungültige Snapshot-Daten.") }
            }
        }
        onExited: (code) => { if (code !== 0) root.restoreFailed("Design konnte nicht wiederhergestellt werden.") }
    }
    Process { id: deleteProc; command: ["bash", "-c", "echo"] }

    function saveSnapshot(): void {
        if (saveProc.running) return
        saveProc.command = ["python3", scriptPath, "save"]
        saveProc.running = true
    }
    function restoreSnapshot(id: string): void {
        if (restoreProc.running) return
        let clean = (id || "").replace(/[^A-Za-z0-9_-]/g, "")
        if (clean.length === 0) { restoreFailed("Ungültige Snapshot-ID."); return }
        restoreProc.command = ["python3", scriptPath, "restore", clean]
        restoreProc.running = true
    }
    function deleteSnapshot(id: string): void {
        if (deleteProc.running) return
        let clean = (id || "").replace(/[^A-Za-z0-9_-]/g, "")
        if (clean.length === 0) return
        deleteProc.command = ["python3", scriptPath, "delete", clean]
        deleteProc.running = true
    }
}
