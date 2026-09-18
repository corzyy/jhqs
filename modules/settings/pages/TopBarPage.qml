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
            delegate: NexusControls.PreviewTile {
                required property var modelData
                readonly property string posId: modelData.id
                readonly property bool isCurrent: Theme.barPosition === posId
                width: (parent.width - 24) / 4
                height: 56
                selected: isCurrent
                label: modelData.label
                contentSpacing: 4
                onClicked: Theme.setBarPosition(posId)
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
