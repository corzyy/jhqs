pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../themes"

Item {
    id: root
    property var monitor: null
    property bool vertical: false
    implicitWidth: vertical ? 24 : hRow.implicitWidth
    implicitHeight: vertical ? vCol.implicitHeight : hRow.implicitHeight

    property var sortedWorkspaces: {
        if (!Hyprland.workspaces) return []
        let v = Hyprland.workspaces.values
        return v ? v.slice().sort((a,b)=>a.id-b.id) : []
    }
    readonly property bool isM3: Theme.workspaceStyle === "m3"
    readonly property bool isDefault2: Theme.workspaceStyle === "default2"
    readonly property real uiScale: Theme.workspaceScale
    property int hoveredIndex: -1
    function hoverScaleFor(idx: int): real {
        if (!Theme.animationsEnabled || isDefault2) return 1.0
        if (hoveredIndex < 0) return 1.0
        return idx === hoveredIndex ? 1.08 : 1.0
    }
    function setHoverAt(px: real, py: real): void {
        let container = vertical ? vCol : hRow
        for (let i = 0; i < container.children.length; i++) {
            let ch = container.children[i]
            if (!ch || ch.ws === undefined || ch.index === undefined || !ch.visible) continue
            let lp = ch.mapFromItem(root, px, py)
            if (lp.x >= 0 && lp.x <= ch.width && lp.y >= 0 && lp.y <= ch.height) {
                hoveredIndex = ch.index
                return
            }
        }
        hoveredIndex = -1
    }
    function clearHover(): void { hoveredIndex = -1 }
    property var occupiedWsIds: {
        let s = { }
        try {
            if (!Hyprland.toplevels) return s
            let tls = Hyprland.toplevels.values
            let list = tls ? (typeof tls === "function" ? tls() : tls) : null
            if (list) for (let i = 0; i < list.length; i++) {
                try { let id = list[i] && list[i].workspace && list[i].workspace.id; if (id !== undefined) s[id] = true } catch (e2) { }
            }
        } catch (e) { }
        return s
    }
    function isOccupied(ws): bool { if (!ws) return false
        let w = ws.windows
        if (w) {
            if (Array.isArray(w)) return w.length > 0
            if (w.values !== undefined) {
                let vals = typeof w.values === "function" ? w.values() : w.values
                if (vals && vals.length > 0) return true
            } else if (typeof w.length === "number") {
                return w.length > 0
            }
        }
        try { if (root.occupiedWsIds[ws.id]) return true } catch (e) { }
        return ws.active || ws.focused
    }
    function activateAt(px: real, py: real): bool {
        let container = vertical ? vCol : hRow
        for (let i = 0; i < container.children.length; i++) {
            let ch = container.children[i]
            if (!ch || ch.ws === undefined || !ch.visible) continue
            let lp = ch.mapFromItem(root, px, py)
            if (lp.x >= 0 && lp.x <= ch.width && lp.y >= 0 && lp.y <= ch.height) {
                let ws = ch.ws
                if (ws && ws.activate) ws.activate()
                else if (ws) Hyprland.dispatch("workspace " + ws.name)
                return true
            }
        }
        return false
    }

    RowLayout {
        id: hRow
        anchors.centerIn: parent
        visible: !root.vertical
        spacing: root.isDefault2 ? 0 : Theme.workspaceSpacing
        Repeater {
            model: root.sortedWorkspaces
            delegate: Item {
                id: hDelegate
                required property var modelData
                required property int index
                property var ws: modelData
                property bool occupied: root.isOccupied(ws)
                implicitWidth: ((root.isM3 ? (ws.focused ? 28 : occupied ? 14 : 8) + 2 : 20) + (root.isDefault2 ? 0 : Theme.workspaceSpacing)) * root.uiScale; implicitHeight: 24 * root.uiScale
                opacity: root.isM3 ? 1.0 : (occupied || ws.focused ? 1.0 : 0.5)
                scale: root.hoverScaleFor(index)
                Behavior on opacity { enabled: !root.isDefault2; NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
                Behavior on scale { enabled: !root.isDefault2; NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.centerIn: parent
                    visible: root.isM3
                    width: (ws.focused ? 28 : occupied ? 14 : 8) * root.uiScale
                    height: 10 * root.uiScale
                    radius: height / 2
                    color: ws.focused ? Theme.accent : occupied ? Theme.textSecondary : Theme.divider
                    Behavior on color { enabled: !root.isDefault2; ColorAnimation { duration: Theme.animFast } }
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.centerIn: parent
                    width: 13 * root.uiScale; height: 13 * root.uiScale; radius: Math.max(2, Math.min(6.5, Theme.cornerRadius)); color: Theme.textPrimary
                    visible: !root.isM3 && !root.isDefault2
                    opacity: ws.focused ? 1 : 0
                    scale: ws.focused ? 1.1 : 0.6
                    Behavior on opacity { enabled: !root.isDefault2; NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                    Behavior on scale { enabled: !root.isDefault2; NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                    Behavior on color { enabled: !root.isDefault2; ColorAnimation { duration: Theme.animFast } }
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.fill: parent
                    anchors.topMargin: -(Theme.barThickness - 24 * root.uiScale) / 2
                    anchors.bottomMargin: -(Theme.barThickness - 24 * root.uiScale) / 2
                    radius: 0
                    color: ws.focused ? Theme.bgSelected : Theme.bgHover
                    border.color: Theme.divider
                    border.width: 1
                    visible: root.isDefault2 && (ws.focused || root.hoveredIndex === index)
                    opacity: (ws.focused || root.hoveredIndex === index) ? 1 : 0
                    Behavior on opacity { enabled: !root.isDefault2; NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                    Behavior on color { enabled: !root.isDefault2; ColorAnimation { duration: Theme.animFast } }
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    anchors.centerIn: parent
                    text: ws.name
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(14) * root.uiScale; font.weight: root.isDefault2 ? ((ws.focused || root.hoveredIndex === index) ? Font.Medium : Font.Normal) : (Theme.textBold ? Font.Medium : Font.Normal)
                    color: root.hoveredIndex === index ? Theme.primary : (root.isDefault2 ? (ws.focused ? Theme.accent : Theme.textPrimary) : Theme.textPrimary)
                    visible: !root.isM3
                    opacity: root.isDefault2 ? 1 : (ws.focused ? 0 : 1)
                    scale: root.isDefault2 ? 1.0 : (ws.focused ? 0.7 : 1.0)
                    Behavior on color { enabled: !root.isDefault2; ColorAnimation { duration: Theme.animFast } }
                    Behavior on opacity { enabled: !root.isDefault2; NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                    Behavior on scale { enabled: !root.isDefault2; NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 2 * root.uiScale; radius: 0
                    y: parent.height - height - 2 + (Theme.barThickness - 24 * root.uiScale) / 2
                    color: Theme.accent
                    visible: root.isDefault2
                    opacity: ws.focused ? 1 : 0
                    Behavior on opacity { enabled: !root.isDefault2; NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                    Behavior on color { enabled: !root.isDefault2; ColorAnimation { duration: Theme.animFast } }
                }
                MouseArea {
                    id: hHover
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    z: 10
                    onEntered: root.hoveredIndex = hDelegate.index
                    onExited: if (root.hoveredIndex === hDelegate.index) root.hoveredIndex = -1
                    onClicked: mouse => {
                        mouse.accepted = true
                        if (ws && ws.activate) ws.activate()
                        else Hyprland.dispatch("workspace " + ws.name)
                    }
                    onWheel: wheel => {
                        Hyprland.dispatch(wheel.angleDelta.y > 0 ? "workspace m-1" : "workspace m+1")
                        wheel.accepted = true
                    }
                }
            }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: root.sortedWorkspaces.length===0; text:"\u2014"; color: Theme.textPrimary; font.pixelSize: Theme.fs(13)
            opacity: visible ? 1 : 0
            Behavior on opacity { enabled: !root.isDefault2; NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
        }
    }

    ColumnLayout {
        id: vCol
        anchors.centerIn: parent
        visible: root.vertical
        spacing: root.isDefault2 ? 0 : Theme.workspaceSpacing
        Repeater {
            model: root.sortedWorkspaces
            delegate: Item {
                id: vDelegate
                required property var modelData
                required property int index
                property var ws: modelData
                property bool occupied: root.isOccupied(ws)
                implicitWidth: 24 * root.uiScale; implicitHeight: ((root.isM3 ? (ws.focused ? 28 : occupied ? 14 : 8) + 2 : 20) + (root.isDefault2 ? 0 : Theme.workspaceSpacing)) * root.uiScale
                opacity: root.isM3 ? 1.0 : (occupied || ws.focused ? 1.0 : 0.5)
                scale: root.hoverScaleFor(index)
                Behavior on opacity { enabled: !root.isDefault2; NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
                Behavior on scale { enabled: !root.isDefault2; NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.centerIn: parent
                    visible: root.isM3
                    width: 10 * root.uiScale
                    height: (ws.focused ? 28 : occupied ? 14 : 8) * root.uiScale
                    radius: width / 2
                    color: ws.focused ? Theme.accent : occupied ? Theme.textSecondary : Theme.divider
                    Behavior on color { enabled: !root.isDefault2; ColorAnimation { duration: Theme.animFast } }
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.centerIn: parent
                    width: 13 * root.uiScale; height: 13 * root.uiScale; radius: Math.max(2, Math.min(6.5, Theme.cornerRadius)); color: Theme.textPrimary
                    visible: !root.isM3 && !root.isDefault2
                    opacity: ws.focused ? 1 : 0
                    scale: ws.focused ? 1.1 : 0.6
                    Behavior on opacity { enabled: !root.isDefault2; NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                    Behavior on scale { enabled: !root.isDefault2; NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                    Behavior on color { enabled: !root.isDefault2; ColorAnimation { duration: Theme.animFast } }
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.fill: parent
                    anchors.leftMargin: -(Theme.barThickness - 24 * root.uiScale) / 2
                    anchors.rightMargin: -(Theme.barThickness - 24 * root.uiScale) / 2
                    radius: 0
                    color: ws.focused ? Theme.bgSelected : Theme.bgHover
                    border.color: Theme.divider
                    border.width: 1
                    visible: root.isDefault2 && (ws.focused || root.hoveredIndex === index)
                    opacity: (ws.focused || root.hoveredIndex === index) ? 1 : 0
                    Behavior on opacity { enabled: !root.isDefault2; NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                    Behavior on color { enabled: !root.isDefault2; ColorAnimation { duration: Theme.animFast } }
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    anchors.centerIn: parent
                    text: ws.name
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(14) * root.uiScale; font.weight: root.isDefault2 ? ((ws.focused || root.hoveredIndex === index) ? Font.Medium : Font.Normal) : (Theme.textBold ? Font.Medium : Font.Normal)
                    color: root.hoveredIndex === index ? Theme.primary : (root.isDefault2 ? (ws.focused ? Theme.accent : Theme.textPrimary) : Theme.textPrimary)
                    visible: !root.isM3
                    opacity: root.isDefault2 ? 1 : (ws.focused ? 0 : 1)
                    scale: root.isDefault2 ? 1.0 : (ws.focused ? 0.7 : 1.0)
                    Behavior on color { enabled: !root.isDefault2; ColorAnimation { duration: Theme.animFast } }
                    Behavior on opacity { enabled: !root.isDefault2; NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                    Behavior on scale { enabled: !root.isDefault2; NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2 * root.uiScale; radius: 0
                    x: Theme.barPosition === "right" ? parent.width - width - 2 + (Theme.barThickness - 24 * root.uiScale) / 2 : 2 - (Theme.barThickness - 24 * root.uiScale) / 2
                    color: Theme.accent
                    visible: root.isDefault2
                    opacity: ws.focused ? 1 : 0
                    Behavior on opacity { enabled: !root.isDefault2; NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                    Behavior on color { enabled: !root.isDefault2; ColorAnimation { duration: Theme.animFast } }
                }
                MouseArea {
                    id: vHover
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    z: 10
                    onEntered: root.hoveredIndex = vDelegate.index
                    onExited: if (root.hoveredIndex === vDelegate.index) root.hoveredIndex = -1
                    onClicked: mouse => {
                        mouse.accepted = true
                        if (ws && ws.activate) ws.activate()
                        else Hyprland.dispatch("workspace " + ws.name)
                    }
                    onWheel: wheel => {
                        Hyprland.dispatch(wheel.angleDelta.y > 0 ? "workspace m-1" : "workspace m+1")
                        wheel.accepted = true
                    }
                }
            }
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: root.sortedWorkspaces.length===0; text:"\u2014"; color: Theme.textPrimary; font.pixelSize: Theme.fs(13)
            Layout.alignment: Qt.AlignHCenter
            opacity: visible ? 1 : 0
            Behavior on opacity { enabled: !root.isDefault2; NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easingStandard } }
        }
    }
}
