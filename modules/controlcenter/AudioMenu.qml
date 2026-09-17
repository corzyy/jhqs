pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "../../themes"
import "../../Commons"

// In-control-center audio menu: expands under the volume slider row and lists
// PipeWire output/input devices. Picking a row sets the preferred default node
// (same Pipewire API BluetoothService uses for audio-output follow).
Rectangle {
    id: menu

    property bool open: false

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio !== null && n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio !== null && !n.isSink && !n.isStream)

    // Binding the nodes makes audio.muted/audio.volume reactive (see
    // VolumeService for the unbind/ready caveat).
    PwObjectTracker { objects: menu.sinks.concat(menu.sources) }

    function defaultSinkId(): int {
        let d = Pipewire.defaultAudioSink
        return d !== null ? d.id : -1
    }
    function defaultSourceId(): int {
        let d = Pipewire.defaultAudioSource
        return d !== null ? d.id : -1
    }
    function deviceLabel(node: var): string {
        return Util.cleanAudioName(node.description || "", node.name || "")
    }
    function deviceVolume(node: var): int {
        try { return Math.round((node.audio.volume || 0) * 100) } catch (e) { return 0 }
    }
    function deviceMuted(node: var): bool {
        try { return node.audio.muted === true } catch (e) { return false }
    }
    function deviceGlyph(node: var): string {
        if (!node.isSink) return "󰍬"
        let d = ((node.description || "") + " " + (node.name || "")).toLowerCase()
        if (d.indexOf("headphone") !== -1 || d.indexOf("headset") !== -1 || d.indexOf("kopfhörer") !== -1) return "󰋋"
        if (d.indexOf("hdmi") !== -1 || d.indexOf("displayport") !== -1) return "󰍹"
        if (d.indexOf("bluetooth") !== -1 || d.indexOf("bluez") !== -1) return "󰂯"
        if (d.indexOf("usb") !== -1) return "󰓃"
        return "󰕾"
    }
    function pick(node: var): void {
        try {
            if (node.isSink) Pipewire.preferredDefaultAudioSink = node
            else Pipewire.preferredDefaultAudioSource = node
        } catch (e) {}
    }

    implicitHeight: menu.open ? menuColumn.implicitHeight + 20 : 0
    // Stays visible through the close run so the layout keeps shrinking the
    // item; hiding it earlier would freeze its height and deadlock reopening.
    visible: menu.open || implicitHeight > 0.5
    clip: true
    radius: Theme.cornerRadiusSmall
    color: Theme.cardBg
    border.color: Theme.divider
    border.width: 1
    antialiasing: Theme.shapesAa

    // M3 fade through: slow effects in, fast effects out (cc edit chrome).
    Behavior on implicitHeight {
        enabled: Theme.animationsEnabled
        NumberAnimation {
            duration: menu.open ? Theme.durSlowEffects : Theme.durFastEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: menu.open ? Theme.curveSlowEffects : Theme.curveFastEffects
        }
    }

    component SectionLabel: Text {
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(10)
        font.weight: Font.Bold
        font.letterSpacing: 1.2
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
    }

    component EmptyLabel: Text {
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(11)
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
    }

    component DeviceRow: Rectangle {
        id: row

        required property var node
        required property bool isActive
        signal picked()

        implicitHeight: 40
        radius: Theme.cornerRadiusSmall
        antialiasing: Theme.shapesAa
        color: row.isActive ? Theme.withAlpha(Theme.primary, 0.14)
            : rowMouse.containsMouse ? Theme.withAlpha(Theme.on_surface, 0.07) : "transparent"
        border.width: row.isActive ? 1 : 0
        border.color: Theme.withAlpha(Theme.primary, 0.55)

        Behavior on color {
            enabled: Theme.animationsEnabled
            ColorAnimation { duration: Theme.durFastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastEffects }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 10
                Layout.preferredHeight: 10
                Layout.alignment: Qt.AlignVCenter
                radius: 5
                antialiasing: Theme.shapesAa
                color: row.isActive ? Theme.primary : "transparent"
                border.color: row.isActive ? Theme.primary : Theme.textMuted
                border.width: row.isActive ? 0 : 1
            }
            Text {
                text: menu.deviceGlyph(row.node)
                color: row.isActive ? Theme.textPrimary : Theme.textSecondary
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(16)
                Layout.preferredWidth: 22
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignVCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: menu.deviceLabel(row.node)
                color: row.isActive ? Theme.textPrimary : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(12)
                font.weight: row.isActive ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
                maximumLineCount: 1
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Text {
                visible: menu.deviceMuted(row.node)
                text: "󰝟"
                color: Theme.errorColor
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(13)
                Layout.alignment: Qt.AlignVCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Text {
                text: menu.deviceVolume(row.node) + "%"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(10)
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignVCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.picked()
        }
    }

    ColumnLayout {
        id: menuColumn
        x: 10
        y: 10
        width: parent.width - 20
        spacing: 4

        SectionLabel { text: "AUSGABE"; visible: menu.sinks.length > 0 }
        Repeater {
            model: menu.sinks
            delegate: DeviceRow {
                required property var modelData
                Layout.fillWidth: true
                node: modelData
                isActive: menu.defaultSinkId() === modelData.id
                onPicked: menu.pick(modelData)
            }
        }
        EmptyLabel { visible: menu.sinks.length === 0; text: "Keine Ausgabegeräte" }

        SectionLabel {
            text: "EINGABE"
            visible: menu.sources.length > 0
            Layout.topMargin: 6
        }
        Repeater {
            model: menu.sources
            delegate: DeviceRow {
                required property var modelData
                Layout.fillWidth: true
                node: modelData
                isActive: menu.defaultSourceId() === modelData.id
                onPicked: menu.pick(modelData)
            }
        }
        EmptyLabel { visible: menu.sources.length === 0; text: "Keine Eingabegeräte" }
    }
}
