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
        SettingsControls.SettingsSliderRow { label: "Timeout"; from: 0; to: 30; stepSize: 1; unit: "s"; value: Theme.notifTimeout; onMoved: v => Theme.setNotifTimeout(Math.round(v)); onApplied: v => Theme.setNotifTimeout(Math.round(v)) }
        SettingsControls.SettingsDropdown {
            label: "Corner"
            options: ["top-left", "top-center", "top-right", "bottom-left", "bottom-center", "bottom-right"]
            current: Theme.notifPosition
            onPicked: v => Theme.setNotifPosition(v)
        }
    }

    SettingsControls.SettingsSection {
        title: "Focus"
        SettingsControls.SettingsRow {
            title: "Do Not Disturb"
            SettingsControls.SettingsToggle { on: Theme.dndEnabled; onToggled: n => Theme.setDndEnabled(n) }
        }
    }
}
