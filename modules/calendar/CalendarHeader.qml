pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../themes"

ColumnLayout {
    id: root
    required property var scope
    property bool showNav: true
    property bool showHero: true
    property bool vertical: false
    readonly property bool isMinimal: Theme.shellTheme === "minimal"

    Layout.fillWidth: true
    spacing: 8

    RowLayout {
        visible: root.showNav
        Layout.fillWidth: true
        Layout.preferredHeight: root.isMinimal ? monthLabel.implicitHeight + 10 : 40
        spacing: 8
        opacity: root.scope.showCalendar ? 1 : 0
        transform: Translate {
            y: root.scope.showCalendar ? 0 : 12
            Behavior on y {
                SequentialAnimation {
                    PauseAnimation { duration: 0 }
                    NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate }
                }
            }
        }
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: 0 }
                NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate }
            }
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: isMinimal ? 0 : width / 2
            color: isMinimal ? "transparent" : (prevMouse.containsMouse ? Theme.bgHover : Theme.panelSurface)
            border.color: isMinimal ? "transparent" : Theme.divider
            border.width: isMinimal ? 0 : (Theme.panelBlur > 0.001 ? 0 : 1)
            scale: isMinimal ? 1.0 : (Theme.animationsEnabled && prevMouse.pressed ? Theme.pressScale : (Theme.animationsEnabled && prevMouse.containsMouse ? Theme.hoverScale : 1.0))
            Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
            Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                anchors.centerIn: parent
                text: "‹"
                color: prevMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                font.family: root.scope.contentFontFamily; font.pixelSize: Theme.fs(18); font.bold: true
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
            }
            MouseArea { id: prevMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.scope.moveMonth(-1) }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            id: monthLabel
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            text: root.scope.viewDate.toLocaleDateString(Qt.locale("en_US"), "MMMM yyyy").toUpperCase()
            color: Theme.textSecondary; font.family: root.scope.contentFontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Bold; font.letterSpacing: root.isMinimal ? 1 : 1.2
            onTextChanged: monthSwap.restart()
            SequentialAnimation {
                id: monthSwap
                PropertyAction { target: monthLabel; property: "opacity"; value: 0 }
                PropertyAction { target: monthLabel; property: "scale"; value: 0.94 }
                ParallelAnimation {
                    NumberAnimation { target: monthLabel; property: "opacity"; to: 1; duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate }
                    NumberAnimation { target: monthLabel; property: "scale"; to: 1; duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate }
                }
            }
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: isMinimal ? 0 : width / 2
            color: isMinimal ? "transparent" : (nextMouse.containsMouse ? Theme.bgHover : Theme.panelSurface)
            border.color: isMinimal ? "transparent" : Theme.divider
            border.width: isMinimal ? 0 : (Theme.panelBlur > 0.001 ? 0 : 1)
            scale: isMinimal ? 1.0 : (Theme.animationsEnabled && nextMouse.pressed ? Theme.pressScale : (Theme.animationsEnabled && nextMouse.containsMouse ? Theme.hoverScale : 1.0))
            Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
            Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                anchors.centerIn: parent
                text: "›"
                color: nextMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                font.family: root.scope.contentFontFamily; font.pixelSize: Theme.fs(18); font.bold: true
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
            }
            MouseArea { id: nextMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.scope.moveMonth(1) }
        }
    }

    Rectangle {
        antialiasing: Theme.shapesAa
        visible: root.showHero && !root.isMinimal
        Layout.fillWidth: true
        Layout.preferredHeight: root.vertical ? 170 : 116
        Layout.fillHeight: root.vertical
        radius: Theme.cornerRadius
        color: Theme.accentDim
        border.width: 0
        clip: true
        Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
        opacity: root.scope.showCalendar ? 1 : 0
        transform: Translate {
            y: root.scope.showCalendar ? 0 : 14
            Behavior on y {
                SequentialAnimation {
                    PauseAnimation { duration: Theme.animStagger }
                    NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate }
                }
            }
        }
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: Theme.animStagger }
                NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate }
            }
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            readonly property real blobSize: Math.min(120, parent.height - 24)
            width: blobSize; height: blobSize
            radius: width / 2
            x: parent.width - blobSize / 2
            y: (parent.height - height) / 2
            color: Theme.withAlpha(Theme.on_primary_container, 0.09)
        }
        RowLayout {
            visible: !root.vertical
            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; anchors.topMargin: 12; anchors.bottomMargin: 12
            spacing: 10
            Rectangle {
                antialiasing: Theme.shapesAa
                Layout.preferredWidth: 56; Layout.preferredHeight: 56
                Layout.alignment: Qt.AlignVCenter
                radius: width / 2
                color: Theme.withAlpha(Theme.on_primary_container, 0.16)
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    id: heroCalIcon
                    property bool _ready: false
                    Component.onCompleted: _ready = true
                    anchors.centerIn: parent
                    text: "󰃭"
                    font.family: root.scope.contentFontFamily; font.pixelSize: Theme.fs(26)
                    color: Theme.on_primary_container
                    onTextChanged: if (_ready) heroIconPop.restart()
                    SequentialAnimation {
                        id: heroIconPop
                        ScaleAnimator { target: heroCalIcon; from: 0.5; to: 1; duration: Theme.animEmph; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot }
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: root.scope.today.toLocaleDateString(Qt.locale("en_US"), "dddd").toUpperCase()
                    color: Theme.withAlpha(Theme.on_primary_container, 0.75)
                    font.family: root.scope.contentFontFamily
                    font.pixelSize: Theme.fs(10); font.weight: Font.Bold; font.letterSpacing: 1.4
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    id: heroDate
                    property bool _ready: false
                    Component.onCompleted: _ready = true
                    text: root.scope.today.toLocaleDateString(Qt.locale("en_US"), "MMMM d")
                    color: Theme.on_primary_container
                    font.family: root.scope.contentFontFamily
                    font.pixelSize: Theme.fs(24); font.weight: Font.Bold
                    onTextChanged: if (_ready) heroDatePop.restart()
                    SequentialAnimation {
                        id: heroDatePop
                        ScaleAnimator { target: heroDate; from: 0.85; to: 1; duration: Theme.animEmph; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot }
                    }
                }
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: backLabel.implicitWidth + 24
                implicitHeight: 32
                radius: height / 2
                color: root.scope.viewingCurrentMonth ? Theme.on_primary_container : Theme.withAlpha(Theme.on_primary_container, 0.16)
                scale: Theme.animationsEnabled && todayMouse.pressed && !root.scope.viewingCurrentMonth ? Theme.pressScale : 1.0
                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    id: backLabel
                    anchors.centerIn: parent
                    text: root.scope.viewingCurrentMonth ? "HEUTE" : "ZURÜCK"
                    font.family: root.scope.contentFontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Bold; font.letterSpacing: 0.8
                    color: root.scope.viewingCurrentMonth ? Theme.accentDim : Theme.on_primary_container
                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                }
            }
        }
        ColumnLayout {
            visible: root.vertical
            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; anchors.topMargin: 14; anchors.bottomMargin: 14
            spacing: 6
            Rectangle {
                antialiasing: Theme.shapesAa
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 56; Layout.preferredHeight: 56
                radius: width / 2
                color: Theme.withAlpha(Theme.on_primary_container, 0.16)
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    anchors.centerIn: parent
                    text: "󰃭"
                    font.family: root.scope.contentFontFamily; font.pixelSize: Theme.fs(26)
                    color: Theme.on_primary_container
                }
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.scope.today.toLocaleDateString(Qt.locale("en_US"), "dddd").toUpperCase()
                color: Theme.withAlpha(Theme.on_primary_container, 0.75)
                font.family: root.scope.contentFontFamily
                font.pixelSize: Theme.fs(10); font.weight: Font.Bold; font.letterSpacing: 1.4
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.scope.today.toLocaleDateString(Qt.locale("en_US"), "MMMM d")
                color: Theme.on_primary_container
                font.family: root.scope.contentFontFamily
                font.pixelSize: Theme.fs(22); font.weight: Font.Bold
                wrapMode: Text.WordWrap
            }
            Item { Layout.fillHeight: true }
            Rectangle {
                antialiasing: Theme.shapesAa
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: height / 2
                color: root.scope.viewingCurrentMonth ? Theme.on_primary_container : Theme.withAlpha(Theme.on_primary_container, 0.16)
                scale: Theme.animationsEnabled && todayMouse.pressed && !root.scope.viewingCurrentMonth ? Theme.pressScale : 1.0
                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    anchors.centerIn: parent
                    text: root.scope.viewingCurrentMonth ? "HEUTE" : "ZURÜCK"
                    font.family: root.scope.contentFontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Bold; font.letterSpacing: 0.8
                    color: root.scope.viewingCurrentMonth ? Theme.accentDim : Theme.on_primary_container
                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                }
            }
        }
        MouseArea {
            id: todayMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.scope.viewingCurrentMonth ? Qt.ArrowCursor : Qt.PointingHandCursor
            enabled: !root.scope.viewingCurrentMonth
            onClicked: root.scope.goToToday()
        }
    }

    Item {
        visible: root.showHero && root.isMinimal
        Layout.fillWidth: true
        Layout.preferredHeight: minimalHeroRow.height
        opacity: root.scope.showCalendar ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingStandard } }
        Row {
            id: minimalHeroRow
            anchors.centerIn: parent
            spacing: 22
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                anchors.baseline: minimalHeroDate.baseline
                text: "󰃭"
                color: minimalHeroMouse.containsMouse ? Theme.accent : Theme.textPrimary
                font.family: root.scope.contentFontFamily; font.pixelSize: Theme.fs(48)
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingSmooth } }
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                id: minimalHeroDate
                anchors.verticalCenter: parent.verticalCenter
                text: root.scope.today.toLocaleDateString(Qt.locale("en_US"), "MMMM d")
                color: minimalHeroMouse.containsMouse ? Theme.accent : Theme.textPrimary
                font.family: root.scope.contentFontFamily
                font.pixelSize: Theme.fs(52); font.weight: Font.Bold
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingSmooth } }
            }
        }
        MouseArea {
            id: minimalHeroMouse
            x: minimalHeroRow.x; y: minimalHeroRow.y
            width: minimalHeroRow.width; height: minimalHeroRow.height
            enabled: !root.scope.viewingCurrentMonth
            hoverEnabled: enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: root.scope.goToToday()
        }
    }
}
