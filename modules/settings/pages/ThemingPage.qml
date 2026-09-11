pragma ComponentBehavior: Bound
import QtQuick
import "../../../themes"
import "../../../services"
import ".."

// Application Theming — ported from DankMaterialShell's Theme & Colors
// (Applications / Cursor / Icon / Matugen Templates / System App Theming),
// adapted to jhqs: matugen runs directly, Hyprland-only, qt via qt*ct.
Column {
    id: root
    width: parent ? parent.width : 400
    spacing: 10

    function templateSubtitle(appId: string, base: string): string {
        if (ThemingService.isAppDetected(appId)) return base
        if (base.length > 0) return base + " · Not detected"
        return "Not detected"
    }

    SettingsControls.SettingsSection {
        title: "Applications"
        SettingsControls.SettingsRow {
            title: "Sync Mode with Portal"
            subtitle: "Sync dark mode with settings portals for system-wide theme hints"
            SettingsControls.SettingsToggle { on: ThemingService.syncModeWithPortal; onToggled: n => ThemingService.setSyncMode(n) }
        }
        SettingsControls.SettingsRow {
            title: "Terminals - Always use Dark Theme"
            subtitle: "Force terminal applications to always use dark color schemes"
            SettingsControls.SettingsToggle { on: ThemingService.terminalsAlwaysDark; onToggled: n => ThemingService.setTerminalsAlwaysDark(n) }
        }
    }

    SettingsControls.SettingsSection {
        title: "Cursor Theme"
        SettingsControls.SettingsDropdown {
            label: "Theme"
            options: ThemingService.availableCursorThemes
            current: ThemingService.cursorTheme
            onPicked: v => ThemingService.setCursorTheme(v)
        }
        SettingsControls.SettingsSliderRow { label: "Cursor Size"; from: 12; to: 128; stepSize: 1; unit: "px"; value: ThemingService.cursorSize; onMoved: v => ThemingService.setCursorSize(Math.round(v)); onApplied: v => ThemingService.setCursorSize(Math.round(v)) }
        Text {
            width: parent.width
            text: "Applies live via hyprctl setcursor + env.lua, GTK settings and XResources."
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
            color: Theme.textMuted
            wrapMode: Text.WordWrap
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
    }

    SettingsControls.SettingsSection {
        title: "Icon Theme"
        SettingsControls.SettingsRow {
            title: "Separate Light & Dark Themes"
            subtitle: "Use different icon themes for light and dark mode"
            SettingsControls.SettingsToggle { on: ThemingService.iconThemePerMode; onToggled: n => ThemingService.setIconThemePerMode(n) }
        }
        SettingsControls.SettingsDropdown {
            visible: !ThemingService.iconThemePerMode
            height: visible ? implicitHeight : 0
            label: "Theme"
            options: ThemingService.availableIconThemes
            current: ThemingService.iconTheme
            onPicked: v => ThemingService.setIconTheme(v)
        }
        SettingsControls.SettingsDropdown {
            visible: ThemingService.iconThemePerMode
            height: visible ? implicitHeight : 0
            label: "Dark"
            options: ThemingService.availableIconThemes
            current: ThemingService.iconTheme
            onPicked: v => ThemingService.setIconTheme(v)
        }
        SettingsControls.SettingsDropdown {
            visible: ThemingService.iconThemePerMode
            height: visible ? implicitHeight : 0
            label: "Light"
            options: ThemingService.availableIconThemes
            current: ThemingService.iconThemeLight
            onPicked: v => ThemingService.setIconThemeLight(v)
        }
    }

    SettingsControls.SettingsSection {
        title: "Matugen Templates"
        SettingsControls.SettingsRow {
            title: "Run User Templates"
            subtitle: "Include your own [templates.*] blocks from matugen config"
            SettingsControls.SettingsToggle { on: ThemingService.runUserTemplates; onToggled: n => ThemingService.setRunUserTemplates(n) }
        }
        SettingsControls.SettingsRow {
            title: "GTK 3"
            subtitle: root.templateSubtitle("gtk", "gtk-3.0/colors.css")
            SettingsControls.SettingsToggle { on: ThemingService.templateGtk3; onToggled: n => ThemingService.setTemplate("gtk3", n) }
        }
        SettingsControls.SettingsRow {
            title: "GTK 4"
            subtitle: root.templateSubtitle("gtk", "gtk-4.0/colors.css")
            SettingsControls.SettingsToggle { on: ThemingService.templateGtk4; onToggled: n => ThemingService.setTemplate("gtk4", n) }
        }
        SettingsControls.SettingsRow {
            title: "Qt5ct"
            subtitle: root.templateSubtitle("qt5ct", "qt5ct/colors/matugen.conf")
            SettingsControls.SettingsToggle { on: ThemingService.templateQt5ct; onToggled: n => ThemingService.setTemplate("qt5ct", n) }
        }
        SettingsControls.SettingsRow {
            title: "Qt6ct"
            subtitle: root.templateSubtitle("qt6ct", "qt6ct/colors/matugen.conf")
            SettingsControls.SettingsToggle { on: ThemingService.templateQt6ct; onToggled: n => ThemingService.setTemplate("qt6ct", n) }
        }
        SettingsControls.SettingsRow {
            title: "KColorScheme"
            subtitle: root.templateSubtitle("qt6ct", "color-schemes/Matugen.colors")
            SettingsControls.SettingsToggle { on: ThemingService.templateQtColorscheme; onToggled: n => ThemingService.setTemplate("qt-colorscheme", n) }
        }
        SettingsControls.SettingsRow {
            title: "Kitty"
            subtitle: root.templateSubtitle("kitty", "kitty/current-theme.conf")
            SettingsControls.SettingsToggle { on: ThemingService.templateKitty; onToggled: n => ThemingService.setTemplate("kitty", n) }
        }
        SettingsControls.SettingsRow {
            title: "Ghostty"
            subtitle: root.templateSubtitle("ghostty", "")
            SettingsControls.SettingsToggle { on: ThemingService.templateGhostty; onToggled: n => ThemingService.setTemplate("ghostty", n) }
        }
        SettingsControls.SettingsRow {
            title: "Fcitx5"
            subtitle: root.templateSubtitle("fcitx5", "")
            SettingsControls.SettingsToggle { on: ThemingService.templateFcitx5; onToggled: n => ThemingService.setTemplate("fcitx5", n) }
        }
        SettingsControls.SettingsRow {
            title: "Firefox"
            subtitle: root.templateSubtitle("firefox", "")
            SettingsControls.SettingsToggle { on: ThemingService.templateFirefox; onToggled: n => ThemingService.setTemplate("firefox", n) }
        }
        SettingsControls.SettingsRow {
            title: "VS Code"
            subtitle: root.templateSubtitle("code", "Requires DMS Theme extension style colors")
            SettingsControls.SettingsToggle { on: ThemingService.templateVscode; onToggled: n => ThemingService.setTemplate("vscode", n) }
        }
        SettingsControls.SettingsRow {
            title: "Neovim"
            subtitle: root.templateSubtitle("nvim", "")
            SettingsControls.SettingsToggle { on: ThemingService.templateNeovim; onToggled: n => ThemingService.setTemplate("neovim", n) }
        }
        SettingsControls.SettingsRow {
            title: "Btop"
            subtitle: root.templateSubtitle("btop", "btop/themes/matugen.theme")
            SettingsControls.SettingsToggle { on: ThemingService.templateBtop; onToggled: n => ThemingService.setTemplate("btop", n) }
        }
        SettingsControls.SettingsRow {
            title: "Vesktop / Discord"
            subtitle: root.templateSubtitle("vesktop", "midnight + system24 css")
            SettingsControls.SettingsToggle { on: ThemingService.templateVesktop; onToggled: n => ThemingService.setTemplate("vesktop", n) }
        }
        SettingsControls.SettingsRow {
            title: "OBS"
            subtitle: root.templateSubtitle("obs", "matugen.obt")
            SettingsControls.SettingsToggle { on: ThemingService.templateObs; onToggled: n => ThemingService.setTemplate("obs", n) }
        }
        SettingsControls.SettingsRow {
            title: "Opencode"
            subtitle: "opencode/themes/matugen.json"
            SettingsControls.SettingsToggle { on: ThemingService.templateOpencode; onToggled: n => ThemingService.setTemplate("opencode", n) }
        }
        SettingsControls.SettingsRow {
            title: "Papirus Folders"
            subtitle: root.templateSubtitle("papirus_folders", "recolors Papirus-Matugen")
            SettingsControls.SettingsToggle { on: ThemingService.templatePapirus; onToggled: n => ThemingService.setTemplate("papirus", n) }
        }
        SettingsControls.SettingsRow {
            title: "PrismLauncher"
            subtitle: root.templateSubtitle("prismlauncher", "")
            SettingsControls.SettingsToggle { on: ThemingService.templatePrismlauncher; onToggled: n => ThemingService.setTemplate("prismlauncher", n) }
        }
        Text {
            width: parent.width
            text: "Takes effect on the next wallpaper / theme apply (matugen-run.sh builds a filtered matugen config)."
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
            color: Theme.textMuted
            wrapMode: Text.WordWrap
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
    }

    SettingsControls.SettingsSection {
        title: "System App Theming"
        Text {
            visible: !ThemingService.matugenAvailable
            width: parent.width
            text: "matugen not found — install the matugen package for dynamic theming."
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
            color: Theme.errorColor
            wrapMode: Text.WordWrap
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
        Text {
            width: parent.width
            text: "The settings below modify your GTK and Qt settings. Back up qt5ct.conf / qt6ct.conf and ~/.config/gtk-3.0 / gtk-4.0 first if you wish to preserve them."
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
            color: Theme.textMuted
            wrapMode: Text.WordWrap
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
        Row {
            width: parent.width; spacing: 8
            Repeater {
                model: [
                    { id: "gtk", label: "Apply GTK Colors" },
                    { id: "qt", label: "Apply Qt Colors" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool isGtk: (modelData.id + "") === "gtk"
                    width: (root.width - 24) / 2; height: 34
                    radius: Theme.minimalTheme ? 0 : Theme.cornerRadiusSmall
                    antialiasing: Theme.shapesAa
                    color: applyMouse.containsMouse ? (Theme.minimalTheme ? Theme.withAlpha(Theme.textPrimary, 0.08) : Theme.bgHover) : (Theme.minimalTheme ? Theme.withAlpha(Theme.textPrimary, 0.04) : Theme.panelSurface)
                    border.color: Theme.minimalTheme ? Theme.withAlpha(Theme.textPrimary, 0.25) : Theme.divider
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                    Text { anchors.centerIn: parent; text: modelData.label; font.family: Theme.minimalTheme ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Medium; color: Theme.accent
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    MouseArea { id: applyMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: isGtk ? ThemingService.applyGtkColors() : ThemingService.applyQtColors() }
                }
            }
        }
        Text {
            visible: ThemingService.lastApplyMessage.length > 0
            width: parent.width
            text: ThemingService.lastApplyMessage
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
            color: ThemingService.lastApplyOk ? Theme.textMuted : Theme.errorColor
            wrapMode: Text.WordWrap
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
        Text {
            width: parent.width
            text: "Generates baseline GTK3/4 and Qt5/Qt6 configs following matugen colors (only qt6ct needs qt6ct installed). Install adw-gtk3, then Apply GTK Colors once."
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
            color: Theme.textMuted
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
    }
}
