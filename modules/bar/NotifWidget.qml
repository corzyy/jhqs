pragma ComponentBehavior: Bound
import QtQuick
import "../../themes"
import "../../services"

Item {
    id: root
    signal clicked()
    property bool vertical: false

    readonly property int notifCount: HistoryService.history.length
    readonly property bool dnd: Theme.dndEnabled

    implicitWidth: (root.vertical ? colContent.implicitWidth : rowContent.implicitWidth) + 12
    implicitHeight: (root.vertical ? colContent.implicitHeight : rowContent.implicitHeight) + 8
    Behavior on implicitWidth { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }

    Row {
        id: rowContent
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 5
        scale: Theme.animationsEnabled && mouse.containsMouse ? 1.06 : 1.0
        Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }

        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            id: rowIcon
            property bool _ready: false
            Component.onCompleted: _ready = true
            text: root.dnd ? "" : ""
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(14)
            color: mouse.containsMouse ? Theme.primary : (root.dnd ? Theme.textMuted : Theme.secondary)
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
            onTextChanged: if (_ready) rowPop.restart()
            SequentialAnimation {
                id: rowPop
                ScaleAnimator { target: rowIcon; from: 0.6; to: 1; duration: Theme.animEmph; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot }
            }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            id: rowCount
            visible: root.notifCount > 0
            text: root.notifCount > 99 ? "99+" : root.notifCount.toString()
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Bold
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
            onTextChanged: countPop.restart()
            SequentialAnimation {
                id: countPop
                ScaleAnimator { target: rowCount; from: 0.6; to: 1; duration: Theme.animEmph; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot }
            }
        }
    }

    Column {
        id: colContent
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 2
        scale: Theme.animationsEnabled && mouse.containsMouse ? 1.06 : 1.0
        Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }

        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            id: colIcon
            property bool _ready: false
            Component.onCompleted: _ready = true
            text: root.dnd ? "" : ""
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(14)
            color: mouse.containsMouse ? Theme.primary : (root.dnd ? Theme.textMuted : Theme.secondary)
            anchors.horizontalCenter: parent.horizontalCenter
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
            onTextChanged: if (_ready) colPop.restart()
            SequentialAnimation {
                id: colPop
                ScaleAnimator { target: colIcon; from: 0.6; to: 1; duration: Theme.animEmph; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot }
            }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: root.notifCount > 0
            text: root.notifCount > 99 ? "99+" : root.notifCount.toString()
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Bold
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            anchors.horizontalCenter: parent.horizontalCenter
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
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
