pragma ComponentBehavior: Bound
import QtQuick
import "../../../themes"
import "../../../services"
import ".."

NexusControls.PageBase {
    id: root
    title: "Workspaces"

    NexusControls.SectionHeader { first: true; text: "Style" }
    Row {
        width: parent.width
        spacing: 8
        Repeater {
            model: [
                { id: "default", label: "Default" },
                { id: "default2", label: "Default2" },
                { id: "m3", label: "M3" }
            ]
            delegate: NexusControls.PreviewTile {
                required property var modelData
                readonly property string styleId: modelData.id
                readonly property bool isCurrent: Theme.workspaceStyle === styleId
                width: (parent.width - 16) / 3
                height: 64
                selected: isCurrent
                label: modelData.label
                onClicked: Theme.setWorkspaceStyle(styleId)
                Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 56
                        height: 22
                        // Default: workspace numbers, focused one accented
                        Row {
                            visible: styleId === "default"
                            anchors.centerIn: parent
                            spacing: 7
                            Repeater {
                                model: ["1", "2", "3"]
                                delegate: Text {
                                    required property var modelData
                                    required property int index
                                    text: modelData
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fs(12)
                                    font.weight: index === 1 ? Font.Bold : Font.Normal
                                    color: index === 1 ? Theme.accent : Theme.textMuted
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                            }
                        }
                        // Default2: boxed cell with accent underline on focused
                        Row {
                            visible: styleId === "default2"
                            anchors.centerIn: parent
                            spacing: 5
                            Repeater {
                                model: 3
                                delegate: Rectangle {
                                    required property int index
                                    width: 15; height: 20; radius: 0
                                    antialiasing: Theme.shapesAa
                                    color: index === 1 ? Theme.withAlpha(Theme.accent, 0.20) : "transparent"
                                    border.color: index === 1 ? Theme.accent : Theme.divider
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: index + 1
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: Theme.fs(10)
                                        font.weight: index === 1 ? Font.Bold : Font.Normal
                                        color: index === 1 ? Theme.textPrimary : Theme.textMuted
                                        antialiasing: Theme.textAa
                                        renderType: Theme.textRenderType
                                    }
                                    Rectangle {
                                        visible: index === 1
                                        anchors.left: parent.left; anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 2
                                        color: Theme.accent
                                    }
                                }
                            }
                        }
                        // M3: pills sized by state, focused one accented
                        Row {
                            visible: styleId === "m3"
                            anchors.centerIn: parent
                            spacing: 4
                            Repeater {
                                model: [8, 22, 8]
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: modelData; height: 7; radius: 3.5
                                    anchors.verticalCenter: parent.verticalCenter
                                    antialiasing: Theme.shapesAa
                                    color: index === 1 ? Theme.accent : Theme.divider
                                }
                            }
                        }
                    }
                }
            }
        }

    NexusControls.SectionHeader { text: "Spacing" }
    NexusControls.SliderRow { first: true; last: true; label: "Distance"; from: 0; to: 24; stepSize: 1; unit: "px"; value: Theme.workspaceSpacing; onMoved: v => Theme.setWorkspaceSpacing(Math.round(v)); onApplied: v => Theme.setWorkspaceSpacing(Math.round(v)) }

    NexusControls.SectionHeader { text: "Scale" }
    NexusControls.SliderRow { first: true; last: true; label: "Widget Scale"; from: 50; to: 200; stepSize: 5; unit: "%"; value: Theme.workspaceScale * 100; onMoved: v => Theme.setWorkspaceScale(v / 100); onApplied: v => Theme.setWorkspaceScale(v / 100) }
}
