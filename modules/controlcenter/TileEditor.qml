pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../themes"

ColumnLayout {
    id: root
    required property var scope
    Layout.fillWidth: true
    spacing: 12

    readonly property string tab: scope.ccEditTab
    readonly property int editRowH: 64
    readonly property int editGap: 8
    readonly property int layoutRowH: 64
    readonly property int layoutGap: 8
    function editSlotY(i: int): real { return i * (editRowH + editGap) }
    function layoutSlotY(i: int): real { return i * (layoutRowH + layoutGap) }
    function tileSlot(id: string): int { return Math.max(0, scope.tileOrderList().indexOf(id)) }
    function blockSlot(id: string): int { return Math.max(0, scope.blockOrderList().indexOf(id)) }
    function tileIcon(id: string): string {
        if (id === "wired") return "󰈀"
        if (id === "bluetooth") return scope.bluetoothActive ? "󰂯" : "󰂲"
        if (id === "power") { try { return scope.powerModeIcon() } catch (e) { return "󰾅" } }
        return scope.dndActive ? "󰂛" : "󰂚"
    }
    function tileName(id: string): string {
        if (id === "wired") return "Kabel"
        if (id === "bluetooth") return "Bluetooth"
        if (id === "power") return "Energiemodus"
        return "Nicht stören"
    }
    function blockName(id: string): string {
        if (id === "volume") return "Lautstärke"
        if (id === "tiles") return "Kacheln"
        return "Media-Player"
    }
    function blockSub(id: string): string {
        if (id === "volume") return "Lautstärkeregler"
        if (id === "tiles") return "Kacheln & Gerätemenüs"
        return "Aktuelle Wiedergabe"
    }

    Item {
        visible: root.tab === "edit"
        Layout.fillWidth: true
        Layout.preferredHeight: 4 * root.editRowH + 3 * root.editGap

        Item {
            width: parent.width
            height: root.editRowH
            y: root.editSlotY(root.tileSlot("wired"))
            Behavior on y { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
            RowLayout {
                anchors.fill: parent
                spacing: 8
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: root.tileIcon("wired")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(22)
                    color: scope.isTileHidden("wired") ? Theme.textMuted : Theme.textPrimary
                    Layout.preferredWidth: 28
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: root.tileName("wired")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(13)
                    font.weight: Font.Medium
                    color: scope.isTileHidden("wired") ? Theme.textMuted : Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                Item {
                    Layout.preferredWidth: 128
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        anchors.fill: parent
                        radius: height / 2
                        color: Theme.surface2
                    }
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        width: 62
                        height: 26
                        y: 2
                        x: scope.tileSize("wired") === "compact" ? 64 : 2
                        radius: height / 2
                        color: Theme.bgSelected
                        border.color: Theme.divider
                        border.width: 1
                        Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
                    }
                    Row {
                        anchors.fill: parent
                        Item {
                            width: 64; height: 30
                            Text { anchors.centerIn: parent; text: "Groß"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Medium; color: scope.tileSize("wired") === "compact" ? Theme.textSecondary : Theme.textPrimary
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.setTileSize("wired", "large") }
                        }
                        Item {
                            width: 64; height: 30
                            Text { anchors.centerIn: parent; text: "Kompakt"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Medium; color: scope.tileSize("wired") === "compact" ? Theme.textPrimary : Theme.textSecondary
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.setTileSize("wired", "compact") }
                        }
                    }
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    radius: width / 2
                    color: eyeWiredMouse.containsMouse ? Theme.bgHover : (scope.isTileHidden("wired") ? "transparent" : Theme.surface2)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        anchors.centerIn: parent
                        text: scope.isTileHidden("wired") ? "󰈉" : "󰈈"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(15)
                        color: scope.isTileHidden("wired") ? Theme.textMuted : Theme.textPrimary
                    }
                    MouseArea {
                        id: eyeWiredMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: scope.toggleTileHidden("wired")
                    }
                }
                Item {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        width: 22; height: 30
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: "󰅀"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fs(14)
                        color: Theme.textSecondary
                        opacity: root.tileSlot("wired") <= 0 ? 0.3 : 1
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.moveTile("wired", -1) }
                    }
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        x: 22; width: 22; height: 30
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: "󰅁"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fs(14)
                        color: Theme.textSecondary
                        opacity: root.tileSlot("wired") >= 3 ? 0.3 : 1
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.moveTile("wired", 1) }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: root.editRowH
            y: root.editSlotY(root.tileSlot("bluetooth"))
            Behavior on y { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
            RowLayout {
                anchors.fill: parent
                spacing: 8
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: root.tileIcon("bluetooth")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(22)
                    color: scope.isTileHidden("bluetooth") ? Theme.textMuted : Theme.textPrimary
                    Layout.preferredWidth: 28
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: root.tileName("bluetooth")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(13)
                    font.weight: Font.Medium
                    color: scope.isTileHidden("bluetooth") ? Theme.textMuted : Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                Item {
                    Layout.preferredWidth: 128
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        anchors.fill: parent
                        radius: height / 2
                        color: Theme.surface2
                    }
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        width: 62
                        height: 26
                        y: 2
                        x: scope.tileSize("bluetooth") === "compact" ? 64 : 2
                        radius: height / 2
                        color: Theme.bgSelected
                        border.color: Theme.divider
                        border.width: 1
                        Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
                    }
                    Row {
                        anchors.fill: parent
                        Item {
                            width: 64; height: 30
                            Text { anchors.centerIn: parent; text: "Groß"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Medium; color: scope.tileSize("bluetooth") === "compact" ? Theme.textSecondary : Theme.textPrimary
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.setTileSize("bluetooth", "large") }
                        }
                        Item {
                            width: 64; height: 30
                            Text { anchors.centerIn: parent; text: "Kompakt"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Medium; color: scope.tileSize("bluetooth") === "compact" ? Theme.textPrimary : Theme.textSecondary
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.setTileSize("bluetooth", "compact") }
                        }
                    }
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    radius: width / 2
                    color: eyeBtMouse.containsMouse ? Theme.bgHover : (scope.isTileHidden("bluetooth") ? "transparent" : Theme.surface2)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        anchors.centerIn: parent
                        text: scope.isTileHidden("bluetooth") ? "󰈉" : "󰈈"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(15)
                        color: scope.isTileHidden("bluetooth") ? Theme.textMuted : Theme.textPrimary
                    }
                    MouseArea {
                        id: eyeBtMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: scope.toggleTileHidden("bluetooth")
                    }
                }
                Item {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        width: 22; height: 30
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: "󰅀"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fs(14)
                        color: Theme.textSecondary
                        opacity: root.tileSlot("bluetooth") <= 0 ? 0.3 : 1
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.moveTile("bluetooth", -1) }
                    }
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        x: 22; width: 22; height: 30
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: "󰅁"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fs(14)
                        color: Theme.textSecondary
                        opacity: root.tileSlot("bluetooth") >= 3 ? 0.3 : 1
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.moveTile("bluetooth", 1) }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: root.editRowH
            y: root.editSlotY(root.tileSlot("power"))
            Behavior on y { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
            RowLayout {
                anchors.fill: parent
                spacing: 8
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: root.tileIcon("power")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(22)
                    color: scope.isTileHidden("power") ? Theme.textMuted : Theme.textPrimary
                    Layout.preferredWidth: 28
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: root.tileName("power")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(13)
                    font.weight: Font.Medium
                    color: scope.isTileHidden("power") ? Theme.textMuted : Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                Item {
                    Layout.preferredWidth: 128
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        anchors.fill: parent
                        radius: height / 2
                        color: Theme.surface2
                    }
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        width: 62
                        height: 26
                        y: 2
                        x: scope.tileSize("power") === "compact" ? 64 : 2
                        radius: height / 2
                        color: Theme.bgSelected
                        border.color: Theme.divider
                        border.width: 1
                        Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
                    }
                    Row {
                        anchors.fill: parent
                        Item {
                            width: 64; height: 30
                            Text { anchors.centerIn: parent; text: "Groß"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Medium; color: scope.tileSize("power") === "compact" ? Theme.textSecondary : Theme.textPrimary
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.setTileSize("power", "large") }
                        }
                        Item {
                            width: 64; height: 30
                            Text { anchors.centerIn: parent; text: "Kompakt"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Medium; color: scope.tileSize("power") === "compact" ? Theme.textPrimary : Theme.textSecondary
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.setTileSize("power", "compact") }
                        }
                    }
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    radius: width / 2
                    color: eyePowerMouse.containsMouse ? Theme.bgHover : (scope.isTileHidden("power") ? "transparent" : Theme.surface2)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        anchors.centerIn: parent
                        text: scope.isTileHidden("power") ? "󰈉" : "󰈈"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(15)
                        color: scope.isTileHidden("power") ? Theme.textMuted : Theme.textPrimary
                    }
                    MouseArea {
                        id: eyePowerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: scope.toggleTileHidden("power")
                    }
                }
                Item {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        width: 22; height: 30
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: "󰅀"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fs(14)
                        color: Theme.textSecondary
                        opacity: root.tileSlot("power") <= 0 ? 0.3 : 1
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.moveTile("power", -1) }
                    }
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        x: 22; width: 22; height: 30
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: "󰅁"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fs(14)
                        color: Theme.textSecondary
                        opacity: root.tileSlot("power") >= 3 ? 0.3 : 1
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.moveTile("power", 1) }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: root.editRowH
            y: root.editSlotY(root.tileSlot("dnd"))
            Behavior on y { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
            RowLayout {
                anchors.fill: parent
                spacing: 8
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: root.tileIcon("dnd")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(22)
                    color: scope.isTileHidden("dnd") ? Theme.textMuted : Theme.textPrimary
                    Layout.preferredWidth: 28
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: root.tileName("dnd")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(13)
                    font.weight: Font.Medium
                    color: scope.isTileHidden("dnd") ? Theme.textMuted : Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                Item {
                    Layout.preferredWidth: 128
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        anchors.fill: parent
                        radius: height / 2
                        color: Theme.surface2
                    }
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        width: 62
                        height: 26
                        y: 2
                        x: scope.tileSize("dnd") === "compact" ? 64 : 2
                        radius: height / 2
                        color: Theme.bgSelected
                        border.color: Theme.divider
                        border.width: 1
                        Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
                    }
                    Row {
                        anchors.fill: parent
                        Item {
                            width: 64; height: 30
                            Text { anchors.centerIn: parent; text: "Groß"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Medium; color: scope.tileSize("dnd") === "compact" ? Theme.textSecondary : Theme.textPrimary
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.setTileSize("dnd", "large") }
                        }
                        Item {
                            width: 64; height: 30
                            Text { anchors.centerIn: parent; text: "Kompakt"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); font.weight: Font.Medium; color: scope.tileSize("dnd") === "compact" ? Theme.textPrimary : Theme.textSecondary
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.setTileSize("dnd", "compact") }
                        }
                    }
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    radius: width / 2
                    color: eyeDndMouse.containsMouse ? Theme.bgHover : (scope.isTileHidden("dnd") ? "transparent" : Theme.surface2)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        anchors.centerIn: parent
                        text: scope.isTileHidden("dnd") ? "󰈉" : "󰈈"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(15)
                        color: scope.isTileHidden("dnd") ? Theme.textMuted : Theme.textPrimary
                    }
                    MouseArea {
                        id: eyeDndMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: scope.toggleTileHidden("dnd")
                    }
                }
                Item {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        width: 22; height: 30
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: "󰅀"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fs(14)
                        color: Theme.textSecondary
                        opacity: root.tileSlot("dnd") <= 0 ? 0.3 : 1
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.moveTile("dnd", -1) }
                    }
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        x: 22; width: 22; height: 30
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: "󰅁"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fs(14)
                        color: Theme.textSecondary
                        opacity: root.tileSlot("dnd") >= 3 ? 0.3 : 1
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.moveTile("dnd", 1) }
                    }
                }
            }
        }
    }

    Item {
        id: layoutList
        visible: root.tab === "layout"
        Layout.fillWidth: true
        Layout.preferredHeight: 3 * root.layoutRowH + 2 * root.layoutGap

        Item {
            id: layoutRowVolume
            width: parent.width
            height: root.layoutRowH
            property string blockId: "volume"
            property bool dragging: false
            property real dragY: 0
            property real grabDy: 0
            y: dragging ? dragY : root.layoutSlotY(root.blockSlot(blockId))
            Behavior on y { enabled: !layoutRowVolume.dragging; NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
            z: dragging ? 5 : 0
            scale: dragging ? 1.02 : 1.0
            Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
            Rectangle {
                antialiasing: Theme.shapesAa
                anchors.fill: parent
                radius: Theme.cornerRadiusSmall
                color: layoutRowVolume.dragging ? Theme.cardBg : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: "⋮⋮"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(18)
                    color: Theme.textMuted
                    Layout.alignment: Qt.AlignVCenter
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        text: root.blockName("volume")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(13)
                        font.weight: Font.Medium
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        text: root.blockSub("volume")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(11)
                        color: Theme.textSecondary
                        Layout.fillWidth: true
                    }
                }
                Item {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 12
                    Layout.alignment: Qt.AlignVCenter
                    Rectangle { anchors.fill: parent; radius: height / 2; color: Theme.surface2
                        antialiasing: Theme.shapesAa
                    }
                    Rectangle { width: 34; height: 12; radius: height / 2; color: Theme.accent
                        antialiasing: Theme.shapesAa
                    }
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: "#" + (root.blockSlot("volume") + 1)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
                    color: Theme.textMuted
                    Layout.alignment: Qt.AlignVCenter
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeVerCursor
                preventStealing: true
                onPressed: mouse => { layoutRowVolume.dragY = layoutRowVolume.y; layoutRowVolume.grabDy = mouse.y; layoutRowVolume.dragging = true }
                onPositionChanged: mouse => {
                    if (!layoutRowVolume.dragging) return
                    var p = layoutList.mapFromItem(layoutRowVolume, mouse.x, mouse.y)
                    var maxY = 2 * (root.layoutRowH + root.layoutGap)
                    layoutRowVolume.dragY = Math.max(0, Math.min(maxY, p.y - layoutRowVolume.grabDy))
                    var s = Math.max(0, Math.min(2, Math.round(layoutRowVolume.dragY / (root.layoutRowH + root.layoutGap))))
                    if (s !== root.blockSlot("volume")) scope.moveBlockTo("volume", s)
                }
                onReleased: layoutRowVolume.dragging = false
                onCanceled: layoutRowVolume.dragging = false
            }
        }

        Item {
            id: layoutRowTiles
            width: parent.width
            height: root.layoutRowH
            property string blockId: "tiles"
            property bool dragging: false
            property real dragY: 0
            property real grabDy: 0
            y: dragging ? dragY : root.layoutSlotY(root.blockSlot(blockId))
            Behavior on y { enabled: !layoutRowTiles.dragging; NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
            z: dragging ? 5 : 0
            scale: dragging ? 1.02 : 1.0
            Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
            Rectangle {
                antialiasing: Theme.shapesAa
                anchors.fill: parent
                radius: Theme.cornerRadiusSmall
                color: layoutRowTiles.dragging ? Theme.cardBg : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: "⋮⋮"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(18)
                    color: Theme.textMuted
                    Layout.alignment: Qt.AlignVCenter
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        text: root.blockName("tiles")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(13)
                        font.weight: Font.Medium
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        text: root.blockSub("tiles")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(11)
                        color: Theme.textSecondary
                        Layout.fillWidth: true
                    }
                }
                Grid {
                    columns: 2
                    spacing: 3
                    Layout.alignment: Qt.AlignVCenter
                    Repeater {
                        model: 4
                        Rectangle { width: 10; height: 10; radius: width / 2; color: Theme.surface2
                            antialiasing: Theme.shapesAa
                        }
                    }
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: "#" + (root.blockSlot("tiles") + 1)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
                    color: Theme.textMuted
                    Layout.alignment: Qt.AlignVCenter
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeVerCursor
                preventStealing: true
                onPressed: mouse => { layoutRowTiles.dragY = layoutRowTiles.y; layoutRowTiles.grabDy = mouse.y; layoutRowTiles.dragging = true }
                onPositionChanged: mouse => {
                    if (!layoutRowTiles.dragging) return
                    var p = layoutList.mapFromItem(layoutRowTiles, mouse.x, mouse.y)
                    var maxY = 2 * (root.layoutRowH + root.layoutGap)
                    layoutRowTiles.dragY = Math.max(0, Math.min(maxY, p.y - layoutRowTiles.grabDy))
                    var s = Math.max(0, Math.min(2, Math.round(layoutRowTiles.dragY / (root.layoutRowH + root.layoutGap))))
                    if (s !== root.blockSlot("tiles")) scope.moveBlockTo("tiles", s)
                }
                onReleased: layoutRowTiles.dragging = false
                onCanceled: layoutRowTiles.dragging = false
            }
        }

        Item {
            id: layoutRowMedia
            width: parent.width
            height: root.layoutRowH
            property string blockId: "media"
            property bool dragging: false
            property real dragY: 0
            property real grabDy: 0
            y: dragging ? dragY : root.layoutSlotY(root.blockSlot(blockId))
            Behavior on y { enabled: !layoutRowMedia.dragging; NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
            z: dragging ? 5 : 0
            scale: dragging ? 1.02 : 1.0
            Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
            Rectangle {
                antialiasing: Theme.shapesAa
                anchors.fill: parent
                radius: Theme.cornerRadiusSmall
                color: layoutRowMedia.dragging ? Theme.cardBg : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: "⋮⋮"
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fs(18)
                    color: Theme.textMuted
                    Layout.alignment: Qt.AlignVCenter
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        text: root.blockName("media")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(13)
                        font.weight: Font.Medium
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        text: root.blockSub("media")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(11)
                        color: Theme.textSecondary
                        Layout.fillWidth: true
                    }
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    radius: Theme.cornerRadiusSmall
                    color: Theme.surface2
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        width: 10; height: 10
                        radius: width / 2
                        anchors.centerIn: parent
                        color: Theme.accent
                    }
                }
                Text {
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                    text: "#" + (root.blockSlot("media") + 1)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
                    color: Theme.textMuted
                    Layout.alignment: Qt.AlignVCenter
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeVerCursor
                preventStealing: true
                onPressed: mouse => { layoutRowMedia.dragY = layoutRowMedia.y; layoutRowMedia.grabDy = mouse.y; layoutRowMedia.dragging = true }
                onPositionChanged: mouse => {
                    if (!layoutRowMedia.dragging) return
                    var p = layoutList.mapFromItem(layoutRowMedia, mouse.x, mouse.y)
                    var maxY = 2 * (root.layoutRowH + root.layoutGap)
                    layoutRowMedia.dragY = Math.max(0, Math.min(maxY, p.y - layoutRowMedia.grabDy))
                    var s = Math.max(0, Math.min(2, Math.round(layoutRowMedia.dragY / (root.layoutRowH + root.layoutGap))))
                    if (s !== root.blockSlot("media")) scope.moveBlockTo("media", s)
                }
                onReleased: layoutRowMedia.dragging = false
                onCanceled: layoutRowMedia.dragging = false
            }
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 0
        Item {
            Layout.preferredWidth: 184
            Layout.preferredHeight: 38
            Rectangle {
                antialiasing: Theme.shapesAa
                anchors.fill: parent
                radius: height / 2
                color: Theme.surface2
            }
            Rectangle {
                antialiasing: Theme.shapesAa
                width: 88
                height: 32
                y: 3
                x: root.tab === "layout" ? 93 : 3
                radius: height / 2
                color: Theme.bgSelected
                border.color: Theme.divider
                border.width: 1
                Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasizedDecelerate } }
            }
            Row {
                anchors.fill: parent
                Item {
                    width: 92; height: 38
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "󰏫"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13); color: root.tab === "edit" ? Theme.textPrimary : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                        Text { text: "Edit"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Medium; color: root.tab === "edit" ? Theme.textPrimary : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.ccEditTab = "edit" }
                }
                Item {
                    width: 92; height: 38
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "󰌆"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(13); color: root.tab === "layout" ? Theme.textPrimary : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                        Text { text: "Layout"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Medium; color: root.tab === "layout" ? Theme.textPrimary : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scope.ccEditTab = "layout" }
                }
            }
        }
    }
}
