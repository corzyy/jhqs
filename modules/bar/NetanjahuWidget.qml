import QtQuick
import QtQuick.Layouts
import "../../themes"

BarWidgetBase {
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
