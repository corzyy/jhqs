pragma ComponentBehavior: Bound
import QtQuick
import "../../../themes"
import ".."

Column {
    id: root
    width: parent ? parent.width : 400
    spacing: 10

    SettingsSection {
        title: "Overlays"
        SettingsRow {
            title: "Volume OSD"
            SettingsToggle { on: Theme.osdVolumeEnabled; onToggled: n => Theme.setOsdVolumeEnabled(n) }
        }
        SettingsRow {
            title: "Launch OSD"
            SettingsToggle { on: Theme.osdLaunchEnabled; onToggled: n => Theme.setOsdLaunchEnabled(n) }
        }
        SettingsDropdown {
            label: "Position"
            options: ["top", "bottom", "right"]
            current: Theme.osdPosition
            onPicked: v => Theme.setOsdPosition(v)
        }
    }
}
