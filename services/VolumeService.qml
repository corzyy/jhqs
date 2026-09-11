pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../themes"

Singleton {
    id: root
    property PwNode sink: Pipewire.defaultAudioSink
    property bool sinkReady: sink && sink.ready && sink.audio
    property int pct: sinkReady ? Math.round(sink.audio.volume * 100) : fbPct
    property bool isMuted: sinkReady ? sink.audio.muted : fbMuted
    property int fbPct: 0
    property bool fbMuted: false

    FileView {
        id: volumeFile
        path: Quickshell.env("HOME") + "/.config/quickshell/jhqs/config/volume.json"
        watchChanges: true; blockLoading: true; printErrors: false
        onFileChanged: {
            try { reload() } catch (e) { }
        }
        adapter: JsonAdapter {
            property bool showPct: false
        }
    }
    readonly property bool showPct: volumeFile.adapter.showPct === true
    function setShowPct(v: bool): void {
        let nv = !!v
        if ((volumeFile.adapter.showPct === true) === nv) return
        volumeFile.adapter.showPct = nv
        volumeFile.writeAdapter()
    }

    readonly property string icon: isMuted || pct === 0 ? "󰝟"
                               : pct < 34 ? "󰕿"
                               : pct < 67 ? "󰖀" : "󰕾"

    Process {
        id: volProbe
        command: ["bash", "-c", Quickshell.env("HOME") + "/.config/quickshell/jhqs/scripts/volume.sh get 2>/dev/null | tr -d '\\n'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                if (out === "muted") root.fbMuted = true
                else if (out.endsWith("%")) {
                    let n = parseInt(out)
                    if (!isNaN(n)) { root.fbPct = n; root.fbMuted = false }
                }
            }
        }
    }
    // CPU/RAM: fallback shell probe used to run every 1s forever, even when
    // PipeWire signals already drive pct/isMuted. Gate it to !sinkReady and
    // slow to 5s so the steady state is zero forks on a working PipeWire box.
    Timer {
        interval: 5000
        running: !root.sinkReady
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!volProbe.running) volProbe.running = true
    }

    Process { id: volUp; command: ["/usr/bin/wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+", "-l", "1.0"] }
    Process { id: volDown; command: ["/usr/bin/wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"] }
    Process { id: volMuteToggle; command: ["/usr/bin/wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] }
    Process { id: volSetProc; command: ["bash", "-c", "echo"] }

    function stepUp(): void { volUp.running = true; Theme.triggerVolumeOsd() }
    function stepDown(): void { volDown.running = true; Theme.triggerVolumeOsd() }
    function toggleMute(): void {
        try {
            if (sinkReady) { sink.audio.muted = !sink.audio.muted; return }
        } catch (e) {}
        if (!volMuteToggle.running) volMuteToggle.running = true
    }
    function setVolumeFrac(v: real): void {
        let v2 = Math.max(0, Math.min(1, v))
        try {
            if (sinkReady) { sink.audio.volume = v2; if (sink.audio.muted && v2 > 0) sink.audio.muted = false; return }
        } catch (e) {}
        volSetProc.command = ["bash", "-c", "/usr/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ " + Math.round(v2 * 100) + "% 2>/dev/null; /usr/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null; echo done"]
        if (!volSetProc.running) volSetProc.running = true
    }
}
