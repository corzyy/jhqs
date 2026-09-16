import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../../themes"

Rectangle {
    id: root

    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    readonly property bool hasPlayer: player !== null
    readonly property string titleText: hasPlayer && player.trackTitle ? player.trackTitle : "Keine Wiedergabe"
    readonly property string artistText: hasPlayer ? (player.trackArtist || player.identity || "") : "Kein Medienplayer aktiv"
    readonly property string artUrl: hasPlayer && player.trackArtUrl ? player.trackArtUrl : ""
    readonly property bool playing: hasPlayer && player.isPlaying

    implicitHeight: 82
    radius: 24
    color: Theme.surface_container_high
    border.width: 1
    border.color: Theme.outline_variant
    antialiasing: Theme.shapesAa

    component MediaButton: Item {
        id: button
        required property string glyph
        property bool prominent: false
        property bool available: true
        signal clicked()

        implicitWidth: prominent ? 42 : 34
        implicitHeight: prominent ? 42 : 34
        opacity: available ? 1.0 : 0.4

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            antialiasing: Theme.shapesAa
            color: button.prominent ? Theme.primary
                : buttonMouse.containsMouse && button.available ? Theme.withAlpha(Theme.on_surface, 0.1)
                : "transparent"

            Behavior on color {
                enabled: Theme.animationsEnabled
                ColorAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
            }

            Text {
                anchors.centerIn: parent
                text: button.glyph
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(button.prominent ? 19 : 17)
                color: button.prominent ? Theme.on_primary : Theme.textPrimary
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.available
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 58
            Layout.preferredHeight: 58
            Layout.alignment: Qt.AlignVCenter
            radius: 16
            color: Theme.withAlpha(Theme.primary, 0.18)
            antialiasing: Theme.shapesAa
            clip: true

            Text {
                anchors.centerIn: parent
                text: "󰎇"
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(24)
                color: Theme.textSecondary
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }

            Image {
                anchors.fill: parent
                source: root.artUrl
                sourceSize: Qt.size(116, 116)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: Theme.imageSmooth
                mipmap: Theme.imageMipmap
                visible: status === Image.Ready
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.titleText
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(13)
                font.weight: Font.Medium
                elide: Text.ElideRight
                maximumLineCount: 1
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }

            Text {
                Layout.fillWidth: true
                text: root.artistText
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(11)
                elide: Text.ElideRight
                maximumLineCount: 1
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            MediaButton {
                glyph: "󰒮"
                available: root.hasPlayer && root.player.canGoPrevious
                onClicked: if (root.player) root.player.previous()
            }
            MediaButton {
                glyph: root.playing ? "󰏤" : "󰐊"
                prominent: true
                available: root.hasPlayer && root.player.canTogglePlaying
                onClicked: if (root.player) root.player.togglePlaying()
            }
            MediaButton {
                glyph: "󰒭"
                available: root.hasPlayer && root.player.canGoNext
                onClicked: if (root.player) root.player.next()
            }
        }
    }
}
