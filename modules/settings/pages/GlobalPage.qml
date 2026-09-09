pragma ComponentBehavior: Bound
import QtQuick
import "../../../themes"
import "../../../services"
import ".."

Column {
    id: root
    width: parent ? parent.width : 400
    spacing: 10

    SettingsSection {
        title: "Shell Theme"
        Row {
            width: parent.width; spacing: 8
            Repeater {
                model: ["Modern", "Minimal"]
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: Theme.shellTheme === (modelData + "").toLowerCase()
                    width: (root.width - 24) / 2; height: 34
                    radius: Theme.minimalTheme ? 0 : Theme.cornerRadiusSmall
                    antialiasing: Theme.shapesAa
                    color: isCurrent && Theme.minimalTheme ? Theme.withAlpha(Theme.accent, 0.16)
                        : isCurrent ? Theme.bgSelected
                        : themeMouse.containsMouse ? (Theme.minimalTheme ? Theme.withAlpha(Theme.textPrimary, 0.08) : Theme.bgHover)
                        : (Theme.minimalTheme ? Theme.withAlpha(Theme.textPrimary, 0.04) : Theme.panelSurface)
                    border.color: isCurrent ? Theme.accent : (Theme.minimalTheme ? Theme.withAlpha(Theme.textPrimary, 0.25) : Theme.divider)
                    border.width: isCurrent && Theme.minimalTheme ? 2 : 1
                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                    Text { anchors.centerIn: parent; text: modelData; font.family: Theme.minimalTheme ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Theme.minimalTheme ? Font.Bold : Font.Medium; color: Theme.textPrimary
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    MouseArea { id: themeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Theme.setShellTheme((modelData + "").toLowerCase()) }
                }
            }
        }
        Text {
            visible: Theme.shellTheme === "minimal"
            width: parent ? parent.width : 300
            text: "Quattro menu styling, sharp corners, no blur (shell + Hyprland)."
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
            color: Theme.textMuted
            wrapMode: Text.WordWrap
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
    }

    SettingsSection {
        title: "Appearance"
        SettingsSliderRow { visible: !Theme.minimalTheme; height: visible ? implicitHeight : 0; label: "Corner Radius"; from: 0; to: 24; stepSize: 1; unit: "px"; value: Theme.cornerRadius; onMoved: v => Theme.setShellRadius(Math.round(v)); onApplied: v => Theme.setShellRadius(Math.round(v)) }
        SettingsSliderRow { visible: !Theme.minimalTheme; height: visible ? implicitHeight : 0; label: "Panel Blur"; from: 0; to: 1; stepSize: 0.05; value: Theme.panelBlur; onMoved: v => Theme.setPanelBlur(v); onApplied: v => Theme.setPanelBlur(v) }
        SettingsRow {
            title: "Accent Border"
            SettingsToggle { on: Theme.panelAccentBorder; onToggled: n => Theme.setPanelAccentBorder(n) }
        }
    }

    SettingsSection {
        title: "Motion"
        SettingsRow {
            title: "Animations"
            SettingsToggle { on: Theme.animationsEnabled; onToggled: n => Theme.setAnimationsEnabled(n) }
        }
        SettingsSliderRow { label: "Animation Scale"; from: 0.2; to: 3.0; stepSize: 0.1; unit: "x"; value: Theme.animationScale; onMoved: v => Theme.setAnimationScale(v); onApplied: v => Theme.setAnimationScale(v) }
    }

    SettingsSection {
        title: "Font"
        SettingsSliderRow { label: "Shell Text Size"; from: 85; to: 125; stepSize: 5; unit: "%"; value: Theme.fontScale * 100; onMoved: v => Theme.setFontScale(v / 100); onApplied: v => Theme.setFontScale(v / 100) }
        SettingsSliderRow { label: "System Text Size"; from: 8; to: 16; stepSize: 1; unit: "pt"; value: Theme.fontSize; onMoved: v => Theme.setFontSize(v); onApplied: v => Theme.setFontSize(v) }
        SettingsRow {
            title: "Bold Text"
            SettingsToggle { on: Theme.textBold; onToggled: n => Theme.setTextBold(n) }
        }
    }

    SettingsSection {
        title: "Antialiasing"
        SettingsRow {
            title: "Shapes & Corners"
            subtitle: "Edge smoothing on all rounded shapes and panels"
            SettingsToggle { on: Theme.shapesAa; onToggled: n => Theme.setShapesAa(n) }
        }
        SettingsRow {
            title: "Text"
            subtitle: "Smooth glyph edges"
            SettingsToggle { on: Theme.textAa; onToggled: n => Theme.setTextAa(n) }
        }
        SettingsRow {
            title: "Native Text Rendering"
            subtitle: "OS rasterizer (crisper) vs Qt rasterizer"
            SettingsToggle { on: Theme.textNative; onToggled: n => Theme.setTextNative(n) }
        }
        SettingsRow {
            title: "Image Smoothing"
            subtitle: "Bilinear filtering on scaled images"
            SettingsToggle { on: Theme.imageSmooth; onToggled: n => Theme.setImageSmooth(n) }
        }
        SettingsRow {
            title: "Image Mipmaps"
            subtitle: "+33% VRAM, sharper downscaled images"
            SettingsToggle { on: Theme.imageMipmap; onToggled: n => Theme.setImageMipmap(n) }
        }
    }

    SettingsSection {
        visible: !Theme.minimalTheme; height: visible ? implicitHeight : 0
        title: "Blur"
        SettingsRow {
            title: "Blur"
            SettingsToggle { on: SettingsService.hyprBlur; onToggled: n => SettingsService.applyBlur(n) }
        }
        SettingsSliderRow { label: "Blur Size"; from: 0; to: 30; stepSize: 1; value: SettingsService.hyprBlurSize; onMoved: v => SettingsService.previewBlurSize(v); onApplied: v => SettingsService.applyBlurSize(v) }
        SettingsSliderRow { label: "Blur Passes"; from: 1; to: 6; stepSize: 1; value: SettingsService.hyprBlurPasses; onMoved: v => SettingsService.previewBlurPasses(v); onApplied: v => SettingsService.applyBlurPasses(v) }
        SettingsSliderRow { label: "Vibrancy"; from: 0; to: 3; stepSize: 0.05; value: SettingsService.hyprVibrancy; onMoved: v => SettingsService.previewVibrancy(v); onApplied: v => SettingsService.applyVibrancy(v) }
        SettingsSliderRow { label: "Vibrancy Darkness"; from: 0; to: 1; stepSize: 0.01; value: SettingsService.hyprVibrancyDarkness; onMoved: v => SettingsService.previewVibrancyDarkness(v); onApplied: v => SettingsService.applyVibrancyDarkness(v) }
        SettingsSliderRow { label: "Contrast"; from: 0; to: 2; stepSize: 0.05; value: SettingsService.hyprContrast; onMoved: v => SettingsService.previewContrast(v); onApplied: v => SettingsService.applyContrast(v) }
        SettingsSliderRow { label: "Brightness"; from: 0; to: 2; stepSize: 0.05; value: SettingsService.hyprBrightness; onMoved: v => SettingsService.previewBlurBrightness(v); onApplied: v => SettingsService.applyBlurBrightness(v) }
        SettingsSliderRow { label: "Noise"; from: 0; to: 1; stepSize: 0.01; value: SettingsService.hyprNoise; onMoved: v => SettingsService.previewNoise(v); onApplied: v => SettingsService.applyNoise(v) }
        SettingsRow {
            title: "Ignore Opacity"
            SettingsToggle { on: SettingsService.hyprIgnoreOpacity; onToggled: n => SettingsService.applyIgnoreOpacity(n) }
        }
        SettingsRow {
            title: "New Optimizations"
            SettingsToggle { on: SettingsService.hyprNewOpt; onToggled: n => SettingsService.applyNewOpt(n) }
        }
        SettingsRow {
            title: "Special Workspace"
            SettingsToggle { on: SettingsService.hyprSpecial; onToggled: n => SettingsService.applyBlurSpecial(n) }
        }
        SettingsRow {
            title: "Popups"
            SettingsToggle { on: SettingsService.hyprPopups; onToggled: n => SettingsService.applyBlurPopups(n) }
        }
    }
}
