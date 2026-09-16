import QtQuick
import QtQuick.Controls
import "../../themes"

Slider {
    id: control

    required property string glyph
    property bool muted: false
    property int trackHeight: 52
    property color trackColor: Theme.surface_container_highest
    property color fillColor: Theme.primary
    property color iconColor: Theme.on_surface
    property color iconActiveColor: Theme.on_primary

    signal userMoved(real value)

    from: 0
    to: 1
    implicitHeight: trackHeight
    topPadding: 0
    bottomPadding: 0
    leftPadding: 0
    rightPadding: 0
    handle: null

    onMoved: userMoved(value)

    background: Rectangle {
        id: track
        y: (control.availableHeight - height) / 2
        width: control.availableWidth
        height: control.trackHeight
        radius: height / 2
        antialiasing: Theme.shapesAa
        color: control.trackColor
        border.width: control.activeFocus ? 2 : 0
        border.color: Theme.on_surface

        Rectangle {
            id: fill
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(0, Math.round(control.visualPosition * parent.width))
            radius: Math.min(parent.radius, width / 2)
            antialiasing: Theme.shapesAa
            color: control.fillColor

            Behavior on width {
                enabled: Theme.animationsEnabled && !control.pressed
                NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
            }
        }

        Text {
            id: glyphLabel
            readonly property bool covered: fill.width >= x + width
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: control.glyph
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fs(21)
            color: control.muted ? Theme.errorColor : (covered ? control.iconActiveColor : control.iconColor)
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType

            Behavior on color {
                enabled: Theme.animationsEnabled
                ColorAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
            }
        }
    }

    WheelHandler {
        onWheel: event => {
            const step = 0.05
            control.value = Math.max(control.from, Math.min(control.to, control.value + (event.angleDelta.y > 0 ? step : -step)))
            control.userMoved(control.value)
            event.accepted = true
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
