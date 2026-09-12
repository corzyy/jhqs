pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "../../../themes"
import "../../../services"
import "../../../Commons"
import ".."
import "../../../Ui" as Ui

Column {
    id: root
    width: parent ? parent.width : 400
    spacing: 10

    property var sinks: []
    property string defaultSink: ""
    // NOTE: brightVal removed — dead (slider binds SettingsService.brightness directly).

    Process {
        id: sinkListProc
        command: ["bash", "-c", "pactl list sinks 2>/dev/null | awk ' /Name:/{n=$2} /Description:|Beschreibung:/{sub(/^[^:]*: /, \"\"); d=$0; print n\"|\"d}'"]
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
                    arr.push({name: ln.substring(0, sep).trim(), desc: ln.substring(sep + 1).trim()})
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

    SettingsControls.SettingsSection {
        title: "Output"
        Row {
            width: parent.width; spacing: 10
            Text { text: VolumeService.icon; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(20); color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Ui.MSlider {
                id: audioVolSlider
                width: parent.width - 90
                from: 0; to: 100; stepSize: 1
                value: VolumeService.pct
                compact: true; showValueLabel: false; showStopDot: false
                wheelEnabled: false
                trackHeight: 14; trackRadius: 7; handleWidth: 4; handleHeight: 16; trackGap: 4
                onMoved: v => volSet.setVol(Math.round(v))
            }
            Connections {
                target: VolumeService
                function onPctChanged() { if (!audioVolSlider.dragging) audioVolSlider.value = VolumeService.pct }
            }
            Text { text: VolumeService.pct + "%"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); color: Theme.textSecondary; width: 44; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
        }
        SettingsControls.SettingsRow {
            title: VolumeService.isMuted ? "Unmute" : "Mute"
            SettingsControls.SettingsToggle { on: !VolumeService.isMuted; onToggled: n => volSet.setMute(!n) }
        }
        SettingsControls.SettingsDropdown {
            label: "Sink"
            options: root.sinks.map(s => s.desc.length > 0 ? s.desc : s.name)
            current: { let m = root.sinks.find(s => s.name === root.defaultSink); return m ? (m.desc.length > 0 ? m.desc : m.name) : root.defaultSink }
            onPicked: v => { let m = root.sinks.find(s => (s.desc.length > 0 ? s.desc : s.name) === v); if (m) switchSink(m.name) }
        }
    }

    Process { id: volProc; command: ["bash", "-c", "echo"]; onExited: pumpVolProc() }
    QtObject {
        id: volSet
        property string pending: ""
        // PERF: slider drags fork wpctl per pixel (old code dropped ticks
        // while running — volume lagged behind the finger). Coalesce.
        function setVol(p): void {
            let v = Math.max(0, Math.min(100, Math.round(p)))
            pending = "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + v + "% -l 1.0 >/dev/null 2>&1; wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 >/dev/null 2>&1"
            if (!volProc.running) pumpVolProc()
            Theme.triggerVolumeOsd()
        }
        function pumpVolProc(): void {
            if (pending === "" || volProc.running) return
            let c = pending
            pending = ""
            volProc.command = ["bash", "-c", c]
            volProc.running = true
        }
        function setMute(m): void {
            volProc.command = ["bash", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ " + (m ? "1" : "0") + " >/dev/null 2>&1"]
            if (!volProc.running) volProc.running = true
        }
    }
    function pumpVolProc(): void { volSet.pumpVolProc() }

    SettingsControls.SettingsSection {
        title: "Display"
        SettingsControls.SettingsSliderRow { label: "Brightness"; from: 5; to: 100; stepSize: 1; unit: "%"; value: SettingsService.brightness; onMoved: v => SettingsService.applyBrightness(v); onApplied: v => SettingsService.applyBrightness(v) }
    }
}
