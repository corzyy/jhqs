pragma ComponentBehavior: Bound
import QtQuick
import "../../../themes"
import ".."

Column {
    id: root
    width: parent ? parent.width : 400
    spacing: 10

    SettingsControls.SettingsSection {
        title: "Popups"
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
                font.letterSpacing: 0
                color: Theme.textSecondary
            }
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
                    delegate: Rectangle {
                        required property var modelData
                        readonly property string posId: modelData.id
                        readonly property bool isCurrent: Theme.notifPosition === posId
                        readonly property bool isTop: posId.indexOf("top") === 0
                        readonly property bool isLeft: posId.indexOf("left") !== -1
                        readonly property bool isRight: posId.indexOf("right") !== -1
                        width: (parent.width - 16) / 3
                        height: 68
                        radius: Theme.cornerRadiusSmall
                        antialiasing: Theme.shapesAa
                        color: isCurrent ? Theme.withAlpha(Theme.accent, 0.16)
                            : posMouse.containsMouse ? (Theme.withAlpha(Theme.textPrimary, 0.08))
                            : (Theme.withAlpha(Theme.textPrimary, 0.04))
                        border.color: isCurrent ? Theme.accent : Theme.divider
                        border.width: isCurrent ? 2 : 1
                        Column {
                            anchors.centerIn: parent
                            spacing: 4
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
                        MouseArea { id: posMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Theme.setNotifPosition(posId) }
                    }
                }
            }
        }
        SettingsControls.SettingsSliderRow { label: "Timeout"; from: 0; to: 30; stepSize: 1; unit: "s"; value: Theme.notifTimeout; onMoved: v => Theme.setNotifTimeout(Math.round(v)); onApplied: v => Theme.setNotifTimeout(Math.round(v)) }
    }

    SettingsControls.SettingsSection {
        title: "Focus"
        SettingsControls.SettingsRow {
            title: "Do Not Disturb"
            SettingsControls.SettingsToggle { on: Theme.dndEnabled; onToggled: n => Theme.setDndEnabled(n) }
        }
    }
}
