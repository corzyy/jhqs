pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../../themes"
import "../../../Ui" as Ui

Rectangle {
    antialiasing: Theme.shapesAa
    id: root
    required property var scope

    Layout.fillWidth: true
    Layout.preferredHeight: 52
    radius: Theme.cornerRadius
    color: Theme.cardBg
    border.width: 0
    Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }

    readonly property bool volLive: scope.volumeDragging || scope.liveVolActive
    readonly property bool volMutedState: volLive ? scope.fallbackMuted : scope.isMuted

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8

        Rectangle {
            antialiasing: Theme.shapesAa
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: width / 2
            color: muteMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08) : "transparent"
            border.width: 0
            Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
            scale: Theme.animationsEnabled && muteMouse.pressed ? 0.9 : 1.0
            Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                id: muteIcon
                property bool _ready: false
                Component.onCompleted: _ready = true
                anchors.centerIn: parent
                text: {
                    let pct = root.volLive ? scope.fallbackPct : scope.volPct
                    if (root.volMutedState || pct === 0) return "󰝟"
                    if (pct < 34) return "󰕿"
                    if (pct < 67) return "󰖀"
                    return "󰕾"
                }
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(16)
                color: root.volMutedState ? Theme.textSecondary : Theme.accent
                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                onTextChanged: if (_ready) iconSwap.restart()
                SequentialAnimation {
                    id: iconSwap
                    ScaleAnimator { target: muteIcon; from: 1; to: 0.55; duration: Theme.animFast; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedAccelerate }
                    ScaleAnimator { target: muteIcon; from: 0.55; to: 1; duration: Theme.animEmph; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot }
                }
            }
            MouseArea {
                id: muteMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: scope.toggleMute()
            }
        }

        Ui.MSlider {
            id: volumeSlider
            Layout.fillWidth: true
            property int effectivePct: root.volLive ? scope.fallbackPct : (scope.sinkReady ? scope.volPct : scope.fallbackPct)
            from: 0; to: 100; value: effectivePct; stepSize: 1; showValueLabel: false
            showStopDot: false
            trackHeight: 14
            handleWidth: 4
            handleHeight: 16
            trackGap: 4
            activeTrackColor: root.volMutedState ? Theme.textMuted : Theme.accent
            inactiveTrackColor: root.volMutedState ? Theme.divider : Theme.surface2
            handleColor: root.volMutedState ? Theme.textPrimary : Theme.accent
            stateLayerColor: root.volMutedState ? Theme.textPrimary : Theme.accent
            valueIndicatorColor: root.volMutedState ? Theme.panelSurface : Theme.primary
            valueIndicatorTextColor: root.volMutedState ? Theme.textPrimary : Theme.on_primary
            onMoved: v => scope.setVolumePct(Math.round(v))
            onPressedChanged: pressed => scope.volumeDragging = pressed
        }

        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: {
                if (root.volMutedState) return "stumm"
                if (root.volLive) return scope.fallbackPct + "%"
                if (scope.sinkReady) return scope.volPct + "%"
                return scope.fallbackText
            }
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(11)
            font.weight: Font.Medium
            color: root.volMutedState ? Theme.textSecondary : Theme.textPrimary
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        }

        Rectangle {
            antialiasing: Theme.shapesAa
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: width / 2
            color: Theme.accent
            scale: scope.showSinkPicker ? 1.15 : 1.0
            transformOrigin: Item.Center
            Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
            Rectangle {
                antialiasing: Theme.shapesAa
                anchors.fill: parent
                radius: parent.radius
                color: Theme.onAccent
                opacity: sinkBtnMouse.containsMouse ? 0.15 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                anchors.centerIn: parent
                text: scope.showSinkPicker ? "󰅃" : "󰅂"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(15)
                color: Theme.onAccent
            }
            MouseArea {
                id: sinkBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    scope.toggleExpandable("sink")
                    if (scope.showSinkPicker) scope.refreshSinks()
                }
            }
        }
    }
}
