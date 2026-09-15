pragma ComponentBehavior: Bound
import QtQuick

// Merged from categories/{Style,Setup,Learn,Install,Remove,System}Category.qml
// (each was 11-19 lines of pure static data). Single source for all
// menu category lists + theme options.
QtObject {
    id: root

    readonly property var styleMenu: [
        {title: "Wallpaper", icon: "󰋩", arrow: "›"},
        {title: "Themes", icon: "󰉼", arrow: "›"},
        {title: "Font", icon: "󰛖", arrow: "›"},
        {title: "Modules", icon: "󰐱", arrow: "›"}
    ]
    readonly property var themeOptions: [
        {id: "wallpaper", title: "Wallpaper / Monet", icon: "󰸉", subtitle: "Automatic from wallpaper", placeholder: false},
        {id: "everforest", title: "Everforest", icon: "󰇧", subtitle: "Everforest Soft • #A7C080", placeholder: false},
        {id: "tokyonight", title: "Tokyo Night", icon: "󰖔", subtitle: "Tokyo Night • #7aa2f7 / #1a1b26", placeholder: false},
        {id: "petrichor", title: "Petrichor", icon: "󰋊", subtitle: "Omarchy Petrichor • #93a06b / #171a15", placeholder: false},
        {id: "monochrome", title: "Monochrome", icon: "󰃥", subtitle: "Grayscale 16 • #e7e7e7 / #181818", placeholder: false},
        {id: "catppuccin", title: "Catppuccin Mocha", icon: "󰄛", subtitle: "Catppuccin Mocha • #cba6f7 / #1e1e2e", placeholder: false},
        {id: "gruvbox", title: "Gruvbox", icon: "󰌛", subtitle: "Omarchy Gruvbox • #7daea3 / #282828", placeholder: false}
    ]

    readonly property var setupMenu: [
        {title: "Settings", icon: "󰒓", arrow: "›"},
        {title: "Monitors", icon: "󰍹", arrow: ""},
        {title: "Keybindings", icon: "󰌌", arrow: ""},
        {title: "Autostart", icon: "󰐥", arrow: ""},
        {title: "Audio", icon: "󰕾", arrow: ""},
        {title: "Shell Update", icon: "󰚰", arrow: ""}
    ]

    readonly property var learnMenu: [
        {title: "Keybindings", icon: "󰌌", arrow: ""},
        {title: "Apps", icon: "󰀻", arrow: ""},
        {title: "Windows", icon: "󰖲", arrow: ""},
        {title: "Workspaces", icon: "󰏃", arrow: ""}
    ]

    readonly property var installMenu: [
        {title: "Package", icon: "󰣛", arrow: "›"},
        {title: "Flatpak", icon: "󰇚", arrow: "›"},
        {title: "Web App", icon: "󰖟", arrow: "›"},
        {title: "Gaming", icon: "󰊗", arrow: "›"},
        {title: "Browser", icon: "󰖟", arrow: "›"}
    ]

    readonly property var removeMenu: [
        {title: "Package", icon: "󰣛", arrow: "›"},
        {title: "Flatpak", icon: "󰆴", arrow: "›"},
        {title: "Web App", icon: "󰖟", arrow: "›"}
    ]

    readonly property var sessionMenu: [
        {title: "Lock", icon: "󰌾", arrow: ""},
        {title: "Log Out", icon: "󰍃", arrow: ""},
        {title: "Suspend", icon: "󰒲", arrow: ""},
        {title: "Restart", icon: "󰜉", arrow: ""},
        {title: "Shut Down", icon: "󰐥", arrow: ""}
    ]
}
