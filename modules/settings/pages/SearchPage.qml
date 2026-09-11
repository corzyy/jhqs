pragma ComponentBehavior: Bound
import QtQuick
import "../../../themes"
import ".."

Column {
    id: root
    width: parent ? parent.width : 400
    spacing: 10

    SettingsControls.SettingsSection {
        title: "Menu Search"
        SettingsControls.SettingsRow {
            title: "Apps"
            subtitle: "App hits and the Apps entry"
            SettingsControls.SettingsToggle { on: Theme.searchAppsEnabled; onToggled: n => Theme.setSearchAppsEnabled(n) }
        }
        SettingsControls.SettingsRow {
            title: "Style"
            subtitle: "Wallpaper, Themes, Font, Modules"
            SettingsControls.SettingsToggle { on: Theme.searchStyleEnabled; onToggled: n => Theme.setSearchStyleEnabled(n) }
        }
        SettingsControls.SettingsRow {
            title: "Setup"
            subtitle: "Settings, Monitors, Keybindings, Autostart, Audio"
            SettingsControls.SettingsToggle { on: Theme.searchSetupEnabled; onToggled: n => Theme.setSearchSetupEnabled(n) }
        }
        SettingsControls.SettingsRow {
            title: "Install"
            subtitle: "Package, AUR, Flatpak, Web App, Gaming, Browser"
            SettingsControls.SettingsToggle { on: Theme.searchInstallEnabled; onToggled: n => Theme.setSearchInstallEnabled(n) }
        }
        SettingsControls.SettingsRow {
            title: "Remove"
            subtitle: "Package, AUR, Flatpak, Web App"
            SettingsControls.SettingsToggle { on: Theme.searchRemoveEnabled; onToggled: n => Theme.setSearchRemoveEnabled(n) }
        }
        SettingsControls.SettingsRow {
            title: "About"
            SettingsControls.SettingsToggle { on: Theme.searchAboutEnabled; onToggled: n => Theme.setSearchAboutEnabled(n) }
        }
        SettingsControls.SettingsRow {
            title: "System"
            subtitle: "Lock, logout, suspend, reboot, shutdown"
            SettingsControls.SettingsToggle { on: Theme.searchSystemEnabled; onToggled: n => Theme.setSearchSystemEnabled(n) }
        }
    }
}
