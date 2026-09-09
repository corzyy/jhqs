pragma ComponentBehavior: Bound
import QtQuick
import "../../themes"

Item {
    id: root
    property bool on: false
    property bool enabled: true
    signal toggled(bool next)
    property bool iconShown: false
    Timer {
        id: iconShowTimer
        interval: Math.max(0, Math.round(Theme.animSlow * 0.4))
        repeat: false
        onTriggered: root.iconShown = true
    }
    onOnChanged: {
        if (root.on) {
            if (Theme.animationsEnabled) iconShowTimer.restart()
            else root.iconShown = true
        } else {
            iconShowTimer.stop()
            root.iconShown = false
        }
    }
    Component.onCompleted: root.iconShown = root.on && root.enabled
    implicitWidth: 46; implicitHeight: 26
    width: 46; height: 26
    readonly property bool isMinimal: Theme.minimalTheme

    Item {
        visible: root.isMinimal
        anchors.centerIn: parent
        width: 42; height: 22
        Rectangle {
            antialiasing: Theme.shapesAa
            anchors.centerIn: parent
            width: 42; height: 22
            radius: 0
            color: root.on && root.enabled ? Theme.withAlpha(Theme.textPrimary, 0.18) : Theme.withAlpha(Theme.textPrimary, 0.04)
            border.color: root.on && root.enabled ? "transparent" : Theme.withAlpha(Theme.textPrimary, 0.4)
            border.width: root.on && root.enabled ? 0 : 1
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            Rectangle {
                antialiasing: Theme.shapesAa
                width: 16; height: 16
                radius: 0
                x: root.on ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter
                color: root.on && root.enabled ? Theme.textPrimary : Theme.textSecondary
                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
            onClicked: if (root.enabled) root.toggled(!root.on)
        }
    }

    Rectangle {
        visible: !root.isMinimal
        antialiasing: Theme.shapesAa
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: !root.enabled ? Theme.divider : root.on ? Theme.accent : Theme.panelSurface
        border.color: root.on && root.enabled ? "transparent" : Theme.divider
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
        scale: Theme.animationsEnabled && toggleMouse.pressed ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }

        Rectangle {
            antialiasing: Theme.shapesAa
            id: knob
            width: 20
            height: 20
            radius: 10
            color: root.on && root.enabled ? Theme.onAccent : Theme.textPrimary
            x: root.on ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            scale: Theme.animationsEnabled && toggleMouse.pressed ? 0.9 : 1.0
            Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
            Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
            Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                anchors.centerIn: parent
                text: "󰄬"
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fs(12)
                font.weight: Font.Bold
                color: Theme.accent
                opacity: root.iconShown && root.enabled ? 1 : 0
                scale: root.iconShown ? 1.0 : 0.6
                rotation: root.iconShown ? 0 : -90
                Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                Behavior on rotation { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
            }
        }
        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
            onClicked: if (root.enabled) root.toggled(!root.on)
        }
    }
    opacity: root.enabled ? 1 : 0.6
}
