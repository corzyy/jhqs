pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../../themes"

Rectangle {
    antialiasing: Theme.shapesAa
    id: root
    required property var scope
    readonly property bool active: scope.wiredActive
    readonly property bool compact: scope.tileSize("wired") === "compact"

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
    scale: Theme.animationsEnabled && wiredMouse.pressed ? 0.97 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }

    Rectangle {
        antialiasing: Theme.shapesAa
        anchors.fill: parent
        radius: parent.radius
        color: root.active ? Theme.onAccent : "#ffffff"
        opacity: wiredMouse.containsMouse ? 0.08 : 0
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
            text: "󰈀"
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fs(26)
            color: root.active ? Theme.onAccent : Theme.textSecondary
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: "Kabel"
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
                text: scope.wiredStatus
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(12)
                color: root.active ? Theme.withAlpha(Theme.onAccent, 0.8) : Theme.textSecondary
                elide: Text.ElideRight
                Layout.fillWidth: true
                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
            }
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter
            radius: width / 2
            color: wiredChevronMouse.containsMouse ? (root.active ? Theme.withAlpha(Theme.onAccent, 0.2) : Theme.withAlpha(Theme.scrim, 0.08)) : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                anchors.centerIn: parent
                text: scope.showWiredMenu ? "󰅃" : "󰅂"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(16)
                color: root.active ? Theme.onAccent : Theme.textSecondary
                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
            }
            MouseArea {
                id: wiredChevronMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    scope.toggleExpandable("wired")
                    if (scope.showWiredMenu) scope.refreshWiredMenu()
                }
            }
        }
    }

    Text {
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
        visible: root.compact
        anchors.centerIn: parent
        text: "󰈀"
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.fs(26)
        color: root.active ? Theme.onAccent : Theme.textSecondary
        Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
    }

    MouseArea {
        id: wiredMouse
        anchors.fill: parent
        anchors.rightMargin: root.compact ? 0 : 46
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property double _holdAt: 0
        onPressAndHold: {
            wiredMouse._holdAt = Date.now()
            scope.toggleExpandable("wired")
            if (scope.showWiredMenu) scope.refreshWiredMenu()
        }
        onClicked: mouse => {
            if (Date.now() - wiredMouse._holdAt < 800) return
            if (mouse.button === Qt.RightButton) scope.openNetworkSettings()
            else scope.toggleWired()
        }
    }
}
