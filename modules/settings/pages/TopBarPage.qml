pragma ComponentBehavior: Bound
import QtQuick
import "../../../themes"
import ".."

NexusControls.PageBase {
    id: root
    title: "Top Bar"

    NexusControls.SectionHeader { first: true; text: "Position" }
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
                width: (parent.width - 24) / 4
                height: 56
                radius: 16
                antialiasing: Theme.shapesAa
                color: isCurrent ? Theme.withAlpha(Theme.accent, 0.16)
                    : posMouse.containsMouse ? (Theme.withAlpha(Theme.textPrimary, 0.08))
                    : (Theme.surface_container)
                border.color: isCurrent ? Theme.accent : Theme.divider
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

    NexusControls.SectionHeader { text: "Bar" }
    NexusControls.SliderRow { first: true; label: "Thickness"; from: 20; to: 48; stepSize: 1; unit: "px"; value: Theme.barThickness; onMoved: v => Theme.setBarThickness(Math.round(v)); onApplied: v => Theme.setBarThickness(Math.round(v)) }
    NexusControls.SliderRow { label: "Opacity"; from: 0; to: 1; stepSize: 0.01; value: Theme.barOpacity; onMoved: v => Theme.setBarOpacity(v); onApplied: v => Theme.setBarOpacity(v) }
    NexusControls.SliderRow { label: "Module Spacing"; from: -12; to: 24; stepSize: 1; unit: "px"; value: Theme.barModuleSpacing; onMoved: v => Theme.setBarModuleSpacing(Math.round(v)); onApplied: v => Theme.setBarModuleSpacing(Math.round(v)) }
    NexusControls.SliderRow { label: "Edge Distance"; from: 0; to: 600; stepSize: 1; unit: "px"; value: Theme.barEdgeDistance; onMoved: v => Theme.setBarEdgeDistance(Math.round(v)); onApplied: v => Theme.setBarEdgeDistance(Math.round(v)) }
    NexusControls.SliderRow { label: "Top Distance"; from: 0; to: 32; stepSize: 1; unit: "px"; value: Theme.barTopDistance; onMoved: v => Theme.setBarTopDistance(Math.round(v)); onApplied: v => Theme.setBarTopDistance(Math.round(v)) }
    NexusControls.SliderRow { last: true; label: "Content Padding"; from: 0; to: 32; stepSize: 1; unit: "px"; value: Theme.barContentPadding; onMoved: v => Theme.setBarContentPadding(Math.round(v)); onApplied: v => Theme.setBarContentPadding(Math.round(v)) }
}
