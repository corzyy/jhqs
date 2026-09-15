// Optimized: migrated to BarWidgetBase (kills ~30 lines of duplicated
// hover/scale/mouse code) and fixes the vertical-mode bug — the old version
// ignored `vertical` and always used horizontal padding/layout.
import QtQuick
import QtQuick.Layouts
import "../../themes"
import "../../services"

BarWidgetBase {
    id: root
    // NOTE: `vertical` is inherited from BarWidgetBase and set by BarModule;
    // do NOT self-assign (vertical: root.vertical would be a binding loop).

    // Ein Farbmapping für beide Orientierungen (war 2x kopiert).
    readonly property color _fg: hovered ? Theme.accent : (NetworkService.netActive ? Theme.textPrimary : Theme.textMuted)

    rowContent: Component {
        RowLayout {
            spacing: 6
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: NetworkService.icon
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14)
                // CPU: single hovered binding via BarWidgetBase (no per-icon MouseArea).
                color: root._fg
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
    colContent: Component {
        ColumnLayout {
            spacing: 2
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: NetworkService.icon
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14)
                color: root._fg
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
