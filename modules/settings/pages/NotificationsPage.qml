pragma ComponentBehavior: Bound
import QtQuick
import "../../../themes"
import ".."

NexusControls.PageBase {
    id: root
    title: "Notifications"

    NexusControls.SectionHeader { first: true; text: "Position" }
    Grid {
        width: parent.width
        columns: 3
        spacing: 8
        Repeater {
            model: [
                { id: "top-left", label: "Top Left" },
                { id: "top-center", label: "Top Center" },
                { id: "top-right", label: "Top Right" },
                { id: "bottom-left", label: "Bottom Left" },
                { id: "bottom-center", label: "Bottom Center" },
                { id: "bottom-right", label: "Bottom Right" }
            ]
            delegate: NexusControls.PreviewTile {
                required property var modelData
                readonly property string posId: modelData.id
                readonly property bool isCurrent: Theme.notifPosition === posId
                readonly property bool isTop: posId.indexOf("top") === 0
                readonly property bool isLeft: posId.indexOf("left") !== -1
                readonly property bool isRight: posId.indexOf("right") !== -1
                width: (parent.width - 16) / 3
                height: 68
                selected: isCurrent
                label: modelData.label
                contentSpacing: 4
                onClicked: Theme.setNotifPosition(posId)
                Rectangle {
                        antialiasing: Theme.shapesAa
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 44
                        height: 26
                        radius: 2
                        color: "transparent"
                        border.color: isCurrent ? Theme.accent : Theme.divider
                        border.width: 1
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            x: isLeft ? 2 : isRight ? parent.width - width - 2 : (parent.width - width) / 2
                            y: isTop ? 2 : parent.height - height - 2
                            width: 14
                            height: 5
                            radius: 1
                            color: isCurrent ? Theme.accent : Theme.textMuted
                        }
                    }
                }
            }
        }
    NexusControls.SliderRow { first: true; last: true; label: "Timeout"; from: 0; to: 30; stepSize: 1; unit: "s"; value: Theme.notifTimeout; onMoved: v => Theme.setNotifTimeout(Math.round(v)); onApplied: v => Theme.setNotifTimeout(Math.round(v)) }

    NexusControls.SectionHeader { text: "Focus" }
    NexusControls.ToggleRow {
        first: true
        last: true
        text: "Do Not Disturb"
        checked: Theme.dndEnabled
        onToggled: n => Theme.setDndEnabled(n)
    }
}
