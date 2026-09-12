import QtQuick
import Quickshell
import "../../themes"

Item {
    id: root
    signal clicked()
    property bool vertical: false
    implicitWidth: vertical ? 28 : row.implicitWidth + 14
    implicitHeight: vertical ? vCol.implicitHeight + 10 : 24
    // NOTE: `opacity: enabled ? ...` + its Behavior removed — `enabled` is
    // never set false, so this was a permanent 1.0 with a dead animation.

    readonly property bool isTimeOnly: Theme.clockFormat === "timeOnly"

    // Label-toggle convention: BarModule right-click calls this when present.
    // New label-capable modules just add an equivalent toggleLabel().
    function toggleLabel(): void { Theme.toggleClockFormat() }

    SystemClock { id: c; precision: SystemClock.Minutes }

    // PERF: 5x Qt.formatDateTime ran in BOTH orientations (hidden branch still
    // bound). Cache once per minute; hidden branch reads "" (no format call).
    readonly property bool _showDay: !isTimeOnly
    readonly property string _dayStr: (!vertical && _showDay) ? Qt.formatDateTime(c.date, "dddd") : ""
    readonly property string _timeStr: !vertical ? Qt.formatDateTime(c.date, "HH:mm") : ""
    readonly property string _hhStr: vertical ? Qt.formatDateTime(c.date, "HH") : ""
    readonly property string _mmStr: vertical ? Qt.formatDateTime(c.date, "mm") : ""
    readonly property string _dddStr: (vertical && _showDay) ? Qt.formatDateTime(c.date, "ddd") : ""
    readonly property color _hoverColor: mouse.containsMouse ? Theme.primary : Theme.textPrimary

    Row {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 8
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            id: dayText
            visible: !root.isTimeOnly
            text: root._dayStr
            color: root._hoverColor
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); font.weight: Theme.textBold ? Font.Medium : Font.Normal
            anchors.verticalCenter: parent.verticalCenter
            opacity: visible ? 1 : 0
            width: visible ? implicitWidth : 0
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            id: timeText
            text: root._timeStr
            color: root._hoverColor
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); font.weight: Theme.textBold ? Font.Medium : Font.Normal
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    Column {
        id: vCol
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 2
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: root._hhStr
            color: root._hoverColor
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); font.weight: Theme.textBold ? Font.Medium : Font.Normal
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: root._mmStr
            color: root._hoverColor
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); font.weight: Theme.textBold ? Font.Medium : Font.Normal
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: !root.isTimeOnly
            text: root._dddStr
            color: mouse.containsMouse ? Theme.primary : Theme.textMuted
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Normal
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: visible ? 0.85 : 0
            height: visible ? implicitHeight : 0
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) root.toggleLabel()
            else root.clicked()
        }
    }
}
