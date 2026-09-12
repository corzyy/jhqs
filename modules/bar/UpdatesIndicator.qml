pragma ComponentBehavior: Bound
import QtQuick
import "../../themes"
import "../../services"

Item {
    id: root
    signal clicked()
    signal middleClicked()
    property bool vertical: false
    // Label-toggle convention (see BarModule): right-click calls this when
    // present. Uses the generic Theme label store so future modules can copy
    // this pattern with zero BarModule changes.
    function toggleLabel(): void { Theme.toggleBarLabel("updates") }

    // NOTE: redundant `visible: true` removed; also dropped the per-widget
    // `Behavior on implicitWidth` pattern elsewhere (it re-animated the bar
    // on every count change).
    // PERF: single display string + hover color (was 4x hover + 2x toString()
    // driving implicitWidth relayout per count change, in both orientations).
    readonly property string _displayStr: UpdateService.displayCount.toString()
    readonly property color _iconFg: mouse.containsMouse ? Theme.accent : Theme.textPrimary
    readonly property color _textFg: mouse.containsMouse ? Theme.accent : Theme.textPrimary
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
            color: root._iconFg
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: Theme.barLabelVisible("updates") && UpdateService.displayCount > 0
            text: root._displayStr
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Bold
            color: root._textFg
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
            color: root._iconFg
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: Theme.barLabelVisible("updates") && UpdateService.displayCount > 0
            text: root._displayStr
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Bold
            color: root._textFg
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent; anchors.margins: -6
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) root.toggleLabel()
            else if (mouse.button === Qt.MiddleButton) { UpdateService.checkNow(); root.middleClicked() }
            else root.clicked()
        }
    }
}
