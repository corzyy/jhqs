pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../themes"

Item {
    id: root
    required property var scope
    readonly property string contentFont: (root.scope && root.scope.contentFontFamily) || Theme.fontFamily

    readonly property var players: root.scope.allPlayers
    readonly property int playerCount: players.length
    readonly property real carouselH: 156
    readonly property real pageW: Math.max(0, carousel.width)
    readonly property real contentH: playerCount === 0 ? placeholderCol.implicitHeight + 32 : carouselH
    implicitHeight: contentH

    Layout.preferredWidth: 260
    Layout.fillWidth: true
    Layout.fillHeight: true

    function indexOfPlayer(p: var): int {
        if (!p) return -1
        let a = root.players
        for (let i = 0; i < a.length; i++) if (a[i] === p) return i
        return -1
    }
    function appIcon(p: var): string {
        if (!p) return ""
        let cands = []
        try {
            if (p.desktopEntry && p.desktopEntry !== "") cands.push(p.desktopEntry, String(p.desktopEntry).toLowerCase())
            if (p.identity && p.identity !== "") cands.push(p.identity, String(p.identity).toLowerCase())
        } catch (e) { }
        for (let i = 0; i < cands.length; i++) {
            try {
                let u = Quickshell.iconPath(cands[i], true)
                if (u && u !== "" && !u.includes("image-missing")) return u
            } catch (e2) { }
        }
        try {
            let dbus = p.dbusName || ""
            let m = (/org\.mpris\.MediaPlayer2\.(.+)/).exec(dbus)
            if (m && m[1]) {
                let u2 = Quickshell.iconPath(m[1].split(".")[0], true)
                if (u2 && u2 !== "" && !u2.includes("image-missing")) return u2
            }
        } catch (e3) { }
        return ""
    }
    function syncCarouselToCurrent(): void {
        let i = indexOfPlayer(root.scope.currentPlayer)
        if (i >= 0 && carousel.currentIndex !== i && !carousel.moving && !carousel.flicking)
            carousel.currentIndex = i
    }
    function stepSource(dir: int): void {
        if (root.playerCount < 2) return
        let n = root.playerCount
        let i = (((carousel.currentIndex + dir) % n) + n) % n
        carousel.currentIndex = i
        if (root.players[i])
            try { root.scope.selectedPlayer = root.players[i] } catch (e) { }
    }
    property var curPlayer: scope.currentPlayer
    onCurPlayerChanged: syncCarouselToCurrent()
    onPlayerCountChanged: syncCarouselToCurrent()
    Component.onCompleted: syncCarouselToCurrent()

    ColumnLayout {
        id: placeholderCol
        anchors.centerIn: parent
        width: parent.width - 20
        spacing: 10
        visible: root.playerCount === 0
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            Layout.alignment: Qt.AlignHCenter
            text: "󰎆"
            font.family: root.contentFont
            font.pixelSize: Theme.fs(36)
            color: Theme.textMuted
            opacity: 0.6
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Keine Wiedergabe"
            font.family: root.contentFont
            font.pixelSize: Theme.fs(11)
            font.weight: Font.Medium
            color: Theme.textSecondary
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Starte einen Player um hier\nSteuerung zu sehen"
            font.family: root.contentFont
            font.pixelSize: Theme.fs(9)
            color: Theme.textMuted
            wrapMode: Text.WordWrap
        }
    }

    ColumnLayout {
        id: musicMainCol
        visible: root.playerCount > 0
        anchors.fill: parent
        spacing: 6

        ListView {
            id: carousel
            Layout.fillWidth: true
            Layout.preferredHeight: root.carouselH
            orientation: ListView.Horizontal
            model: root.players
            spacing: 8
            clip: false
            boundsBehavior: Flickable.StopAtBounds
            snapMode: ListView.SnapToItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: Math.max(0, (width - root.pageW) / 2)
            preferredHighlightEnd: preferredHighlightBegin + root.pageW
            highlightMoveDuration: Theme.animSlow
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (root.playerCount < 2) return
                    const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                    if (d > 0) root.stepSource(-1)
                    else if (d < 0) root.stepSource(1)
                    else return
                    event.accepted = true
                }
            }
            onCurrentIndexChanged: {
                if ((carousel.moving || carousel.flicking) && root.players[carousel.currentIndex])
                    try { root.scope.selectedPlayer = root.players[carousel.currentIndex] } catch (e) { }
            }
            onMovementEnded: {
                if (root.players[carousel.currentIndex] && root.scope.currentPlayer !== root.players[carousel.currentIndex])
                    try { root.scope.selectedPlayer = root.players[carousel.currentIndex] } catch (e2) { }
            }

            delegate: Item {
                id: page
                required property var modelData
                required property int index
                property var player: modelData
                width: root.pageW
                height: carousel.height

                Rectangle {
                    antialiasing: Theme.shapesAa
                    id: card
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    color: Theme.cardBg
                    clip: true
                    property bool artReady: artImg.status === Image.Ready
                    property color ink: artReady ? "#ffffff" : Theme.textPrimary
                    property color inkDim: artReady ? Theme.withAlpha("#ffffff", 0.75) : Theme.textSecondary
                    property color chipBg: artReady ? Theme.withAlpha("#ffffff", 0.20) : Theme.surface2
                    Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingSmooth } }

                    Image {
                        smooth: Theme.imageSmooth
                        mipmap: Theme.imageMipmap
                        id: artImg
                        anchors.fill: parent
                        visible: false
                        source: page.player ? (page.player.trackArtUrl || "") : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize.width: 320
                        sourceSize.height: 320
                        onStatusChanged: if (status === Image.Error) source = ""
                    }
                    Canvas {
                        id: coverCanvas
                        anchors.fill: parent
                        visible: artUrl !== ""
                        property string artUrl: page.player ? (page.player.trackArtUrl || "") : ""
                        property string cachedUrl: ""
                        property real rad: card.radius
                        onArtUrlChanged: {
                            if (cachedUrl !== "" && cachedUrl !== artUrl) unloadImage(cachedUrl)
                            cachedUrl = artUrl
                            if (artUrl !== "") loadImage(artUrl)
                            requestPaint()
                        }
                        onRadChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onImageLoaded: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            var w = width, h = height
                            ctx.clearRect(0, 0, w, h)
                            if (artUrl === "" || !isImageLoaded(artUrl)) return
                            var iw = artImg.implicitWidth, ih = artImg.implicitHeight
                            if (!(iw > 0) || !(ih > 0)) { iw = 1; ih = 1 }
                            var a = iw / ih
                            var dw = h * a, dh = h
                            if (dw < w) { dw = w; dh = w / a }
                            var dx = (w - dw) / 2, dy = (h - dh) / 2
                            var r = Math.min(rad, w / 2, h / 2)
                            ctx.save()
                            ctx.beginPath()
                            ctx.moveTo(r, 0)
                            ctx.lineTo(w - r, 0)
                            ctx.arc(w - r, r, r, -Math.PI / 2, 0, false)
                            ctx.lineTo(w, h - r)
                            ctx.arc(w - r, h - r, r, 0, Math.PI / 2, false)
                            ctx.lineTo(r, h)
                            ctx.arc(r, h - r, r, Math.PI / 2, Math.PI, false)
                            ctx.lineTo(0, r)
                            ctx.arc(r, r, r, Math.PI, Math.PI * 1.5, false)
                            ctx.closePath()
                            ctx.clip()
                            ctx.globalAlpha = 1 / 9
                            for (var ox = -2; ox <= 2; ox += 2)
                                for (var oy = -2; oy <= 2; oy += 2)
                                    ctx.drawImage(artUrl, dx + ox, dy + oy, dw, dh)
                            ctx.globalAlpha = 1
                            ctx.fillStyle = "rgba(0,0,0,0.55)"
                            ctx.fillRect(0, 0, w, h)
                            ctx.restore()
                        }
                    }
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        visible: !card.artReady
                        anchors.centerIn: parent
                        text: "󰎆"
                        font.family: root.contentFont
                        font.pixelSize: Theme.fs(44)
                        color: Theme.textMuted
                        opacity: 0.5
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (page.index !== carousel.currentIndex) {
                                carousel.currentIndex = page.index
                                try { root.scope.selectedPlayer = page.player } catch (e) { }
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle {
                                antialiasing: Theme.shapesAa
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 13
                                color: card.chipBg
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                IconImage {
                                    id: appImg
                                    anchors.fill: parent
                                    anchors.margins: 5
                                    source: root.appIcon(page.player)
                                    asynchronous: true
                                    implicitSize: Qt.size(32, 32)
                                    visible: source !== ""
                                }
                                Text {
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                    visible: appImg.source === ""
                                    anchors.centerIn: parent
                                    text: "󰎆"
                                    font.family: root.contentFont
                                    font.pixelSize: Theme.fs(14)
                                    color: card.inkDim
                                }
                            }
                            Item { Layout.fillWidth: true; height: 1 }
                            Rectangle {
                                antialiasing: Theme.shapesAa
                                visible: page.player && (page.player.identity || "") !== ""
                                Layout.preferredHeight: 22
                                Layout.preferredWidth: Math.min(120, pillTxt.implicitWidth + 20)
                                radius: 11
                                color: card.chipBg
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Text {
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                    id: pillTxt
                                    width: parent.width - 20
                                    anchors.centerIn: parent
                                    horizontalAlignment: Text.AlignHCenter
                                    text: page.player ? (page.player.identity || "") : ""
                                    font.family: root.contentFont
                                    font.pixelSize: Theme.fs(9)
                                    color: card.inkDim
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }
                        }

                        Item { Layout.fillWidth: true; Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2
                                Text {
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                    text: page.player ? (page.player.trackTitle || "Unbekannter Titel") : ""
                                    font.family: root.contentFont
                                    font.pixelSize: Theme.fs(13)
                                    font.weight: Font.Medium
                                    color: card.ink
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                                Text {
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                    text: page.player ? (page.player.trackArtist || page.player.identity || "") : ""
                                    font.family: root.contentFont
                                    font.pixelSize: Theme.fs(11)
                                    color: card.inkDim
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }
                            Rectangle {
                                antialiasing: Theme.shapesAa
                                id: playBtn
                                property bool playing: page.player ? !!page.player.isPlaying : false
                                Layout.preferredWidth: playing ? 64 : 44
                                Layout.preferredHeight: 44
                                Layout.alignment: Qt.AlignVCenter
                                radius: 22
                                color: playing ? Theme.accentDim : Theme.accent
                                scale: Theme.animationsEnabled && playMouse.pressed ? 0.9 : 1.0
                                Behavior on Layout.preferredWidth { NumberAnimation { duration: Theme.animEmph; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
                                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                                Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                                Item {
                                    anchors.centerIn: parent
                                    width: 24
                                    height: 24
                                    Text {
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                        anchors.centerIn: parent
                                        text: "󰐊"
                                        font.family: root.contentFont
                                        font.pixelSize: Theme.fs(18)
                                        color: playBtn.playing ? Theme.onTileActive : Theme.onAccent
                                        opacity: playBtn.playing ? 0 : 1
                                        scale: playBtn.playing ? 0.6 : 1.0
                                        rotation: playBtn.playing ? -90 : 0
                                        Behavior on opacity { NumberAnimation { duration: Theme.animEmph; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                                        Behavior on scale { NumberAnimation { duration: Theme.animEmph; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                                        Behavior on rotation { NumberAnimation { duration: Theme.animEmph; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
                                        Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                                    }
                                    Text {
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                        anchors.centerIn: parent
                                        text: "󰏤"
                                        font.family: root.contentFont
                                        font.pixelSize: Theme.fs(18)
                                        color: playBtn.playing ? Theme.onTileActive : Theme.onAccent
                                        opacity: playBtn.playing ? 1 : 0
                                        scale: playBtn.playing ? 1.0 : 0.6
                                        rotation: playBtn.playing ? 0 : 90
                                        Behavior on opacity { NumberAnimation { duration: Theme.animEmph; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                                        Behavior on scale { NumberAnimation { duration: Theme.animEmph; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                                        Behavior on rotation { NumberAnimation { duration: Theme.animEmph; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
                                        Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                                    }
                                }
                                MouseArea {
                                    id: playMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { try { page.player.togglePlaying() } catch (e) { } }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Item {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                Layout.alignment: Qt.AlignVCenter
                                scale: Theme.animationsEnabled && prevMouse.pressed ? 0.9 : 1.0
                                Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                                Text {
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                    anchors.centerIn: parent
                                    text: "󰒮"
                                    font.family: root.contentFont
                                    font.pixelSize: Theme.fs(20)
                                    color: card.ink
                                    opacity: prevMouse.containsMouse ? 1.0 : 0.85
                                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                                }
                                MouseArea {
                                    id: prevMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { try { page.player.previous() } catch (e) { } }
                                }
                            }
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24
                                Layout.alignment: Qt.AlignVCenter
                                visible: page.player && (page.player.length || 0) > 0
                                Canvas {
                                    id: wave
                                    anchors.fill: parent
                                    property real frac: 0
                                    property real posBase: 0
                                    property real posAt: 0
                                    property real mprisFrac: (page.player && (page.player.length || 0) > 0) ? Math.min(1, (page.player.position || 0) / page.player.length) : 0
                                    onMprisFracChanged: {
                                        frac = mprisFrac
                                        try { posBase = page.player.position || 0 } catch (e) { posBase = 0 }
                                        posAt = Date.now()
                                        requestPaint()
                                    }
                                    property real phase: 0
                                    property bool playing: page.player ? !!page.player.isPlaying : false
                                    onPlayingChanged: requestPaint()
                                    property real amp: playing ? 3 : 0
                                    Behavior on amp { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                                    onAmpChanged: requestPaint()
                                    property color played: card.artReady ? "#ffffff" : Theme.accent
                                    property color rest: card.artReady ? Theme.withAlpha("#ffffff", 0.35) : Theme.divider
                                    onFracChanged: requestPaint()
                                    onWidthChanged: requestPaint()
                                    Component.onCompleted: {
                                        frac = mprisFrac
                                        try { posBase = page.player.position || 0 } catch (e2) { posBase = 0 }
                                        posAt = Date.now()
                                    }
                                    Timer {
                                        interval: 250
                                        repeat: true
                                        running: page.player && page.player.isPlaying && (page.player.length || 0) > 0
                                        onTriggered: {
                                            wave.phase += 0.7
                                            try {
                                                if (page.player && page.player.isPlaying && (page.player.length || 0) > 0) {
                                                    let est = wave.posBase + (Date.now() - wave.posAt) / 1000
                                                    let f = Math.min(1, est / page.player.length)
                                                    if (Math.abs(f - wave.frac) > 0.0004) wave.frac = f
                                                }
                                            } catch (e3) { }
                                            wave.requestPaint()
                                        }
                                    }
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        var w = width, h = height
                                        if (w <= 0 || h <= 0) return
                                        ctx.clearRect(0, 0, w, h)
                                        ctx.lineCap = "round"
                                        var cy = Math.round(h / 2) + 0.5
                                        var f = Math.max(0, Math.min(1, frac))
                                        var fx = 5 + f * Math.max(1, w - 10)
                                        if (fx < w - 1) {
                                            ctx.strokeStyle = rest
                                            ctx.lineWidth = 2
                                            ctx.beginPath()
                                            ctx.moveTo(fx, cy)
                                            ctx.lineTo(w, cy)
                                            ctx.stroke()
                                        }
                                        ctx.strokeStyle = played
                                        ctx.lineWidth = 2.5
                                        ctx.beginPath()
                                        var waveAmp = amp, waveLen = 26, first = true
                                        for (var x = 0; x <= fx; x += 2) {
                                            var y = cy + waveAmp * Math.sin((x / waveLen) * 2 * Math.PI + phase)
                                            if (first) { ctx.moveTo(x, y); first = false } else { ctx.lineTo(x, y) }
                                        }
                                        ctx.stroke()
                                        ctx.fillStyle = played
                                        ctx.beginPath()
                                        ctx.arc(fx, cy, 5, 0, 2 * Math.PI)
                                        ctx.fill()
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: mouse => seekTo(mouse.x)
                                    onPositionChanged: mouse => { if (pressed) seekTo(mouse.x) }
                                    function seekTo(x: real): void {
                                        if (!page.player || (page.player.length || 0) <= 0) return
                                        let r = Math.max(0, Math.min(1, (x - 5) / Math.max(1, width - 10)))
                                        try { page.player.position = r * page.player.length } catch (e) { }
                                    }
                                }
                            }
                            Item {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                Layout.alignment: Qt.AlignVCenter
                                scale: Theme.animationsEnabled && nextMouse.pressed ? 0.9 : 1.0
                                Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                                Text {
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                    anchors.centerIn: parent
                                    text: "󰒭"
                                    font.family: root.contentFont
                                    font.pixelSize: Theme.fs(20)
                                    color: card.ink
                                    opacity: nextMouse.containsMouse ? 1.0 : 0.85
                                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                                }
                                MouseArea {
                                    id: nextMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { try { page.player.next() } catch (e) { } }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.playerCount > 1 ? 16 : 0
                            visible: root.playerCount > 1
                            Rectangle {
                                antialiasing: Theme.shapesAa
                                anchors.centerIn: parent
                                width: pagerRow.implicitWidth + 16
                                height: 16
                                radius: 8
                                color: card.chipBg
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Row {
                                    id: pagerRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Repeater {
                                        model: root.playerCount
                                        delegate: Rectangle {
                                            required property int index
                                            width: index === carousel.currentIndex ? 14 : 6
                                            height: 6
                                            radius: 3
                                            color: index === carousel.currentIndex ? card.ink : card.inkDim
                                            opacity: index === carousel.currentIndex ? 1 : 0.55
                                            Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                                            MouseArea {
                                                anchors.fill: parent
                                                anchors.margins: -6
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    carousel.currentIndex = index
                                                    if (root.players[index])
                                                        try { root.scope.selectedPlayer = root.players[index] } catch (e) { }
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
}
