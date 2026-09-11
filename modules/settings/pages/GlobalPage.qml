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
        title: "Appearance"
        SettingsControls.SettingsRow {
            title: "Accent Border"
            SettingsControls.SettingsToggle { on: Theme.panelAccentBorder; onToggled: n => Theme.setPanelAccentBorder(n) }
        }
    }

    SettingsControls.SettingsSection {
        title: "Motion"
        SettingsControls.SettingsRow {
            title: "Animations"
            SettingsControls.SettingsToggle { on: Theme.animationsEnabled; onToggled: n => Theme.setAnimationsEnabled(n) }
        }
        SettingsControls.SettingsSliderRow { label: "Animation Scale"; from: 0.2; to: 3.0; stepSize: 0.1; unit: "x"; value: Theme.animationScale; onMoved: v => Theme.setAnimationScale(v); onApplied: v => Theme.setAnimationScale(v) }
    }

    SettingsControls.SettingsSection {
        title: "Font"
        SettingsControls.SettingsSliderRow { label: "Shell Text Size"; from: 85; to: 125; stepSize: 5; unit: "%"; value: Theme.fontScale * 100; onMoved: v => Theme.setFontScale(v / 100); onApplied: v => Theme.setFontScale(v / 100) }
        SettingsControls.SettingsSliderRow { label: "System Text Size"; from: 8; to: 16; stepSize: 1; unit: "pt"; value: Theme.fontSize; onMoved: v => Theme.setFontSize(v); onApplied: v => Theme.setFontSize(v) }
        SettingsControls.SettingsRow {
            title: "Bold Text"
            SettingsControls.SettingsToggle { on: Theme.textBold; onToggled: n => Theme.setTextBold(n) }
        }
    }

    SettingsControls.SettingsSection {
        title: "Antialiasing"
        SettingsControls.SettingsRow {
            title: "Shapes & Corners"
            subtitle: "Edge smoothing on all rounded shapes and panels"
            SettingsControls.SettingsToggle { on: Theme.shapesAa; onToggled: n => Theme.setShapesAa(n) }
        }
        SettingsControls.SettingsRow {
            title: "Text"
            subtitle: "Smooth glyph edges"
            SettingsControls.SettingsToggle { on: Theme.textAa; onToggled: n => Theme.setTextAa(n) }
        }
        SettingsControls.SettingsRow {
            title: "Native Text Rendering"
            subtitle: "OS rasterizer (crisper) vs Qt rasterizer"
            SettingsControls.SettingsToggle { on: Theme.textNative; onToggled: n => Theme.setTextNative(n) }
        }
        SettingsControls.SettingsRow {
            title: "Image Smoothing"
            subtitle: "Bilinear filtering on scaled images"
            SettingsControls.SettingsToggle { on: Theme.imageSmooth; onToggled: n => Theme.setImageSmooth(n) }
        }
        SettingsControls.SettingsRow {
            title: "Image Mipmaps"
            subtitle: "+33% VRAM, sharper downscaled images"
            SettingsControls.SettingsToggle { on: Theme.imageMipmap; onToggled: n => Theme.setImageMipmap(n) }
        }
    }

}
