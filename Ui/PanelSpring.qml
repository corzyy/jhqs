// PanelSpring — simplified: instant show/hide, no spring physics.
// The animation system was removed (user runs Minimal, no animations).
// Property names are kept so all panel call-sites work unchanged;
// values are now pure functions of `shown`.
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    visible: false
    required property bool shown
    // Kept for call-site compat only; no longer read.
    required property real hiddenX
    required property real hiddenY
    property bool minimal: false
    property bool slideFade: false
    property real slideFadeDist: 12
    readonly property real fade: root.shown ? 1 : 0
    readonly property real zoom: 1.0
    readonly property real slideX: 0
    readonly property real slideY: 0
    // Kept for compat (WeatherPanel debug hook reads offset).
    readonly property real offset: root.shown ? 0 : 1
    readonly property bool boxVisible: root.shown
    readonly property int hideDelay: 0
}
