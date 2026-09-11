import QtQuick
import QtQuick.Layouts
import "../../themes"
import "../../services"

Item {
    id: root
    signal clicked()
    signal rightClicked()
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
            text: VolumeService.icon
            font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14)
            color: mouse.containsMouse ? Theme.accent : (VolumeService.isMuted ? Theme.textMuted : Theme.textPrimary)
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: VolumeService.showPct
            text: VolumeService.pct + "%"
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Theme.textBold ? Font.Bold : Font.Normal
            color: mouse.containsMouse ? Theme.accent : (VolumeService.isMuted ? Theme.textMuted : Theme.textPrimary)
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
            color: mouse.containsMouse ? Theme.accent : (VolumeService.isMuted ? Theme.textMuted : Theme.textPrimary)
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: VolumeService.showPct
            text: VolumeService.pct + "%"
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); font.weight: Theme.textBold ? Font.Bold : Font.Normal
            color: mouse.containsMouse ? Theme.accent : (VolumeService.isMuted ? Theme.textMuted : Theme.textPrimary)
            Layout.alignment: Qt.AlignHCenter
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
