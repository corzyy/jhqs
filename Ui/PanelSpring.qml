pragma ComponentBehavior: Bound
import QtQuick
import "../themes"

Item {
    id: root
    visible: false
    required property bool shown
    required property real hiddenX
    required property real hiddenY
    property bool minimal: false
    property bool slideFade: false
    property real slideFadeDist: 12
    function dirSign(v: real): real { return v > 0 ? 1 : (v < 0 ? -1 : 0) }
    property real offset: 1
    Component.onCompleted: { if (root.shown) root.offset = 0 }
    readonly property int enterDur: root.minimal ? Theme.animFast : root.slideFade ? Theme.animSlow : Theme.celestiaPanelDur
    readonly property int exitDur: root.minimal ? Theme.animMicro : root.slideFade ? Theme.panelAnimExit : Theme.animNormal
    readonly property real springMass: Math.max(0.04, Math.min(9.0, Theme.animationScale * Theme.animationScale))
    SpringAnimation {
        id: enterAnim
        target: root
        property: "offset"
        to: 0
        spring: 4.0
        damping: 0.35
        mass: root.springMass
        epsilon: 0.002
        onStopped: if (root.shown) root.offset = 0
    }
    NumberAnimation {
        id: exitAnim
        target: root
        property: "offset"
        to: 1
        duration: root.exitDur
        easing.type: Theme.easingBounce
        easing.overshoot: Theme.panelOvershootSlide
        onStopped: if (!root.shown) root.offset = 1
    }
    onShownChanged: {
        if (!Theme.animationsEnabled || root.exitDur <= 0 && !root.shown || root.enterDur <= 0 && root.shown) {
            enterAnim.stop()
            exitAnim.stop()
            root.offset = root.shown ? 0 : 1
            return
        }
        if (root.shown) { exitAnim.stop(); enterAnim.restart() }
        else { enterAnim.stop(); exitAnim.restart() }
    }
    readonly property real fade: Math.max(0, Math.min(1, 1 - root.offset))
    readonly property real zoom: root.minimal ? 1.0 : root.slideFade ? 0.97 + 0.03 * (1 - root.offset) : 0.92 + 0.08 * (1 - root.offset)
    readonly property real slideX: root.minimal ? 0 : root.slideFade ? root.dirSign(root.hiddenX) * root.slideFadeDist * root.offset : root.hiddenX * root.offset
    readonly property real slideY: root.minimal ? 0 : root.slideFade ? root.dirSign(root.hiddenY) * root.slideFadeDist * root.offset : root.hiddenY * root.offset
    readonly property bool boxVisible: root.offset < 1
    readonly property int hideDelay: root.exitDur + 20
}
