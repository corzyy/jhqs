pragma ComponentBehavior: Bound
import QtQuick
import "../../themes"

Column {
    id: root
    property string current: "global"
    property string query: ""
    signal select(string name)
    signal queryChanged2(string text)
    width: 190
    spacing: 8

    property var sections: [
        {id: "global", title: "Global", icon: "󰔎"},
        {id: "hypr", title: "Hyprland", icon: "󰖲"},
        {id: "bar", title: "Top Bar", icon: "󰍹"},
        {id: "modules", title: "Modules", icon: "󰐱"},
        {id: "workspaces", title: "Workspaces", icon: ""},
        {id: "notif", title: "Notifications", icon: "󰂚"},
        {id: "osd", title: "OSD", icon: "󰍉"},
        {id: "search", title: "Search", icon: "󰈞"}
    ]
    readonly property bool searching: (query || "").trim().length > 0
    readonly property bool isMinimal: Theme.minimalTheme
    property var filtered: {
        let q = (root.query || "").toLowerCase().trim()
        if (q.length === 0) return root.sections
        return root.sections.filter(s => (s.title + "").toLowerCase().includes(q))
    }

    Rectangle {
        antialiasing: Theme.shapesAa
        width: parent.width; height: 36
        radius: root.isMinimal ? 0 : Theme.cornerRadiusSmall
        color: root.isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.04) : Theme.panelSurface
        border.color: searchInput.activeFocus ? Theme.accent : (root.isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.25) : Theme.divider)
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
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
                font.family: root.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(13)
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
                    radius: root.isMinimal ? 0 : Theme.cornerRadiusSmall
                    color: isCurrent && root.isMinimal ? Theme.withAlpha(Theme.accent, 0.16)
                        : isCurrent ? Theme.bgSelected
                        : navMouse.containsMouse ? (root.isMinimal ? Theme.withAlpha(Theme.textPrimary, 0.08) : Theme.bgHover) : "transparent"
                    border.color: isCurrent ? (root.isMinimal ? Theme.accent : Theme.divider) : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard } }
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 10; spacing: 10
                        Text { text: modelData.icon; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(15); color: isCurrent ? Theme.textPrimary : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                        Text { text: modelData.title; font.family: root.isMinimal ? Theme.iconFontFamily : Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: isCurrent && root.isMinimal ? Font.Bold : Font.Medium; color: isCurrent ? Theme.textPrimary : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter
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
