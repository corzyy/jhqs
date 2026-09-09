pragma ComponentBehavior: Bound
import QtQuick
import "../../themes"

Column {
    id: root
    property string label: ""
    property string text: ""
    property string placeholder: ""
    signal applied(string value)
    width: parent ? parent.width : 300
    spacing: 4
    readonly property bool isMinimal: Theme.minimalTheme

    onTextChanged: if (!fieldInput.activeFocus) fieldInput.text = root.text
    Component.onCompleted: fieldInput.text = root.text

    Text {
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
        visible: root.label.length > 0
        text: root.label
        font.family: root.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Medium
        color: root.isMinimal ? Theme.textSecondary : Theme.textPrimary
        width: parent.width; elide: Text.ElideRight
    }
    Rectangle {
        antialiasing: Theme.shapesAa
        width: parent.width; height: 36
        radius: root.isMinimal ? 0 : Theme.cornerRadiusSmall
        color: root.isMinimal
            ? (fieldMouse.containsMouse || fieldInput.activeFocus ? Theme.withAlpha(Theme.textPrimary, 0.08) : Theme.withAlpha(Theme.textPrimary, 0.04))
            : (fieldInput.activeFocus ? Theme.bgSelected : Theme.panelSurface)
        border.color: fieldInput.activeFocus ? Theme.accent : (root.isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.25) : Theme.divider)
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
        Text {
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
            verticalAlignment: Text.AlignVCenter
            visible: fieldInput.displayText.length === 0
            text: root.placeholder
            font.family: root.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(12)
            color: Theme.textMuted
            elide: Text.ElideRight
        }
        TextInput {
            id: fieldInput
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            font.family: root.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(12)
            color: Theme.textPrimary
            clip: true
            onAccepted: { root.applied(text); focus = false }
        }
        MouseArea { id: fieldMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.IBeamCursor; acceptedButtons: Qt.NoButton }
    }
}
