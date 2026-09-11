pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "../../../themes"
import "../../../services"
import ".."

Column {
    id: root
    width: parent ? parent.width : 400
    spacing: 10

    property int idleLock: 300
    property int idleSuspend: 900

    Process {
        id: idleFetchProc
        command: ["bash", "-c", "f=~/.config/hypr/hypridle.conf; lock=$(grep -oP 'timeout\\s*=\\s*\\K\\d+' \"$f\" 2>/dev/null | head -1); susp=$(grep -oP 'timeout\\s*=\\s*\\K\\d+' \"$f\" 2>/dev/null | sed -n '2p'); echo \"$lock|$susp\" | tr -d '\\n'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let p = (text || "").trim().split("|")
                let a = parseInt(p[0]); if (!isNaN(a)) root.idleLock = Math.max(30, Math.min(3600, a))
                let b = parseInt(p[1]); if (!isNaN(b)) root.idleSuspend = Math.max(60, Math.min(7200, b))
            }
        }
    }
    Component.onCompleted: if (!idleFetchProc.running) idleFetchProc.running = true

    SettingsControls.SettingsSection {
        title: "Performance"
        SettingsControls.SettingsRow {
            title: "GameMode"
            SettingsControls.SettingsToggle { on: SettingsService.gamemode; onToggled: n => SettingsService.applyGamemode(n) }
        }
    }

    SettingsControls.SettingsSection {
        title: "Workflow Presets"
        Grid {
            width: parent.width; columns: 2; spacing: 8
            Repeater {
                model: [
                    {id: "coding", title: "Coding", icon: "󰅩"},
                    {id: "gaming", title: "Gaming", icon: "󰊴"},
                    {id: "present", title: "Present", icon: "󰈩"},
                    {id: "chill", title: "Chill", icon: "󰋋"}
                ]
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: (root.width - 32) / 2; height: 64
                    radius: Theme.cornerRadiusSmall
                    color: presetMouse.containsMouse ? Theme.bgHover : Theme.panelSurface
                    border.color: Theme.divider; border.width: 1
                    Column {
                        anchors.fill: parent; anchors.margins: 8; spacing: 1
                        Text { text: modelData.icon + "  " + modelData.title; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13); font.weight: Font.Medium; color: Theme.textPrimary
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                    }
                    MouseArea { id: presetMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: SettingsService.applyPreset(modelData.id) }
                }
            }
        }
    }

    SettingsControls.SettingsSection {
        title: "Idle & Lock"
        SettingsControls.SettingsSliderRow {
            label: "Lock After"; from: 30; to: 1800; stepSize: 30; unit: "s"; value: root.idleLock
            onMoved: v => root.idleLock = Math.round(v)
            onApplied: v => { root.idleLock = Math.round(v); SettingsService.runBackend(["hypridle", "lock=" + Math.round(v)]) }
        }
        SettingsControls.SettingsSliderRow {
            label: "Suspend After"; from: 60; to: 7200; stepSize: 60; unit: "s"; value: root.idleSuspend
            onMoved: v => root.idleSuspend = Math.round(v)
            onApplied: v => { root.idleSuspend = Math.round(v); SettingsService.runBackend(["hypridle", "suspend=" + Math.round(v)]) }
        }
    }
}
