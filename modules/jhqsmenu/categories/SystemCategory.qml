pragma ComponentBehavior: Bound
import QtQuick

QtObject {
    readonly property var items: [
        {title: "Sperren", icon: "󰌾", arrow: ""},
        {title: "Abmelden", icon: "󰍃", arrow: ""},
        {title: "Ruhezustand", icon: "󰒲", arrow: ""},
        {title: "Neustarten", icon: "󰜉", arrow: ""},
        {title: "Herunterfahren", icon: "󰐥", arrow: ""}
    ]
}
