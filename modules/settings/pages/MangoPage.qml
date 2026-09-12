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
        title: "Layout"
        Row {
            width: parent.width; spacing: 8
            Repeater {
                model: [
                    { id: "dwindle", label: "Dwindle" },
                    { id: "scroller", label: "Scrolling" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    readonly property string layId: modelData.id
                    readonly property bool isCurrent: MangoService.mangoLayout === layId
                    width: (parent.width - 8) / 2; height: 78
                    radius: Theme.cornerRadiusSmall
                    antialiasing: Theme.shapesAa
                    color: isCurrent ? Theme.withAlpha(Theme.accent, 0.16)
                        : layMouse.containsMouse ? (Theme.withAlpha(Theme.textPrimary, 0.08))
                        : (Theme.withAlpha(Theme.textPrimary, 0.04))
                    border.color: isCurrent ? Theme.accent : Theme.divider
                    border.width: isCurrent ? 2 : 1
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 44
                            height: 30
                            radius: 2
                            color: "transparent"
                            border.color: isCurrent ? Theme.accent : Theme.divider
                            border.width: 1
                            // Dwindle: recursive split — master left, right stacked then split
                            Rectangle {
                                visible: layId === "dwindle"
                                x: 2; y: 2; width: 19; height: 26; radius: 1
                                color: Theme.withAlpha(Theme.textPrimary, 0.10)
                                border.color: Theme.accent; border.width: 1
                            }
                            Rectangle {
                                visible: layId === "dwindle"
                                x: 23; y: 2; width: 19; height: 12; radius: 1
                                color: Theme.withAlpha(Theme.textPrimary, 0.10)
                                border.color: Theme.divider; border.width: 1
                            }
                            Rectangle {
                                visible: layId === "dwindle"
                                x: 23; y: 16; width: 8; height: 12; radius: 1
                                color: Theme.withAlpha(Theme.textPrimary, 0.10)
                                border.color: Theme.divider; border.width: 1
                            }
                            Rectangle {
                                visible: layId === "dwindle"
                                x: 33; y: 16; width: 9; height: 12; radius: 1
                                color: Theme.withAlpha(Theme.textPrimary, 0.10)
                                border.color: Theme.divider; border.width: 1
                            }
                            // Scrolling: full-height window strip, focused center
                            Rectangle {
                                visible: layId === "scroller"
                                x: 2; y: 2; width: 10; height: 26; radius: 1
                                color: Theme.withAlpha(Theme.textPrimary, 0.10)
                                border.color: Theme.divider; border.width: 1
                            }
                            Rectangle {
                                visible: layId === "scroller"
                                x: 14; y: 2; width: 16; height: 26; radius: 1
                                color: Theme.withAlpha(Theme.textPrimary, 0.10)
                                border.color: Theme.accent; border.width: 1
                            }
                            Rectangle {
                                visible: layId === "scroller"
                                x: 32; y: 2; width: 10; height: 26; radius: 1
                                color: Theme.withAlpha(Theme.textPrimary, 0.10)
                                border.color: Theme.divider; border.width: 1
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
                    MouseArea { id: layMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: MangoService.applyLayout(layId) }
                }
            }
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Rewrites layout_name in workspaces.conf tagrules + switches live. Cycle with SUPER+N (switch_layout)."
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
            color: Theme.textMuted
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
    }

    SettingsControls.SettingsSection {
        title: "Gaps & Borders"
        SettingsControls.SettingsSliderRow { label: "Inner Gap"; from: 0; to: 60; stepSize: 1; unit: "px"; value: MangoService.mangoGappih; onMoved: v => { MangoService.preview("gappih", Math.round(v)); MangoService.preview("gappiv", Math.round(v)) }; onApplied: v => MangoService.applyInnerGap(v) }
        SettingsControls.SettingsSliderRow { label: "Outer Gap"; from: 0; to: 100; stepSize: 1; unit: "px"; value: MangoService.mangoGappoh; onMoved: v => { MangoService.preview("gappoh", Math.round(v)); MangoService.preview("gappov", Math.round(v)) }; onApplied: v => MangoService.applyOuterGap(v) }
        SettingsControls.SettingsSliderRow { label: "Border Size"; from: 0; to: 20; stepSize: 1; unit: "px"; value: MangoService.mangoBorderpx; onMoved: v => MangoService.preview("borderpx", Math.round(v)); onApplied: v => MangoService.applyBorderpx(v) }
        SettingsControls.SettingsSliderRow { label: "Corner Radius"; from: 0; to: 40; stepSize: 1; unit: "px"; value: MangoService.mangoBorderRadius; onMoved: v => MangoService.preview("border_radius", Math.round(v)); onApplied: v => MangoService.applyBorderRadius(v) }
    }

    SettingsControls.SettingsSection {
        title: "Animations"
        SettingsControls.SettingsRow {
            title: "Enabled"
            SettingsControls.SettingsToggle { on: MangoService.mangoAnimations; onToggled: n => MangoService.applyAnimations(n) }
        }
        SettingsControls.SettingsDropdown {
            label: "Open"
            options: ["slide", "zoom", "fade", "none"]
            current: MangoService.mangoAnimOpen
            onPicked: v => MangoService.applyAnimType("open", v)
        }
        SettingsControls.SettingsDropdown {
            label: "Close"
            options: ["slide", "zoom", "fade", "none"]
            current: MangoService.mangoAnimClose
            onPicked: v => MangoService.applyAnimType("close", v)
        }
        SettingsControls.SettingsSliderRow { label: "Open Duration"; from: 0; to: 2000; stepSize: 10; unit: "ms"; value: MangoService.mangoAnimDurOpen; onMoved: v => MangoService.preview("animation_duration_open", Math.round(v)); onApplied: v => MangoService.applyAnimDur("open", v) }
        SettingsControls.SettingsSliderRow { label: "Close Duration"; from: 0; to: 2000; stepSize: 10; unit: "ms"; value: MangoService.mangoAnimDurClose; onMoved: v => MangoService.preview("animation_duration_close", Math.round(v)); onApplied: v => MangoService.applyAnimDur("close", v) }
        SettingsControls.SettingsSliderRow { label: "Move Duration"; from: 0; to: 2000; stepSize: 10; unit: "ms"; value: MangoService.mangoAnimDurMove; onMoved: v => MangoService.preview("animation_duration_move", Math.round(v)); onApplied: v => MangoService.applyAnimDur("move", v) }
        SettingsControls.SettingsSliderRow { label: "Tag Duration"; from: 0; to: 2000; stepSize: 10; unit: "ms"; value: MangoService.mangoAnimDurTag; onMoved: v => MangoService.preview("animation_duration_tag", Math.round(v)); onApplied: v => MangoService.applyAnimDur("tag", v) }
    }

    SettingsControls.SettingsSection {
        title: "Behavior"
        SettingsControls.SettingsRow {
            title: "Smart Gaps"
            subtitle: "No gaps when a single window is visible"
            SettingsControls.SettingsToggle { on: MangoService.mangoSmartgaps; onToggled: n => MangoService.applySmartgaps(n) }
        }
        SettingsControls.SettingsRow {
            title: "No Border When Single"
            SettingsControls.SettingsToggle { on: MangoService.mangoNoBorderSingle; onToggled: n => MangoService.applyNoBorderSingle(n) }
        }
        SettingsControls.SettingsRow {
            title: "No Radius When Single"
            SettingsControls.SettingsToggle { on: MangoService.mangoNoRadiusSingle; onToggled: n => MangoService.applyNoRadiusSingle(n) }
        }
    }
}
