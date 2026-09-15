// Optimized: migrated to BarWidgetBase (fixes dead `vertical` prop — the old
// version declared it but never built a Column, so vertical bars got wrong
// padding). Hover tint preserved via root.hovered.
import QtQuick
import QtQuick.Layouts
import "../../themes"
import "../../services"

BarWidgetBase {
    id: root

    // Ein Farbmapping für beide Orientierungen (war 2x kopiert).
    readonly property color _fg: hovered ? Theme.accent : (BluetoothService.btActive ? Theme.textPrimary : Theme.textMuted)

    rowContent: Component {
        RowLayout {
            spacing: 6
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: BluetoothService.icon
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14)
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
                text: BluetoothService.icon
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14)
                color: root._fg
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
