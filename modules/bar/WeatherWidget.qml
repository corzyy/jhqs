import QtQuick
import QtQuick.Layouts
import "../../themes"
import "../../services"

Item {
    id: root
    signal clicked()
    signal middleClicked()
    property bool vertical: false
    // Label-toggle convention (see BarModule): right-click calls this when present.
    function toggleLabel(): void { WeatherService.setShowLabel(!WeatherService.showLabel) }
    implicitWidth: vertical ? col.implicitWidth + 12 : row.implicitWidth + 16
    implicitHeight: vertical ? col.implicitHeight + 10 : row.implicitHeight + 10

    // PERF: single temp string + hover color (was 2x concat + 4x hover reads
    // per weather update, in both orientations).
    readonly property string _tempStr: WeatherService.reportTempNum + WeatherService.tempUnit
    readonly property color _fg: mouse.containsMouse ? Theme.primary : Theme.textPrimary

    RowLayout {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 6
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: WeatherService.label
            font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14)
            color: root._fg
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            readonly property bool labelVisible: WeatherService.hasData && WeatherService.showLabel
            opacity: labelVisible ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity {
                enabled: Theme.animationsEnabled
                NumberAnimation { duration: Theme.durSmall; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMotion }
            }
            text: root._tempStr
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Theme.barTextWeight
            color: root._fg
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
            font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14)
            color: root._fg
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            readonly property bool labelVisible: WeatherService.hasData && WeatherService.showLabel
            opacity: labelVisible ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity {
                enabled: Theme.animationsEnabled
                NumberAnimation { duration: Theme.durSmall; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMotion }
            }
            text: root._tempStr
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11); font.weight: Theme.barTextWeight
            color: root._fg
            Layout.alignment: Qt.AlignHCenter
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) root.toggleLabel()
            else if (mouse.button === Qt.MiddleButton) { WeatherService.refresh(); root.middleClicked() }
            else root.clicked()
        }
    }
}
