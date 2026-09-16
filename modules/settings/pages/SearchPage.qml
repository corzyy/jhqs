pragma ComponentBehavior: Bound
import QtQuick
import "../../../themes"
import "../../../services"
import ".."

NexusControls.PageBase {
    id: root
    title: "Search"

    NexusControls.SectionHeader { first: true; text: "Results" }
    NexusControls.ToggleRow {
        first: true
        text: "Applications"
        subtext: "Installed apps in menu search"
        checked: SettingsService.searchApps
        onToggled: n => SettingsService.setSearchEnabled("searchApps", n)
    }
    NexusControls.ToggleRow {
        last: true
        text: "Menu entries"
        subtext: "Top-level rows like Apps, Style, System"
        checked: SettingsService.searchMenu
        onToggled: n => SettingsService.setSearchEnabled("searchMenu", n)
    }

    NexusControls.SectionHeader { text: "Categories" }
    NexusControls.ToggleRow { first: true; text: "Learn"; checked: SettingsService.searchLearn; onToggled: n => SettingsService.setSearchEnabled("searchLearn", n) }
    NexusControls.ToggleRow { text: "Style"; checked: SettingsService.searchStyle; onToggled: n => SettingsService.setSearchEnabled("searchStyle", n) }
    NexusControls.ToggleRow { text: "Setup"; checked: SettingsService.searchSetup; onToggled: n => SettingsService.setSearchEnabled("searchSetup", n) }
    NexusControls.ToggleRow { text: "Install"; checked: SettingsService.searchInstall; onToggled: n => SettingsService.setSearchEnabled("searchInstall", n) }
    NexusControls.ToggleRow { text: "Remove"; checked: SettingsService.searchRemove; onToggled: n => SettingsService.setSearchEnabled("searchRemove", n) }
    NexusControls.ToggleRow { last: true; text: "System"; checked: SettingsService.searchSystem; onToggled: n => SettingsService.setSearchEnabled("searchSystem", n) }

    NexusControls.SectionHeader { text: "Features" }
    NexusControls.ToggleRow {
        first: true
        text: "Math"
        subtext: "Calculator, e.g. 12*8 or sqrt(2). Enter copies the result."
        checked: SettingsService.searchMath
        onToggled: n => SettingsService.setSearchEnabled("searchMath", n)
    }
    NexusControls.ToggleRow {
        text: "Units"
        subtext: "Converter, e.g. 100km mi or 32F C. Enter copies the result."
        checked: SettingsService.searchUnits
        onToggled: n => SettingsService.setSearchEnabled("searchUnits", n)
    }
    NexusControls.ToggleRow {
        text: "Generator"
        subtext: "uuid, pw 20 or pin. Enter copies the secret."
        checked: SettingsService.searchGen
        onToggled: n => SettingsService.setSearchEnabled("searchGen", n)
    }
    NexusControls.ToggleRow {
        last: true
        text: "Emoji"
        subtext: ":fire or emoji fire. Enter copies the glyph."
        checked: SettingsService.searchEmoji
        onToggled: n => SettingsService.setSearchEnabled("searchEmoji", n)
    }
}
