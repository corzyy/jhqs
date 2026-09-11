// BarWidgetBase — shared shell for all single-icon bar widgets.
// DRY: 10/12 bar widgets duplicated this exact block (hover scale, dual
// Row/Column layouts, mouse handling). Centralizing it removes ~400 lines
// and guarantees consistent padding/behavior. It also avoids the old
// pattern of instantiating BOTH Row and Column trees: only the active
// orientation's content slot is loaded via Loader.
import QtQuick
import QtQuick.Layouts
import "../../themes"

Item {
    id: root
    signal clicked()
    signal rightClicked()

    // Content providers supply one component each; only the active one loads.
    property Component rowContent
    property Component colContent
    property bool vertical: false
    // Padding convention: horizontal +16/+10, vertical +12/+10.
    property int hPad: 16
    property int vPad: 12
    property int rowPadV: 10

    implicitWidth: (vertical ? colLoader.implicitWidth + vPad : rowLoader.implicitWidth + hPad)
    implicitHeight: (vertical ? colLoader.implicitHeight + rowPadV : rowLoader.implicitHeight + rowPadV)

    // CPU: scale animation only; no implicitWidth Behavior here (the old
    // per-widget `Behavior on implicitWidth` re-animated the whole bar on
    // every temp/volume string change — layout thrash).

    Loader {
        id: rowLoader
        anchors.centerIn: parent
        active: !root.vertical && root.rowContent !== null
        asynchronous: false
        sourceComponent: root.rowContent
    }
    Loader {
        id: colLoader
        anchors.centerIn: parent
        active: root.vertical && root.colContent !== null
        asynchronous: false
        sourceComponent: root.colContent
    }

    // Exposed so icon delegates can tint on hover without adding their own
    // MouseArea (one hover listener per widget, not two).
    readonly property bool hovered: mouse.containsMouse

    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: m => {
            if (m.button === Qt.RightButton) root.rightClicked()
            else root.clicked()
        }
    }
}
