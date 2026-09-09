pragma ComponentBehavior: Bound
import QtQuick
import "../../themes"
import "../../Ui" as Ui

Column {
    id: root
    property string label: ""
    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    property string unit: ""
    signal moved(real v)
    signal applied(real v)
    width: parent ? parent.width : 300
    spacing: 0
    readonly property bool isMinimal: Theme.minimalTheme

    function dispDecimals(): int {
        let s = root.stepSize.toString()
        let i = s.indexOf(".")
        if (i === -1) return 0
        return Math.max(0, Math.min(3, s.length - i - 1))
    }

    Row {
        width: parent.width
        height: 20
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: root.label
            font.family: root.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Medium
            color: root.isMinimal ? Theme.textSecondary : Theme.textPrimary
            width: parent.width - 70; elide: Text.ElideRight
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: (root.stepSize < 1 ? Number(root.value).toFixed(root.dispDecimals()) : Math.round(root.value)) + (root.unit.length > 0 ? root.unit : "")
            font.family: root.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(11)
            color: Theme.textSecondary
            width: 70; horizontalAlignment: Text.AlignRight
        }
    }
    Item {
        visible: root.isMinimal
        width: parent.width
        height: 22
        property real liveValue: root.value
        property real extValue: root.value
        onExtValueChanged: if (!omMouse.dragging) liveValue = extValue
        onVisibleChanged: if (visible) liveValue = root.value
        readonly property real range: Math.max(0.0001, root.to - root.from)
        readonly property real progress: Math.max(0, Math.min(1, (liveValue - root.from) / range))
        Rectangle {
            antialiasing: Theme.shapesAa
            id: omTrack
            anchors.left: parent.left; anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 4
            radius: 2
            color: Theme.withAlpha(Theme.textPrimary, 0.18)
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            anchors.left: omTrack.left
            anchors.verticalCenter: omTrack.verticalCenter
            height: 4
            radius: 2
            width: omTrack.width * parent.progress
            color: Theme.textPrimary
            Behavior on width { enabled: !omMouse.dragging; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            width: 14; height: 14
            radius: 7
            color: Theme.textPrimary
            border.color: Theme.bg
            border.width: 2
            anchors.verticalCenter: omTrack.verticalCenter
            x: Math.max(0, Math.min(omTrack.width - width, omTrack.width * parent.progress - width / 2))
            scale: omMouse.containsMouse || omMouse.dragging ? 1.15 : 1.0
            Behavior on x { enabled: !omMouse.dragging; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        }
        MouseArea {
            id: omMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            property bool dragging: false
            function valueFromX(px: real): real {
                let c = Math.max(0, Math.min(omTrack.width, px))
                return Math.max(root.from, Math.min(root.to, root.from + (c / omTrack.width) * parent.range))
            }
            function snap(v: real): real {
                if (root.stepSize > 0) v = Math.round(v / root.stepSize) * root.stepSize
                return Math.max(root.from, Math.min(root.to, v))
            }
            onPressed: mouse => {
                omMouse.dragging = true
                let v = snap(valueFromX(mouse.x))
                parent.liveValue = v
                root.moved(v)
            }
            onPositionChanged: mouse => {
                if (!omMouse.dragging) return
                let v = snap(valueFromX(mouse.x))
                parent.liveValue = v
                root.moved(v)
            }
            onReleased: {
                omMouse.dragging = false
                root.applied(parent.liveValue)
                parent.liveValue = root.value
            }
            onWheel: wheel => { wheel.accepted = false }
        }
    }
    Ui.MSlider {
        visible: !root.isMinimal
        id: slider
        width: parent.width
        from: root.from; to: root.to
        value: root.value
        stepSize: root.stepSize
        compact: true
        wheelEnabled: false
        showValueLabel: false
        showStopDot: false
        trackHeight: 14; trackRadius: 7; handleWidth: 4; handleHeight: 16; trackGap: 4
        activeTrackColor: Theme.onTileActive
        inactiveTrackColor: Theme.withAlpha(Theme.onTileActive, 0.45)
        handleColor: Theme.onTileActive
        stateLayerColor: Theme.onTileActive
        onMoved: v => root.moved(v)
        onPressedChanged: pressed => { if (!pressed) root.applied(slider.value) }
    }
}
