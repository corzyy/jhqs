pragma ComponentBehavior: Bound
import QtQuick
import "../../../themes"
import "../../../services"
import ".."

NexusControls.PageBase {
    id: root
    title: "Appearance"

    NexusControls.SectionHeader { first: true; text: "Panels" }
    NexusControls.ConnectedRect {
        first: true
        last: true
        // Preview in the same card style as the other settings previews.
        // Click toggles the accent border.
        height: 78
        color: Theme.panelAccentBorder ? Theme.withAlpha(Theme.accent, 0.16)
            : previewMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08)
            : Theme.withAlpha(Theme.textPrimary, 0.04)
        border.color: Theme.panelBorderColor
        border.width: Theme.panelAccentBorder ? 2 : 1
        Column {
            anchors.centerIn: parent
            spacing: 6
            Rectangle {
                antialiasing: Theme.shapesAa
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64
                height: 30
                radius: 2
                color: Theme.bg
                border.color: Theme.panelBorderColor
                border.width: 2
                Column {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 3
                    Rectangle { width: 20; height: 4; radius: 2; color: Theme.withAlpha(Theme.textPrimary, 0.35); antialiasing: Theme.shapesAa }
                    Rectangle { width: parent.width; height: 1; color: Theme.divider }
                    Rectangle { width: parent.width * 0.7; height: 4; radius: 2; color: Theme.withAlpha(Theme.textPrimary, 0.14); antialiasing: Theme.shapesAa }
                }
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Accent Border"
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(11)
                color: Theme.textSecondary
            }
        }
        MouseArea { id: previewMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Theme.setPanelAccentBorder(!Theme.panelAccentBorder) }
    }
    NexusControls.SliderRow { first: true; last: true; label: "Rounding"; from: 0; to: 40; stepSize: 1; unit: "px"; value: Theme.cornerRadius; onMoved: v => { Theme.setCornerRadius(Math.round(v)); MangoService.preview("border_radius", Math.round(v)) }; onApplied: v => { Theme.setCornerRadius(Math.round(v)); MangoService.applyBorderRadius(v) } }
    Text {
        width: parent.width
        leftPadding: 8
        wrapMode: Text.WordWrap
        text: "Applies to the shell and MangoWM windows."
        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
        color: Theme.textMuted
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
    }

    NexusControls.SectionHeader { text: "Animations" }
    NexusControls.ToggleRow {
        first: true
        last: true
        text: "Shell Animations"
        subtext: "Panels, menus, toggles and sliders"
        checked: Theme.animationsEnabled
        onToggled: n => Theme.setAnimationsEnabled(n)
    }

    NexusControls.SectionHeader { text: "Font" }
    NexusControls.SliderRow { first: true; label: "Shell Text Size"; from: 85; to: 125; stepSize: 5; unit: "%"; value: Theme.fontScale * 100; onMoved: v => Theme.setFontScale(v / 100); onApplied: v => Theme.setFontScale(v / 100) }
    NexusControls.SliderRow { label: "System Text Size"; from: 8; to: 16; stepSize: 1; unit: "pt"; value: Theme.fontSize; onMoved: v => Theme.setFontSize(v); onApplied: v => Theme.setFontSize(v) }
    NexusControls.ToggleRow {
        last: true
        text: "Bold Text"
        checked: Theme.textBold
        onToggled: n => Theme.setTextBold(n)
    }
}
