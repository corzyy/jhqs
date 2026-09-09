pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../themes"

ColumnLayout {
    id: root
    required property var scope
    readonly property bool isMinimal: Theme.shellTheme === "minimal"

    Layout.fillWidth: true
    spacing: 8
    opacity: root.scope.showCalendar ? 1 : 0
    transform: Translate {
        y: root.scope.showCalendar ? 0 : 12
        Behavior on y {
            SequentialAnimation {
                PauseAnimation { duration: Theme.animStagger * 4 }
                NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate }
            }
        }
    }
    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: Theme.animStagger * 4 }
            NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate }
        }
    }

    RowLayout {
        visible: root.isMinimal
        Layout.fillWidth: true
        Layout.preferredHeight: 14
        spacing: 12
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: String(root.scope.today.getFullYear())
            font.family: root.scope.contentFontFamily; font.pixelSize: Theme.fs(11)
            font.letterSpacing: 1
            color: Theme.textMuted
            Layout.alignment: Qt.AlignVCenter
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            height: 6; radius: 0
            color: Theme.withAlpha(Theme.textPrimary, 0.12)
            Rectangle {
                antialiasing: Theme.shapesAa
                width: Math.round(parent.width * root.scope.yearDone)
                height: parent.height
                color: Theme.accent
                Behavior on width { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
            }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: root.scope.yearDonePercent + "%"
            font.family: root.scope.contentFontFamily; font.pixelSize: Theme.fs(11)
            color: Theme.textPrimary
            Layout.alignment: Qt.AlignVCenter
        }
    }

    RowLayout {
        visible: !root.isMinimal
        Layout.fillWidth: true
        spacing: 8
        Rectangle {
            antialiasing: Theme.shapesAa
            Layout.preferredWidth: 30; Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter
            radius: width / 2
            color: Theme.secondary_container
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                anchors.centerIn: parent
                text: "󰔟"
                font.family: root.scope.contentFontFamily; font.pixelSize: Theme.fs(14)
                color: Theme.on_secondary_container
            }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: String(root.scope.today.getFullYear())
            font.family: root.scope.contentFontFamily; font.pixelSize: Theme.fs(13); font.weight: Font.Bold
            color: Theme.textSecondary
            Layout.alignment: Qt.AlignVCenter
        }
        Item { Layout.fillWidth: true }
        Rectangle {
            antialiasing: Theme.shapesAa
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: pctLabel.implicitWidth + 16
            implicitHeight: 26
            radius: height / 2
            color: Theme.bgSelected
            border.color: Theme.divider
            border.width: 1
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                id: pctLabel
                anchors.centerIn: parent
                text: root.scope.yearDonePercent + "%"
                font.family: root.scope.contentFontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Bold
                color: Theme.textSecondary
            }
        }
    }
    Item {
        visible: !root.isMinimal
        Layout.fillWidth: true
        Layout.preferredHeight: 12
        Rectangle {
            antialiasing: Theme.shapesAa
            anchors.left: parent.left; anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 8; radius: height / 2
            color: Theme.secondary_container
            opacity: 0.55
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            id: yearFill
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(8, Math.round(parent.width * root.scope.yearDone))
            height: 8; radius: height / 2
            color: Theme.accent
            Behavior on width { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
            Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            width: 12; height: 12
            radius: width / 2
            color: Theme.accent
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, yearFill.width - width / 2))
            Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
        }
    }
}
