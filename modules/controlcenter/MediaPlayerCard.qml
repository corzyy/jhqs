import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import "../../themes"
import "../../services"

// Android 17 / M3 Expressive media carousel:
// - every MPRIS session is a card; the active one is large, the others are
//   narrow pills next to it
// - selecting a pill runs a container-transform morph (Android 17 style):
//   the pill expands into the large card while the previous large card
//   minimizes, animating width, corner radius and content reveal together
// - track change on the active card: M3 fade through (fade + scale 92%)
Item {
    id: root

    readonly property var players: Mpris.players.values
    readonly property int playerCount: players ? players.length : 0
    property int activeIndex: 0
    // Clamp only against a non-empty list: the model can briefly be empty at
    // startup, which must not reset an explicitly chosen activeIndex.
    onPlayersChanged: if (players && players.length > 0 && root.activeIndex >= players.length) root.activeIndex = 0

    implicitHeight: playerCount > 0 ? 150 : 96

    // The card sits on (blurred) album art, so its foreground is always
    // light with a dark scrim instead of the shell's surface colors.
    readonly property color fg: Qt.rgba(1, 1, 1, 1.0)
    readonly property color fgDim: Qt.rgba(1, 1, 1, 0.74)
    readonly property color glass: Qt.rgba(1, 1, 1, 0.16)
    readonly property color glassHover: Qt.rgba(1, 1, 1, 0.26)

    // Carousel geometry: the active card takes whatever the peeks leave over.
    readonly property real peekWidth: 40
    readonly property real cardGap: 6
    readonly property real bigWidth: Math.max(peekWidth, width - Math.max(0, playerCount - 1) * (peekWidth + cardGap))

    readonly property string outputName: {
        try {
            let s = VolumeService.sink
            if (s) {
                let d = s.description || s.nickname || s.name
                if (d && ("" + d).length > 0) return "" + d
            }
        } catch (e) { }
        return "Audio"
    }

    function requestExpand(index: int): void {
        if (index < 0 || index >= playerCount || index === root.activeIndex) return
        activeIndex = index
    }

    RowLayout {
        anchors.fill: parent
        spacing: root.cardGap
        visible: root.playerCount > 0

        Repeater {
            model: root.players
            delegate: MediaCard {
                required property var modelData
                required property int index
                Layout.fillHeight: true
                cardPlayer: modelData
                active: index === root.activeIndex
                onExpandRequested: root.requestExpand(index)
            }
        }
    }

    // No session at all: single placeholder card.
    ClippingRectangle {
        anchors.fill: parent
        visible: root.playerCount === 0
        radius: 32
        color: Theme.surface_container_high
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        antialiasing: Theme.shapesAa

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.withAlpha(Theme.primary_container, 0.25) }
                GradientStop { position: 1.0; color: Theme.withAlpha(Theme.surface_container_high, 1.0) }
            }
        }
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 28
            spacing: 4

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "󰝚"
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(24)
                color: root.fgDim
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Keine Wiedergabe"
                color: root.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(14)
                font.weight: Font.Medium
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Kein Medienplayer aktiv"
                color: root.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(11)
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
        }
    }

    component IconButton: Item {
        id: button
        property string glyph
        property bool active: false
        signal activated()
        implicitWidth: 30
        implicitHeight: 30
        opacity: button.enabled ? 1.0 : 0.35

        Rectangle {
            anchors.centerIn: parent
            width: 28
            height: 28
            radius: width / 2
            color: buttonMouse.containsMouse && button.enabled ? root.glassHover : "transparent"

            Behavior on color {
                enabled: Theme.animationsEnabled
                ColorAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
            }
        }

        Text {
            anchors.centerIn: parent
            text: button.glyph
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fs(16)
            color: button.active ? Theme.primary : root.fg
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType

            Behavior on color {
                enabled: Theme.animationsEnabled
                ColorAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }

    // One card per session. The same component renders the large active card
    // and the narrow peeks; only width, radius and content reveal differ, so
    // the morph is a single animated property (implicitWidth).
    component MediaCard: Item {
        id: cardItem
        required property var cardPlayer
        property bool active: false
        signal expandRequested()

        readonly property bool playing: cardItem.cardPlayer ? cardItem.cardPlayer.isPlaying : false
        readonly property bool canToggle: cardItem.cardPlayer ? cardItem.cardPlayer.canTogglePlaying : false
        readonly property bool canPrev: cardItem.cardPlayer ? cardItem.cardPlayer.canGoPrevious : false
        readonly property bool canNext: cardItem.cardPlayer ? cardItem.cardPlayer.canGoNext : false
        readonly property bool canShuffle: cardItem.cardPlayer ? (cardItem.cardPlayer.shuffleSupported && cardItem.cardPlayer.canControl) : false
        readonly property bool shuffleOn: cardItem.cardPlayer ? (cardItem.cardPlayer.shuffleSupported && cardItem.cardPlayer.shuffle) : false
        readonly property bool canLoop: cardItem.cardPlayer ? (cardItem.cardPlayer.loopSupported && cardItem.cardPlayer.canControl) : false
        readonly property bool loopOn: cardItem.cardPlayer ? (cardItem.cardPlayer.loopSupported && cardItem.cardPlayer.loopState !== MprisLoopState.None) : false
        readonly property bool loopOne: cardItem.cardPlayer ? (cardItem.cardPlayer.loopSupported && cardItem.cardPlayer.loopState === MprisLoopState.Track) : false
        readonly property bool seekable: cardItem.cardPlayer ? (cardItem.cardPlayer.canSeek && cardItem.cardPlayer.positionSupported) : false
        readonly property bool hasProgress: cardItem.cardPlayer ? (cardItem.cardPlayer.positionSupported && cardItem.cardPlayer.lengthSupported && trackLength > 0) : false
        readonly property real trackLength: cardItem.cardPlayer ? Math.max(0, cardItem.cardPlayer.length || 0) : 0

        // Track metadata is rendered from a snapshot so the fade-through can
        // still show the old track while the player already reports the new.
        property real _txFade: 1
        property real _txScale: 1
        property string _dispTitle: ""
        property string _dispArtist: ""
        property string _dispArt: ""

        readonly property string titleText: cardItem._dispTitle !== "" ? cardItem._dispTitle : "Unbekannter Titel"
        readonly property string artistText: cardItem._dispArtist !== "" ? cardItem._dispArtist : (cardItem.cardPlayer && cardItem.cardPlayer.identity ? cardItem.cardPlayer.identity : "")
        readonly property string artUrl: cardItem._dispArt

        function syncDisplay(): void {
            if (!cardItem.cardPlayer) { _dispTitle = ""; _dispArtist = ""; _dispArt = ""; return }
            _dispTitle = cardItem.cardPlayer.trackTitle || ""
            _dispArtist = cardItem.cardPlayer.trackArtist || ""
            _dispArt = cardItem.cardPlayer.trackArtUrl || ""
        }
        onCardPlayerChanged: { syncDisplay(); refreshAppIcon() }
        Component.onCompleted: { syncDisplay(); refreshAppIcon() }

        // position is only pushed on nonlinear changes; poke it with a timer
        // while this card is the active one.
        property real positionSecs: 0
        property bool seeking: false
        property real seekPreview: 0
        readonly property real displayPosition: seeking ? seekPreview : positionSecs
        readonly property real progressFrac: trackLength > 0 ? Math.max(0, Math.min(1, displayPosition / trackLength)) : 0

        onActiveChanged: if (cardItem.active && cardItem.cardPlayer) cardItem.positionSecs = cardItem.cardPlayer.position

        Timer {
            running: cardItem.active && cardItem.playing && cardItem.hasProgress
            interval: 1000
            repeat: true
            onTriggered: if (cardItem.cardPlayer) cardItem.cardPlayer.positionChanged()
        }
        Connections {
            target: cardItem.cardPlayer
            ignoreUnknownSignals: true
            function onPositionChanged() { if (!cardItem.seeking) cardItem.positionSecs = cardItem.cardPlayer.position }
            function onPostTrackChanged() {
                cardItem.positionSecs = 0
                cardItem.seeking = false
                if (cardItem.active) trackChangeAnim.restart()
                else cardItem.syncDisplay()
            }
        }

        // M3 fade through for track changes (only the active card animates):
        // outgoing fades over the first 35% of the run, incoming fades in
        // scaling from 92% (same split as Ui.Motion's FadeThrough).
        SequentialAnimation {
            id: trackChangeAnim
            ParallelAnimation {
                NumberAnimation { target: cardItem; property: "_txFade"; to: 0; duration: Theme.durMotionFadeThrough * Theme.motionFadeThroughExit; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMotion }
                NumberAnimation { target: cardItem; property: "_txScale"; to: Theme.motionFadeThroughScale; duration: Theme.durMotionFadeThrough * Theme.motionFadeThroughExit; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMotion }
            }
            ScriptAction { script: cardItem.syncDisplay() }
            ParallelAnimation {
                NumberAnimation { target: cardItem; property: "_txFade"; to: 1; duration: Theme.durMotionFadeThrough * Theme.motionFadeThroughEnter; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMotion }
                NumberAnimation { target: cardItem; property: "_txScale"; to: 1; duration: Theme.durMotionFadeThrough * Theme.motionFadeThroughEnter; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMotion }
            }
            ScriptAction { script: artSyncTimer.restart() }
        }
        // Some players publish trackArtUrl slightly after the track change;
        // pick it up once the fade-through has finished.
        Timer {
            id: artSyncTimer
            interval: 1500
            repeat: false
            onTriggered: {
                if (cardItem.cardPlayer && cardItem.cardPlayer.trackArtUrl && cardItem.cardPlayer.trackArtUrl !== cardItem._dispArt) {
                    cardItem._dispArt = cardItem.cardPlayer.trackArtUrl
                }
            }
        }

        // Imperative (not a binding): Theme.appIconFor() writes its memo
        // caches, which would trip "binding loop detected" if reactive.
        property string appIconPath: ""
        function refreshAppIcon(): void {
            let next = ""
            try {
                if (cardItem.cardPlayer && cardItem.cardPlayer.desktopEntry && cardItem.cardPlayer.desktopEntry.length > 0) {
                    let p = Theme.appIconFor(cardItem.cardPlayer.desktopEntry)
                    if (p && p.length > 0 && p !== Quickshell.iconPath("application-x-executable")) next = p
                }
            } catch (e) { }
            if (next !== appIconPath) appIconPath = next
        }
        Connections {
            target: Theme
            function onAppsRevChanged() { cardItem.refreshAppIcon() }
        }

        function togglePlay(): void { if (cardItem.cardPlayer && cardItem.canToggle) cardItem.cardPlayer.togglePlaying() }
        function prev(): void { if (cardItem.canPrev) cardItem.cardPlayer.previous() }
        function next(): void { if (cardItem.canNext) cardItem.cardPlayer.next() }
        function toggleShuffle(): void { if (cardItem.canShuffle) cardItem.cardPlayer.shuffle = !cardItem.cardPlayer.shuffle }
        function cycleLoop(): void {
            if (!cardItem.canLoop) return
            let s = cardItem.cardPlayer.loopState
            cardItem.cardPlayer.loopState = (s === MprisLoopState.None) ? MprisLoopState.Playlist
                : (s === MprisLoopState.Playlist) ? MprisLoopState.Track : MprisLoopState.None
        }
        function commitSeek(frac: real): void {
            if (!cardItem.seekable || cardItem.trackLength <= 0) { cardItem.seeking = false; return }
            let target = Math.max(0, Math.min(cardItem.trackLength, frac * cardItem.trackLength))
            cardItem.seeking = false
            cardItem.positionSecs = target
            cardItem.cardPlayer.position = target
        }

        // Container-transform morph: width drives everything. The radius
        // interpolates pill -> extra-large and the foreground fades in with a
        // smoothstep so the expanding card reveals its content.
        readonly property real reveal: {
            let span = root.bigWidth - root.peekWidth
            if (span <= 0) return 1
            let t = Math.max(0, Math.min(1, (cardItem.width - root.peekWidth) / span))
            return t * t * (3 - 2 * t)
        }
        readonly property bool controlsEnabled: cardItem.active && cardItem.reveal > 0.85

        implicitWidth: cardItem.active ? root.bigWidth : root.peekWidth
        Behavior on implicitWidth {
            enabled: Theme.animationsEnabled
            NumberAnimation { duration: Theme.durMotionSharedAxis; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMotion }
        }

        ClippingRectangle {
            anchors.fill: parent
            radius: Math.min(32, width / 2)
            color: Theme.surface_container_high
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            antialiasing: Theme.shapesAa
            opacity: cardItem._txFade
            transform: Scale {
                origin.x: width / 2
                origin.y: height / 2
                xScale: cardItem._txScale
                yScale: cardItem._txScale
            }

            // Full-bleed album art, decoded at thumbnail size and scaled up
            // (cheap blur) with a scrim for text contrast.
            Rectangle {
                anchors.fill: parent
                visible: !artImage.visible
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.withAlpha(Theme.primary, 0.55) }
                    GradientStop { position: 1.0; color: Theme.withAlpha(Theme.primary_container, 0.9) }
                }
            }
            Image {
                id: artImage
                anchors.fill: parent
                source: cardItem.artUrl
                sourceSize: Qt.size(64, 64)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: Theme.imageSmooth
                visible: status === Image.Ready
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.42) }
                    GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.30) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.58) }
                }
            }

            // Foreground: laid out at the full card width and clipped by the
            // container, so the morph reveals it without a reflow.
            ColumnLayout {
                x: 14
                y: 14
                width: root.bigWidth - 28
                height: parent.height - 28
                spacing: 8
                opacity: cardItem.reveal

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: width / 2
                        color: root.glass

                        Image {
                            anchors.fill: parent
                            anchors.margins: 5
                            source: cardItem.appIconPath
                            sourceSize: Qt.size(48, 48)
                            asynchronous: true
                            cache: true
                            smooth: Theme.imageSmooth
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: cardItem.appIconPath.length === 0
                            text: "󰝚"
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(15)
                            color: root.fg
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: Math.min(outputRow.implicitWidth + 20, 168)
                        radius: height / 2
                        color: root.glass

                        RowLayout {
                            id: outputRow
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                text: "󰓃"
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(13)
                                color: root.fgDim
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.maximumWidth: 126
                                text: root.outputName
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(11)
                                color: root.fg
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: cardItem.titleText
                            color: root.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(15)
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                text: "󰎇"
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(12)
                                color: root.fgDim
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            Text {
                                Layout.fillWidth: true
                                text: cardItem.artistText
                                color: root.fgDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(11)
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                        }
                    }

                    Rectangle {
                        id: playButton
                        Layout.preferredWidth: 70
                        Layout.preferredHeight: 46
                        radius: height / 2
                        color: Theme.primary
                        opacity: cardItem.canToggle ? 1.0 : 0.55
                        scale: playMouse.pressed ? Theme.pressScale : (playMouse.containsMouse ? 1.04 : 1.0)
                        transformOrigin: Item.Center
                        antialiasing: Theme.shapesAa

                        Behavior on scale {
                            enabled: Theme.animationsEnabled
                            NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial }
                        }
                        Behavior on opacity {
                            enabled: Theme.animationsEnabled
                            NumberAnimation { duration: Theme.durFastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastEffects }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: cardItem.playing ? "󰏤" : "󰐊"
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fs(22)
                            color: Theme.on_primary
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }

                        MouseArea {
                            id: playMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: cardItem.controlsEnabled && cardItem.canToggle
                            onClicked: cardItem.togglePlay()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    IconButton {
                        glyph: "󰒮"
                        enabled: cardItem.controlsEnabled && cardItem.canPrev
                        onActivated: cardItem.prev()
                    }

                    Item {
                        id: seekBar
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        visible: cardItem.hasProgress

                        readonly property bool hot: seekMouse.containsMouse || cardItem.seeking

                        function fracAt(x: real): real {
                            return width > 0 ? Math.max(0, Math.min(1, x / width)) : 0
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 5
                            radius: height / 2
                            color: Qt.rgba(1, 1, 1, 0.26)
                            antialiasing: Theme.shapesAa

                            Rectangle {
                                width: Math.round(parent.width * cardItem.progressFrac)
                                height: parent.height
                                radius: parent.radius
                                color: root.fg
                                antialiasing: Theme.shapesAa
                            }
                        }
                        Rectangle {
                            width: seekBar.hot ? 16 : 12
                            height: width
                            radius: width / 2
                            x: Math.max(0, Math.min(seekBar.width - width, seekBar.width * cardItem.progressFrac - width / 2))
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.fg
                            antialiasing: Theme.shapesAa

                            Behavior on width {
                                enabled: Theme.animationsEnabled
                                NumberAnimation { duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial }
                            }
                        }

                        MouseArea {
                            id: seekMouse
                            anchors.fill: parent
                            enabled: cardItem.controlsEnabled && cardItem.seekable
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => { cardItem.seekPreview = seekBar.fracAt(mouse.x); cardItem.seeking = true }
                            onPositionChanged: mouse => { if (cardItem.seeking) cardItem.seekPreview = seekBar.fracAt(mouse.x) }
                            onReleased: mouse => cardItem.commitSeek(seekBar.fracAt(mouse.x))
                            onCanceled: cardItem.seeking = false
                        }
                    }

                    IconButton {
                        glyph: "󰒭"
                        enabled: cardItem.controlsEnabled && cardItem.canNext
                        onActivated: cardItem.next()
                    }
                    IconButton {
                        glyph: "󰒝"
                        enabled: cardItem.controlsEnabled && cardItem.canShuffle
                        active: cardItem.shuffleOn
                        onActivated: cardItem.toggleShuffle()
                    }
                    IconButton {
                        glyph: cardItem.loopOne ? "󰑘" : "󰑖"
                        enabled: cardItem.controlsEnabled && cardItem.canLoop
                        active: cardItem.loopOn
                        onActivated: cardItem.cycleLoop()
                    }
                }
            }
        }

        // Selecting a pill expands it; the active card's controls sit above
        // this area and win whenever this card is already active.
        MouseArea {
            anchors.fill: parent
            enabled: !cardItem.active
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cardItem.expandRequested()
        }
    }
}
