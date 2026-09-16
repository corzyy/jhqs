pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../themes"

Scope {
    id: root
    property bool showNetanjahu: false
    signal dismissed()
    property bool _winVisible: showNetanjahu
    Timer { id: hideTimer; interval: Theme.panelHideDelay; repeat: false; onTriggered: if (!root.showNetanjahu) root._winVisible = false }
    onShowNetanjahuChanged: {
        if (showNetanjahu) { _winVisible = true; hideTimer.stop() } else hideTimer.restart()
    }

    readonly property string flagSource: Qt.resolvedUrl("../../assets/flag_of_israel.png")
    readonly property string portraitSource: Qt.resolvedUrl("../../assets/netanjahu.jpg")
    readonly property string laserSource: Qt.resolvedUrl("../../assets/netanjahu_angry.png")
    readonly property real flagAspect: 1280.0 / 931.0
    readonly property real portraitAspect: 1280.0 / 1699.0
    readonly property real laserAspect: 335.0 / 597.0
    readonly property real combinedAspect: flagAspect + portraitAspect + laserAspect

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: root._winVisible && Theme.isPrimaryScreen(modelData)
            color: "transparent"
            exclusiveZone: 0
            anchors { top: true; left: true; right: true; bottom: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "netanjahu"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            readonly property real gap: 28
            readonly property real mediaHeight: Math.max(60, Math.min(height * 0.76, (width - 2 * gap - 48) / root.combinedAspect))

            Item {
                id: content
                anchors.fill: parent
                opacity: root.showNetanjahu ? 1 : 0
                Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects } }

                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: 0.96
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dismissed()
                }

                Item {
                    id: keyCatcher
                    anchors.fill: parent
                    focus: true
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.dismissed()
                            event.accepted = true
                        }
                    }
                    Component.onCompleted: forceActiveFocus()
                }
                Connections {
                    target: root
                    function onShowNetanjahuChanged() {
                        if (root.showNetanjahu) Qt.callLater(() => keyCatcher.forceActiveFocus())
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: win.gap
                    Image {
                        source: root.flagSource
                        width: win.mediaHeight * root.flagAspect
                        height: win.mediaHeight
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }
                    Image {
                        source: root.portraitSource
                        width: win.mediaHeight * root.portraitAspect
                        height: win.mediaHeight
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }
                    Image {
                        source: root.laserSource
                        width: win.mediaHeight * root.laserAspect
                        height: win.mediaHeight
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 24
                    text: "Click or press Esc to close"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
            }
        }
    }
}
