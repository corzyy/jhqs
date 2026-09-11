pragma ComponentBehavior: Bound
import QtQuick
import "../../../themes"
import ".."

Column {
    id: root
    width: parent ? parent.width : 400
    spacing: 10

    SettingsControls.SettingsSection {
        title: "Style"
        SettingsControls.SettingsDropdown {
            label: "Style"
            options: ["Full Bar", "Island"]
            current: Theme.barStyle === "island" ? "Island" : "Full Bar"
            onPicked: v => Theme.setBarStyle(v === "Island" ? "island" : "full")
        }
        Column {
            width: parent.width
            spacing: 6
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: "Position"
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(12)
                font.weight: Font.Medium
                color: Theme.textSecondary
            }
            Row {
                width: parent.width
                spacing: 8
                Repeater {
                    model: [
                        { id: "top", label: "Top" },
                        { id: "bottom", label: "Bottom" },
                        { id: "left", label: "Left" },
                        { id: "right", label: "Right" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property string posId: modelData.id
                        readonly property bool isCurrent: Theme.barPosition === posId
                        width: (root.width - 24) / 4
                        height: 56
                        radius: 0
                        antialiasing: Theme.shapesAa
                        color: isCurrent ? Theme.withAlpha(Theme.accent, 0.16) : isCurrent ? Theme.bgSelected
                            : posMouse.containsMouse ? (Theme.withAlpha(Theme.textPrimary, 0.08))
                            : (Theme.withAlpha(Theme.textPrimary, 0.04))
                        border.color: isCurrent ? Theme.accent : (Theme.withAlpha(Theme.textPrimary, 0.25))
                        border.width: isCurrent ? 2 : 1
                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            Rectangle {
                                antialiasing: Theme.shapesAa
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 26
                                height: 18
                                radius: 2
                                color: "transparent"
                                border.color: isCurrent ? Theme.accent : Theme.divider
                                border.width: 1
                                Rectangle {
                                    antialiasing: Theme.shapesAa
                                    x: posId === "left" ? 1 : posId === "right" ? parent.width - width - 1 : 1
                                    y: posId === "top" ? 1 : posId === "bottom" ? parent.height - height - 1 : 1
                                    width: (posId === "left" || posId === "right") ? 3 : parent.width - 2
                                    height: (posId === "left" || posId === "right") ? parent.height - 2 : 3
                                    radius: 1
                                    color: isCurrent ? Theme.accent : Theme.textMuted
                                }
                            }
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fs(11)
                                font.weight: isCurrent ? Font.Medium : Font.Normal
                                color: isCurrent ? Theme.textPrimary : Theme.textSecondary
                            }
                        }
                        MouseArea { id: posMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Theme.setBarPosition(posId) }
                    }
                }
            }
        }
    }

    SettingsControls.SettingsSection {
        title: "Bar"
        SettingsControls.SettingsRow {
            title: "Module Background"
            subtitle: "Matugen pill behind left / 2-5ths / center / 4-5ths / right modules"
            SettingsControls.SettingsToggle { on: Theme.barModuleBackground; onToggled: n => Theme.setBarModuleBackground(n) }
        }
        SettingsControls.SettingsSliderRow { label: "Thickness"; from: 20; to: 48; stepSize: 1; unit: "px"; value: Theme.barThickness; onMoved: v => Theme.setBarThickness(Math.round(v)); onApplied: v => Theme.setBarThickness(Math.round(v)) }
        SettingsControls.SettingsSliderRow { label: "Opacity"; from: 0; to: 1; stepSize: 0.01; value: Theme.barOpacity; onMoved: v => Theme.setBarOpacity(v); onApplied: v => Theme.setBarOpacity(v) }
        SettingsControls.SettingsSliderRow { label: "Module Spacing"; from: -12; to: 24; stepSize: 1; unit: "px"; value: Theme.barModuleSpacing; onMoved: v => Theme.setBarModuleSpacing(Math.round(v)); onApplied: v => Theme.setBarModuleSpacing(Math.round(v)) }
        SettingsControls.SettingsSliderRow { label: "Edge Distance"; from: 0; to: 600; stepSize: 1; unit: "px"; value: Theme.barEdgeDistance; onMoved: v => Theme.setBarEdgeDistance(Math.round(v)); onApplied: v => Theme.setBarEdgeDistance(Math.round(v)) }
        SettingsControls.SettingsSliderRow { label: "Top Distance"; from: 0; to: 32; stepSize: 1; unit: "px"; value: Theme.barTopDistance; onMoved: v => Theme.setBarTopDistance(Math.round(v)); onApplied: v => Theme.setBarTopDistance(Math.round(v)) }
        SettingsControls.SettingsSliderRow { label: "Content Padding"; from: 0; to: 32; stepSize: 1; unit: "px"; value: Theme.barContentPadding; onMoved: v => Theme.setBarContentPadding(Math.round(v)); onApplied: v => Theme.setBarContentPadding(Math.round(v)) }
    }
}
