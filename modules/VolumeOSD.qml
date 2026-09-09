pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "../themes"
import "../Ui" as Ui

Scope {
    id: osdScope

    readonly property int barT: Theme.barThickness
    readonly property string barPos: Theme.barPosition
    readonly property bool isMinimal: Theme.minimalTheme
    readonly property int quattroPad: 10
    readonly property int quattroGap: 10
    readonly property int quattroIconGap: 16
    readonly property int quattroBarWidth: 96
    readonly property int quattroBottomMargin: 67
    readonly property string quattroMessage: displayMuted ? "Muted" : displayPct + "%"
    function iconForQuattro(pct: int, muted: bool): string {
        if (muted || pct <= 0) return ""
        if (pct <= 33) return ""
        if (pct <= 66) return ""
        return ""
    }

    property PwNode sink: Pipewire.defaultAudioSink
    property bool sinkReady: sink && sink.ready && sink.audio
    property int volPct: sinkReady ? Math.round(sink.audio.volume * 100) : 0
    property bool isMuted: sinkReady ? sink.audio.muted : false
    property string sinkIdentity: sink ? (sink.name + ":" + sink.id) : ""

    property bool osdVisible: false
    property bool _winVisible: osdVisible
    Timer { id: osdHideTimer; interval: Theme.panelHideDelay; repeat: false; onTriggered: if (!osdScope.osdVisible) osdScope._winVisible = false }
    onOsdVisibleChanged: {
        if (osdVisible) { _winVisible = true; osdHideTimer.stop() }
        else osdHideTimer.restart()
    }
    property bool inited: false
    property int lastPct: -1
    property bool lastMuted: false
    property bool sinkSwitchGuard: false
    Timer { id: sinkSwitchClear; interval: 400; repeat: false; onTriggered: osdScope.sinkSwitchGuard = false }

    onSinkIdentityChanged: {
        if (!inited) return
        sinkSwitchGuard = true
        sinkSwitchClear.restart()
        lastPct = volPct
        lastMuted = isMuted
    }
    onSinkReadyChanged: {
        if (!inited) return
        if (sinkReady) {
            sinkSwitchGuard = true
            sinkSwitchClear.restart()
            lastPct = volPct
            lastMuted = isMuted
        }
    }

    Timer {
        id: initTimer
        interval: 1500
        running: true
        repeat: false
        onTriggered: {
            osdScope.inited = true
            osdScope.lastPct = osdScope.volPct
            osdScope.lastMuted = osdScope.isMuted
        }
    }

    Timer {
        id: hideTimer
        interval: 1600
        repeat: false
        onTriggered: osdScope.osdVisible = false
    }

    function showVolume() {
        if (!inited) return
        if (!Theme.osdVolumeEnabled) return
        osdVisible = true
        hideTimer.interval = osdScope.isMinimal ? 1200 : 1600
        hideTimer.restart()
    }
    function showOsd() { showVolume() }

    onVolPctChanged: {
        if (!inited) return
        if (pollOverride && volPct === fallbackPct && isMuted === fallbackMuted) pollOverride = false
        if (sinkSwitchGuard) { lastPct = volPct; return }
        if (volPct !== lastPct) {
            if (lastPct !== -1) showVolume()
            lastPct = volPct
        }
    }
    onIsMutedChanged: {
        if (!inited) return
        if (pollOverride && isMuted === fallbackMuted && volPct === fallbackPct) pollOverride = false
        if (sinkSwitchGuard) { lastMuted = isMuted; return }
        if (isMuted !== lastMuted) {
            showVolume()
            lastMuted = isMuted
        }
    }

    Connections {
        target: Theme
        function onVolumeOsdTriggerChanged() { osdScope.showVolume() }
    }

    Process {
        id: eventMonProc
        running: true
        command: ["bash", "-c", "command -v pw-mon >/dev/null 2>&1 && exec pw-mon || sleep 2147483647"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { if (!externalDebounce.running) externalDebounce.restart() }
        }
        onExited: (code, status) => eventMonRestart.restart()
    }
    Timer { id: eventMonRestart; interval: 1000; repeat: false; onTriggered: if (!eventMonProc.running) eventMonProc.running = true }
    Timer {
        id: externalDebounce
        interval: 70
        repeat: false
        onTriggered: { if (!pollProc.running) pollProc.running = true }
    }

    Connections {
        target: osdScope.sink && osdScope.sink.audio ? osdScope.sink.audio : null
        ignoreUnknownSignals: true
        function onVolumeChanged() {
            if (!osdScope.inited || osdScope.sinkSwitchGuard) return
            if (!osdScope.sinkReady) return
            let p = Math.round(osdScope.sink.audio.volume * 100)
            if (p !== osdScope.lastPct) osdScope.showVolume()
        }
        function onMutedChanged() {
            if (!osdScope.inited || osdScope.sinkSwitchGuard) return
            if (!osdScope.sinkReady) return
            if (osdScope.sink.audio.muted !== osdScope.lastMuted) osdScope.showVolume()
        }
    }

    property bool pollOverride: false
    Process {
        id: pollProc
        command: ["bash", "-c", "/home/jakob/.config/quickshell/jhqs/scripts/volume.sh get 2>/dev/null | tr -d '\\n'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = (text || "").trim()
                if (txt.length === 0) return
                let muted = txt.toLowerCase() === "muted"
                let pct = -1
                if (txt.endsWith("%")) {
                    let n = parseInt(txt)
                    if (!isNaN(n)) pct = n
                }
                if (pct < 0 && !muted) return
                if (muted) pct = osdScope.displayPct
                if (pct !== osdScope.lastPct || muted !== osdScope.lastMuted) {
                    if (!osdScope.sinkReady) {
                        osdScope.fallbackPct = pct
                        osdScope.fallbackMuted = muted
                        osdScope.showVolume()
                    } else if (pct !== osdScope.volPct || muted !== osdScope.isMuted) {
                        osdScope.fallbackPct = pct
                        osdScope.fallbackMuted = muted
                        osdScope.pollOverride = true
                        osdScope.showVolume()
                        pollOverrideClearTimer.restart()
                    }
                    osdScope.lastPct = pct
                    osdScope.lastMuted = muted
                }
            }
        }
    }
    Timer { id: pollOverrideClearTimer; interval: 1200; repeat: false; onTriggered: osdScope.pollOverride = false }
    Timer {
        id: pollTimer
        interval: 5000
        running: osdScope.osdVisible || !osdScope.sinkReady
        repeat: true
        triggeredOnStart: false
        onTriggered: if (!pollProc.running && osdScope.inited) pollProc.running = true
    }

    IpcHandler {
        target: "volumeOsd"
        function show(): void { osdScope.showVolume() }
        function status(): string { return "visible=" + osdScope.osdVisible + " volPct=" + osdScope.volPct + " displayPct=" + osdScope.displayPct + " displayMuted=" + osdScope.displayMuted + " lastPct=" + osdScope.lastPct + " inited=" + osdScope.inited }
        function trigger(pct: int, muted: bool): void {
            if (!osdScope.sinkReady) {
                fallbackPct = pct
                fallbackMuted = muted
                osdScope.showVolume()
            }
        }
    }
    IpcHandler {
        target: "osd"
        function showVolume(): void { osdScope.showVolume() }
        function status(): string { return "visible=" + osdScope.osdVisible + " vol=" + osdScope.displayPct + (osdScope.displayMuted ? " muted" : "") }
    }
    property int fallbackPct: 0
    property bool fallbackMuted: false
    property int displayPct: pollOverride ? fallbackPct : (sinkReady ? volPct : fallbackPct)
    property bool displayMuted: pollOverride ? fallbackMuted : (sinkReady ? isMuted : fallbackMuted)

    function iconFor(pct: int, muted: bool): string {
        if (muted || pct === 0) return "󰝟"
        if (pct < 34) return "󰕿"
        if (pct < 67) return "󰖀"
        return "󰕾"
    }

    property bool osdDragging: false
    Process { id: osdVolSetProc; command: ["bash","-c","echo"] }
    Process { id: audioSettingsProc; command: ["bash", "-c", "command -v pavucontrol >/dev/null 2>&1 && pavucontrol 2>/dev/null &"] }
    function toggleOsdMute() {
        let m = !displayMuted
        if (sinkReady) {
            try { sink.audio.muted = m } catch(e) { }
        }
        let v = m ? "1" : "0"
        osdVolSetProc.command = ["bash","-c","wpctl set-mute @DEFAULT_AUDIO_SINK@ " + v + " 2>/dev/null; pactl set-sink-mute @DEFAULT_AUDIO_SINK@ " + v + " 2>/dev/null || true"]
        if (!osdVolSetProc.running) osdVolSetProc.running = true
        fallbackMuted = m
        showVolume()
    }
    function setOsdVolumePct(v: int) {
        let clamped = Math.max(0, Math.min(100, v))
        if (sinkReady) {
            try {
                if (sink.audio.muted) sink.audio.muted = false
                sink.audio.volume = clamped/100
            } catch(e) { }
        }
        let frac = (clamped/100).toFixed(2)
        osdVolSetProc.command = ["bash","-c","wpctl set-volume @DEFAULT_AUDIO_SINK@ "+frac+" 2>/dev/null; wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null; pactl set-sink-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null || true"]
        if (!osdVolSetProc.running) osdVolSetProc.running = true
        fallbackPct = clamped; fallbackMuted = false
        showVolume()
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: osdScope._winVisible && Theme.osdVolumeEnabled && modelData.name === "DP-1"
            color: "transparent"
            exclusiveZone: 0
            mask: Region { item: osdScope.isMinimal ? quattroWrapper : osdWrapper }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "volumeosd"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: true; left: true; right: true; bottom: true }

            Item {
                id: quattroWrapper
                visible: osdScope.isMinimal
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: osdScope.quattroBottomMargin
                width: quattroCard.width
                height: quattroCard.height
                opacity: osdScope.osdVisible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: osdScope.osdVisible ? Theme.panelAnimFade : Theme.panelAnimExit; easing.type: osdScope.osdVisible ? Theme.panelEasingFade : Theme.panelEasingExit } }

                Rectangle {
                    id: quattroCard
                    readonly property int iconW: Math.max(16, Math.ceil(widestIconMetrics.tightBoundingRect.width))
                    readonly property int valueW: Math.ceil(valueMetrics.advanceWidth)
                    width: 2 + osdScope.quattroPad + iconW + osdScope.quattroIconGap + osdScope.quattroBarWidth + osdScope.quattroGap + valueW + osdScope.quattroPad + 2
                    height: 2 + osdScope.quattroPad + 20 + osdScope.quattroPad + 2
                    radius: Theme.cornerRadius
                    color: Theme.bg
                    border.color: Theme.accent
                    border.width: 2
                    antialiasing: Theme.shapesAa

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 2 + osdScope.quattroPad
                        anchors.rightMargin: 2 + osdScope.quattroPad
                        anchors.topMargin: 2 + osdScope.quattroPad
                        anchors.bottomMargin: 2 + osdScope.quattroPad
                        spacing: osdScope.quattroGap
                        Item {
                            width: quattroCard.iconW + osdScope.quattroIconGap - osdScope.quattroGap
                            height: parent.height
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                x: Math.round((quattroCard.iconW - Math.ceil(iconMetrics.tightBoundingRect.width)) / 2 - iconMetrics.tightBoundingRect.x)
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: osdScope.iconForQuattro(osdScope.displayPct, osdScope.displayMuted)
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(20)
                                color: Theme.textPrimary
                                textFormat: Text.PlainText
                            }
                        }
                        Rectangle {
                            width: osdScope.quattroBarWidth
                            height: 6
                            radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.withAlpha(Theme.textPrimary, 0.45)
                            antialiasing: Theme.shapesAa
                            Rectangle {
                                height: parent.height
                                width: parent.width * Math.max(0, Math.min(1, osdScope.displayPct / 100))
                                radius: 3
                                color: osdScope.displayMuted ? Theme.errorColor : Theme.accent
                                antialiasing: Theme.shapesAa
                                Behavior on width {
                                    enabled: osdScope.osdVisible
                                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            width: quattroCard.valueW
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: osdScope.quattroMessage
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(14)
                            font.bold: true
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            textFormat: Text.PlainText
                        }
                    }

                    TextMetrics {
                        id: iconMetrics
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fs(20)
                        text: osdScope.iconForQuattro(osdScope.displayPct, osdScope.displayMuted)
                    }
                    TextMetrics {
                        id: widestIconMetrics
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fs(20)
                        text: ""
                    }
                    TextMetrics {
                        id: valueMetrics
                        font.family: Theme.iconFontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(14)
                        text: "Muted"
                    }
                }
            }

            Item {
                id: osdWrapper
                visible: !osdScope.isMinimal
                readonly property int pillW: 64
                readonly property int pillH: 320
                readonly property int pillR: Theme.cornerRadius
                readonly property int bottomClear: 12
                function applyPosAnchors(): void {
                    anchors.top = undefined
                    anchors.bottom = undefined
                    anchors.verticalCenter = undefined
                    anchors.horizontalCenter = undefined
                    anchors.right = undefined
                    if (Theme.osdPosition === "top") { anchors.top = parent.top; anchors.horizontalCenter = parent.horizontalCenter }
                    else if (Theme.osdPosition === "bottom") { anchors.bottom = parent.bottom; anchors.horizontalCenter = parent.horizontalCenter }
                    else { anchors.right = parent.right; anchors.verticalCenter = parent.verticalCenter }
                }
                Component.onCompleted: applyPosAnchors()
                Connections { target: Theme; function onOsdPositionChanged() { osdWrapper.applyPosAnchors() } }
                anchors.rightMargin: 10 + (osdScope.barPos === "right" ? osdScope.barT : 0)
                anchors.bottomMargin: Theme.osdPosition === "bottom" ? (osdWrapper.bottomClear + (osdScope.barPos === "bottom" ? osdScope.barT : 0)) : 0
                anchors.topMargin: Theme.osdPosition === "top" ? (osdScope.barT + 8) : 0
                width: pillW
                height: pillH
                opacity: osdScope.osdVisible ? 1 : 0
                scale: osdScope.osdVisible ? 1 : 0.88
                transform: Translate {
                    id: osdSlide
                    y: osdScope.osdVisible ? 0 : (Theme.osdPosition === "top" ? -22 : 22)
                    x: osdScope.osdVisible ? 0 : (Theme.osdPosition === "right" ? 22 : 0)
                    Behavior on y { NumberAnimation { duration: osdScope.osdVisible ? Theme.panelAnimSlide : Theme.panelAnimExit; easing.type: osdScope.osdVisible ? Theme.panelEasingSlide : Theme.panelEasingExit; easing.overshoot: Theme.panelOvershootSlide } }
                    Behavior on x { NumberAnimation { duration: osdScope.osdVisible ? Theme.panelAnimSlide : Theme.panelAnimExit; easing.type: osdScope.osdVisible ? Theme.panelEasingSlide : Theme.panelEasingExit; easing.overshoot: Theme.panelOvershootSlide } }
                }
                Behavior on opacity { NumberAnimation { duration: osdScope.osdVisible ? Theme.panelAnimFade : Theme.panelAnimExit; easing.type: osdScope.osdVisible ? Theme.panelEasingFade : Theme.panelEasingExit } }
                Behavior on scale { NumberAnimation { duration: osdScope.osdVisible ? Theme.panelAnimScale : Theme.panelAnimExit; easing.type: osdScope.osdVisible ? Theme.panelEasingScale : Theme.panelEasingExit; easing.overshoot: osdScope.osdVisible ? Theme.panelOvershootScale : 0 } }

                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.fill: parent
                    anchors.leftMargin: 2
                    anchors.topMargin: 2
                    radius: osdWrapper.pillR
                    color: Theme.scrim
                    opacity: osdScope.osdVisible ? 0.18 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }
                }

                Rectangle {
                    antialiasing: Theme.shapesAa
                    id: osdBox
                    anchors.fill: parent
                    radius: osdWrapper.pillR
                    color: Theme.panelBg
                    border.color: Theme.panelBorderColor
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.topMargin: 12
                        anchors.bottomMargin: 12
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                anchors.centerIn: parent
                                text: osdScope.iconFor(osdScope.displayPct, osdScope.displayMuted)
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(19)
                                color: osdScope.displayMuted ? Theme.errorColor : Theme.textPrimary
                                horizontalAlignment: Text.AlignHCenter
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: osdScope.toggleOsdMute()
                            }
                        }

                        Ui.MSlider {
                            id: barV
                            Layout.fillHeight: true
                            Layout.alignment: Qt.AlignHCenter
                            orientation: "vertical"
                            from: 0; to: 100; value: osdScope.displayPct; stepSize: 1
                            showStopDot: false; showValueLabel: false; showTicks: false
                            trackHeight: 24
                            trackRadius: 12
                            handleWidth: 4
                            handleHeight: 28
                            stateLayerSize: 48
                            trackGap: 4
                            activeTrackColor: osdScope.displayMuted ? Theme.withAlpha(Theme.errorColor, 0.95) : Theme.accent
                            inactiveTrackColor: osdScope.displayMuted ? Theme.withAlpha(Theme.bgHover, 0.9) : Theme.bgHover
                            handleColor: osdScope.displayMuted ? Theme.errorColor : Theme.accent
                            stateLayerColor: osdScope.displayMuted ? Theme.errorColor : Theme.accent
                            onMoved: v => osdScope.setOsdVolumePct(Math.round(v))
                            onPressedChanged: pressed => { osdScope.osdDragging = pressed; if (pressed) osdScope.showVolume() }
                        }

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                anchors.centerIn: parent
                                text: "󰒓"
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(15)
                                color: settingsHover.containsMouse ? Theme.textPrimary : Theme.textMuted
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }
                            MouseArea {
                                id: settingsHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { if (!audioSettingsProc.running) audioSettingsProc.running = true }
                            }
                        }
                    }
                }
            }
        }
    }
}
