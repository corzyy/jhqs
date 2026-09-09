pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../themes"

ColumnLayout {
    id: root
    required property var scope
    readonly property bool isMinimal: Theme.shellTheme === "minimal"

    Layout.fillWidth: true
    spacing: 3
    opacity: root.scope.showCalendar ? 1 : 0
    transform: Translate {
        id: gridTrans
        x: 0
        y: root.scope.showCalendar ? 0 : 12
        Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
        Behavior on y {
            SequentialAnimation {
                PauseAnimation { duration: Theme.animStagger * 2 }
                NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate }
            }
        }
    }
    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: Theme.animStagger * 2 }
            NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate }
        }
    }
    Connections {
        target: root.scope
        function onViewMonthChanged() { gridTrans.x = root.scope._monthDir > 0 ? 14 : -14; slideBack.restart() }
        function onViewYearChanged() { gridTrans.x = root.scope._monthDir > 0 ? 14 : -14; slideBack.restart() }
    }
    Timer { id: slideBack; interval: 10; repeat: false; onTriggered: gridTrans.x = 0 }

    Item { visible: root.isMinimal; Layout.fillWidth: true; Layout.preferredHeight: visible ? 10 : 0 }

    Row {
        id: headerRow
        Layout.fillWidth: true
        spacing: root.scope.cellSpacing
        Rectangle {
            antialiasing: Theme.shapesAa
            width: root.scope.weekColumnWidth; height: root.isMinimal ? 16 : 24; radius: root.isMinimal ? 0 : width / 2
            color: weekStartMouse.containsMouse ? Theme.bgHover : "transparent"
            scale: root.isMinimal ? 1.0 : (Theme.animationsEnabled && weekStartMouse.pressed ? Theme.pressScale : 1.0)
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
            Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
            Text { anchors.centerIn: parent; text: "W"; color: weekStartMouse.containsMouse ? Theme.textPrimary : Theme.textMuted; font.family: root.scope.contentFontFamily; font.pixelSize: Theme.fs(root.isMinimal ? 10 : 9); font.letterSpacing: root.isMinimal ? 1 : 0.5; font.bold: true
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            MouseArea { id: weekStartMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.scope.toggleWeekStart() }
        }
        Item { width: root.scope.gutterWidth; height: root.isMinimal ? 16 : 24 }
        Repeater {
            model: root.scope.weekdays
            delegate: Text {
                required property var modelData
                width: root.scope.cellWidth; height: root.isMinimal ? 16 : 24
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: root.scope.weekdayLabel(modelData)
                color: Theme.textMuted; font.family: root.scope.contentFontFamily; font.pixelSize: Theme.fs(root.isMinimal ? 10 : 9); font.letterSpacing: root.isMinimal ? 1 : 0.6; font.bold: true
            }
        }
    }

    Repeater {
        model: root.scope.weeks
        delegate: Row {
            required property var modelData
            spacing: root.scope.cellSpacing
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                width: root.scope.weekColumnWidth; height: root.scope.cellHeight
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: String(modelData.week)
                color: Theme.textMuted; font.family: root.scope.contentFontFamily; font.pixelSize: Theme.fs(root.isMinimal ? 10 : 9); opacity: 0.9
            }
            Item { width: root.scope.gutterWidth; height: root.scope.cellHeight }
            Repeater {
                model: modelData.days
                delegate: Rectangle {
                    required property var modelData
                    width: root.scope.cellWidth; height: root.scope.cellHeight; radius: root.isMinimal ? 0 : height / 2
                    color: modelData.today ? (root.isMinimal ? "transparent" : Theme.accent) : (root.isMinimal ? "transparent" : (dayMouse.containsMouse ? Theme.bgHover : "transparent"))
                    border.width: modelData.today && root.isMinimal ? 1 : 0
                    border.color: Theme.withAlpha(Theme.textPrimary, 0.4)
                    scale: root.isMinimal ? 1.0 : (Theme.animationsEnabled && dayMouse.pressed ? Theme.pressScale : (Theme.animationsEnabled && dayMouse.containsMouse ? 1.08 : 1.0))
                    Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                    Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        id: dayText
                        anchors.centerIn: parent
                        text: String(modelData.day)
                        color: {
                            if (modelData.today) return root.isMinimal ? Theme.textPrimary : Theme.onAccent
                            if (!modelData.inMonth) return Theme.withAlpha(Theme.textMuted, 0.45)
                            if (modelData.weekend) return Theme.textSecondary
                            return Theme.textPrimary
                        }
                        font.family: root.scope.contentFontFamily; font.pixelSize: Theme.fs(root.isMinimal ? 12 : 11); font.bold: modelData.today
                        opacity: modelData.inMonth ? 1.0 : 0.45
                    }
                    Connections {
                        target: root.scope
                        function onShowCalendarChanged() {
                            if (root.scope.showCalendar && modelData.today) todayPop.restart()
                        }
                    }
                    SequentialAnimation {
                        id: todayPop
                        PauseAnimation { duration: Theme.animStagger * 4 }
                        ScaleAnimator { target: dayText; from: 0.4; to: 1; duration: Theme.animEmph; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot }
                    }
                    MouseArea { id: dayMouse; anchors.fill: parent; hoverEnabled: true }
                }
            }
        }
    }
}
