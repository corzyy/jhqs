pragma Singleton
import QtQuick
import Quickshell
import "../themes" as Themes

QtObject {
    id: root

    readonly property color foreground: Themes.Theme.textPrimary
    readonly property color background: Themes.Theme.bg
    readonly property color accent: Themes.Theme.accent
    readonly property color urgent: Themes.Theme.errorColor
    readonly property color muted: Themes.Theme.textMuted

    readonly property color surface: Themes.Theme.surface
    readonly property color surfaceContainer: Themes.Theme.surface_container
    readonly property color surfaceHigh: Themes.Theme.surface_container_high
    readonly property color surfaceHighest: Themes.Theme.surface_container_highest
    readonly property color primary: Themes.Theme.primary
    readonly property color primaryContainer: Themes.Theme.primary_container
    readonly property color onPrimary: Themes.Theme.on_primary
    readonly property color onSurface: Themes.Theme.on_surface
    readonly property color onSurfaceVariant: Themes.Theme.on_surface_variant
    readonly property color outline: Themes.Theme.outline
    readonly property color outlineVariant: Themes.Theme.outline_variant
    readonly property color scrim: Themes.Theme.scrim
    readonly property color error: Themes.Theme.error

    readonly property color panelBg: Themes.Theme.panelBg
    readonly property color cardBg: Themes.Theme.cardBg
    readonly property color panelSurface: Themes.Theme.panelSurface
    readonly property color divider: Themes.Theme.divider
    readonly property color textPrimary: Themes.Theme.textPrimary
    readonly property color textSecondary: Themes.Theme.textSecondary
    readonly property color textMuted: Themes.Theme.textMuted

    readonly property var shellValues: ({})

    function withAlpha(c: color, a: real): color {
        return Themes.Theme.withAlpha(c, a)
    }
}
