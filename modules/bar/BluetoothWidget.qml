import QtQuick
import QtQuick.Layouts
import "../../themes"
import "../../services"

Item {
    id: root
    signal clicked()
    signal rightClicked()
    property bool vertical: false
    implicitWidth: row.implicitWidth + 16
    implicitHeight: row.implicitHeight + 10
    scale: Theme.animationsEnabled && mouse.containsMouse ? 1.06 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: BluetoothService.icon
            font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14)
            color: mouse.containsMouse ? Theme.accent : (BluetoothService.btActive ? Theme.textPrimary : Theme.textMuted)
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) root.rightClicked()
            else root.clicked()
        }
    }
}
