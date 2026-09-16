pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "../../../themes"
import "../../../services"
import "../../../Commons"
import ".."

NexusControls.PageBase {
    id: root
    title: "Audio"

    property var sinks: []
    property string defaultSink: ""

    Process {
        id: sinkListProc
        command: ["bash", "-c", "LC_ALL=C pactl list sinks 2>/dev/null | awk ' /Name:/{n=$2} /Description:|Beschreibung:/{sub(/^[^:]*: /, \"\"); d=$0; print n\"|\"d}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                if (out.length === 0) { root.sinks = []; return }
                let arr = []
                for (let ln of out.split("\n")) {
                    ln = ln.trim()
                    if (!ln) continue
                    let sep = ln.indexOf("|")
                    if (sep === -1) continue
                    let nm = ln.substring(0, sep).trim()
                    let ds = ln.substring(sep + 1).trim()
                    arr.push({name: nm, desc: Util.cleanAudioName(ds, nm)})
                }
                root.sinks = arr
            }
        }
    }
    Process { id: sinkDefProc; command: ["bash", "-c", "pactl get-default-sink 2>/dev/null | tr -d '\\n'"]; stdout: StdioCollector { onStreamFinished: { let o = (text || "").trim(); if (o) root.defaultSink = o } } }
    Process { id: sinkSetProc; command: ["bash", "-c", "echo"] }
    function refreshSinks(): void { if (!sinkListProc.running) sinkListProc.running = true; if (!sinkDefProc.running) sinkDefProc.running = true }
    function switchSink(name: string): void {
        if (!name) return
        // STABILITY: full DQ-escape ($ ` \ ") — old code only escaped quotes,
        // leaving command substitution open on crafted sink names.
        let safe = Util.shellEscapeDq(name)
        root.defaultSink = name
        sinkSetProc.command = ["bash", "-c", "pactl set-default-sink \"" + safe + "\" 2>/dev/null; for i in $(pactl list short sink-inputs 2>/dev/null | cut -f1); do pactl move-sink-input \"$i\" \"" + safe + "\" 2>/dev/null; done; echo done"]
        if (!sinkSetProc.running) sinkSetProc.running = true
    }
    Component.onCompleted: refreshSinks()

    NexusControls.SectionHeader { first: true; text: "Output" }
    // NOTE: volume/mute go through VolumeService (PipeWire direct, instant
    // indicators). The old per-pixel wpctl fork queue lived here and lagged
    // behind the finger.
    NexusControls.SliderRow {
        first: true
        icon: VolumeService.icon
        label: "Output"
        from: 0; to: 100; stepSize: 1; unit: "%"
        value: VolumeService.pct
        onMoved: v => VolumeService.setVolumeFrac(Math.round(v) / 100)
        onApplied: v => VolumeService.setVolumeFrac(Math.round(v) / 100)
    }
    NexusControls.ToggleRow {
        text: VolumeService.isMuted ? "Unmute" : "Mute"
        checked: !VolumeService.isMuted
        onToggled: n => VolumeService.setMuted(!n)
    }
    NexusControls.DropdownRow {
        last: true
        label: "Sink"
        options: root.sinks.map(s => s.desc.length > 0 ? s.desc : s.name)
        current: { let m = root.sinks.find(s => s.name === root.defaultSink); return m ? (m.desc.length > 0 ? m.desc : m.name) : root.defaultSink }
        onPicked: v => { let m = root.sinks.find(s => (s.desc.length > 0 ? s.desc : s.name) === v); if (m) switchSink(m.name) }
    }

    NexusControls.SectionHeader { text: "Display" }
    NexusControls.SliderRow { first: true; last: true; label: "Brightness"; from: 5; to: 100; stepSize: 1; unit: "%"; value: SettingsService.brightness; onMoved: v => SettingsService.applyBrightness(v); onApplied: v => SettingsService.applyBrightness(v) }
}
