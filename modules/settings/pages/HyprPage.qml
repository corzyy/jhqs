pragma ComponentBehavior: Bound
import QtQuick
import "../../../themes"
import "../../../services"
import ".."

Column {
    id: root
    width: parent ? parent.width : 400
    spacing: 10

    SettingsControls.SettingsSection {
        title: "Gaps & Borders"
        SettingsControls.SettingsSliderRow { label: "Gaps In"; from: 0; to: 40; stepSize: 1; value: SettingsService.hyprGapsIn; onMoved: v => SettingsService.previewGapsIn(v); onApplied: v => SettingsService.applyGapsIn(v) }
        SettingsControls.SettingsSliderRow { label: "Gaps Out"; from: 0; to: 60; stepSize: 1; value: SettingsService.hyprGapsOut; onMoved: v => SettingsService.previewGapsOut(v); onApplied: v => SettingsService.applyGapsOut(v) }
        SettingsControls.SettingsSliderRow { label: "Border Size"; from: 0; to: 12; stepSize: 1; value: SettingsService.hyprBorder; onMoved: v => SettingsService.previewBorder(v); onApplied: v => SettingsService.applyBorder(v) }
    }

    SettingsControls.SettingsSection {
        title: "Effects"
        SettingsControls.SettingsRow {
            title: "Shadows"
            SettingsControls.SettingsToggle { on: SettingsService.hyprShadow; onToggled: n => SettingsService.applyShadow(n) }
        }
        SettingsControls.SettingsRow {
            title: "Tearing"
            SettingsControls.SettingsToggle { on: SettingsService.hyprTearing; onToggled: n => SettingsService.applyTearing(n) }
        }
    }

    SettingsControls.SettingsSection {
        title: "Layout"
        Row {
            width: parent.width; spacing: 8
            Repeater {
                model: ["dwindle", "scrolling"]
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: SettingsService.hyprLayout === modelData
                    width: (root.width - 24) / 2; height: 34
                    radius: 0
                    color: isCurrent ? Theme.withAlpha(Theme.accent, 0.16) : isCurrent ? Theme.bgSelected
                        : layMouse.containsMouse ? (Theme.withAlpha(Theme.textPrimary, 0.08))
                        : (Theme.withAlpha(Theme.textPrimary, 0.04))
                    border.color: isCurrent ? Theme.accent : (Theme.withAlpha(Theme.textPrimary, 0.25))
                    border.width: isCurrent ? 2 : 1
                    Text { anchors.centerIn: parent; text: modelData; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Bold; color: Theme.textPrimary
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    MouseArea { id: layMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: SettingsService.applyLayout(modelData + "") }
                }
            }
        }
    }

    SettingsControls.SettingsSection {
        title: "Animations"
        SettingsControls.SettingsRow {
            title: "Enabled"
            SettingsControls.SettingsToggle { on: SettingsService.animEnabled; onToggled: n => SettingsService.applyAnimEnabled(n) }
        }
        SettingsControls.SettingsSliderRow { label: "Speed Scale"; from: 0.2; to: 3.0; stepSize: 0.1; unit: "x"; value: SettingsService.animSpeed; onMoved: v => SettingsService.previewAnimSpeed(v); onApplied: v => SettingsService.applyAnimSpeed(v) }
        SettingsControls.SettingsDropdown {
            label: "Curve"
            options: ["linear", "md3_standard", "md3_decel", "md3_accel", "overshot", "crazyshot", "hyprnostretch", "fluent_decel", "easeInOutCirc", "easeOutCirc", "easeOutExpo"]
            current: SettingsService.animBezier
            onPicked: v => SettingsService.applyAnimBezier(v)
        }
    }
}
