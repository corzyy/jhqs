import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import "../../themes"

Item {
    id: root
    property bool vertical: false
    implicitWidth: vertical ? col.implicitWidth + 12 : row.implicitWidth + 16
    implicitHeight: vertical ? col.implicitHeight + 10 : row.implicitHeight + 10

    property var activeTl: {
        try {
            let cur = Hyprland.activeToplevel
            if (cur) return cur
        } catch (e) { }
        try {
            let tv = Hyprland.toplevels ? Hyprland.toplevels.values : null
            let list = (typeof tv === "function") ? tv() : tv
            if (list) {
                for (let i = 0; i < list.length; i++) {
                    let t = list[i]
                    if (!t) continue
                    try {
                        if (t.activated || (t.wayland && t.wayland.activated)) return t
                    } catch (e2) { }
                }
            }
        } catch (e3) { }
        return null
    }
    function appIdForTl(tl: var): string {
        try {
            if (!tl) return ""
            if (tl.wayland && tl.wayland.appId && tl.wayland.appId.length > 0) return tl.wayland.appId
            let o = tl.lastIpcObject
            if (o) {
                if (o.class && ("" + o.class).length > 0) return "" + o.class
                if (o.initialClass && ("" + o.initialClass).length > 0) return "" + o.initialClass
            }
        } catch (e) { }
        return ""
    }
    readonly property string winAppId: {
        try { return appIdForTl(activeTl) } catch (e) { return "" }
    }
    readonly property string winIcon: {
        Theme.appsRev
        try {
            if (winAppId.length > 0) {
                let p = Theme.appIconFor(winAppId)
                if (p && p.length > 0 && p !== Quickshell.iconPath("application-x-executable")) return p
            }
        } catch (e) { }
        return ""
    }
    readonly property string winTitle: {
        try {
            if (activeTl && activeTl.title && ("" + activeTl.title).trim().length > 0) return "" + activeTl.title
        } catch (e) { }
        if (winAppId.length > 0) return winAppId
        return "Desktop"
    }

    RowLayout {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 8
        IconImage {
            visible: root.winIcon !== ""
            source: root.winIcon
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter
            asynchronous: true
            implicitSize: Qt.size(36, 36)
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: root.winIcon === ""
            text: "󰍹"
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fs(15)
            font.weight: Theme.textBold ? Font.Bold : Font.Normal
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            text: root.winTitle
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(12)
            font.weight: Theme.textBold ? Font.Bold : Font.Normal
            color: mouse.containsMouse ? Theme.primary : Theme.textSecondary
            elide: Text.ElideRight
            Layout.maximumWidth: 180
            Layout.alignment: Qt.AlignVCenter
        }
    }
    ColumnLayout {
        id: col
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 9
        IconImage {
            visible: root.winIcon !== ""
            source: root.winIcon
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignHCenter
            asynchronous: true
            implicitSize: Qt.size(36, 36)
        }
        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            visible: root.winIcon === ""
            text: "󰍹"
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fs(14)
            font.weight: Theme.textBold ? Font.Bold : Font.Normal
            color: mouse.containsMouse ? Theme.primary : Theme.textPrimary
            Layout.alignment: Qt.AlignHCenter
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }
}
