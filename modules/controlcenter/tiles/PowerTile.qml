pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../../themes"

Rectangle {
    antialiasing: Theme.shapesAa
    id: root
    required property var scope
    readonly property bool active: scope.powerMode.toLowerCase() !== "power-saver"
    readonly property bool compact: scope.tileSize("power") === "compact"

    Layout.fillWidth: true
    Layout.columnSpan: compact ? 1 : 2
    Layout.preferredHeight: compact ? 60 : 76
    Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
    radius: active ? Theme.cornerRadius : height / 2
    Behavior on radius {
        SequentialAnimation {
            PauseAnimation { duration: Theme.animStagger }
            NumberAnimation { duration: Theme.animEmph; easing.type: Theme.easingBounce; easing.overshoot: 1.2 }
        }
    }
    color: active ? Theme.accent : Theme.cardBg
    border.width: 0
    Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
    scale: Theme.animationsEnabled && pmMouse.pressed ? 0.97 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }

    Rectangle {
        antialiasing: Theme.shapesAa
        anchors.fill: parent
        radius: parent.radius
        color: root.active ? Theme.onAccent : "#ffffff"
        opacity: pmMouse.containsMouse ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
    }

    RowLayout {
        visible: !root.compact
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            id: tileIcon
            property bool _ready: false
            Component.onCompleted: _ready = true
            text: scope.powerModeIcon()
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(26)
            color: root.active ? Theme.onAccent : Theme.textSecondary
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
            onTextChanged: if (_ready) iconSwap.restart()
            SequentialAnimation {
                id: iconSwap
                ScaleAnimator { target: tileIcon; from: 1; to: 0.55; duration: Theme.animFast; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedAccelerate }
                ScaleAnimator { target: tileIcon; from: 0.55; to: 1; duration: Theme.animEmph; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: "Energiemodus"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(14)
                font.weight: Font.Medium
                color: root.active ? Theme.onAccent : Theme.textPrimary
                elide: Text.ElideRight
                Layout.fillWidth: true
                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: scope.powerModeLabel()
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(12)
                color: root.active ? Theme.withAlpha(Theme.onAccent, 0.8) : Theme.textSecondary
                elide: Text.ElideRight
                Layout.fillWidth: true
                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
            }
        }
    }

    Text {
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
        id: tileIconCompact
        property bool _ready: false
        Component.onCompleted: _ready = true
        visible: root.compact
        anchors.centerIn: parent
        text: scope.powerModeIcon()
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(26)
        color: root.active ? Theme.onAccent : Theme.textSecondary
        Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
        onTextChanged: if (_ready) iconSwapCompact.restart()
        SequentialAnimation {
            id: iconSwapCompact
            ScaleAnimator { target: tileIconCompact; from: 1; to: 0.55; duration: Theme.animFast; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedAccelerate }
            ScaleAnimator { target: tileIconCompact; from: 0.55; to: 1; duration: Theme.animEmph; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot }
        }
    }

    MouseArea {
        id: pmMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        property double _holdAt: 0
        onPressAndHold: {
            pmMouse._holdAt = Date.now()
        }
        onClicked: {
            if (Date.now() - pmMouse._holdAt < 800) return
            scope.cyclePowerMode()
        }
    }
}
