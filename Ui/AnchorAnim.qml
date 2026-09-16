// AnchorAnim — Caelestia-expressive AnchorAnimation primitive.
//
// Port of caelestia-dots/shell components/AnchorAnim.qml. Same type ids as
// Anim minus the effects family (anchors are spatial motion).
pragma ComponentBehavior: Bound
import QtQuick
import "../themes"

AnchorAnimation {
    id: root

    enum Type {
        StandardSmall = 0,
        Standard,
        StandardLarge,
        StandardExtraLarge,
        EmphasizedSmall,
        Emphasized,
        EmphasizedLarge,
        EmphasizedExtraLarge,
        FastSpatial,
        DefaultSpatial,
        SlowSpatial
    }

    property int type: AnchorAnim.DefaultSpatial

    duration: Theme.animDurationFor(type)
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.animCurveFor(type)
}
