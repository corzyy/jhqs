pragma ComponentBehavior: Bound
import QtQuick
import "../themes"

// M3 expressive slider (m3.material.io/components/sliders), XS size.
// Geometry (dp = px 1:1): 16 track (full pill, 2dp inner corners facing the
// handle), 6dp handle↔track gap, 4x44 pill handle (shrinks to 2 wide while
// pressed), 4dp stop dot at the inactive end, 4dp tick dots, 40dp state
// layer (hover 8% / focus+pressed 12%), floating pill value label.
// Colors: active/handle primary, inactive surface-container-highest,
// active ticks surface-container-highest, inactive ticks primary,
// disabled on-surface at 38% (tracks 12% inactive) with no stop dot.
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
    property color tickActiveColor: Theme.surface_container_highest
    property color tickInactiveColor: Theme.primary
    property color disabledActiveColor: Theme.on_surface
    property color disabledInactiveColor: Theme.on_surface
    property color stopDotColor: Theme.primary

    property string orientation: "horizontal"
    readonly property bool _vertical: orientation === "vertical"
    property bool compact: false
    property int trackHeight: compact ? 10 : 16
    property int trackRadius: trackHeight / 2
    // Corner radius of the track ends facing the handle gap (2 = M3 stock,
    // 0 = squared/slot look).
    property int trackInnerRadius: 2
    property int handleWidth: 4
    property int handleHeight: compact ? 18 : 44
    // -1 keeps the M3 pill handle; >= 0 squares it off.
    property real handleRadius: -1
    property int indicatorRadius: 16
    property int stateLayerSize: compact ? 26 : 40
    property int tickSize: 4
    property int trackGap: 6
    property int stopDotSize: 4
    property bool showStopDot: true
    property bool wheelEnabled: true

    readonly property real _range: Math.max(0.0001, to - from)
    readonly property real _ratio: Math.max(0, Math.min(1, (value - from) / _range))
    readonly property bool _isDiscrete: stepSize > 0
    // M3 floating label: steady while hovered, keyboard-focused or pressed.
    readonly property bool _showIndicator: showValueLabel && (dragging || hovered || activeFocus) && enabled
    readonly property int _tickCount: _isDiscrete && showTicks ? Math.max(0, Math.round(_range / stepSize) + 1) : 0
    // Handle shrinks in width while pressed (M3 press feedback).
    readonly property int _thinSide: handlePressed && enabled ? 2 : handleWidth

    signal moved(real newValue)
    signal pressedChanged(bool pressed)

    implicitHeight: _vertical ? 120 : (label.length > 0 ? 18 : 0) + (compact ? 24 : 48)
    implicitWidth: _vertical ? 48 : 120
    height: implicitHeight
    width: _vertical ? 48 : parent ? parent.width : implicitWidth
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
        return Math.round(snapped * _snapFactor) / _snapFactor
    }
    function _stepDecimals(): int {
        if (decimals > 0) return decimals
        if (_isDiscrete && stepSize > 0 && stepSize < 1) {
            let dot = stepSize.toString().indexOf(".")
            if (dot !== -1) return stepSize.toString().length - dot - 1
        }
        return 0
    }
    readonly property real _snapFactor: Math.pow(10, _stepDecimals())
    function _valueText(): string {
        if (valueText.length > 0) return valueText
        const d = _stepDecimals()
        if (d > 0) return value.toFixed(d)
        return Math.round(value).toString()
    }
    function _commit(v: real): void {
        v = _snap(v)
        if (v !== value) {
            root.value = v
            root.moved(v)
        }
    }
    function _nudge(steps: real): void {
        const step = _isDiscrete ? stepSize : Math.max(1, Math.round(_range * 0.02))
        _commit(value + steps * step)
    }
    function setValueFromRatio(r: real) {
        if (!enabled) return
        _commit(from + r * _range)
    }

    component Caption: Text {
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
        required property color baseColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(11)
        height: visible ? 18 : 0
        color: root.enabled ? baseColor : Theme.withAlpha(baseColor, 0.38)
    }

    Caption {
        id: labelText
        visible: root.label.length > 0
        text: root.label
        baseColor: Theme.textSecondary
        font.weight: Font.Medium
        anchors.top: parent.top
        anchors.left: parent.left
    }
    Caption {
        id: valueLabel
        visible: root.label.length > 0
        text: root._valueText()
        baseColor: Theme.textMuted
        anchors.top: parent.top
        anchors.right: parent.right
        horizontalAlignment: Text.AlignRight
    }

    Item {
        id: sliderArea
        anchors.top: root._vertical ? parent.top : (root.label.length > 0 ? labelText.bottom : parent.top)
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: root._vertical ? 4 : 0
        anchors.rightMargin: root._vertical ? 4 : 0
        height: root._vertical ? parent.height : (root.compact ? 24 : 48)
        width: root._vertical ? 40 : parent.width

        readonly property int hPad: 2
        readonly property int vPad: 2
        readonly property int trackLeft: hPad
        readonly property int trackTop: vPad
        readonly property int trackW: width - hPad * 2
        readonly property int trackH: height - vPad * 2
        readonly property real handleCenterX: trackLeft + trackW * root._ratio
        readonly property real handleCenterY: trackTop + trackH * (1 - root._ratio)
        readonly property int effHandleW: root._vertical ? root.handleHeight : root._thinSide
        readonly property int effHandleH: root._vertical ? root._thinSide : root.handleHeight
        // Track segments stop at the 6dp gap around the handle.
        readonly property real activeW: Math.max(0, handleCenterX - root._thinSide / 2 - root.trackGap - trackLeft)
        readonly property real inactiveX: handleCenterX + root._thinSide / 2 + root.trackGap
        readonly property real inactiveW: Math.max(0, trackLeft + trackW - inactiveX)
        readonly property real activeH: Math.max(0, trackTop + trackH - handleCenterY - root._thinSide / 2 - root.trackGap)
        readonly property real inactiveY: trackTop
        readonly property real inactiveH: Math.max(0, handleCenterY - root._thinSide / 2 - root.trackGap - trackTop)

        Rectangle {
            antialiasing: Theme.shapesAa
            id: activeTrack
            visible: !root._vertical && sliderArea.activeW > 0.5
            x: sliderArea.trackLeft
            width: sliderArea.activeW
            anchors.verticalCenter: parent.verticalCenter
            height: root.trackHeight
            topLeftRadius: Math.min(root.trackRadius, height / 2)
            bottomLeftRadius: Math.min(root.trackRadius, height / 2)
            topRightRadius: root.trackInnerRadius
            bottomRightRadius: root.trackInnerRadius
            color: root.enabled ? root.activeTrackColor : Theme.withAlpha(root.disabledActiveColor, 0.38)
            // Drags track the finger instantly; clicks/keys glide.
            Behavior on width { enabled: Theme.animationsEnabled && !root.dragging; NumberAnimation { duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial } }
            Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: Theme.durSlowEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSlowEffects } }
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            id: inactiveTrack
            visible: !root._vertical && sliderArea.inactiveW > 0.5
            x: sliderArea.inactiveX
            width: sliderArea.inactiveW
            anchors.verticalCenter: parent.verticalCenter
            height: root.trackHeight
            topLeftRadius: root.trackInnerRadius
            bottomLeftRadius: root.trackInnerRadius
            topRightRadius: Math.min(root.trackRadius, height / 2)
            bottomRightRadius: Math.min(root.trackRadius, height / 2)
            color: root.enabled ? root.inactiveTrackColor : Theme.withAlpha(root.disabledInactiveColor, 0.12)
            Behavior on width { enabled: Theme.animationsEnabled && !root.dragging; NumberAnimation { duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial } }
            Behavior on x { enabled: Theme.animationsEnabled && !root.dragging; NumberAnimation { duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial } }
            Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: Theme.durSlowEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSlowEffects } }
            Rectangle {
                antialiasing: Theme.shapesAa
                visible: root.showStopDot && root.enabled && sliderArea.inactiveW > 12
                width: root.stopDotSize; height: root.stopDotSize; radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right; anchors.rightMargin: 6
                color: root.stopDotColor
            }
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            id: activeTrackV
            visible: root._vertical && sliderArea.activeH > 0.5
            anchors.horizontalCenter: parent.horizontalCenter
            y: sliderArea.handleCenterY + root._thinSide / 2 + root.trackGap
            height: sliderArea.activeH
            width: root.trackHeight
            topLeftRadius: root.trackInnerRadius
            topRightRadius: root.trackInnerRadius
            bottomLeftRadius: Math.min(root.trackRadius, width / 2)
            bottomRightRadius: Math.min(root.trackRadius, width / 2)
            color: root.enabled ? root.activeTrackColor : Theme.withAlpha(root.disabledActiveColor, 0.38)
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            id: inactiveTrackV
            visible: root._vertical && sliderArea.inactiveH > 0.5
            anchors.horizontalCenter: parent.horizontalCenter
            y: sliderArea.trackTop
            height: sliderArea.inactiveH
            width: root.trackHeight
            topLeftRadius: Math.min(root.trackRadius, width / 2)
            topRightRadius: Math.min(root.trackRadius, width / 2)
            bottomLeftRadius: root.trackInnerRadius
            bottomRightRadius: root.trackInnerRadius
            color: root.enabled ? root.inactiveTrackColor : Theme.withAlpha(root.disabledInactiveColor, 0.12)
            Rectangle {
                antialiasing: Theme.shapesAa
                visible: root.showStopDot && root.enabled && sliderArea.inactiveH > 12
                width: root.stopDotSize; height: root.stopDotSize; radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.topMargin: 6
                color: root.stopDotColor
            }
        }
        // Tick dots sit at fixed stops across the full track; a stop inside
        // the handle gap is hidden. Active-side ticks contrast the primary
        // track, inactive-side ticks contrast the light track (M3).
        Repeater {
            model: !root._vertical && root._isDiscrete && root.showTicks && root._tickCount > 1 ? root._tickCount : 0
            delegate: Rectangle {
                required property int index
                readonly property real stopX: sliderArea.trackLeft + sliderArea.trackW * (index / (root._tickCount - 1))
                readonly property bool onActive: stopX <= sliderArea.trackLeft + sliderArea.activeW + 0.5
                readonly property bool onInactive: stopX >= sliderArea.inactiveX - 0.5
                visible: onActive || onInactive
                width: root.tickSize; height: root.tickSize; radius: width / 2
                x: stopX - width / 2
                anchors.verticalCenter: parent.verticalCenter
                antialiasing: Theme.shapesAa
                color: !root.enabled ? Theme.withAlpha(Theme.on_surface, 0.38)
                    : onActive ? root.tickActiveColor : root.tickInactiveColor
            }
        }
        Repeater {
            model: root._vertical && root._isDiscrete && root.showTicks && root._tickCount > 1 ? root._tickCount : 0
            delegate: Rectangle {
                required property int index
                readonly property real stopY: sliderArea.trackTop + sliderArea.trackH * (1 - index / (root._tickCount - 1))
                readonly property bool onActive: stopY >= sliderArea.trackTop + sliderArea.trackH - sliderArea.activeH - 0.5
                readonly property bool onInactive: stopY <= sliderArea.inactiveY + sliderArea.inactiveH + 0.5
                visible: onActive || onInactive
                width: root.tickSize; height: root.tickSize; radius: width / 2
                y: stopY - height / 2
                anchors.horizontalCenter: parent.horizontalCenter
                antialiasing: Theme.shapesAa
                color: !root.enabled ? Theme.withAlpha(Theme.on_surface, 0.38)
                    : onActive ? root.tickActiveColor : root.tickInactiveColor
            }
        }

        Rectangle {
            antialiasing: Theme.shapesAa
            id: stateLayer
            width: root.stateLayerSize; height: root.stateLayerSize; radius: width / 2
            anchors.verticalCenter: root._vertical ? undefined : parent.verticalCenter
            anchors.horizontalCenter: root._vertical ? parent.horizontalCenter : undefined
            x: root._vertical ? (sliderArea.width / 2 - width / 2) : (sliderArea.handleCenterX - width / 2)
            y: root._vertical ? (sliderArea.handleCenterY - height / 2) : (parent.height / 2 - height / 2)
            color: {
                if (!root.enabled) return "transparent"
                if (root.handlePressed) return Theme.withAlpha(root.stateLayerColor, 0.12)
                if (root.activeFocus) return Theme.withAlpha(root.stateLayerColor, 0.12)
                if (root.handleHovered) return Theme.withAlpha(root.stateLayerColor, 0.08)
                return "transparent"
            }
            Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: Theme.durSlowEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSlowEffects } }
        }

        Item {
            id: handleWrap
            width: sliderArea.effHandleW; height: sliderArea.effHandleH
            anchors.verticalCenter: root._vertical ? undefined : parent.verticalCenter
            anchors.horizontalCenter: root._vertical ? parent.horizontalCenter : undefined
            x: root._vertical ? (sliderArea.width / 2 - width / 2) : (sliderArea.handleCenterX - width / 2)
            y: root._vertical ? (sliderArea.handleCenterY - height / 2) : (parent.height / 2 - height / 2)
            // Clicks/keys glide the handle on the expressive spatial curve.
            Behavior on x { enabled: Theme.animationsEnabled && !root.dragging; NumberAnimation { duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial } }
            Behavior on y { enabled: Theme.animationsEnabled && !root.dragging; NumberAnimation { duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial } }
            Behavior on width { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
            Behavior on height { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }

            Rectangle {
                antialiasing: Theme.shapesAa
                id: handleRect
                anchors.fill: parent
                radius: root.handleRadius >= 0 ? root.handleRadius : Math.min(width, height) / 2
                color: root.enabled ? root.handleColor : Theme.withAlpha(Theme.on_surface, 0.38)
                Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: Theme.durSlowEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSlowEffects } }
            }

            Loader {
                active: root._showIndicator
                asynchronous: true
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top; anchors.bottomMargin: 8
                width: item ? item.width : 48; height: item ? item.height : 32
                sourceComponent: Item {
                    width: Math.max(48, indicatorText.implicitWidth + 24); height: 32
                    opacity: 0; scale: 0.7
                    transformOrigin: Item.Bottom
                    Component.onCompleted: { opacity = 1; scale = 1 }
                    Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects } }
                    Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        anchors.fill: parent
                        radius: root.indicatorRadius
                        color: root.valueIndicatorColor
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            id: indicatorText; anchors.centerIn: parent; text: root._valueText()
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Medium; color: root.valueIndicatorTextColor
                        }
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
                let inHandle = root._vertical ? Math.abs(mouse.y - sliderArea.handleCenterY) < root.stateLayerSize / 2 : Math.abs(mouse.x - sliderArea.handleCenterX) < root.stateLayerSize / 2
                root.handleHovered = inHandle
                if (pressed) updateFromMouse(root._vertical ? mouse.y : mouse.x)
            }
            onPressed: mouse => { root.dragging = true; root.handlePressed = true; root.forceActiveFocus(); updateFromMouse(root._vertical ? mouse.y : mouse.x); root.pressedChanged(true) }
            onReleased: { root.dragging = false; root.handlePressed = false; root.pressedChanged(false) }
            onClicked: mouse => updateFromMouse(root._vertical ? mouse.y : mouse.x)
            onWheel: wheel => {
                if (!root.wheelEnabled) return
                let dir = wheel.angleDelta.y > 0 ? 1 : -1
                if (root._vertical) dir = -dir
                if (root._isDiscrete) root._nudge(dir)
                else root._commit(root.value + dir * root._range * 0.05)
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
            let handled = true
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) root._nudge(-1)
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) root._nudge(1)
            else if (event.key === Qt.Key_PageDown) root._nudge(-5)
            else if (event.key === Qt.Key_PageUp) root._nudge(5)
            else if (event.key === Qt.Key_Home) root._commit(root.from)
            else if (event.key === Qt.Key_End) root._commit(root.to)
            else handled = false
            if (handled) event.accepted = true
        }
    }
}
