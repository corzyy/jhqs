pragma ComponentBehavior: Bound
import QtQuick
import "../../../themes"
import ".."

Column {
    id: root
    width: parent ? parent.width : 400
    spacing: 10

    SettingsSection {
        title: "Menu Search"
        SettingsRow {
            title: "Apps"
            subtitle: "App hits and the Apps entry"
            SettingsToggle { on: Theme.searchAppsEnabled; onToggled: n => Theme.setSearchAppsEnabled(n) }
        }
        SettingsRow {
            title: "Style"
            subtitle: "Wallpaper, Themes, Font, Modules"
            SettingsToggle { on: Theme.searchStyleEnabled; onToggled: n => Theme.setSearchStyleEnabled(n) }
        }
        SettingsRow {
            title: "Setup"
            subtitle: "Settings, Monitors, Keybindings, Autostart, Audio"
            SettingsToggle { on: Theme.searchSetupEnabled; onToggled: n => Theme.setSearchSetupEnabled(n) }
        }
        SettingsRow {
            title: "Install"
            subtitle: "Package, AUR, Flatpak, Web App, Gaming, Browser"
            SettingsToggle { on: Theme.searchInstallEnabled; onToggled: n => Theme.setSearchInstallEnabled(n) }
        }
        SettingsRow {
            title: "Remove"
            subtitle: "Package, AUR, Flatpak, Web App"
            SettingsToggle { on: Theme.searchRemoveEnabled; onToggled: n => Theme.setSearchRemoveEnabled(n) }
        }
        SettingsRow {
            title: "About"
            SettingsToggle { on: Theme.searchAboutEnabled; onToggled: n => Theme.setSearchAboutEnabled(n) }
        }
        SettingsRow {
            title: "System"
            subtitle: "Lock, logout, suspend, reboot, shutdown"
            SettingsToggle { on: Theme.searchSystemEnabled; onToggled: n => Theme.setSearchSystemEnabled(n) }
        }
    }
}
