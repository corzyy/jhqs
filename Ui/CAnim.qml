// CAnim — Caelestia-expressive ColorAnimation primitive.
//
// Port of caelestia-dots/shell components/CAnim.qml: color/opacity fades
// always use the slow-effects curve (300ms). Collapses to 0 when animations
// are off.
import QtQuick
import "../themes"

ColorAnimation {
    duration: Theme.durSlowEffects
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curveSlowEffects
}
