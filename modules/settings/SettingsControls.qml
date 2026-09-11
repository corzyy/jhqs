pragma ComponentBehavior: Bound
import QtQuick
import "../../themes"

// Merged from SettingsDropdown/Row/Section/Sidebar/SliderRow/TextField/Toggle.qml
// (7 files, ~500 lines of small form primitives). Usage changed from bare
//   SettingsRow { ... }
// to namespaced inline components (existing bare 'import ".."' exposes this file):
//   SettingsControls.SettingsRow { ... }
// SettingsPanel.qml (which uses 'import "./settings" as S') uses
//   S.SettingsControls.SettingsSidebar { ... }
QtObject {
    id: __settingsControls

    // From SettingsDropdown.qml.
    component SettingsDropdown: Column {
        id: root
        property string label: ""
        property var options: []
        property string current: ""
        signal picked(string value)
        width: parent ? parent.width : 300
        spacing: 6

        Rectangle {
            antialiasing: Theme.shapesAa
            id: btn
            width: parent.width; height: 36
            radius: 0
            color: (ddMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08) : Theme.withAlpha(Theme.textPrimary, 0.04))
            border.color: Theme.withAlpha(Theme.textPrimary, 0.25); border.width: 1
            Row {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                spacing: 8
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: root.label.length > 0 ? root.label : ""
                    visible: root.label.length > 0
                    font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12)
                    color: Theme.textSecondary
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: root.current
                    font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Medium
                    color: Theme.textPrimary; elide: Text.ElideRight
                    width: parent.width - (root.label.length > 0 ? 80 : 40)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: root.open ? "▴" : "▾"
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12)
                    color: Theme.textSecondary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea { id: ddMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.open = !root.open }
        }

        property bool open: false
        Column {
            id: list
            width: parent.width
            visible: root.open
            spacing: 2
            Repeater {
                // RAM: delegates only exist while open. Previously all options
                // (icon themes, sinks — up to 50 rows with MouseArea+Behavior)
                // were instantiated per dropdown even when collapsed.
                model: root.open ? root.options : []
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: modelData + "" === root.current
                    width: list.width; height: 32
                    radius: 0
                    color: isCurrent ? Theme.withAlpha(Theme.accent, 0.16) : optMouse.containsMouse ? (Theme.withAlpha(Theme.textPrimary, 0.08))
                        : isCurrent ? Theme.bgSelected : "transparent"
                    border.color: isCurrent ? (Theme.accent) : "transparent"
                    border.width: 1
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        anchors.fill: parent; anchors.leftMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        text: modelData + ""
                        font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12)
                        font.weight: isCurrent ? Font.Bold : Font.Normal
                        color: isCurrent ? Theme.textPrimary : Theme.textSecondary
                    }
                    MouseArea { id: optMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.picked(modelData + ""); root.open = false } }
                }
            }
        }
    }

    // From SettingsRow.qml.
    component SettingsRow: Rectangle {
        antialiasing: Theme.shapesAa
        id: root
        property string title: ""
        property string subtitle: ""
        property bool selected: false
        default property alias control: slot.children
        width: parent ? parent.width : 300
        height: subtitle.length > 0 ? 52 : 40
        radius: 0
        color: (selected || rowMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.08) : "transparent")
        border.color: "transparent"
        border.width: 0

        MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 10
            spacing: 10
            Column {
                width: parent.width - slotWrap.width - 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: root.title
                    font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12)
                    font.weight: root.selected ? Font.Bold : Font.Medium
                    color: Theme.textPrimary
                    elide: Text.ElideRight; width: parent.width
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    visible: root.subtitle.length > 0
                    text: root.subtitle
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10)
                    color: Theme.textMuted
                    elide: Text.ElideRight; width: parent.width
                }
            }
            Item {
                id: slotWrap
                width: slot.children.length > 0 ? slot.implicitWidth : 0
                height: parent.height
                Row { id: slot; anchors.centerIn: parent; spacing: 6 }
            }
        }
    }

    // From SettingsSection.qml.
    component SettingsSection: Column {
        id: root
        property string title: ""
        default property alias content: body.children
        spacing: 6
        width: parent ? parent.width : 300

        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: root.title.length > 0
            text: root.title.toUpperCase()
            font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(10)
            font.weight: Font.Bold; font.letterSpacing: 1.2
            color: Theme.textSecondary
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            id: card
            width: parent.width
            implicitHeight: body.implicitHeight + (0)
            radius: 0
            color: "transparent"
            border.color: "transparent"
            border.width: 0
            Column {
                id: body
                anchors.fill: parent
                anchors.margins: 0
                spacing: 6
            }
        }
    }

    // From SettingsSidebar.qml.
    component SettingsSidebar: Column {
        id: root
        property string current: "global"
        property string query: ""
        signal select(string name)
        signal queryChanged2(string text)
        width: 190
        spacing: 8

        property var sections: [
            {id: "global", title: "Global", icon: "󰔎"},
            {id: "theming", title: "Theming", icon: "󰔿"},
            {id: "hypr", title: "Hyprland", icon: "󰖲"},
            {id: "bar", title: "Top Bar", icon: "󰍹"},
            {id: "modules", title: "Modules", icon: "󰐱"},
            {id: "workspaces", title: "Workspaces", icon: ""},
            {id: "notif", title: "Notifications", icon: "󰂚"},
            {id: "osd", title: "OSD", icon: "󰍉"},
            {id: "search", title: "Search", icon: "󰈞"}
        ]
        readonly property bool searching: (query || "").trim().length > 0
        property var filtered: {
            let q = (root.query || "").toLowerCase().trim()
            if (q.length === 0) return root.sections
            return root.sections.filter(s => (s.title + "").toLowerCase().includes(q))
        }

        Rectangle {
            antialiasing: Theme.shapesAa
            width: parent.width; height: 36
            radius: 0
            color: Theme.withAlpha(Theme.textPrimary, 0.04)
            border.color: searchInput.activeFocus ? Theme.accent : (Theme.withAlpha(Theme.textPrimary, 0.25))
            border.width: 1
            Row {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 6
                Text { text: "󰍉"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13); color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
                TextInput {
                    id: searchInput
                    width: parent.width - 30
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.query
                    font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13)
                    color: Theme.textPrimary
                    clip: true
                    onTextChanged: root.queryChanged2(text)
                    Keys.onPressed: e => { if (e.key === Qt.Key_Escape) { root.queryChanged2(""); e.accepted = true } }
                }
            }
        }

        Flickable {
            width: parent.width
            height: Math.max(120, parent.height - 44)
            clip: true
            contentHeight: navCol.height
            contentWidth: width
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            Column {
                id: navCol
                width: parent.width
                spacing: 4
                Component {
                    id: rowDelegate
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        required property var modelData
                        required property int index
                        readonly property bool isCurrent: modelData.id === root.current
                        width: navCol.width; height: 38
                        radius: 0
                        color: isCurrent ? Theme.withAlpha(Theme.accent, 0.16) : isCurrent ? Theme.bgSelected
                            : navMouse.containsMouse ? (Theme.withAlpha(Theme.textPrimary, 0.08)) : "transparent"
                        border.color: isCurrent ? (Theme.accent) : "transparent"
                        border.width: 1
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 10; spacing: 10
                            Text { text: modelData.icon; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(15); color: isCurrent ? Theme.textPrimary : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            Text { text: modelData.title; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12); font.weight: isCurrent ? Font.Bold : Font.Medium; color: isCurrent ? Theme.textPrimary : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                        }
                        MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.select(modelData.id) }
                    }
                }
                Repeater {
                    model: root.searching ? root.filtered : []
                    delegate: rowDelegate
                }
                Repeater {
                    model: !root.searching ? root.sections : []
                    delegate: rowDelegate
                }
            }
        }
    }

    // From SettingsSliderRow.qml.
    component SettingsSliderRow: Column {
        id: root
        property string label: ""
        property real from: 0
        property real to: 100
        property real value: 0
        property real stepSize: 1
        property string unit: ""
        signal moved(real v)
        signal applied(real v)
        width: parent ? parent.width : 300
        spacing: 0

        function dispDecimals(): int {
            let s = root.stepSize.toString()
            let i = s.indexOf(".")
            if (i === -1) return 0
            return Math.max(0, Math.min(3, s.length - i - 1))
        }

        Row {
            width: parent.width
            height: 20
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: root.label
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Medium
                color: Theme.textSecondary
                width: parent.width - 70; elide: Text.ElideRight
            }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                text: (root.stepSize < 1 ? Number(root.value).toFixed(root.dispDecimals()) : Math.round(root.value)) + (root.unit.length > 0 ? root.unit : "")
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(11)
                color: Theme.textSecondary
                width: 70; horizontalAlignment: Text.AlignRight
            }
        }
        Item {
            width: parent.width
            height: 22
            property real liveValue: root.value
            property real extValue: root.value
            onExtValueChanged: if (!omMouse.dragging) liveValue = extValue
            onVisibleChanged: if (visible) liveValue = root.value
            readonly property real range: Math.max(0.0001, root.to - root.from)
            readonly property real progress: Math.max(0, Math.min(1, (liveValue - root.from) / range))
            Rectangle {
                antialiasing: Theme.shapesAa
                id: omTrack
                anchors.left: parent.left; anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 4
                radius: 2
                color: Theme.withAlpha(Theme.textPrimary, 0.18)
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                anchors.left: omTrack.left
                anchors.verticalCenter: omTrack.verticalCenter
                height: 4
                radius: 2
                width: omTrack.width * parent.progress
                color: Theme.textPrimary
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                width: 14; height: 14
                radius: 7
                color: Theme.textPrimary
                border.color: Theme.bg
                border.width: 2
                anchors.verticalCenter: omTrack.verticalCenter
                x: Math.max(0, Math.min(omTrack.width - width, omTrack.width * parent.progress - width / 2))
            }
            MouseArea {
                id: omMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                property bool dragging: false
                function valueFromX(px: real): real {
                    let c = Math.max(0, Math.min(omTrack.width, px))
                    return Math.max(root.from, Math.min(root.to, root.from + (c / omTrack.width) * parent.range))
                }
                function snap(v: real): real {
                    if (root.stepSize > 0) v = Math.round(v / root.stepSize) * root.stepSize
                    return Math.max(root.from, Math.min(root.to, v))
                }
                onPressed: mouse => {
                    omMouse.dragging = true
                    let v = snap(valueFromX(mouse.x))
                    parent.liveValue = v
                    root.moved(v)
                }
                onPositionChanged: mouse => {
                    if (!omMouse.dragging) return
                    let v = snap(valueFromX(mouse.x))
                    parent.liveValue = v
                    root.moved(v)
                }
                onReleased: {
                    omMouse.dragging = false
                    root.applied(parent.liveValue)
                    parent.liveValue = root.value
                }
                onWheel: wheel => { wheel.accepted = false }
            }
        }
    }

    // From SettingsTextField.qml.
    component SettingsTextField: Column {
        id: root
        property string label: ""
        property string text: ""
        property string placeholder: ""
        signal applied(string value)
        width: parent ? parent.width : 300
        spacing: 4

        onTextChanged: if (!fieldInput.activeFocus) fieldInput.text = root.text
        Component.onCompleted: fieldInput.text = root.text

        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: root.label.length > 0
            text: root.label
            font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Medium
            color: Theme.textSecondary
            width: parent.width; elide: Text.ElideRight
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            width: parent.width; height: 36
            radius: 0
            color: (fieldMouse.containsMouse || fieldInput.activeFocus ? Theme.withAlpha(Theme.textPrimary, 0.08) : Theme.withAlpha(Theme.textPrimary, 0.04))
            border.color: fieldInput.activeFocus ? Theme.accent : (Theme.withAlpha(Theme.textPrimary, 0.25))
            border.width: 1
            Text {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                verticalAlignment: Text.AlignVCenter
                visible: fieldInput.displayText.length === 0
                text: root.placeholder
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12)
                color: Theme.textMuted
                elide: Text.ElideRight
            }
            TextInput {
                id: fieldInput
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(12)
                color: Theme.textPrimary
                clip: true
                onAccepted: { root.applied(text); focus = false }
            }
            MouseArea { id: fieldMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.IBeamCursor; acceptedButtons: Qt.NoButton }
        }
    }

    // From SettingsToggle.qml.
    component SettingsToggle: Item {
        id: root
        property bool on: false
        property bool enabled: true
        signal toggled(bool next)
        implicitWidth: 46; implicitHeight: 26
        width: 46; height: 26

        Item {
            anchors.centerIn: parent
            width: 42; height: 22
            Rectangle {
                antialiasing: Theme.shapesAa
                anchors.centerIn: parent
                width: 42; height: 22
                radius: 0
                color: root.on && root.enabled ? Theme.withAlpha(Theme.textPrimary, 0.18) : Theme.withAlpha(Theme.textPrimary, 0.04)
                border.color: root.on && root.enabled ? "transparent" : Theme.withAlpha(Theme.textPrimary, 0.4)
                border.width: root.on && root.enabled ? 0 : 1
                Rectangle {
                    antialiasing: Theme.shapesAa
                    width: 16; height: 16
                    radius: 0
                    x: root.on ? parent.width - width - 3 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.on && root.enabled ? Theme.textPrimary : Theme.textSecondary
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                onClicked: if (root.enabled) root.toggled(!root.on)
            }
        }

        opacity: root.enabled ? 1 : 0.6
    }

}