import QtQuick
import QtQuick.Layouts
import "../../themes"
import "../../services"

Item {
    id: root
    signal clicked()
    property bool vertical: false
    implicitWidth: vertical ? col.implicitWidth + 12 : row.implicitWidth + 16
    implicitHeight: vertical ? col.implicitHeight + 10 : row.implicitHeight + 10

    RowLayout {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 6
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: WeatherService.label
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(14); font.weight: Theme.textBold ? Font.Bold : Font.Normal
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: WeatherService.hasData && WeatherService.showLabel
            text: WeatherService.reportTempNum + WeatherService.tempUnit
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Theme.textBold ? Font.Bold : Font.Normal
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            Layout.alignment: Qt.AlignVCenter
        }
    }
    ColumnLayout {
        id: col
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 2
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: WeatherService.label
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(14); font.weight: Theme.textBold ? Font.Bold : Font.Normal
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: WeatherService.hasData && WeatherService.showLabel
            text: WeatherService.reportTempNum + WeatherService.tempUnit
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11); font.weight: Theme.textBold ? Font.Bold : Font.Normal
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            Layout.alignment: Qt.AlignHCenter
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
