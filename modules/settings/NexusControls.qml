pragma ComponentBehavior: Unbound
import QtQuick
import QtQuick.Shapes
import "../../themes"
import "../../Ui" as Ui

// NexusControls — Caelestia Nexus (caelestia-dots/shell, modules/nexus/common)
// look-alike row kit, wired to jhqs Theme + services.
//
// Mapping of Caelestia design tokens onto jhqs:
//   Colours.palette.m3surface            -> Theme.surface
//   m3surfaceContainer                   -> Theme.surface_container
//   m3surfaceContainerHigh(est)          -> Theme.surface_container_high(est)
//   m3surfaceContainerLow(est)           -> Theme.surface_container_low(est)
//   m3primary / m3onPrimary              -> Theme.accent / Theme.onAccent
//   m3secondaryContainer                 -> Theme.secondary_container
//   m3onSecondaryContainer               -> Theme.on_secondary_container
//   m3onSurface(Variant)                 -> Theme.textPrimary (textSecondary)
//   m3outline(Variant)                   -> Theme.textMuted / Theme.divider
//   rounding extraSmall 4 / extraLarge 28
//   (fixed M3 values, like Nexus — independent of Theme.cornerRadius)
//
// Usage (mirrors the old SettingsControls namespacing):
//   import "../settings" as S
//   S.NexusControls.ToggleRow { text: "..."; checked: ...; onToggled: ... }
//
// Groups: stack rows with 2px spacing (the page column already uses it),
// mark the outer rows first:true / last:true for the Nexus 28px outer
// rounding, and put a SectionHeader above each group.
QtObject {
    id: __nexusControls

    // Grouped-list card. Standalone container for custom previews.
    component ConnectedRect: Rectangle {
        id: root
        property bool first: false
        property bool last: false
        antialiasing: Theme.shapesAa
        width: parent ? parent.width : 300
        color: hoverMouse.containsMouse ? Theme.surface_container_high : Theme.surface_container
        topLeftRadius: first ? 28 : 4
        topRightRadius: first ? 28 : 4
        bottomLeftRadius: last ? 28 : 4
        bottomRightRadius: last ? 28 : 4
        Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: Theme.durSlowEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSlowEffects } }
        MouseArea { id: hoverMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
    }

    // Small group label above a row group.
    component SectionHeader: Text {
        id: root
        property bool first: false
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Medium
        color: Theme.textSecondary
        elide: Text.ElideRight
        leftPadding: 8
        topPadding: first ? 0 : 14
        bottomPadding: 4
    }

    // 1:1 port of Caelestia StyledSwitch
    // (caelestia-dots/shell components/controls/StyledSwitch.qml).
    // Token mapping: Colours m3primary/m3onPrimary/m3onSurface/
    // m3surfaceContainerHighest/m3surfaceContainer/m3outline/m3surface ->
    // Theme.accent/onAccent/on_surface/surface_container_highest/
    // surface_container/outline/surface; body.medium/large 14/16 and
    // padding xs/s/m 4/8/12 are the Caelestia defaults; Colours.layer()
    // is identity with transparency off so base colors are used directly.
    // The Templates Switch root is an Item + MouseArea to keep the
    // parent-owned checked contract; pressed/hovered feed the same
    // properties and Space/Enter replaces the built-in key handling.
    component M3Switch: Item {
        id: root
        property bool checked: false
        property bool disabled: false
        signal toggled(bool next)
        // Tokens.font.body.medium.pointSize + Tokens.padding.small * 2
        readonly property int trackHeight: Theme.fs(14) + 16
        // StyledSwitch: implicitWidth = implicitHeight * 1.7
        readonly property int trackWidth: Math.round(trackHeight * 1.7)
        readonly property int handleSize: trackHeight - 4
        implicitWidth: trackWidth
        implicitHeight: trackHeight
        activeFocusOnTab: !disabled
        Keys.onSpacePressed: event => { if (!root.disabled) root.toggled(!root.checked); event.accepted = true }
        Keys.onEnterPressed: event => { if (!root.disabled) root.toggled(!root.checked); event.accepted = true }
        Keys.onReturnPressed: event => { if (!root.disabled) root.toggled(!root.checked); event.accepted = true }

        Rectangle {
            anchors.centerIn: parent
            width: root.trackWidth
            height: root.trackHeight
            radius: height / 2
            antialiasing: Theme.shapesAa
            color: {
                if (root.disabled)
                    return root.checked ? Qt.alpha(Theme.on_surface, 0.12) : Qt.alpha(Theme.surface_container_highest, 0.38)
                return root.checked ? Theme.accent : Theme.surface_container_highest
            }

            Rectangle {
                // StyledSwitch: pressed handle widens to implicitHeight * 1.2
                readonly property real nonAnimWidth: swMouse.pressed ? root.handleSize * 1.2 : root.handleSize

                implicitWidth: nonAnimWidth
                implicitHeight: root.handleSize
                radius: Math.min(width, height) / 2
                antialiasing: Theme.shapesAa
                color: {
                    if (root.disabled)
                        return root.checked ? Theme.surface : Qt.alpha(Theme.on_surface, 0.12)
                    return root.checked ? Theme.onAccent : Theme.outline
                }

                x: root.checked ? root.trackWidth - nonAnimWidth - 2 : 2
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    antialiasing: Theme.shapesAa

                    color: root.checked ? Theme.accent : Theme.on_surface
                    opacity: swMouse.pressed ? 0.1 : swMouse.containsMouse ? 0.08 : 0

                    Behavior on opacity {
                        Ui.Anim {
                            type: Ui.Anim.DefaultEffects
                        }
                    }
                }

                Shape {
                    id: icon

                    property point start1: {
                        if (swMouse.pressed)
                            return Qt.point(width * 0.2, height / 2)
                        if (root.checked)
                            return Qt.point(width * 0.15, height / 2)
                        return Qt.point(width * 0.15, height * 0.15)
                    }
                    property point end1: {
                        if (swMouse.pressed) {
                            if (root.checked)
                                return Qt.point(width * 0.4, height / 2)
                            return Qt.point(width * 0.8, height / 2)
                        }
                        if (root.checked)
                            return Qt.point(width * 0.4, height * 0.7)
                        return Qt.point(width * 0.85, height * 0.85)
                    }
                    property point start2: {
                        if (swMouse.pressed) {
                            if (root.checked)
                                return Qt.point(width * 0.4, height / 2)
                            return Qt.point(width * 0.2, height / 2)
                        }
                        if (root.checked)
                            return Qt.point(width * 0.4, height * 0.7)
                        return Qt.point(width * 0.15, height * 0.85)
                    }
                    property point end2: {
                        if (swMouse.pressed)
                            return Qt.point(width * 0.8, height / 2)
                        if (root.checked)
                            return Qt.point(width * 0.85, height * 0.2)
                        return Qt.point(width * 0.85, height * 0.15)
                    }

                    anchors.centerIn: parent
                    width: height
                    height: root.handleSize - 12
                    preferredRendererType: Shape.CurveRenderer
                    asynchronous: true

                    ShapePath {
                        strokeWidth: Theme.fs(16) * 0.15
                        strokeColor: {
                            if (root.disabled)
                                return root.checked ? Theme.outline : Theme.surface_container
                            return root.checked ? Theme.accent : Theme.surface_container_highest
                        }
                        fillColor: "transparent"
                        capStyle: Theme.cornerRadius === 0 ? ShapePath.SquareCap : ShapePath.RoundCap

                        startX: icon.start1.x
                        startY: icon.start1.y

                        PathLine {
                            x: icon.end1.x
                            y: icon.end1.y
                        }
                        PathMove {
                            x: icon.start2.x
                            y: icon.start2.y
                        }
                        PathLine {
                            x: icon.end2.x
                            y: icon.end2.y
                        }

                        Behavior on strokeColor {
                            Ui.CAnim {}
                        }
                    }

                    Behavior on start1 {
                        PropertyAnimation {
                            duration: Theme.durFastSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curveFastSpatial
                        }
                    }
                    Behavior on end1 {
                        PropertyAnimation {
                            duration: Theme.durFastSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curveFastSpatial
                        }
                    }
                    Behavior on start2 {
                        PropertyAnimation {
                            duration: Theme.durFastSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curveFastSpatial
                        }
                    }
                    Behavior on end2 {
                        PropertyAnimation {
                            duration: Theme.durFastSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curveFastSpatial
                        }
                    }
                }

                Behavior on x {
                    Ui.Anim {
                        type: Ui.Anim.FastSpatial
                    }
                }

                Behavior on implicitWidth {
                    Ui.Anim {
                        type: Ui.Anim.FastSpatial
                    }
                }
            }
        }

        MouseArea {
            id: swMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !root.disabled
            cursorShape: root.disabled ? Qt.ForbiddenCursor : Qt.PointingHandCursor
            onClicked: mouse => { if (!root.disabled) root.toggled(!root.checked); mouse.accepted = true }
        }
    }

    // Title + optional subtext + trailing M3 switch. Whole row clicks toggle.
    component ToggleRow: Rectangle {
        id: root
        property string text: ""
        property string subtext: ""
        property bool checked: false
        property bool first: false
        property bool last: false
        signal toggled(bool next)
        antialiasing: Theme.shapesAa
        width: parent ? parent.width : 300
        implicitHeight: Math.max(col.implicitHeight, sw.trackHeight) + 24
        height: implicitHeight
        color: rowMouse.containsMouse ? Theme.surface_container_high : Theme.surface_container
        topLeftRadius: first ? 28 : 4
        topRightRadius: first ? 28 : 4
        bottomLeftRadius: last ? 28 : 4
        bottomRightRadius: last ? 28 : 4
        Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: Theme.durSlowEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSlowEffects } }
        // Declared before the Row: the switch keeps its own press feedback and
        // clicks on the text/empty area fall through to here.
        MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled(!root.checked) }
        Row {
            anchors.fill: parent
            anchors.leftMargin: 20; anchors.rightMargin: 16
            spacing: 12
            Column {
                id: col
                width: Math.max(0, parent.width - sw.trackWidth - 12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                    width: parent.width
                    text: root.text
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13)
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text {
                    width: parent.width
                    visible: root.subtext.length > 0
                    text: root.subtext
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
                    color: Theme.textMuted
                    elide: Text.ElideRight
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
            }
            M3Switch {
                id: sw
                anchors.verticalCenter: parent.verticalCenter
                checked: root.checked
                onToggled: n => root.toggled(n)
            }
        }
    }

    // Icon + label/value + M3 expressive slider (same geometry/logic as
    // Ui.MSlider: 16dp pill track with 2dp inner corners, 6dp handle gap,
    // 4x44 handle shrinking to 2dp while pressed, stop dot, floating label).
    // moved fires live while dragging (preview), applied once on release.
    component SliderRow: Rectangle {
        id: root
        property string icon: ""
        property string label: ""
        property string valueLabel: ""
        property real from: 0
        property real to: 100
        property real value: 0
        property real stepSize: 1
        property string unit: ""
        property bool first: false
        property bool last: false
        signal moved(real v)
        signal applied(real v)
        antialiasing: Theme.shapesAa
        width: parent ? parent.width : 300
        implicitHeight: row.implicitHeight + 22
        height: implicitHeight
        color: Theme.surface_container
        topLeftRadius: first ? 28 : 4
        topRightRadius: first ? 28 : 4
        bottomLeftRadius: last ? 28 : 4
        bottomRightRadius: last ? 28 : 4
        function dispDecimals(): int {
            let s = root.stepSize.toString()
            let i = s.indexOf(".")
            if (i === -1) return 0
            return Math.max(0, Math.min(3, s.length - i - 1))
        }
        function autoText(live: real): string {
            return (root.stepSize < 1 ? Number(live).toFixed(root.dispDecimals()) : Math.round(live)) + root.unit
        }
        Row {
            id: row
            anchors.left: parent.left; anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 20; anchors.rightMargin: 20
            spacing: 12
            Text {
                visible: root.icon.length > 0
                text: root.icon
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(18)
                color: Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Column {
                width: Math.max(0, parent.width - (root.icon.length > 0 ? 34 : 0))
                spacing: 8
                Row {
                    width: parent.width
                    Text {
                        width: Math.max(0, parent.width - valText.width)
                        text: root.label
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13)
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Text {
                        id: valText
                        text: root.valueLabel.length > 0 ? root.valueLabel : root.autoText(sliderBody.liveValue)
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12)
                        color: Theme.textMuted
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                }
                Item {
                    id: sliderBody
                    width: parent.width
                    height: 48
                    property real liveValue: root.value
                    property real extValue: root.value
                    onExtValueChanged: if (!sliderMouse.dragging) liveValue = extValue
                    onVisibleChanged: if (visible) liveValue = root.value
                    readonly property real range: Math.max(0.0001, root.to - root.from)
                    readonly property real progress: Math.max(0, Math.min(1, (liveValue - root.from) / range))
                    readonly property real handleCX: 2 + (width - 4) * progress
                    readonly property int thin: sliderMouse.pressed ? 2 : 4
                    Rectangle {
                        id: trackA
                        anchors.verticalCenter: parent.verticalCenter
                        x: 2
                        width: Math.max(0, sliderBody.handleCX - sliderBody.thin / 2 - 6 - 2)
                        height: 16
                        topLeftRadius: 8
                        bottomLeftRadius: 8
                        topRightRadius: 2
                        bottomRightRadius: 2
                        color: Theme.accent
                        antialiasing: Theme.shapesAa
                        Behavior on width { enabled: Theme.animationsEnabled && !sliderMouse.dragging; NumberAnimation { duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial } }
                    }
                    Rectangle {
                        id: trackI
                        anchors.verticalCenter: parent.verticalCenter
                        x: sliderBody.handleCX + sliderBody.thin / 2 + 6
                        width: Math.max(0, sliderBody.width - 2 - x)
                        height: 16
                        topLeftRadius: 2
                        bottomLeftRadius: 2
                        topRightRadius: 8
                        bottomRightRadius: 8
                        color: Theme.surface_container_highest
                        antialiasing: Theme.shapesAa
                        Behavior on width { enabled: Theme.animationsEnabled && !sliderMouse.dragging; NumberAnimation { duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial } }
                        Behavior on x { enabled: Theme.animationsEnabled && !sliderMouse.dragging; NumberAnimation { duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial } }
                        Rectangle {
                            visible: parent.width > 12
                            width: 4; height: 4; radius: 2
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right; anchors.rightMargin: 6
                            color: Theme.accent
                            antialiasing: Theme.shapesAa
                        }
                    }
                    Rectangle {
                        width: 40; height: 40; radius: 20
                        anchors.verticalCenter: parent.verticalCenter
                        x: sliderBody.handleCX - 20
                        color: sliderMouse.pressed ? Theme.withAlpha(Theme.accent, 0.12)
                            : sliderMouse.containsMouse ? Theme.withAlpha(Theme.accent, 0.08) : "transparent"
                        antialiasing: Theme.shapesAa
                        Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: Theme.durSlowEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSlowEffects } }
                    }
                    Rectangle {
                        width: sliderBody.thin; height: 44
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: sliderBody.handleCX - width / 2
                        color: Theme.accent
                        antialiasing: Theme.shapesAa
                        Behavior on width { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
                        Behavior on x { enabled: Theme.animationsEnabled && !sliderMouse.dragging; NumberAnimation { duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial } }
                    }
                    Loader {
                        active: sliderMouse.containsMouse || sliderMouse.dragging
                        asynchronous: true
                        // Floating M3 value label: tracks the handle, 8dp
                        // above it, overlaying content while visible.
                        x: sliderBody.handleCX - width / 2
                        y: -38
                        width: item ? item.width : 48; height: item ? item.height : 32
                        sourceComponent: Item {
                            width: Math.max(48, bubbleText.implicitWidth + 24); height: 32
                            opacity: 0; scale: 0.7
                            transformOrigin: Item.Bottom
                            Component.onCompleted: { opacity = 1; scale = 1 }
                            Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects } }
                            Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
                            Rectangle {
                                anchors.fill: parent
                                radius: 16
                                color: Theme.accent
                                antialiasing: Theme.shapesAa
                                Text {
                                    id: bubbleText
                                    anchors.centerIn: parent
                                    text: root.valueLabel.length > 0 ? root.valueLabel : root.autoText(sliderBody.liveValue)
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Medium
                                    color: Theme.onAccent
                                    antialiasing: Theme.textAa
                                    renderType: Theme.textRenderType
                                }
                            }
                        }
                    }
                    MouseArea {
                        id: sliderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        property bool dragging: false
                        function valueFromX(px: real): real {
                            let c = Math.max(0, Math.min(sliderBody.width - 4, px - 2))
                            return Math.max(root.from, Math.min(root.to, root.from + (c / (sliderBody.width - 4)) * sliderBody.range))
                        }
                        function snap(v: real): real {
                            if (root.stepSize > 0) v = Math.round(v / root.stepSize) * root.stepSize
                            return Math.max(root.from, Math.min(root.to, v))
                        }
                        onPressed: mouse => {
                            sliderMouse.dragging = true
                            let v = snap(valueFromX(mouse.x))
                            sliderBody.liveValue = v
                            root.moved(v)
                        }
                        onPositionChanged: mouse => {
                            if (!sliderMouse.dragging) return
                            let v = snap(valueFromX(mouse.x))
                            sliderBody.liveValue = v
                            root.moved(v)
                        }
                        onReleased: {
                            sliderMouse.dragging = false
                            root.applied(sliderBody.liveValue)
                            sliderBody.liveValue = root.value
                        }
                        onWheel: wheel => { wheel.accepted = false }
                    }
                }
            }
        }
    }

    // Label + subtext + tonal dropdown button with inline option list.
    component DropdownRow: Column {
        id: root
        property string label: ""
        property string subtext: ""
        property var options: []
        property string current: ""
        property bool first: false
        property bool last: false
        property bool open: false
        signal picked(string value)
        width: parent ? parent.width : 300
        spacing: 2
        Rectangle {
            antialiasing: Theme.shapesAa
            width: parent.width
            height: 64
            color: btnMouse.containsMouse ? Theme.surface_container_high : Theme.surface_container
            topLeftRadius: root.first ? 28 : 4
            topRightRadius: root.first ? 28 : 4
            bottomLeftRadius: root.open ? 4 : (root.last ? 28 : 4)
            bottomRightRadius: root.open ? 4 : (root.last ? 28 : 4)
            Row {
                anchors.fill: parent
                anchors.leftMargin: 20; anchors.rightMargin: 12
                spacing: 12
                Column {
                    width: Math.max(0, parent.width - pill.width - 12)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Text {
                        width: parent.width
                        text: root.label
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13)
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    Text {
                        width: parent.width
                        visible: root.subtext.length > 0
                        text: root.subtext
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
                        color: Theme.textMuted
                        elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                }
                Rectangle {
                    id: pill
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(pillRow.implicitWidth + 28, 220)
                    height: 36
                    radius: 18
                    color: Theme.secondary_container
                    antialiasing: Theme.shapesAa
                    Row {
                        id: pillRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: root.current
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Medium
                            color: Theme.on_secondary_container
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 160)
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                        Text {
                            text: root.open ? "▴" : "▾"
                            font.pixelSize: Theme.fs(12)
                            color: Theme.on_secondary_container
                            antialiasing: Theme.textAa
                        }
                    }
                }
            }
            MouseArea { id: btnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.open = !root.open }
        }
        Column {
            width: parent.width
            visible: root.open
            spacing: 2
            Repeater {
                model: root.open ? root.options : []
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: modelData + "" === root.current
                    readonly property bool isLastOpt: index === root.options.length - 1
                    width: root.width; height: 44
                    topLeftRadius: 4
                    topRightRadius: 4
                    bottomLeftRadius: isLastOpt && root.last ? 28 : 4
                    bottomRightRadius: isLastOpt && root.last ? 28 : 4
                    color: isCurrent ? Theme.withAlpha(Theme.accent, 0.20)
                        : optMouse.containsMouse ? Theme.surface_container_high : Theme.surface_container
                    border.color: isCurrent ? Theme.accent : "transparent"
                    border.width: 1
                    antialiasing: Theme.shapesAa
                    Text {
                        anchors.fill: parent; anchors.leftMargin: 20
                        verticalAlignment: Text.AlignVCenter
                        text: modelData + ""
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13)
                        font.weight: isCurrent ? Font.Medium : Font.Normal
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    MouseArea { id: optMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.picked(modelData + ""); root.open = false } }
                }
            }
        }
    }

    // Label + subtext + right-aligned pill text field.
    component TextFieldRow: Rectangle {
        id: root
        property string label: ""
        property string subtext: ""
        property string value: ""
        property string placeholder: ""
        property bool first: false
        property bool last: false
        signal valueEdited(string value)
        signal editingFinished(string value)
        antialiasing: Theme.shapesAa
        width: parent ? parent.width : 300
        height: 64
        color: Theme.surface_container
        topLeftRadius: first ? 28 : 4
        topRightRadius: first ? 28 : 4
        bottomLeftRadius: last ? 28 : 4
        bottomRightRadius: last ? 28 : 4
        onValueChanged: if (!fieldInput.activeFocus) fieldInput.text = root.value
        Component.onCompleted: fieldInput.text = root.value
        Row {
            anchors.fill: parent
            anchors.leftMargin: 20; anchors.rightMargin: 16
            spacing: 12
            Column {
                width: Math.max(0, parent.width - fieldBox.width - 12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                    width: parent.width
                    text: root.label
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13)
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text {
                    width: parent.width
                    visible: root.subtext.length > 0
                    text: root.subtext
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
                    color: Theme.textMuted
                    elide: Text.ElideRight
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
            }
            Rectangle {
                id: fieldBox
                anchors.verticalCenter: parent.verticalCenter
                width: 200; height: 40
                radius: 20
                color: Theme.surface_container_highest
                border.color: fieldInput.activeFocus ? Theme.accent : "transparent"
                border.width: fieldInput.activeFocus ? 2 : 0
                antialiasing: Theme.shapesAa
                Text {
                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                    verticalAlignment: Text.AlignVCenter
                    visible: fieldInput.displayText.length === 0
                    text: root.placeholder
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12)
                    color: Theme.textMuted
                    elide: Text.ElideRight
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                TextInput {
                    id: fieldInput
                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13)
                    color: Theme.textPrimary
                    selectionColor: Theme.accent
                    clip: true
                    onTextEdited: root.valueEdited(text)
                    onAccepted: { root.editingFinished(text); focus = false }
                    onActiveFocusChanged: if (!activeFocus && text !== root.value) root.editingFinished(text)
                }
            }
        }
    }

    // Static label + right-aligned value (with optional leading icon).
    component InfoRow: Rectangle {
        id: root
        property string label: ""
        property string subtext: ""
        property string value: ""
        property string icon: ""
        property bool first: false
        property bool last: false
        antialiasing: Theme.shapesAa
        width: parent ? parent.width : 300
        height: subtext.length > 0 ? 64 : 52
        color: Theme.surface_container
        topLeftRadius: first ? 28 : 4
        topRightRadius: first ? 28 : 4
        bottomLeftRadius: last ? 28 : 4
        bottomRightRadius: last ? 28 : 4
        Row {
            anchors.fill: parent
            anchors.leftMargin: 20; anchors.rightMargin: 20
            spacing: 12
            Text {
                visible: root.icon.length > 0
                text: root.icon
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16)
                color: Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Column {
                width: Math.max(0, parent.width - (root.icon.length > 0 ? 34 : 0) - valText.width - 12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                    width: parent.width
                    text: root.label
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13)
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text {
                    width: parent.width
                    visible: root.subtext.length > 0
                    text: root.subtext
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
                    color: Theme.textMuted
                    elide: Text.ElideRight
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
            }
            Text {
                id: valText
                width: Math.min(implicitWidth, 180)
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
                text: root.value
                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13)
                color: Theme.textSecondary
                elide: Text.ElideRight
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
        }
    }

    // Navigation row opening a sub-view: icon + text + chevron.
    component NavRow: Rectangle {
        id: root
        property string icon: ""
        property string text: ""
        property string subtext: ""
        property bool first: false
        property bool last: false
        signal clicked(var event)
        antialiasing: Theme.shapesAa
        width: parent ? parent.width : 300
        height: 64
        color: navMouse.containsMouse ? Theme.surface_container_high : Theme.surface_container
        topLeftRadius: first ? 28 : 4
        topRightRadius: first ? 28 : 4
        bottomLeftRadius: last ? 28 : 4
        bottomRightRadius: last ? 28 : 4
        Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: Theme.durSlowEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSlowEffects } }
        Row {
            anchors.fill: parent
            anchors.leftMargin: 20; anchors.rightMargin: 12
            spacing: 12
            Text {
                visible: root.icon.length > 0
                text: root.icon
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(18)
                color: Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Column {
                width: Math.max(0, parent.width - (root.icon.length > 0 ? 34 : 0) - 24)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                    width: parent.width
                    text: root.text
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13)
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                Text {
                    width: parent.width
                    visible: root.subtext.length > 0
                    text: root.subtext
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
                    color: Theme.textMuted
                    elide: Text.ElideRight
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                font.pixelSize: Theme.fs(20)
                color: Theme.textSecondary
                antialiasing: Theme.textAa
            }
        }
        MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: e => root.clicked(e) }
    }

    // Pill search field (Nexus NavPane SearchBar).
    component SearchBar: Rectangle {
        id: root
        property string text: ""
        property string placeholder: "Search settings"
        signal textChanged2(string text)
        antialiasing: Theme.shapesAa
        width: parent ? parent.width : 300
        height: 48
        radius: 24
        color: Theme.surface_container_lowest
        border.color: searchInput.activeFocus ? Theme.accent : Theme.divider
        border.width: searchInput.activeFocus ? 2 : 1
        Row {
            anchors.fill: parent
            anchors.leftMargin: 16; anchors.rightMargin: 12
            spacing: 10
            Text {
                text: "󰍉"
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(16)
                color: Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            TextInput {
                id: searchInput
                width: Math.max(0, parent.width - 30 - (clearBtn.visible ? 26 : 0))
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13)
                color: Theme.textPrimary
                selectionColor: Theme.accent
                clip: true
                onTextChanged: root.textChanged2(text)
            }
            Text {
                id: clearBtn
                visible: (root.text || "").length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: "✕"
                font.pixelSize: Theme.fs(13)
                color: Theme.textSecondary
                antialiasing: Theme.textAa
                MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: { searchInput.text = ""; searchInput.focus = false; root.textChanged2("") } }
            }
        }
        Text {
            anchors.left: parent.left; anchors.leftMargin: 42
            anchors.verticalCenter: parent.verticalCenter
            visible: (root.text || "").length === 0 && !searchInput.activeFocus
            text: root.placeholder
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13)
            color: Theme.textMuted
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
    }

    // Page container: large title + content column (Nexus PageBase).
    // Scrolling is owned by the panel's Flickable, like before.
    component PageBase: Column {
        id: root
        property string title: ""
        // `data`, not `children`: pages also declare non-visual helpers
        // (Process, QtObject) which a visual-only list would reject.
        default property alias content: body.data
        width: parent ? parent.width : 400
        spacing: 14
        Text {
            width: parent.width
            text: root.title
            font.family: Theme.fontFamily; font.pixelSize: Theme.fs(22); font.weight: Font.Medium
            color: Theme.textPrimary
            elide: Text.ElideRight
            leftPadding: 8
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
        Column {
            id: body
            width: parent.width
            spacing: 2
        }
    }
}
