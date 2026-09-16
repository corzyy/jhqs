// AnimLoader — crossfade content swaps (category open/exit).
//
// Port of caelestia-dots/shell components/AnimLoader.qml: when sourceComp
// changes, the old content fades out (FastEffects), swaps, then fades back
// in (DefaultEffects). Used by jhqsmenu category switches so entering and
// exiting a category never pops.
import QtQuick
import "../themes"

Loader {
    id: root

    property Component sourceComp
    property bool isComplete: false
    property int outAnimType: 11
    property int inAnimType: 12

    asynchronous: true
    Component.onCompleted: {
        isComplete = true
        sourceComponent = sourceComp
    }
    onSourceCompChanged: {
        if (isComplete)
            anim.restart()
    }

    SequentialAnimation {
        id: anim
        running: false
        NumberAnimation {
            target: root
            property: "opacity"
            to: 0
            duration: Theme.animDurationFor(root.outAnimType)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.animCurveFor(root.outAnimType)
        }
        ScriptAction { script: root.sourceComponent = root.sourceComp }
        NumberAnimation {
            target: root
            property: "opacity"
            to: 1
            duration: Theme.animDurationFor(root.inAnimType)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.animCurveFor(root.inAnimType)
        }
    }
}
