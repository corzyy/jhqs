pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../themes"
import "../services"
import "../Ui"
import "./calendar" as CalUI

Scope {
    id: mediaScope
    property bool showMedia: false
    signal dismissed()
    property bool _winVisible: showMedia
    Timer { id: mediaHideTimer; interval: Theme.animSlow + 20; repeat: false; onTriggered: if (!mediaScope.showMedia) mediaScope._winVisible = false }
    onShowMediaChanged: {
        if (showMedia) { _winVisible = true; mediaHideTimer.stop() } else mediaHideTimer.restart()
    }
    readonly property string barPos: Theme.barPosition
    readonly property int screenGap: 6
    property int panelGap: screenGap - Theme.barThickness
    readonly property bool isMinimal: Theme.minimalTheme

    readonly property var curPlayer: MediaService.currentPlayer
    readonly property bool hasPlayer: MediaService.hasPlayer
    readonly property bool playing: MediaService.isPlaying
    readonly property real trackLen: {
        try { let l = mediaScope.curPlayer ? (mediaScope.curPlayer.length || 0) : 0; return (isFinite(l) && l > 0) ? l : 0 } catch (e) { return 0 }
    }
    readonly property real trackPos: {
        try { let p = mediaScope.curPlayer ? (mediaScope.curPlayer.position || 0) : 0; return (isFinite(p) && p > 0) ? p : 0 } catch (e) { return 0 }
    }
    readonly property real trackFrac: trackLen > 0 ? Math.max(0, Math.min(1, trackPos / trackLen)) : 0
    function fmtTime(s: real): string {
        if (!isFinite(s) || s < 0) return "0:00"
        let t = Math.floor(s)
        let m = Math.floor(t / 60)
        let r = t % 60
        return m + ":" + (r < 10 ? "0" + r : "" + r)
    }
    function trackTitle(p: var): string {
        try { let t = p ? (p.trackTitle || "") : ""; if (t !== "") return t } catch (e) {}
        try { let i = p ? (p.identity || "") : ""; if (i !== "") return i } catch (e2) {}
        return "Unknown title"
    }
    function trackArtist(p: var): string {
        try { let a = p ? (p.trackArtist || "") : ""; if (a !== "") return a } catch (e) {}
        try { let i = p ? (p.identity || "") : ""; return i } catch (e2) { return "" }
    }
    function appIcon(p: var): string {
        if (!p) return ""
        let cands = []
        try {
            if (p.desktopEntry && p.desktopEntry !== "") cands.push(p.desktopEntry, String(p.desktopEntry).toLowerCase())
            if (p.identity && p.identity !== "") cands.push(p.identity, String(p.identity).toLowerCase())
        } catch (e) {}
        for (let i = 0; i < cands.length; i++) {
            try {
                let u = Quickshell.iconPath(cands[i], true)
                if (u && u !== "" && !u.includes("image-missing")) return u
            } catch (e2) {}
        }
        try {
            let dbus = p.dbusName || ""
            let m = (/org\.mpris\.MediaPlayer2\.(.+)/).exec(dbus)
            if (m && m[1]) {
                let u2 = Quickshell.iconPath(m[1].split(".")[0], true)
                if (u2 && u2 !== "" && !u2.includes("image-missing")) return u2
            }
        } catch (e3) {}
        return ""
    }
    function seekFrac(f: real): void {
        if (trackLen <= 0) return
        let c = Math.max(0, Math.min(1, f))
        try { if (mediaScope.curPlayer) mediaScope.curPlayer.position = c * trackLen } catch (e) {}
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
            height: 4
            radius: 2
            color: Theme.withAlpha(Theme.textPrimary, 0.18)
        }
        Rectangle {
            anchors.left: slTrack.left
            anchors.verticalCenter: slTrack.verticalCenter
            height: 4
            radius: 2
            width: slTrack.width * slRoot.progress
            color: Theme.textPrimary
            Behavior on width { enabled: !slRoot.dragging; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            width: 14; height: 14
            radius: 7
            color: Theme.textPrimary
            border.color: Theme.bg
            border.width: 2
            anchors.verticalCenter: slTrack.verticalCenter
            x: Math.max(0, Math.min(slTrack.width - width, slTrack.width * slRoot.progress - width / 2))
            scale: slMouse.containsMouse || slRoot.dragging ? 1.15 : 1.0
            Behavior on x { enabled: !slRoot.dragging; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
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
    component OmTransport: Rectangle {
        id: trRoot
        required property string glyph
        property bool primary: false
        signal pressed()
        antialiasing: Theme.shapesAa
        implicitWidth: primary ? 56 : 40
        implicitHeight: 32
        radius: 0
        color: trMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08) : (primary && mediaScope.playing ? Theme.withAlpha(Theme.accent, 0.16) : "transparent")
        border.color: (primary && mediaScope.playing) ? Theme.accent : Theme.withAlpha(Theme.textPrimary, 0.25)
        border.width: (primary && mediaScope.playing) ? 2 : 1
        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        scale: trMouse.pressed ? 0.94 : 1.0
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            anchors.centerIn: parent
            text: trRoot.glyph
            color: Theme.textPrimary
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fs(16)
        }
        MouseArea {
            id: trMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: trRoot.pressed()
        }
    }
    component SourceRow: Rectangle {
        id: srcRect
        required property var player
        required property bool isActive
        signal picked()
        antialiasing: Theme.shapesAa
        color: srcMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08) : (isActive ? Theme.withAlpha(Theme.textPrimary, 0.08) : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        Row {
            anchors.fill: parent
            anchors.leftMargin: 6; anchors.rightMargin: 6
            spacing: 8
            Item {
                width: 24
                height: 24
                anchors.verticalCenter: parent.verticalCenter
                IconImage {
                    id: appImg
                    anchors.fill: parent
                    source: mediaScope.appIcon(srcRect.player)
                    asynchronous: true
                    implicitSize: Qt.size(24, 24)
                    visible: source !== ""
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    visible: appImg.source === ""
                    anchors.centerIn: parent
                    text: "󰎆"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(14)
                    color: srcRect.isActive ? Theme.textPrimary : Theme.textSecondary
                }
            }
            Column {
                width: parent.width - 24 - 8 - 16 - 8 - 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    width: parent.width
                    text: mediaScope.trackTitle(srcRect.player)
                    color: Theme.textPrimary
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(12)
                    font.weight: srcRect.isActive ? Font.Bold : Font.Normal
                    elide: Text.ElideRight
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    visible: text !== ""
                    width: parent.width
                    text: mediaScope.trackArtist(srcRect.player)
                    color: Theme.textSecondary
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(10)
                    elide: Text.ElideRight
                }
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                visible: {
                    try { return !!(srcRect.player && srcRect.player.isPlaying) } catch (e) { return false }
                }
                text: "󰐊"
                color: Theme.accent
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(12)
                width: 16
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: srcMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: srcRect.picked()
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: mediaScope._winVisible && modelData.name === "DP-1"
            color: "transparent"
            exclusiveZone: 0
            anchors { top: true; left: true; right: true; bottom: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "mediapanel"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) { mediaScope.dismissed(); event.accepted = true }
                    else if (mediaScope.isMinimal && mediaScope.hasPlayer && event.key === Qt.Key_Space) { MediaService.togglePlay(); event.accepted = true }
                    else if (mediaScope.isMinimal && mediaScope.hasPlayer && event.key === Qt.Key_Left) { MediaService.playPrev(); event.accepted = true }
                    else if (mediaScope.isMinimal && mediaScope.hasPlayer && event.key === Qt.Key_Right) { MediaService.playNext(); event.accepted = true }
                }
                Component.onCompleted: forceActiveFocus()
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: mediaScope.dismissed()
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                id: mediaBox
                width: mediaScope.isMinimal ? 380 : 300
                implicitHeight: mediaScope.isMinimal ? Math.max(120, Math.min(contentCol.implicitHeight + 36, mediaAnchor.screenHeight - mediaAnchor.edgeOffset - 24)) : Math.max(120, Math.min(20 + musicPlayer.contentH, mediaAnchor.screenHeight - mediaAnchor.edgeOffset - 24))
                Behavior on implicitHeight { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
                BarAnchor {
                    id: mediaAnchor
                    moduleId: "media"
                    barPos: mediaScope.barPos
                    panelWidth: mediaBox.width
                    panelHeight: mediaBox.implicitHeight
                    screenWidth: mediaBox.parent.width
                    screenHeight: mediaBox.parent.height
                    gap: mediaScope.panelGap
                    fallbackX: (mediaBox.parent.width - mediaBox.width) / 2
                    fallbackY: (mediaBox.parent.height - mediaBox.implicitHeight) / 2
                }
                x: mediaAnchor.panelX
                y: mediaAnchor.panelY
                Behavior on x { enabled: mediaAnchor.valid && mediaBox.width > 0 && mediaBox.implicitHeight > 0 && mediaSpring.offset === 0; NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
                Behavior on y { enabled: mediaAnchor.valid && mediaBox.width > 0 && mediaBox.implicitHeight > 0 && mediaSpring.offset === 0; NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
                color: mediaScope.isMinimal ? Theme.bg : Theme.panelBg
                border.color: mediaScope.isMinimal ? Theme.accent : Theme.panelBorderColor
                border.width: mediaScope.isMinimal ? 2 : 1
                radius: mediaScope.isMinimal ? 0 : Theme.cornerRadius
                clip: true
                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }
                PanelSpring {
                    id: mediaSpring
                    slideFade: true
                    shown: mediaScope.showMedia
                    hiddenX: mediaScope.barPos === "left" ? -(mediaBox.width + 5) : mediaScope.barPos === "right" ? (mediaBox.width + 5) : 0
                    hiddenY: mediaScope.barPos === "top" ? -(mediaBox.implicitHeight + 5) : mediaScope.barPos === "bottom" ? (mediaBox.implicitHeight + 5) : 0
                }
                visible: mediaSpring.boxVisible
                opacity: mediaSpring.fade
                scale: mediaSpring.zoom
                transformOrigin: mediaAnchor.origin
                transform: Translate { x: mediaSpring.slideX; y: mediaSpring.slideY }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: mouse => mouse.accepted = true
                    onPressed: mouse => mouse.accepted = true
                    onWheel: wheel => wheel.accepted = true
                }
                Item {
                    visible: !mediaScope.isMinimal
                    anchors.fill: parent
                    anchors.margins: 10
                    CalUI.MusicPlayer {
                        id: musicPlayer
                        scope: MediaService
                        width: parent.width
                        height: parent.height
                    }
                }
                Flickable {
                    visible: mediaScope.isMinimal
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
                        Column {
                            width: parent.width
                            spacing: 6
                            visible: mediaScope.hasPlayer
                            Item {
                                width: parent.width
                                implicitHeight: Math.max(nowHeader.implicitHeight, nowTime.implicitHeight)
                                SectionHeader {
                                    id: nowHeader
                                    text: "NOW PLAYING"
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    id: nowTime
                                    visible: mediaScope.trackLen > 0
                                    text: mediaScope.fmtTime(seekSlider.dragging ? seekSlider.liveValue * mediaScope.trackLen : mediaScope.trackPos) + " / " + mediaScope.fmtTime(mediaScope.trackLen)
                                    color: Theme.textSecondary
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fs(10)
                                    font.weight: Font.Bold
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                            }
                            Text {
                                width: parent.width
                                text: mediaScope.curPlayer ? mediaScope.trackTitle(mediaScope.curPlayer) : ""
                                color: Theme.textPrimary
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(13)
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            Text {
                                visible: text !== ""
                                width: parent.width
                                text: mediaScope.curPlayer ? mediaScope.trackArtist(mediaScope.curPlayer) : ""
                                color: Theme.textSecondary
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(11)
                                elide: Text.ElideRight
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            OmSlider {
                                id: seekSlider
                                visible: mediaScope.trackLen > 0
                                width: parent.width
                                minimum: 0
                                maximum: 1
                                step: 0.005
                                value: mediaScope.trackFrac
                                onReleased: v => mediaScope.seekFrac(v)
                            }
                            Row {
                                width: parent.width
                                spacing: 8
                                OmTransport {
                                    glyph: "󰒮"
                                    onPressed: MediaService.playPrev()
                                }
                                OmTransport {
                                    glyph: mediaScope.playing ? "󰏤" : "󰐊"
                                    primary: true
                                    onPressed: MediaService.togglePlay()
                                }
                                OmTransport {
                                    glyph: "󰒭"
                                    onPressed: MediaService.playNext()
                                }
                            }
                        }
                        Text {
                            visible: !mediaScope.hasPlayer
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "No players found"
                            color: Theme.textMuted
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(11)
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                        Hairline { visible: mediaScope.hasPlayer && sourceRepeater.count > 1; width: parent.width }
                        Column {
                            visible: mediaScope.hasPlayer && sourceRepeater.count > 1
                            width: parent.width
                            spacing: 4
                            SectionHeader { text: "SOURCES" }
                            Repeater {
                                id: sourceRepeater
                                model: MediaService.allPlayers
                                delegate: SourceRow {
                                    required property var modelData
                                    required property int index
                                    player: modelData
                                    isActive: MediaService.currentPlayer === modelData
                                    width: parent.width
                                    implicitHeight: 34
                                    onPicked: {
                                        try { MediaService.selectedPlayer = modelData } catch (e) {}
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
