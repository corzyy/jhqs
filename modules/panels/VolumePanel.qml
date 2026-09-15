pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../themes"
import "../../services"
import "../../Commons"
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
    readonly property string statusText: {
        if (outMuted) return "MUTED"
        let p = VolumeService.pct || 0
        if (p === 0) return "SILENT"
        return p + "%"
    }
    readonly property string activeSinkDesc: {
        if (scope.defaultSink !== "" && scope.audioSinks.length > 0) {
            for (let i = 0; i < scope.audioSinks.length; i++) {
                if (scope.audioSinks[i] && scope.audioSinks[i].name === scope.defaultSink)
                    return scope.audioSinks[i].desc || ""
            }
        }
        if (scope.audioSinks.length > 0) return scope.audioSinks[0].desc || ""
        return "No output found"
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
        command: ["bash", "-c", "def=$(LC_ALL=C pactl get-default-sink 2>/dev/null); LC_ALL=C pactl list sinks 2>/dev/null | awk 'BEGIN{n=\"\";d=\"\";v=0;m=\"no\"} /^[ \\t]*Name:/{n=$2} /^[ \\t]*(Description|Beschreibung):/{sub(/^[ \\t]*(Description|Beschreibung): /,\" \");d=$0} /front-left.*\\/.*%/{for(i=1;i<=NF;i++) if($i ~ /%$/) {v=$i; break}} /^[ \\t]*(Mute|Stumm):/{m=$2} /^$/{if(n!=\"\"){print n\"|\"d\"|\"v\"|\"m; n=\"\";d=\"\";v=0;m=\"no\"}} END{if(n!=\"\")print n\"|\"d\"|\"v\"|\"m}'; echo \"DEF:$def\""]
        stdout: StdioCollector {
            onStreamFinished: {
                let sinks = []
                for (let l of (text || "").trim().split("\n")) {
                    l = l.trim()
                    if (l.indexOf("DEF:") === 0) { scope.defaultSink = l.substring(4).trim(); continue }
                    let p = l.split("|")
                    if (p.length < 2 || (p[0] || "").trim().length === 0) continue
                    sinks.push({ name: (p[0] || "").trim(), desc: Util.cleanAudioName((p[1] || "").trim(), (p[0] || "").trim()), vol: (p[2] || "").trim(), muted: ((p[3] || "no").trim().toLowerCase() === "yes" || (p[3] || "").trim().toLowerCase() === "ja") })
                }
                if (!sameAudioNodes(scope.audioSinks, sinks)) scope.audioSinks = sinks
            }
        }
    }
    Process {
        id: sourcesProc
        command: ["bash", "-c", "def=$(LC_ALL=C pactl get-default-source 2>/dev/null); LC_ALL=C pactl list sources 2>/dev/null | grep -v '\\.monitor' | awk 'BEGIN{n=\"\";d=\"\";v=0;m=\"no\"} /^[ \\t]*Name:/{n=$2} /^[ \\t]*(Description|Beschreibung):/{sub(/^[ \\t]*(Description|Beschreibung): /,\" \");d=$0} /front-left.*\\/.*%/{for(i=1;i<=NF;i++) if($i ~ /%$/) {v=$i; break}} /^[ \\t]*(Mute|Stumm):/{m=$2} /^$/{if(n!=\"\"){print n\"|\"d\"|\"v\"|\"m; n=\"\";d=\"\";v=0;m=\"no\"}} END{if(n!=\"\")print n\"|\"d\"|\"v\"|\"m}'; echo \"DEF:$def\"; vol=$(LC_ALL=C pactl get-source-volume \"$def\" 2>/dev/null | grep -oP '\\d+%' | head -1); mute=$(LC_ALL=C pactl get-source-mute \"$def\" 2>/dev/null | grep -oP '(yes|no)' | head -1); echo \"VOL:$vol|$mute\""]
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
                    srcs.push({ name: (p[0] || "").trim(), desc: Util.cleanAudioName((p[1] || "").trim(), (p[0] || "").trim()) })
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
    Process {
        id: mixerProc
        command: ["bash", "-c", "command -v pavucontrol >/dev/null 2>&1 && pavucontrol 2>/dev/null &"]
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
    function sinkGlyph(desc: string, name: string): string {
        let d = ((desc || "") + " " + (name || "")).toLowerCase()
        if (d.indexOf("headphone") !== -1 || d.indexOf("headset") !== -1 || d.indexOf("kopfhörer") !== -1) return "󰋋"
        if (d.indexOf("hdmi") !== -1 || d.indexOf("displayport") !== -1) return "󰍹"
        if (d.indexOf("bluetooth") !== -1 || d.indexOf("bluez") !== -1) return "󰂯"
        if (d.indexOf("usb") !== -1) return "󰓃"
        return "󰕾"
    }
    function appInitial(name: string): string {
        let s = (name || "").trim()
        return s.length > 0 ? s.charAt(0).toUpperCase() : "♪"
    }

    // ---------- New design primitives (vertical card layout) ----------
    component SectionLabel: Text {
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(10)
        font.weight: Font.Bold
        font.letterSpacing: 1.2
    }
    component Card: Rectangle {
        antialiasing: Theme.shapesAa
        radius: Theme.cornerRadiusSmall
        color: Theme.cardBg
        border.color: Theme.divider
        border.width: 1
    }
    component IconBtn: Rectangle {
        id: iconBtnRoot
        required property string glyph
        signal pressed()
        width: 28; height: 28
        radius: Theme.cornerRadiusSmall
        antialiasing: Theme.shapesAa
        color: btnMouse.containsMouse ? Theme.bgHover : "transparent"
        border.color: btnMouse.containsMouse ? Theme.divider : "transparent"
        border.width: 1
        Text {
            anchors.centerIn: parent
            text: iconBtnRoot.glyph
            color: btnMouse.containsMouse ? Theme.accent : Theme.textSecondary
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fs(13)
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconBtnRoot.pressed()
        }
    }
    component MutePill: Rectangle {
        id: pillRoot
        required property bool muted
        signal pressed()
        implicitWidth: pillLabel.implicitWidth + 24
        implicitHeight: 26
        radius: height / 2
        antialiasing: Theme.shapesAa
        color: pillMouse.containsMouse
            ? (muted ? Theme.withAlpha(Theme.errorColor, 0.28) : Theme.withAlpha(Theme.accent, 0.28))
            : (muted ? Theme.withAlpha(Theme.errorColor, 0.16) : Theme.withAlpha(Theme.accent, 0.16))
        border.color: muted ? Theme.errorColor : Theme.accent
        border.width: 1
        Text {
            id: pillLabel
            anchors.centerIn: parent
            text: pillRoot.muted ? "󰝟  UNMUTE" : "󰕾  MUTE"
            color: pillRoot.muted ? Theme.errorColor : Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(10)
            font.weight: Font.Bold
            font.letterSpacing: 0.6
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pillRoot.pressed()
        }
    }
    component ModernSlider: Item {
        id: slRoot
        property real value: 0
        property real minimum: 0
        property real maximum: 1
        property real step: 0.05
        property bool dragging: false
        property real liveValue: 0
        property color fill: Theme.accent
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
            height: 5
            radius: 2
            color: Theme.withAlpha(Theme.textPrimary, 0.16)
        }
        Rectangle {
            anchors.left: slTrack.left
            anchors.verticalCenter: slTrack.verticalCenter
            height: 5
            radius: 2
            width: slTrack.width * slRoot.progress
            color: slRoot.fill
        }
        Rectangle {
            id: slThumb
            width: 13; height: 13
            radius: 6
            anchors.verticalCenter: slTrack.verticalCenter
            x: Math.max(0, Math.min(slTrack.width - width, slTrack.width * slRoot.progress - width / 2))
            color: slRoot.dragging ? slRoot.fill : Theme.textPrimary
            border.color: slRoot.fill
            border.width: 2
        }
        Rectangle {
            width: 22; height: 22
            radius: 11
            anchors.centerIn: slThumb
            z: -1
            color: (slRoot.dragging || slMouse.containsMouse) ? Theme.withAlpha(slRoot.fill, 0.18) : "transparent"
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
                let v = snap(valueFromX(mouse.x))
                slRoot.liveValue = v
                slRoot.moved(v)
            }
            onClicked: mouse => { if (mouse.button === Qt.RightButton) slRoot.rightClicked() }
            onPositionChanged: mouse => {
                if (!slRoot.dragging) return
                let v = snap(valueFromX(mouse.x))
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
    component DeviceRow: Rectangle {
        id: devRect
        required property string glyph
        required property string label
        required property string sub
        required property bool isActive
        required property bool isMuted
        signal picked()
        implicitHeight: 40
        radius: Theme.cornerRadiusSmall
        antialiasing: Theme.shapesAa
        color: devRect.isActive ? Theme.withAlpha(Theme.accent, 0.14)
            : devMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.07) : "transparent"
        border.color: devRect.isActive ? Theme.withAlpha(Theme.accent, 0.55) : "transparent"
        border.width: devRect.isActive ? 1 : 0
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 10
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 10; Layout.preferredHeight: 10
                Layout.alignment: Qt.AlignVCenter
                radius: 5
                color: devRect.isActive ? Theme.accent : "transparent"
                border.color: devRect.isActive ? Theme.accent : Theme.textMuted
                border.width: devRect.isActive ? 0 : 1
            }
            Text {
                text: devRect.glyph
                color: devRect.isActive ? Theme.textPrimary : Theme.textSecondary
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(16)
                Layout.preferredWidth: 22
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignVCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: devRect.label
                    color: devRect.isActive ? Theme.textPrimary : Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(12)
                    font.weight: devRect.isActive ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text {
                    visible: devRect.sub !== ""
                    Layout.fillWidth: true
                    text: devRect.sub
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(10)
                    elide: Text.ElideRight
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
            }
            Text {
                visible: devRect.isMuted
                text: "󰝟"
                color: Theme.errorColor
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(13)
                Layout.alignment: Qt.AlignVCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
        }
        MouseArea {
            id: devMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: devRect.picked()
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: scope._winVisible && Theme.isPrimaryScreen(modelData)
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
                    else if (event.key === Qt.Key_M) { VolumeService.toggleMute(); event.accepted = true }
                    else if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) { VolumeService.setVolumeFrac(scope.outVol - 0.05); event.accepted = true }
                    else if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) { VolumeService.setVolumeFrac(scope.outVol + 0.05); event.accepted = true }
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
                // Vertical rectangle: narrow width, height grows with content.
                width: 320
                implicitHeight: Math.max(120, Math.min(contentCol.implicitHeight + 20, volAnchor.screenHeight - volAnchor.edgeOffset - 24))
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
                    anchors.margins: 10
                    contentHeight: contentCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height
                    Column {
                        id: contentCol
                        width: parent.width
                        spacing: 8
                        // Header: title + status pill + mixer shortcut.
                        RowLayout {
                            width: parent.width
                            spacing: 6
                            Text {
                                text: "Audio"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(13)
                                font.weight: Font.Bold
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            Rectangle {
                                Layout.preferredHeight: 20
                                Layout.preferredWidth: Math.max(52, statusTxt.implicitWidth + 18)
                                radius: 12
                                color: scope.outMuted ? Theme.withAlpha(Theme.errorColor, 0.16) : Theme.withAlpha(Theme.accent, 0.16)
                                border.color: scope.outMuted ? Theme.errorColor : Theme.accent
                                border.width: 1
                                Text {
                                    id: statusTxt
                                    anchors.centerIn: parent
                                    text: scope.statusText
                                    color: scope.outMuted ? Theme.errorColor : Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fs(10)
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.0
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                            }
                            IconBtn {
                                glyph: "󰍹"
                                onPressed: if (!mixerProc.running) mixerProc.running = true
                            }
                        }
                        // Hero output card.
                        Card {
                            width: parent.width
                            implicitHeight: heroCol.implicitHeight + 20
                            ColumnLayout {
                                id: heroCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    Rectangle {
                                        Layout.preferredWidth: 40; Layout.preferredHeight: 40
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: Theme.cornerRadiusSmall
                                        color: scope.anyAudible ? Theme.withAlpha(Theme.accent, 0.18) : Theme.withAlpha(Theme.textPrimary, 0.06)
                                        border.color: scope.anyAudible ? Theme.withAlpha(Theme.accent, 0.5) : Theme.divider
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            text: VolumeService.icon
                                            color: scope.outMuted ? Theme.textMuted : Theme.textPrimary
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: Theme.fs(19)
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2
                                        SectionLabel { text: "OUTPUT" }
                                        Row {
                                            spacing: 2
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: scope.outMuted ? "0" : String(VolumeService.pct || 0)
                                                color: scope.outMuted ? Theme.textMuted : Theme.textPrimary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fs(22)
                                                font.weight: Font.Bold
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.verticalCenterOffset: -5
                                                text: "%"
                                                color: Theme.textSecondary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fs(11)
                                                font.weight: Font.Bold
                                                antialiasing: Theme.textAa
                                                renderType: Theme.textRenderType
                                            }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: scope.activeSinkDesc
                                            color: Theme.textSecondary
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fs(10)
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                            antialiasing: Theme.textAa
                                            renderType: Theme.textRenderType
                                        }
                                    }
                                    MutePill {
                                        Layout.alignment: Qt.AlignVCenter
                                        muted: scope.outMuted
                                        onPressed: VolumeService.toggleMute()
                                    }
                                }
                                ModernSlider {
                                    id: outSlider
                                    Layout.fillWidth: true
                                    minimum: 0
                                    maximum: 1
                                    step: 0.05
                                    value: scope.outVol
                                    fill: scope.outMuted ? Theme.textMuted : Theme.accent
                                    onMoved: v => VolumeService.setVolumeFrac(v)
                                    onReleased: v => Theme.triggerVolumeOsd()
                                    onRightClicked: VolumeService.toggleMute()
                                }
                                }
                        }
                        // Output devices card.
                        Card {
                            visible: scope.audioSinks.length > 0
                            width: parent.width
                            implicitHeight: sinkCol.implicitHeight + 20
                            ColumnLayout {
                                id: sinkCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6
                                RowLayout {
                                    Layout.fillWidth: true
                                    SectionLabel { text: "DEVICES  •  " + scope.audioSinks.length; Layout.fillWidth: true }
                                }
                                Repeater {
                                    model: scope.audioSinks
                                    delegate: DeviceRow {
                                        required property var modelData
                                        required property int index
                                        glyph: scope.sinkGlyph(modelData.desc, modelData.name)
                                        label: modelData.desc
                                        sub: (modelData.vol || "") !== "" ? String(modelData.vol) + (modelData.muted ? "  •  muted" : "") : ""
                                        isActive: scope.defaultSink !== "" && modelData.name === scope.defaultSink
                                        isMuted: !!modelData.muted
                                        Layout.fillWidth: true
                                        onPicked: scope.setDefaultSink(modelData.name)
                                    }
                                }
                            }
                        }
                        // Input card.
                        Card {
                            visible: scope.audioSources.length > 0
                            width: parent.width
                            implicitHeight: micCol.implicitHeight + 20
                            ColumnLayout {
                                id: micCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    SectionLabel { text: "INPUT"; Layout.fillWidth: true }
                                    Text {
                                        text: Math.round(inSlider.liveValue * 100) + "%"
                                        color: scope.inMuted ? Theme.textMuted : Theme.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fs(10)
                                        font.weight: Font.Bold
                                        Layout.alignment: Qt.AlignVCenter
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                    IconBtn {
                                        glyph: scope.inMuted ? "󰝟" : "󰍬"
                                        onPressed: scope.toggleInputMute()
                                    }
                                }
                                ModernSlider {
                                    id: inSlider
                                    Layout.fillWidth: true
                                    minimum: 0
                                    maximum: 1
                                    step: 0.05
                                    value: scope.inVol
                                    fill: scope.inMuted ? Theme.textMuted : Theme.accent
                                    onMoved: v => scope.setInputVolume(v)
                                    onRightClicked: scope.toggleInputMute()
                                }
                                Repeater {
                                    model: scope.audioSources
                                    delegate: DeviceRow {
                                        required property var modelData
                                        required property int index
                                        glyph: "󰍬"
                                        label: modelData.desc
                                        sub: ""
                                        isActive: scope.defaultSource !== "" && modelData.name === scope.defaultSource
                                        isMuted: false
                                        Layout.fillWidth: true
                                        implicitHeight: 36
                                        onPicked: scope.setDefaultSource(modelData.name)
                                    }
                                }
                            }
                        }
                        // Per-app mixer card.
                        Card {
                            visible: scope.audioStreams.length > 0
                            width: parent.width
                            implicitHeight: appCol.implicitHeight + 20
                            ColumnLayout {
                                id: appCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6
                                SectionLabel { text: "APPS  •  " + scope.audioStreams.length }
                                Repeater {
                                    model: scope.audioStreams
                                    delegate: ColumnLayout {
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        spacing: 6
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10
                                            Rectangle {
                                                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                                                Layout.alignment: Qt.AlignVCenter
                                                radius: Theme.cornerRadiusSmall
                                                color: modelData.muted ? Theme.withAlpha(Theme.textPrimary, 0.05) : Theme.withAlpha(Theme.accent, 0.14)
                                                border.color: Theme.divider
                                                border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: scope.appInitial(modelData.name)
                                                    color: modelData.muted ? Theme.textMuted : Theme.textPrimary
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fs(12)
                                                    font.weight: Font.Bold
                                                    antialiasing: Theme.textAa
                                                    renderType: Theme.textRenderType
                                                }
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: 1
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.name
                                                    color: modelData.muted ? Theme.textSecondary : Theme.textPrimary
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fs(12)
                                                    font.weight: Font.DemiBold
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                    antialiasing: Theme.textAa
                                                    renderType: Theme.textRenderType
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.muted ? "muted" : Math.round(modelData.vol) + "%"
                                                    color: Theme.textMuted
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fs(10)
                                                    antialiasing: Theme.textAa
                                                    renderType: Theme.textRenderType
                                                }
                                            }
                                            IconBtn {
                                                glyph: modelData.muted ? "󰝟" : "󰕾"
                                                onPressed: scope.toggleStreamMute(modelData.index)
                                            }
                                        }
                                        ModernSlider {
                                            Layout.fillWidth: true
                                            Layout.leftMargin: 42
                                            minimum: 0
                                            maximum: 1.5
                                            step: 0.05
                                            value: modelData.vol / 100
                                            fill: modelData.muted ? Theme.textMuted : Theme.accent
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
