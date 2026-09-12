pragma Singleton
import QtQuick
import "../themes" as Themes

QtObject {
    id: root

    readonly property int cornerRadius: Themes.Theme.cornerRadius
    readonly property int cornerRadiusSmall: Themes.Theme.cornerRadiusSmall
    readonly property int gapsOut: 5

    readonly property int barThickness: Themes.Theme.barThickness
    readonly property string barPosition: Themes.Theme.barPosition
    readonly property real barOpacity: Themes.Theme.barOpacity

    readonly property bool animationsEnabled: Themes.Theme.animationsEnabled
    readonly property int animFast: Themes.Theme.animFast
    readonly property int animNormal: Themes.Theme.animNormal
    readonly property int animSlow: Themes.Theme.animSlow
    readonly property int animEmph: Themes.Theme.animEmph

    readonly property real fontScale: Themes.Theme.fontScale
    readonly property string fontFamily: Themes.Theme.fontFamily
    function fs(px: real): int { return Themes.Theme.fs(px) }

    readonly property var styleOverrides: ({})
    readonly property int normalBorderWidth: 1
    readonly property int hoverBorderWidth: 1
    readonly property int selectedBorderWidth: 1
    readonly property int focusBorderWidth: 1
    readonly property real normalBorderAlpha: 1.0
    readonly property real hoverBorderAlpha: 1.0
    readonly property real selectedBorderAlpha: 1.0
    readonly property real focusBorderAlpha: 1.0

    function normalStateColor(fg: color, ac: color, ug: color): color { return Themes.Theme.divider }
    function hoverStateColor(fg: color, ac: color, ug: color): color { return Themes.Theme.divider }
    function selectedStateColor(fg: color, ac: color, ug: color): color { return Themes.Theme.accent }
    function focusStateColor(fg: color, ac: color, ug: color): color { return Themes.Theme.accent }
}
