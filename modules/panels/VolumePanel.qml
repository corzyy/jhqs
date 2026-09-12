pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../themes"
import "../../services"
import "../../Ui"

Scope {
    id: scope
    property bool showVolume: false
    signal dismissed()
    property bool _winVisible: showVolume
    Timer { id: hideTimer; interval: 0; repeat: false; onTriggered: if (!scope.showVolume) scope._winVisible = false }
    onShowVolumeChanged: {
        if (showVolume) {
            _winVisible = true
            hideTimer.stop()
            refreshAudio()
        } else hideTimer.restart()
    }
    readonly property string barPos: Theme.barPosition
    readonly property int screenGap: 6
    property int panelGap: screenGap - Theme.barThickness

    readonly property real outVol: (VolumeService.pct || 0) / 100
    readonly property bool outMuted: VolumeService.isMuted
    readonly property bool anyAudible: !outMuted && VolumeService.pct > 0
    // PERF: moodLabel() ran on every pct/mute tick inside a text binding.
    // Cache as a property so only the string updates, not a function call.
    readonly property string moodText: {
        if (outMuted) return "MUTED"
        let p = VolumeService.pct || 0
        if (p === 0) return "SILENCED"
        if (p >= 100) return "CONCERT HALL"
        if (p >= 85) return "PARTY MODE"
        if (p >= 70) return "CRANKED UP"
        if (p >= 50) return "STEADY GROOVE"
        if (p >= 30) return "EASY LISTENING"
        if (p >= 15) return "MURMUR"
        return "WHISPER"
    }

    property var audioSinks: []
    property string defaultSink: ""
    property var audioSources: []
    property string defaultSource: ""
    property real inVol: 0
    property bool inMuted: false
    property var audioStreams: []
    // PERF: compare-before-assign — rebuilding arrays each 5s tick tore down
    // all sink/source/stream delegates even when nothing changed.
    function sameAudioNodes(a: var, b: var): bool {
        try {
            if (!a || !b || a.length !== b.length) return false
            for (let i = 0; i < a.length; i++) {
                let x = a[i], y = b[i]
                if (!x || !y || x.name !== y.name || (x.desc || "") !== (y.desc || "")
                    || (x.vol || "") !== (y.vol || "") || !!x.muted !== !!y.muted) return false
            }
            return true
        } catch (e) { return false }
    }
    Process {
        id: sinksProc
        command: ["bash", "-c", "def=$(pactl get-default-sink 2>/dev/null); pactl list sinks 2>/dev/null | awk 'BEGIN{n=\"\";d=\"\";v=0;m=\"no\"} /^[ \\t]*Name:/{n=$2} /^[ \\t]*Description:/{sub(/^[ \\t]*Description: /,\" \");d=$0} /front-left.*\\/.*%/{for(i=1;i<=NF;i++) if($i ~ /%$/) {v=$i; break}} /^[ \\t]*Mute:/{m=$2} /^$/{if(n!=\"\"){print n\"|\"d\"|\"v\"|\"m; n=\"\";d=\"\";v=0;m=\"no\"}} END{if(n!=\"\")print n\"|\"d\"|\"v\"|\"m}'; echo \"DEF:$def\""]
        stdout: StdioCollector {
            onStreamFinished: {
                let sinks = []
                for (let l of (text || "").trim().split("\n")) {
                    l = l.trim()
                    if (l.indexOf("DEF:") === 0) { scope.defaultSink = l.substring(4).trim(); continue }
                    let p = l.split("|")
                    if (p.length < 2 || (p[0] || "").trim().length === 0) continue
                    sinks.push({ name: (p[0] || "").trim(), desc: (p[1] || "").trim() || (p[0] || "").trim(), vol: (p[2] || "").trim(), muted: ((p[3] || "no").trim().toLowerCase() === "yes") })
                }
                if (!sameAudioNodes(scope.audioSinks, sinks)) scope.audioSinks = sinks
            }
        }
    }
    Process {
        id: sourcesProc
        command: ["bash", "-c", "def=$(pactl get-default-source 2>/dev/null); pactl list sources 2>/dev/null | grep -v '\\.monitor' | awk 'BEGIN{n=\"\";d=\"\";v=0;m=\"no\"} /^[ \\t]*Name:/{n=$2} /^[ \\t]*Description:/{sub(/^[ \\t]*Description: /,\" \");d=$0} /front-left.*\\/.*%/{for(i=1;i<=NF;i++) if($i ~ /%$/) {v=$i; break}} /^[ \\t]*Mute:/{m=$2} /^$/{if(n!=\"\"){print n\"|\"d\"|\"v\"|\"m; n=\"\";d=\"\";v=0;m=\"no\"}} END{if(n!=\"\")print n\"|\"d\"|\"v\"|\"m}'; echo \"DEF:$def\"; vol=$(pactl get-source-volume \"$def\" 2>/dev/null | grep -oP '\\d+%' | head -1); mute=$(pactl get-source-mute \"$def\" 2>/dev/null | grep -oP '(yes|no)' | head -1); echo \"VOL:$vol|$mute\""]
        stdout: StdioCollector {
            onStreamFinished: {
                let srcs = []
                for (let l of (text || "").trim().split("\n")) {
                    l = l.trim()
                    if (l.indexOf("DEF:") === 0) { scope.defaultSource = l.substring(4).trim(); continue }
                    if (l.indexOf("VOL:") === 0) {
                        let p = l.substring(4).split("|")
                        let v = parseInt((p[0] || "").trim())
                        scope.inVol = isNaN(v) ? 0 : Math.max(0, Math.min(1, v / 100))
                        scope.inMuted = ((p[1] || "no").trim().toLowerCase() === "yes")
                        continue
                    }
                    let p = l.split("|")
                    if (p.length < 2 || (p[0] || "").trim().length === 0) continue
                    srcs.push({ name: (p[0] || "").trim(), desc: (p[1] || "").trim() || (p[0] || "").trim() })
                }
                if (!sameAudioNodes(scope.audioSources, srcs)) scope.audioSources = srcs
            }
        }
    }
    Process {
        id: streamsProc
        command: ["bash", "-c", "pactl list sink-inputs 2>/dev/null | awk 'BEGIN{i=\"\";app=\"\";bin=\"\";v=\"\";m=\"no\"} /^[ \\t]*Sink Input #/{i=$3; sub(/^#/,\"\",i)} /^[ \\t]*application.name =/{sub(/^[ \\t]*application.name = /,\"\"); gsub(/\"/,\"\"); app=$0} /^[ \\t]*application.process.binary =/{sub(/^[ \\t]*application.process.binary = /,\"\"); gsub(/\"/,\"\"); bin=$0} /\\/.*%.*\\//{for(k=1;k<=NF;k++) if($k ~ /%$/) {v=$k; break}} /^[ \\t]*Mute:/{m=$2} /^$/{if(i!=\"\"){print i\"|\"app\"|\"bin\"|\"v\"|\"m; i=\"\";app=\"\";bin=\"\";v=\"\";m=\"no\"}} END{if(i!=\"\")print i\"|\"app\"|\"bin\"|\"v\"|\"m}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = (text || "").trim()
                if (out.length === 0) { if (scope.audioStreams.length !== 0) scope.audioStreams = []; return }
                let arr = []
                for (let l of out.split("\n")) {
                    let p = l.trim().split("|")
                    if (p.length < 3) continue
                    let idx = parseInt((p[0] || "").trim())
                    if (isNaN(idx)) continue
                    let v = parseInt(((p[3] || "").trim()).replace("%", ""))
                    arr.push({
                        index: idx,
                        name: (p[1] || "").trim() || (p[2] || "").trim() || ("Stream " + idx),
                        binary: (p[2] || "").trim(),
                        vol: isNaN(v) ? 0 : Math.max(0, Math.min(150, v)),
                        muted: ((p[4] || "no").trim().toLowerCase() === "yes")
                    })
                }
                // Streams carry vol (int) — compare manually including vol.
                let cur = scope.audioStreams
                let same = cur.length === arr.length
                if (same) {
                    for (let i = 0; i < arr.length; i++) {
                        let a = arr[i], b = cur[i]
                        if (!b || a.index !== b.index || a.name !== b.name
                            || a.vol !== b.vol || !!a.muted !== !!b.muted) { same = false; break }
                    }
                }
                if (!same) scope.audioStreams = arr
            }
        }
    }
    Process {
        id: audioActProc
        command: ["bash", "-c", "echo"]
        onExited: pumpAudioAct()
    }
    property var _audioActPending: null
    // STABILITY: queue instead of drop. Old code overwrote command while
    // running — 2nd click while pactl ran was silently lost.
    function audioAct(cmd: string): void {
        if (audioActProc.running) { _audioActPending = cmd; return }
        audioActProc.command = ["bash", "-c", cmd]
        audioActProc.running = true
        refreshDebounce.restart()
    }
    function pumpAudioAct(): void {
        if (_audioActPending === null || _audioActPending === undefined) {
            refreshDebounce.restart()
            return
        }
        let c = _audioActPending
        _audioActPending = null
        if (audioActProc.running) { _audioActPending = c; return }
        audioActProc.command = ["bash", "-c", c]
        audioActProc.running = true
        refreshDebounce.restart()
    }
    // PERF: one refresh pass per action burst (was Qt.callLater per click +
    // 5s timer, spawning 3x pactl+awk per click).
    Timer {
        id: refreshDebounce
        interval: 500; repeat: false
        onTriggered: refreshAudio()
    }
    function refreshAudio() {
        if (!sinksProc.running) sinksProc.running = true
        if (!sourcesProc.running) sourcesProc.running = true
        if (!streamsProc.running) streamsProc.running = true
    }
    Timer { id: audioTimer; interval: 5000; running: scope.showVolume; repeat: true; triggeredOnStart: false; onTriggered: refreshAudio() }
    function setDefaultSink(name: string): void { audioAct("pactl set-default-sink \"" + name.replace(/"/g, "\\\"") + "\" 2>/dev/null; echo done") }
    function setDefaultSource(name: string): void { audioAct("pactl set-default-source \"" + name.replace(/"/g, "\\\"") + "\" 2>/dev/null; echo done") }
    // PERF: slider onMoved fires per pixel — each used to fork pactl.
    // Throttle to latest value per 100ms; release always lands via flush.
    property real _pendingInputVol: -1
    Timer {
        id: inputVolThrottle
        interval: 100; repeat: false
        onTriggered: flushInputVol()
    }
    function setInputVolume(v: real): void {
        _pendingInputVol = Math.max(0, Math.min(1.5, v))
        if (!inputVolThrottle.running) { inputVolThrottle.start(); flushInputVol() }
    }
    function flushInputVol(): void {
        if (_pendingInputVol < 0) return
        if (audioActProc.running) { inputVolThrottle.restart(); return }
        let pct = Math.max(0, Math.min(150, Math.round(_pendingInputVol * 100)))
        _pendingInputVol = -1
        audioAct("pactl set-source-volume @DEFAULT_SOURCE@ " + pct + "% 2>/dev/null; pactl set-source-mute @DEFAULT_SOURCE@ 0 2>/dev/null; echo done")
    }
    function toggleInputMute(): void { audioAct("pactl set-source-mute @DEFAULT_SOURCE@ toggle 2>/dev/null; echo done") }
    property var _pendingStreamVols: ({})
    Timer {
        id: streamVolThrottle
        interval: 100; repeat: false
        onTriggered: flushStreamVols()
    }
    function setStreamVolume(idx: int, v: real): void {
        _pendingStreamVols[idx] = Math.max(0, Math.min(1.5, v))
        if (!streamVolThrottle.running) { streamVolThrottle.start(); flushStreamVols() }
    }
    function flushStreamVols(): void {
        let keys = []
        try { for (let k in _pendingStreamVols) keys.push(k) } catch (e) {}
        if (keys.length === 0) return
        if (audioActProc.running) { streamVolThrottle.restart(); return }
        // Batch all pending streams in one shell call.
        let cmd = ""
        for (let i = 0; i < keys.length; i++) {
            let pct = Math.max(0, Math.min(150, Math.round(_pendingStreamVols[keys[i]] * 100)))
            cmd += "pactl set-sink-input-volume " + keys[i] + " " + pct + "% 2>/dev/null;"
        }
        _pendingStreamVols = ({})
        audioAct(cmd + " echo done")
        if (Object.keys(_pendingStreamVols).length > 0) streamVolThrottle.restart()
    }
    function toggleStreamMute(idx: int): void { audioAct("pactl set-sink-input-mute " + idx + " toggle 2>/dev/null; echo done") }
    function sinkGlyph(desc: string): string {
        let d = (desc || "").toLowerCase()
        if (d.indexOf("headphone") !== -1 || d.indexOf("headset") !== -1) return "󰋋"
        if (d.indexOf("hdmi") !== -1 || d.indexOf("displayport") !== -1) return "󰍹"
        if (d.indexOf("bluetooth") !== -1) return "󰂯"
        return "󰕾"
    }

    component SectionHeader: Text {
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
        color: Theme.textSecondary
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.fs(10)
        font.weight: Font.Bold
    }
    component Hairline: Rectangle {
        antialiasing: Theme.shapesAa
        color: Theme.withAlpha(Theme.textPrimary, 0.12)
        height: 1
    }
    component OmSwitch: Item {
        id: swRoot
        property bool checked: false
        signal toggled()
        implicitWidth: 42
        implicitHeight: 22
        Rectangle {
            anchors.centerIn: parent
            width: 42; height: 22
            radius: 0
            color: swRoot.checked ? Theme.withAlpha(Theme.textPrimary, 0.18) : Theme.withAlpha(Theme.textPrimary, 0.04)
            border.color: swRoot.checked ? "transparent" : Theme.withAlpha(Theme.textPrimary, 0.4)
            border.width: swRoot.checked ? 0 : 1
            Rectangle {
                width: 16; height: 16
                radius: 0
                x: swRoot.checked ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter
                color: swRoot.checked ? Theme.textPrimary : Theme.textSecondary
            }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: swRoot.toggled()
        }
    }
    component OmSlider: Item {
        id: slRoot
        property real value: 0
        property real minimum: 0
        property real maximum: 1
        property real step: 0.05
        property bool dragging: false
        property real liveValue: 0
        signal moved(real v)
        signal released(real v)
        signal rightClicked()
        implicitWidth: 200
        implicitHeight: 22
        onValueChanged: if (!dragging) liveValue = value
        Component.onCompleted: liveValue = value
        readonly property real range: Math.max(0.0001, maximum - minimum)
        readonly property real progress: Math.max(0, Math.min(1, (liveValue - minimum) / range))
        Rectangle {
            id: slTrack
            anchors.left: parent.left; anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 10
            radius: Math.min(Theme.cornerRadiusSmall, height / 2)
            color: Theme.surface_container_highest
        }
        Rectangle {
            anchors.left: slTrack.left
            anchors.verticalCenter: slTrack.verticalCenter
            height: 10
            radius: Math.min(Theme.cornerRadiusSmall, height / 2)
            width: slTrack.width * slRoot.progress
            color: Theme.accent
        }
        Rectangle {
            width: 26; height: 26
            radius: width / 2
            anchors.verticalCenter: slTrack.verticalCenter
            x: Math.max(-6, Math.min(slTrack.width - width + 6, slTrack.width * slRoot.progress - width / 2))
            color: slRoot.dragging ? Theme.withAlpha(Theme.accent, 0.12)
                : slMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.08) : "transparent"
        }
        Rectangle {
            width: 4; height: 18
            radius: 2
            color: Theme.accent
            anchors.verticalCenter: slTrack.verticalCenter
            x: Math.max(0, Math.min(slTrack.width - width, slTrack.width * slRoot.progress - width / 2))
        }
        MouseArea {
            id: slMouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function valueFromX(px: real): real {
                let c = Math.max(0, Math.min(slTrack.width, px))
                return Math.max(slRoot.minimum, Math.min(slRoot.maximum, slRoot.minimum + (c / slTrack.width) * slRoot.range))
            }
            function snap(v: real): real {
                if (slRoot.step > 0) v = Math.round(v / slRoot.step) * slRoot.step
                return Math.max(slRoot.minimum, Math.min(slRoot.maximum, v))
            }
            onPressed: mouse => {
                if (mouse.button !== Qt.LeftButton) return
                slRoot.dragging = true
                let v = snap(valueFromX(mouse.x - (slRoot.width - slTrack.width) / 2))
                slRoot.liveValue = v
                slRoot.moved(v)
            }
            onClicked: mouse => { if (mouse.button === Qt.RightButton) slRoot.rightClicked() }
            onPositionChanged: mouse => {
                if (!slRoot.dragging) return
                let v = snap(valueFromX(mouse.x - (slRoot.width - slTrack.width) / 2))
                slRoot.liveValue = v
                slRoot.moved(v)
            }
            onReleased: mouse => {
                if (mouse.button !== Qt.LeftButton) return
                slRoot.dragging = false
                slRoot.released(slRoot.liveValue)
                slRoot.liveValue = slRoot.value
            }
            onWheel: wheel => {
                let d = wheel.angleDelta.y > 0 ? slRoot.step : -slRoot.step
                let v = snap(Math.max(slRoot.minimum, Math.min(slRoot.maximum, slRoot.liveValue + d)))
                slRoot.liveValue = v
                slRoot.moved(v)
                slRoot.released(v)
            }
        }
    }
    component NodeRow: Rectangle {
        id: nodeRect
        required property string glyph
        required property string label
        required property bool isActive
        signal picked()
        antialiasing: Theme.shapesAa
        color: nodeMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08) : (isActive ? Theme.withAlpha(Theme.textPrimary, 0.08) : "transparent")
        Row {
            anchors.fill: parent
            anchors.leftMargin: 6; anchors.rightMargin: 6
            spacing: 8
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: nodeRect.glyph
                color: Theme.textPrimary
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(14)
                width: 22
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: nodeRect.label
                color: Theme.textPrimary
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(12)
                font.weight: nodeRect.isActive ? Font.Bold : Font.Normal
                elide: Text.ElideRight
                width: parent.width - 22 - 8 - 12
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: nodeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nodeRect.picked()
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: scope._winVisible && modelData.name === "DP-1"
            color: "transparent"
            exclusiveZone: 0
            anchors { top: true; left: true; right: true; bottom: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "volumepanel"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) { scope.dismissed(); event.accepted = true }
                }
                Component.onCompleted: forceActiveFocus()
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: scope.dismissed()
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                id: volBox
                width: 380
                implicitHeight: Math.max(120, Math.min(contentCol.implicitHeight + 36, volAnchor.screenHeight - volAnchor.edgeOffset - 24))
                BarAnchor {
                    id: volAnchor
                    moduleId: "volume"
                    barPos: scope.barPos
                    panelWidth: volBox.width
                    panelHeight: volBox.implicitHeight
                    screenWidth: volBox.parent.width
                    screenHeight: volBox.parent.height
                    gap: scope.panelGap
                    fallbackX: (volBox.parent.width - volBox.width) / 2
                    fallbackY: (volBox.parent.height - volBox.implicitHeight) / 2
                }
                x: volAnchor.panelX
                y: volAnchor.panelY
                color: Theme.bg
                border.color: Theme.panelBorderColor
                border.width: 2
                radius: 0
                clip: true
                PanelSpring {
                    id: volSpring
                    slideFade: true
                    shown: scope.showVolume
                    hiddenX: scope.barPos === "left" ? -(volBox.width + 5) : scope.barPos === "right" ? (volBox.width + 5) : 0
                    hiddenY: scope.barPos === "top" ? -(volBox.implicitHeight + 5) : scope.barPos === "bottom" ? (volBox.implicitHeight + 5) : 0
                }
                visible: volSpring.boxVisible
                opacity: volSpring.fade
                scale: volSpring.zoom
                transformOrigin: volAnchor.origin
                transform: Translate { x: volSpring.slideX; y: volSpring.slideY }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: mouse => mouse.accepted = true
                    onPressed: mouse => mouse.accepted = true
                    onWheel: wheel => wheel.accepted = true
                }
                Flickable {
                    anchors.fill: parent
                    anchors.margins: 18
                    contentHeight: contentCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height
                    Column {
                        id: contentCol
                        width: parent.width
                        spacing: 14
                        Item {
                            width: parent.width
                            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, muteSwitch.implicitHeight)
                            Text {
                                id: heroIcon
                                text: VolumeService.icon
                                color: Theme.textPrimary
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(24)
                                opacity: scope.outMuted ? 0.5 : 1.0
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            OmSwitch {
                                id: muteSwitch
                                checked: scope.anyAudible
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                onToggled: VolumeService.toggleMute()
                            }
                            Column {
                                id: heroLabels
                                anchors.left: heroIcon.right
                                anchors.leftMargin: 14
                                anchors.right: parent.right
                                anchors.rightMargin: muteSwitch.width + 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text {
                                    width: parent.width
                                    text: "Audio"
                                    color: Theme.textPrimary
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fs(16)
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                                Text {
                                    width: parent.width
                                    text: scope.moodText
                                    color: Theme.textSecondary
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fs(10)
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.2
                                    elide: Text.ElideRight
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                            }
                        }
                        Hairline { width: parent.width }
                        Column {
                            width: parent.width
                            spacing: 6
                            Item {
                                width: parent.width
                                implicitHeight: Math.max(outHeader.implicitHeight, outPct.implicitHeight)
                                SectionHeader {
                                    id: outHeader
                                    text: "OUTPUT"
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    id: outPct
                                    text: Math.round(outSlider.liveValue * 100) + "%"
                                    color: Theme.textSecondary
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fs(10)
                                    font.weight: Font.Bold
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    opacity: scope.outMuted ? 0.5 : 1.0
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                            }
                            OmSlider {
                                id: outSlider
                                width: parent.width
                                minimum: 0
                                maximum: 1
                                step: 0.05
                                value: scope.outVol
                                opacity: scope.outMuted ? 0.5 : 1.0
                                onMoved: v => VolumeService.setVolumeFrac(v)
                                onReleased: v => Theme.triggerVolumeOsd()
                                onRightClicked: VolumeService.toggleMute()
                            }
                            Repeater {
                                model: scope.audioSinks
                                delegate: NodeRow {
                                    required property var modelData
                                    required property int index
                                    glyph: scope.sinkGlyph(modelData.desc)
                                    label: modelData.desc
                                    isActive: scope.defaultSink !== "" && modelData.name === scope.defaultSink
                                    width: parent.width
                                    implicitHeight: 40
                                    onPicked: scope.setDefaultSink(modelData.name)
                                }
                            }
                        }
                        Hairline { visible: scope.audioSources.length > 0; width: parent.width }
                        Column {
                            visible: scope.audioSources.length > 0
                            width: parent.width
                            spacing: 6
                            Item {
                                width: parent.width
                                implicitHeight: Math.max(inHeader.implicitHeight, inPct.implicitHeight)
                                SectionHeader {
                                    id: inHeader
                                    text: "INPUT"
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    id: inPct
                                    text: Math.round(inSlider.liveValue * 100) + "%"
                                    color: Theme.textSecondary
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fs(10)
                                    font.weight: Font.Bold
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    opacity: scope.inMuted ? 0.5 : 1.0
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                            }
                            OmSlider {
                                id: inSlider
                                width: parent.width
                                minimum: 0
                                maximum: 1
                                step: 0.05
                                value: scope.inVol
                                opacity: scope.inMuted ? 0.5 : 1.0
                                onMoved: v => scope.setInputVolume(v)
                                onRightClicked: scope.toggleInputMute()
                            }
                            Repeater {
                                model: scope.audioSources
                                delegate: NodeRow {
                                    required property var modelData
                                    required property int index
                                    glyph: "󰍬"
                                    label: modelData.desc
                                    isActive: scope.defaultSource !== "" && modelData.name === scope.defaultSource
                                    width: parent.width
                                    implicitHeight: 40
                                    onPicked: scope.setDefaultSource(modelData.name)
                                }
                            }
                        }
                        Hairline { visible: scope.audioStreams.length > 0; width: parent.width }
                        Column {
                            visible: scope.audioStreams.length > 0
                            width: parent.width
                            spacing: 6
                            SectionHeader { text: "SOURCES" }
                            Repeater {
                                model: scope.audioStreams
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: parent.width
                                    implicitHeight: 56
                                    color: "transparent"
                                    antialiasing: Theme.shapesAa
                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6; anchors.rightMargin: 6
                                        spacing: 8
                                        Text {
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                            text: modelData.muted ? "󰝟" : "󰕾"
                                            color: Theme.textPrimary
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(14)
                                            width: 22
                                            horizontalAlignment: Text.AlignHCenter
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Column {
                                            width: parent.width - 22 - 8 - 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4
                                            Text {
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                                width: parent.width
                                                text: modelData.name
                                                color: modelData.muted ? Theme.textSecondary : Theme.textPrimary
                                                font.family: Theme.iconFontFamily
                                                font.pixelSize: Theme.fs(12)
                                                elide: Text.ElideRight
                                            }
                                            OmSlider {
                                                width: parent.width
                                                minimum: 0
                                                maximum: 1.5
                                                step: 0.05
                                                value: modelData.vol / 100
                                                opacity: modelData.muted ? 0.5 : 1.0
                                                onMoved: v => scope.setStreamVolume(modelData.index, v)
                                                onRightClicked: scope.toggleStreamMute(modelData.index)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
