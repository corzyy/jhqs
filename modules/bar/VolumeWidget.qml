import QtQuick
import QtQuick.Layouts
import "../../themes"
import "../../services"

Item {
    id: root
    signal clicked()
    signal rightClicked()
    signal middleClicked()
    property bool vertical: false
    // Label-toggle convention (see BarModule): right-click calls this when
    // present, so future label modules only need an equivalent function.
    function toggleLabel(): void { VolumeService.setShowPct(!VolumeService.showPct) }
    implicitWidth: vertical ? col.implicitWidth + 12 : row.implicitWidth + 16
    implicitHeight: vertical ? col.implicitHeight + 10 : row.implicitHeight + 10

    // PERF: single hover/color/text evaluation (was 4x containsMouse + 2x
    // pct+"%" string concat per volume tick per orientation).
    readonly property bool _hovered: mouse.containsMouse
    readonly property color _iconColor: _hovered ? Theme.accent : (VolumeService.isMuted ? Theme.textMuted : Theme.textPrimary)
    readonly property string _pctText: VolumeService.pct + "%"

    RowLayout {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 6
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: VolumeService.icon
            font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14)
            color: root._iconColor
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            readonly property bool labelVisible: VolumeService.showPct
            opacity: labelVisible ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity {
                enabled: Theme.animationsEnabled
                NumberAnimation { duration: Theme.durSmall; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMotion }
            }
            text: root._pctText
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Theme.barTextWeight
            color: root._iconColor
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
            text: VolumeService.icon
            font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14)
            color: root._iconColor
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            readonly property bool labelVisible: VolumeService.showPct
            opacity: labelVisible ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity {
                enabled: Theme.animationsEnabled
                NumberAnimation { duration: Theme.durSmall; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveMotion }
            }
            text: root._pctText
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); font.weight: Theme.barTextWeight
            color: root._iconColor
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
            if (mouse.button === Qt.RightButton) { root.toggleLabel(); root.rightClicked() }
            else if (mouse.button === Qt.MiddleButton) { VolumeService.toggleMute(); root.middleClicked() }
            else root.clicked()
        }
    }
}
