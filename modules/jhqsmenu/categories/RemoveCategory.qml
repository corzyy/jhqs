pragma ComponentBehavior: Bound
import QtQuick

QtObject {
    readonly property var items: [
        {title: "Package", icon: "󰣇", arrow: "›"},
        {title: "AUR", icon: "󰣇", arrow: "›"},
        {title: "Flatpak", icon: "󰆴", arrow: "›"},
        {title: "Web App", icon: "󰖟", arrow: "›"}
    ]
}
