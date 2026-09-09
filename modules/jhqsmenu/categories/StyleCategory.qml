pragma ComponentBehavior: Bound
import QtQuick

QtObject {
    readonly property var items: [
        {title: "Wallpaper", icon: "󰋩", arrow: "›"},
        {title: "Themes", icon: "󰉼", arrow: "›"},
        {title: "Font", icon: "󰛖", arrow: "›"},
        {title: "Modules", icon: "󰐱", arrow: "›"}
    ]
    readonly property var themeOptions: [
        {id: "wallpaper", title: "Wallpaper / Monet", icon: "󰸉", subtitle: "Automatisch aus Wallpaper", placeholder: false},
        {id: "everforest", title: "Everforest", icon: "󰇧", subtitle: "Everforest Soft • #A7C080", placeholder: false},
        {id: "tokyonight", title: "Tokyo Night", icon: "󰖔", subtitle: "Tokyo Night • #7aa2f7 / #1a1b26", placeholder: false},
        {id: "petrichor", title: "Petrichor", icon: "󰋊", subtitle: "Omarchy Petrichor • #93a06b / #171a15", placeholder: false},
        {id: "monochrome", title: "Monochrome", icon: "󰃥", subtitle: "Grayscale 16 • #e7e7e7 / #181818", placeholder: false},
        {id: "catppuccin", title: "Catppuccin Mocha", icon: "󰄛", subtitle: "Catppuccin Mocha • #cba6f7 / #1e1e2e", placeholder: false}
    ]
}
