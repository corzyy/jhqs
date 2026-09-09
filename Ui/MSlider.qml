pragma ComponentBehavior: Bound
import QtQuick
import "../themes"

Item {
    id: root
    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 0
    property bool enabled: true
    property bool showValueIndicator: false
    property bool showTicks: false
    property bool showValueLabel: true
    property string label: ""
    property string valueText: ""
    property int decimals: 0
    property color activeTrackColor: Theme.primary
    property color inactiveTrackColor: Theme.surface_container_highest
    property color handleColor: Theme.primary
    property color handleShadowColor: Theme.scrim
    property color stateLayerColor: Theme.primary
    property color valueIndicatorColor: Theme.primary
    property color valueIndicatorTextColor: Theme.on_primary
    property color tickActiveColor: Theme.on_primary
    property color tickInactiveColor: Theme.on_secondary_container
    property color disabledActiveColor: Theme.on_surface
    property color disabledInactiveColor: Theme.on_surface
    property color stopDotColor: Theme.primary

    property string orientation: "horizontal"
    readonly property bool _vertical: orientation === "vertical"
    property bool compact: false
    property int trackHeight: compact ? 10 : 16
    property int trackRadius: Theme.cornerRadiusSmall
    property int handleWidth: 4
    property int handleHeight: compact ? 18 : 28
    property int stateLayerSize: compact ? 26 : 40
    property int tickSize: 4
    property int trackGap: 8
    property int stopDotSize: 4
    property bool showStopDot: true
    property bool wheelEnabled: true

    readonly property real _range: Math.max(0.0001, to - from)
    readonly property real _ratio: Math.max(0, Math.min(1, (value - from) / _range))
    readonly property bool _isDiscrete: stepSize > 0
    readonly property bool _showIndicator: showValueLabel && (dragging || hovered) && enabled
    readonly property int _tickCount: _isDiscrete && showTicks ? Math.max(0, Math.round(_range / stepSize) + 1) : 0

    signal moved(real newValue)
    signal pressedChanged(bool pressed)

    readonly property int _indicatorReserve: showValueLabel ? 36 : 0
    implicitHeight: _vertical ? 120 : (label.length > 0 ? 18 : 0) + _indicatorReserve + (compact ? 24 : 40)
    implicitWidth: _vertical ? 40 : 120
    height: implicitHeight
    width: _vertical ? 40 : parent ? parent.width : implicitWidth
    focus: enabled
    Keys.enabled: enabled
    activeFocusOnTab: enabled

    property bool dragging: false
    property bool hovered: false
    property bool handlePressed: false
    property bool handleHovered: false

    function _snap(v: real): real {
        if (!_isDiscrete || stepSize <= 0) return Math.max(from, Math.min(to, v))
        let steps = Math.round((v - from) / stepSize)
        let snapped = from + steps * stepSize
        snapped = Math.max(from, Math.min(to, snapped))
        let factor = 1
        if (decimals > 0) factor = Math.pow(10, decimals)
        else if (stepSize < 1) {
            let s = stepSize.toString()
            let dot = s.indexOf(".")
            if (dot !== -1) { let d = s.length - dot - 1; factor = Math.pow(10, d); root.decimals = d }
        }
        return Math.round(snapped * factor) / factor
    }
    function _valueText(): string {
        if (valueText.length > 0) return valueText
        if (decimals > 0) return value.toFixed(decimals)
        if (_isDiscrete && stepSize < 1) {
            let s = stepSize.toString()
            let dot = s.indexOf(".")
            if (dot !== -1) return value.toFixed(s.length - dot - 1)
        }
        return Math.round(value).toString()
    }
    function setValueFromRatio(r: real) {
        if (!enabled) return
        let v = from + r * _range
        v = _snap(v)
        if (v !== value) { root.value = v; root.moved(v) }
    }

    Text {
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
        id: labelText
        visible: root.label.length > 0
        text: root.label
        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Medium
        color: root.enabled ? Theme.textSecondary : Theme.withAlpha(Theme.textSecondary, 0.38)
        anchors.top: parent.top; anchors.left: parent.left; height: visible ? 18 : 0
    }
    Text {
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
        id: valueLabel
        visible: root.label.length > 0
        text: root._valueText()
        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
        color: root.enabled ? Theme.textMuted : Theme.withAlpha(Theme.textMuted, 0.38)
        anchors.top: parent.top; anchors.right: parent.right; height: visible ? 18 : 0; horizontalAlignment: Text.AlignRight
    }

    Item {
        id: sliderArea
        anchors.top: root._vertical ? parent.top : (root.label.length > 0 ? labelText.bottom : parent.top)
        anchors.topMargin: root._vertical ? 0 : root._indicatorReserve
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: root._vertical ? root._indicatorReserve : 0
        height: root._vertical ? parent.height : (root.compact ? 24 : 40)
        width: root._vertical ? 40 : parent.width

        readonly property int hPad: 2
        readonly property int vPad: 2
        readonly property int trackLeft: hPad
        readonly property int trackTop: vPad
        readonly property int trackW: width - hPad*2
        readonly property int trackH: height - vPad*2
        readonly property real handleCenterX: trackLeft + trackW * root._ratio
        readonly property real handleCenterY: trackTop + trackH * (1 - root._ratio)
        readonly property int effHandleW: root._vertical ? root.handleHeight : root.handleWidth
        readonly property int effHandleH: root._vertical ? root.handleWidth : root.handleHeight
        readonly property real activeW: Math.max(0, handleCenterX - trackLeft - root.handleWidth/2 - root.trackGap)
        readonly property real inactiveX: handleCenterX + root.handleWidth/2 + root.trackGap
        readonly property real inactiveW: Math.max(0, trackLeft + trackW - inactiveX)
        readonly property real activeH: Math.max(0, trackTop + trackH - handleCenterY - root.handleWidth/2 - root.trackGap)
        readonly property real inactiveY: trackTop
        readonly property real inactiveH: Math.max(0, handleCenterY - trackTop - root.handleWidth/2 - root.trackGap)

        Rectangle {
            antialiasing: Theme.shapesAa
            id: activeTrack
            visible: !root._vertical && sliderArea.activeW > 0.5
            x: sliderArea.trackLeft
            width: sliderArea.activeW
            anchors.verticalCenter: parent.verticalCenter
            height: root.trackHeight
            radius: Math.min(root.trackRadius, height/2)
            color: root.enabled ? root.activeTrackColor : Theme.withAlpha(root.disabledActiveColor, 0.38)
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            Behavior on width { enabled: !root.dragging; NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            id: inactiveTrack
            visible: !root._vertical && sliderArea.inactiveW > 0.5
            x: sliderArea.inactiveX
            width: sliderArea.inactiveW
            anchors.verticalCenter: parent.verticalCenter
            height: root.trackHeight
            radius: Math.min(root.trackRadius, height/2)
            color: root.enabled ? root.inactiveTrackColor : Theme.withAlpha(root.disabledInactiveColor, 0.12)
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            Behavior on x { enabled: !root.dragging; NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
            Behavior on width { enabled: !root.dragging; NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }

            Rectangle {
                antialiasing: Theme.shapesAa
                visible: root.showStopDot && root.enabled && sliderArea.inactiveW > 12
                width: root.stopDotSize; height: root.stopDotSize; radius: width/2
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right; anchors.rightMargin: 6
                color: root.stopDotColor
                opacity: 0.9
            }
            Loader {
                active: root._isDiscrete && root.showTicks && root._tickCount > 1
                asynchronous: true
                anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                sourceComponent: Row {
                    Repeater {
                        model: root._tickCount
                        delegate: Item {
                            required property int index
                            width: inactiveTrack.width / (root._tickCount - 1); height: inactiveTrack.height
                            Rectangle {
                                antialiasing: Theme.shapesAa
                                width: root.tickSize; height: root.tickSize; radius: width/2; anchors.centerIn: parent
                                visible: true
                                color: root.tickInactiveColor; opacity: 0.9
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            id: activeTrackV
            visible: root._vertical && sliderArea.activeH > 0.5
            anchors.horizontalCenter: parent.horizontalCenter
            y: sliderArea.handleCenterY + root.handleWidth/2 + root.trackGap
            height: sliderArea.activeH
            width: root.trackHeight
            radius: Math.min(root.trackRadius, width/2)
            color: root.enabled ? root.activeTrackColor : Theme.withAlpha(root.disabledActiveColor, 0.38)
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            Behavior on y { enabled: !root.dragging; NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
            Behavior on height { enabled: !root.dragging; NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            id: inactiveTrackV
            visible: root._vertical && sliderArea.inactiveH > 0.5
            anchors.horizontalCenter: parent.horizontalCenter
            y: sliderArea.trackTop
            height: sliderArea.inactiveH
            width: root.trackHeight
            radius: Math.min(root.trackRadius, width/2)
            color: root.enabled ? root.inactiveTrackColor : Theme.withAlpha(root.disabledInactiveColor, 0.12)
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
            Behavior on height { enabled: !root.dragging; NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
            Rectangle {
                antialiasing: Theme.shapesAa
                visible: root.showStopDot && root.enabled && sliderArea.inactiveH > 12
                width: root.stopDotSize; height: root.stopDotSize; radius: width/2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.topMargin: 6
                color: root.stopDotColor; opacity: 0.9
            }
        }
        Loader {
            active: !root._vertical && root._isDiscrete && root.showTicks && root._tickCount > 1 && sliderArea.activeW > 8
            asynchronous: true
            x: sliderArea.trackLeft; width: sliderArea.activeW; y: (parent.height - root.trackHeight) / 2; height: root.trackHeight
            sourceComponent: Row {
                Repeater {
                    model: root._tickCount
                    delegate: Item {
                        required property int index
                        width: (sliderArea.trackW) / (root._tickCount - 1); height: parent.height
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            width: root.tickSize; height: root.tickSize; radius: width/2; anchors.centerIn: parent
                            visible: (index * (sliderArea.trackW / (root._tickCount - 1)) < sliderArea.activeW)
                            color: root.tickActiveColor; opacity: 0.9
                        }
                    }
                }
            }
        }

        Rectangle {
            antialiasing: Theme.shapesAa
            visible: !root._vertical
            anchors.fill: parent; anchors.leftMargin: sliderArea.trackLeft; anchors.rightMargin: sliderArea.trackLeft
            height: root.trackHeight; anchors.verticalCenter: parent.verticalCenter
            radius: Math.min(root.trackRadius, height/2); color: "transparent"
            border.color: root.activeFocus ? Theme.withAlpha(root.stateLayerColor, 0.18) : "transparent"
            border.width: root.activeFocus ? 2 : 0;
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            visible: root._vertical
            anchors.fill: parent; anchors.topMargin: sliderArea.trackTop; anchors.bottomMargin: sliderArea.trackTop
            width: root.trackHeight; anchors.horizontalCenter: parent.horizontalCenter
            radius: Math.min(root.trackRadius, width/2); color: "transparent"
            border.color: root.activeFocus ? Theme.withAlpha(root.stateLayerColor, 0.18) : "transparent"
            border.width: root.activeFocus ? 2 : 0
        }

        Rectangle {
            antialiasing: Theme.shapesAa
            id: stateLayer
            width: root.stateLayerSize; height: root.stateLayerSize; radius: width/2
            anchors.verticalCenter: root._vertical ? undefined : parent.verticalCenter
            anchors.horizontalCenter: root._vertical ? parent.horizontalCenter : undefined
            x: root._vertical ? (sliderArea.width/2 - width/2) : (sliderArea.handleCenterX - width/2)
            y: root._vertical ? (sliderArea.handleCenterY - height/2) : (parent.height/2 - height/2)
            color: {
                if (!root.enabled) return "transparent"
                if (root.handlePressed) return Theme.withAlpha(root.stateLayerColor, 0.12)
                if (root.handleHovered) return Theme.withAlpha(root.stateLayerColor, 0.08)
                return "transparent"
            }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            opacity: root.enabled ? 1 : 0
        }

        Item {
            id: handleWrap
            width: sliderArea.effHandleW; height: sliderArea.effHandleH
            anchors.verticalCenter: root._vertical ? undefined : parent.verticalCenter
            anchors.horizontalCenter: root._vertical ? parent.horizontalCenter : undefined
            x: root._vertical ? (sliderArea.width/2 - width/2) : (sliderArea.handleCenterX - width/2)
            y: root._vertical ? (sliderArea.handleCenterY - height/2) : (parent.height/2 - height/2)
            Behavior on x { enabled: !root.dragging && !root._vertical; NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
            Behavior on y { enabled: !root.dragging && root._vertical; NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }

            Rectangle {
                antialiasing: Theme.shapesAa
                anchors.centerIn: parent
                width: parent.width + 6; height: parent.height + 10; radius: 8
                color: Theme.withAlpha(root.handleShadowColor, 0.14)
                visible: root.enabled && root.handlePressed
                z: -1
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                id: handleRect
                anchors.fill: parent
                radius: 2
                color: root.enabled ? root.handleColor : Theme.withAlpha(Theme.on_surface, 0.38)
                scale: Theme.animationsEnabled && root.handlePressed ? 1.08 : 1.0
                Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            Loader {
                active: root._showIndicator
                asynchronous: true
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top; anchors.bottomMargin: 8
                width: item ? item.width : 36; height: item ? item.height : 34
                sourceComponent: Item {
                    width: indicatorBg.width; height: indicatorBg.height + 6
                    opacity: 1; scale: 1
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        id: indicatorBg
                        width: Math.max(36, indicatorText.implicitWidth + 16); height: 28; radius: 14
                        color: root.valueIndicatorColor; border.color: Theme.divider; border.width: 1
                        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            id: indicatorText; anchors.centerIn: parent; text: root._valueText()
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Medium; color: root.valueIndicatorTextColor
                        }
                    }
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        width: 10; height: 10; color: root.valueIndicatorColor; border.color: Theme.divider; border.width: 1; rotation: 45
                        anchors.top: indicatorBg.bottom; anchors.topMargin: -6; anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent; hoverEnabled: true
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
            enabled: root.enabled; preventStealing: true; acceptedButtons: Qt.LeftButton
            onEntered: root.hovered = true
            onExited: { root.hovered = false; root.handleHovered = false }
            onPositionChanged: mouse => {
                let inHandle = root._vertical ? Math.abs(mouse.y - sliderArea.handleCenterY) < root.stateLayerSize/2 : Math.abs(mouse.x - sliderArea.handleCenterX) < root.stateLayerSize/2
                root.handleHovered = inHandle
                if (pressed) updateFromMouse(root._vertical ? mouse.y : mouse.x)
            }
            onPressed: mouse => { root.dragging = true; root.handlePressed = true; root.forceActiveFocus(); updateFromMouse(root._vertical ? mouse.y : mouse.x); root.pressedChanged(true) }
            onReleased: { root.dragging = false; root.handlePressed = false; root.pressedChanged(false) }
            onClicked: mouse => updateFromMouse(root._vertical ? mouse.y : mouse.x)
            onWheel: wheel => {
                if (!root.wheelEnabled) return
                let step = root._isDiscrete ? root.stepSize : (root._range * 0.05)
                let dir = wheel.angleDelta.y > 0 ? 1 : -1
                if (root._vertical) dir = -dir
                let nv = root._snap(root.value + dir * step)
                if (nv !== root.value) { root.value = nv; root.moved(nv) }
                wheel.accepted = true
            }
            function updateFromMouse(m) {
                let r
                if (root._vertical) r = Math.max(0, Math.min(1, 1 - (m - sliderArea.trackTop) / sliderArea.trackH))
                else r = Math.max(0, Math.min(1, (m - sliderArea.trackLeft) / sliderArea.trackW))
                root.setValueFromRatio(r)
            }
        }
        Keys.onPressed: event => {
            if (!root.enabled) return
            let step = root._isDiscrete ? root.stepSize : Math.max(1, Math.round(root._range * 0.02))
            let handled = true
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) { let nv = root._snap(root.value - step); if (nv !== root.value) { root.value = nv; root.moved(nv) } }
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) { let nv = root._snap(root.value + step); if (nv !== root.value) { root.value = nv; root.moved(nv) } }
            else if (event.key === Qt.Key_PageDown) { let nv = root._snap(root.value - step*5); if (nv !== root.value) { root.value = nv; root.moved(nv) } }
            else if (event.key === Qt.Key_PageUp) { let nv = root._snap(root.value + step*5); if (nv !== root.value) { root.value = nv; root.moved(nv) } }
            else if (event.key === Qt.Key_Home) { if (root.value !== root.from) { root.value = root.from; root.moved(root.from) } }
            else if (event.key === Qt.Key_End) { if (root.value !== root.to) { root.value = root.to; root.moved(root.to) } }
            else handled = false
            if (handled) event.accepted = true
        }
    }
    opacity: root.enabled ? 1 : 0.92
}
