import QtQuick
import QtQuick.Layouts
import "../../themes"

BarWidgetBase {
    id: root

    readonly property color _fg: hovered ? Theme.accent : Theme.textPrimary

    rowContent: Component {
        RowLayout {
            spacing: 6
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: "󰘮"
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
                text: "󰘮"
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14)
                color: root._fg
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
