pragma ComponentBehavior: Bound
import QtQuick
import "../../themes"
import "../../services"

Item {
    id: root
    signal clicked()
    property bool vertical: false

    // NOTE: redundant `visible: true` removed; also dropped the per-widget
    // `Behavior on implicitWidth` pattern elsewhere (it re-animated the bar
    // on every count change).
    implicitWidth: (root.vertical ? colContent.implicitWidth : rowContent.implicitWidth) + 12
    implicitHeight: (root.vertical ? colContent.implicitHeight : rowContent.implicitHeight) + 8

    Row {
        id: rowContent
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 5

        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: "󰚰"
            font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14)
            color: mouse.containsMouse ? Theme.primary : Theme.secondary
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: UpdateService.displayCount > 0
            text: UpdateService.displayCount.toString()
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Bold
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Column {
        id: colContent
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 2

        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: "󰚰"
            font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14)
            color: mouse.containsMouse ? Theme.primary : Theme.secondary
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: UpdateService.displayCount > 0
            text: UpdateService.displayCount.toString()
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Bold
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent; anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
