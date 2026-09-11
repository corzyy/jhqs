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
        title: "Kitty Terminal"
        SettingsControls.SettingsSliderRow { label: "Padding"; from: 0; to: 40; stepSize: 1; unit: "px"; value: SettingsService.kittyPadding; onMoved: v => SettingsService.applyKittyPadding(v); onApplied: v => SettingsService.applyKittyPadding(v) }
        SettingsControls.SettingsSliderRow { label: "Font Size"; from: 6; to: 32; stepSize: 0.5; unit: "pt"; value: SettingsService.kittyFontSize; onMoved: v => SettingsService.applyKittyFont(v); onApplied: v => SettingsService.applyKittyFont(v) }
        SettingsControls.SettingsSliderRow { label: "Opacity"; from: 0.3; to: 1.0; stepSize: 0.05; value: SettingsService.kittyOpacity; onMoved: v => SettingsService.applyKittyOpacity(v); onApplied: v => SettingsService.applyKittyOpacity(v) }
    }

    SettingsControls.SettingsSection {
        title: "Fish Prompt"
        SettingsControls.SettingsDropdown {
            label: "Style"
            options: ["minimal", "starship", "tide", "pure"]
            current: SettingsService.fishPrompt
            onPicked: v => SettingsService.applyFishPrompt(v)
        }
    }
}
