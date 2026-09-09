pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../themes"
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "./notifications"

Scope {
    id: notifScope
    property var notifServer

    readonly property int barT: Theme.barThickness
    readonly property string barPos: Theme.barPosition
    property var targetScreen: {
        let vals = []
        try {
            let v = Quickshell.screens.values
            vals = typeof v === "function" ? v() : v
        } catch(e) { vals = [] }
        if (!vals || vals.length === 0) return null
        for (let i = 0; i < vals.length; i++) {
            if (vals[i] && vals[i].name === "DP-1") return vals[i]
        }
        return vals[0]
    }

    readonly property bool notifTop: {
        try { let p = Theme.notifPosition; return p === "top-left" || p === "top-center" || p === "top-right" } catch(e) { return true }
    }
    readonly property bool notifLeft: {
        try { let p = Theme.notifPosition; return p === "top-left" || p === "bottom-left" } catch(e) { return false }
    }
    readonly property bool notifCenter: {
        try { let p = Theme.notifPosition; return p === "top-center" || p === "bottom-center" } catch(e) { return false }
    }
    readonly property int cardWidth: 380
    readonly property int edgeGap: 12

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: modelData.name === (notifScope.targetScreen ? notifScope.targetScreen.name : "DP-1")

            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "notifications"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"

            anchors { top: true; left: true; right: true; bottom: true }

            mask: Region { item: listCol }

            Column {
                id: listCol
                width: notifScope.cardWidth
                x: notifScope.notifLeft
                    ? notifScope.edgeGap + (notifScope.barPos === "left" ? notifScope.barT : 0)
                    : notifScope.notifCenter
                    ? (parent.width - notifScope.cardWidth) / 2
                    : parent.width - notifScope.cardWidth - notifScope.edgeGap - (notifScope.barPos === "right" ? notifScope.barT : 0)
                y: notifScope.notifTop
                    ? notifScope.edgeGap + (notifScope.barPos === "top" ? notifScope.barT : 0)
                    : parent.height - height - notifScope.edgeGap - (notifScope.barPos === "bottom" ? notifScope.barT : 0)
                spacing: 8

                move: Transition {
                    NumberAnimation { properties: "x,y"; duration: Theme.animSlow; easing.type: Theme.easingSmooth }
                }

                Repeater {
                    id: rep
                    model: notifScope.notifServer ? notifScope.notifServer.trackedNotifications : []
                    delegate: NotificationCard {
                        listWidth: listCol.width
                        stackIndex: index
                        stackCount: rep.count
                    }
                }

            }
        }
    }
}
