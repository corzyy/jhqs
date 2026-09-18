// StatusWidgets — single-icon status widgets for the bar (Bluetooth,
// Network, Netanjahu flag). Merged from the former BluetoothWidget.qml /
// NetworkWidget.qml / NetanjahuWidget.qml files: all three are thin
// BarWidgetBase wrappers differing only in icon source and tint.
import QtQuick
import QtQuick.Layouts
import "../../themes"
import "../../services"

QtObject {
    id: __statusWidgets

    component Bluetooth: BarWidgetBase {
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

    component Network: BarWidgetBase {
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

    component Netanjahu: BarWidgetBase {
        id: root

        readonly property string flagSource: Qt.resolvedUrl("../../assets/flag_of_israel.png")

        rowContent: Component {
            RowLayout {
                spacing: 6
                Image {
                    source: root.flagSource
                    sourceSize.width: 96
                    sourceSize.height: 70
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 15
                    Layout.alignment: Qt.AlignVCenter
                    smooth: true
                    mipmap: true
                    opacity: root.hovered ? 1.0 : 0.92
                }
            }
        }
        colContent: Component {
            ColumnLayout {
                spacing: 2
                Image {
                    source: root.flagSource
                    sourceSize.width: 96
                    sourceSize.height: 70
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 15
                    Layout.alignment: Qt.AlignHCenter
                    smooth: true
                    mipmap: true
                    opacity: root.hovered ? 1.0 : 0.92
                }
            }
        }
    }
}
