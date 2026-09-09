pragma ComponentBehavior: Bound
import QtQuick

QtObject {
    readonly property var items: [
        {title: "Settings", icon: "󰒓", arrow: "›"},
        {title: "Monitors", icon: "󰍹", arrow: ""},
        {title: "Keybindings", icon: "󰌌", arrow: ""},
        {title: "Autostart", icon: "󰐥", arrow: ""},
        {title: "Audio", icon: "󰕾", arrow: ""}
    ]
}
