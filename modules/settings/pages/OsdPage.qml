pragma ComponentBehavior: Bound
import QtQuick
import "../../../themes"
import ".."

Column {
    id: root
    width: parent ? parent.width : 400
    spacing: 10

    SettingsControls.SettingsSection {
        title: "Overlays"
        SettingsControls.SettingsRow {
            title: "Volume OSD"
            SettingsControls.SettingsToggle { on: Theme.osdVolumeEnabled; onToggled: n => Theme.setOsdVolumeEnabled(n) }
        }
        SettingsControls.SettingsRow {
            title: "Launch OSD"
            SettingsControls.SettingsToggle { on: Theme.osdLaunchEnabled; onToggled: n => Theme.setOsdLaunchEnabled(n) }
        }
    }
}
