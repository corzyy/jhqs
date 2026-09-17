pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../themes"
import "../../services"
import "../../Ui"
import "../settings" as S
import "../settings/pages" as Pages

// Settings rework 2 — Caelestia Nexus (caelestia-dots/shell, modules/nexus)
// window look-alike: pill search bar + categorized nav rail with circular
// icon badges (title + description per row) on the left, large-title page
// with slide/fade switch animation on the right.
//
// Colour/rounding mapping mirrors NexusControls: M3 surface roles from
// Theme, fixed 28/32px outer rounding, 4px inner corners, 2px group gaps.
// Backends stay jhqs (Theme, SettingsService, MangoService, …) — only the
// UI chrome is copied. The window lingers for Theme.panelHideDelay after
// close so the exit animation can play (0 = instant when off).
Scope {
    id: settingsScope
    property bool showSettings: false
    property string section: "global"
    property string filterText: ""
    signal dismissed()

    property bool _winVisible: showSettings
    Timer { id: hideTimer; interval: Theme.panelHideDelay; repeat: false; onTriggered: if (!settingsScope.showSettings) settingsScope._winVisible = false }

    // Nexus PageRegistry equivalent: id + title + description + category.
    // Order defines the rail; unknown ids fall back to global so a stale id
    // can never blank the panel.
    readonly property var navEntries: [
        {id: "global", title: "Appearance", icon: "󰔎", desc: "Rounding, animations, fonts", category: "appearance"},
        {id: "mango", title: "Mango", icon: "󰖳", desc: "Layout, gaps, borders", category: "appearance"},
        {id: "audio", title: "Audio", icon: "󰕾", desc: "Volume, outputs, brightness", category: "connectivity"},
        {id: "apps", title: "Apps", icon: "󰀻", desc: "Terminal, shell prompt", category: "system"},
        {id: "bar", title: "Top Bar", icon: "󰍹", desc: "Position, size, spacing", category: "shell"},
        {id: "vitals", title: "Vitals", icon: "󰻠", desc: "CPU, memory, GPU", category: "shell"},
        {id: "workspaces", title: "Workspaces", icon: "", desc: "Style, spacing, tags", category: "shell"},
        {id: "calendar", title: "Calendar", icon: "󰃭", desc: "Layout, week start", category: "shell"},
        {id: "notif", title: "Notifications", icon: "󰂚", desc: "Position, timeout, focus", category: "shell"},
        {id: "search", title: "Search", icon: "󰍉", desc: "Menu results, features", category: "shell"},
        {id: "weather", title: "Weather", icon: "", desc: "Units, refresh", category: "shell"}
    ]
    readonly property var sectionIds: navEntries.map(e => e.id)
    readonly property bool searching: (filterText || "").trim().length > 0
    readonly property var filteredEntries: {
        let q = (settingsScope.filterText || "").toLowerCase().trim()
        if (q.length === 0) return settingsScope.navEntries
        return settingsScope.navEntries.filter(e => ((e.title + " " + e.desc).toLowerCase().includes(q)))
    }
    function entryFor(id: string): var {
        for (let i = 0; i < navEntries.length; i++) if (navEntries[i].id === id) return navEntries[i]
        return navEntries[0]
    }
    function sectionTitle(id: string): string { return entryFor(id).title }
    function selectSection(id: string): void {
        let nid = (id === "modules") ? "vitals" : id
        section = sectionIds.indexOf(nid) >= 0 ? nid : "global"
    }

    // Shown page; the window's two page slots cross-slide on section change
    // (see pageWrap.switchTo). Direct child components so Bound scope resolves
    // under ComponentBehavior: Bound.
    function pageFor(s: string): Component {
        switch (s) {
        case "mango": return mangoComp
        case "audio": return audioComp
        case "apps": return appsComp
        case "bar": return barComp
        case "vitals": return vitalsComp
        case "workspaces": return workspacesComp
        case "calendar": return calendarComp
        case "notif": return notifComp
        case "search": return searchComp
        case "weather": return weatherComp
        default: return globalComp
        }
    }
    function sectionIndex(id: string): int {
        let i = sectionIds.indexOf(id)
        return i >= 0 ? i : 0
    }

    onShowSettingsChanged: {
        if (showSettings) {
            _winVisible = true
            hideTimer.stop()
            SettingsService.refresh()
            try { MangoService.refresh() } catch (e) {}
        } else {
            filterText = ""
            hideTimer.restart()
        }
    }

    IpcHandler {
        target: "settings"
        function state(): string { return "visible=" + settingsScope.showSettings + " section=" + settingsScope.section }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: settingsScope._winVisible && Theme.isPrimaryScreen(modelData)
            color: "transparent"
            exclusiveZone: 0
            anchors { top: true; left: true; right: true; bottom: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "settings"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            // Page swap state lives here (not on the Scope): the shared-axis
            // run targets the page slots, which only exist in this window.
            property string shownSection: ""
            property int lastIdx: 0
            property int animDir: 1
            // Populate the front page slot. Cold opens cannot rely on
            // onShowSettingsChanged: the PanelLoader instantiates the panel
            // while it is already visible, so the signal never fires. The
            // Repeater's slots also do not exist until the next event loop
            // turn, so retry once they do.
            function showPage(section: string): void {
                if (!pageWrap.slot(pageWrap.frontSlot)) {
                    Qt.callLater(() => win.showPage(section))
                    return
                }
                win.shownSection = section
                win.lastIdx = settingsScope.sectionIndex(section)
                pageWrap.reset(section)
            }
            Component.onCompleted: if (settingsScope.showSettings) win.showPage(settingsScope.section)
            Connections {
                target: settingsScope
                function onShowSettingsChanged() {
                    if (settingsScope.showSettings) {
                        win.showPage(settingsScope.section)
                    }
                }
                function onSectionChanged() {
                    if (!settingsScope.showSettings) {
                        win.shownSection = settingsScope.section
                        win.lastIdx = settingsScope.sectionIndex(settingsScope.section)
                        return
                    }
                    pageWrap.switchTo(settingsScope.section)
                }
            }
            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        if (settingsScope.filterText.length > 0) settingsScope.filterText = ""
                        else settingsScope.dismissed()
                        event.accepted = true
                    } else if (event.modifiers === Qt.NoModifier && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        let i = event.key - Qt.Key_1
                        if (i >= 0 && i < settingsScope.sectionIds.length) settingsScope.selectSection(settingsScope.sectionIds[i])
                        event.accepted = true
                    } else if (event.modifiers === Qt.NoModifier && event.key === Qt.Key_0) {
                        if (settingsScope.sectionIds.length > 9) settingsScope.selectSection(settingsScope.sectionIds[9])
                        event.accepted = true
                    }
                }
                Component.onCompleted: forceActiveFocus()
            }
            // Dim lives in the SAME layer surface as the dialog: a separate
            // backdrop surface has no defined stacking order vs. the dialog,
            // and on mango it can sit on top, dismissing the panel on ANY
            // click (even inside the dialog).
            Rectangle {
                antialiasing: Theme.shapesAa
                anchors.fill: parent
                color: Theme.scrim
                opacity: settingsScope.showSettings ? 0.25 : 0
                Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.panelAnimFade; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects } }
            }
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: settingsScope.dismissed() }
            Rectangle {
                antialiasing: Theme.shapesAa
                id: settingsBox
                // Nexus sizing: 16/9 ratio, ~70% of screen height.
                width: Math.min(1020, parent.width - 32)
                implicitHeight: Math.min(660, parent.height - 60)
                x: (parent.width - width) / 2
                y: (parent.height - implicitHeight) / 2
                color: Theme.surface
                radius: 28
                clip: true
                visible: settingsScope._winVisible
                // M3 fade through: the surface fades in while settling from
                // 92%, and fades back out on close.
                Motion {
                    id: boxMotion
                    active: settingsScope.showSettings
                    pattern: Motion.FadeThrough
                }
                opacity: boxMotion.opacity
                scale: boxMotion.scale
                transformOrigin: Item.Center
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: mouse => mouse.accepted = true
                    onPressed: mouse => mouse.accepted = true
                    onWheel: wheel => wheel.accepted = true
                }
                // Floating close button (Nexus windowBtn).
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    width: 40; height: 40
                    radius: 20
                    z: 10
                    color: closeMouse.containsMouse ? Theme.withAlpha(Theme.error, 0.20) : Theme.surface_container_high
                    antialiasing: Theme.shapesAa
                    Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: Theme.durSlowEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSlowEffects } }
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: Theme.fs(14)
                        color: closeMouse.containsMouse ? Theme.error : Theme.textSecondary
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                    }
                    MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: settingsScope.dismissed() }
                }
                Row {
                    anchors.fill: parent
                    anchors.margins: 20
                    anchors.rightMargin: 20
                    spacing: 0
                    Column {
                        id: navCol
                        width: 300
                        height: parent.height
                        spacing: 12
                        S.NexusControls.SearchBar {
                            width: parent.width
                            text: settingsScope.filterText
                            onTextChanged2: t => settingsScope.filterText = t
                        }
                        Flickable {
                            id: navFlick
                            width: parent.width
                            height: parent.height - 60
                            clip: true
                            contentHeight: navList.implicitHeight
                            contentWidth: width
                            boundsBehavior: Flickable.StopAtBounds
                            flickableDirection: Flickable.VerticalFlick
                            Column {
                                id: navList
                                width: navFlick.width
                                spacing: 2
                                Repeater {
                                    model: settingsScope.filteredEntries
                                    delegate: Item {
                                        required property var modelData
                                        required property int index
                                        readonly property bool isCurrent: modelData.id === settingsScope.section
                                        readonly property bool catStart: index === 0 || settingsScope.filteredEntries[index - 1].category !== modelData.category
                                        readonly property bool catEnd: index === settingsScope.filteredEntries.length - 1 || settingsScope.filteredEntries[index + 1].category !== modelData.category
                                        readonly property int topGap: (catStart && index !== 0) ? 12 : 0
                                        width: navList.width
                                        height: 76 + topGap
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: 76
                                            // One radius everywhere: outer corners of a
                                            // group are round, inner corners stay small.
                                            topLeftRadius: (isCurrent || catStart) ? 28 : 4
                                            topRightRadius: (isCurrent || catStart) ? 28 : 4
                                            bottomLeftRadius: (isCurrent || catEnd) ? 28 : 4
                                            bottomRightRadius: (isCurrent || catEnd) ? 28 : 4
                                            color: isCurrent ? Theme.secondary_container
                                                : navMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high
                                            antialiasing: Theme.shapesAa
                                            Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: Theme.durSlowEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSlowEffects } }
                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 12
                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 44; height: 44
                                                    radius: 22
                                                    color: isCurrent ? Theme.accent : Theme.secondary_container
                                                    antialiasing: Theme.shapesAa
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.icon
                                                        font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(20)
                                                        color: isCurrent ? Theme.onAccent : Theme.on_secondary_container
                                                        antialiasing: Theme.textAa
                                                        renderType: Theme.textRenderType
                                                    }
                                                }
                                                Column {
                                                    width: parent.width - 56 - 12
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 0
                                                    Text {
                                                        width: parent.width
                                                        text: modelData.title
                                                        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(14)
                                                        color: Theme.textPrimary
                                                        elide: Text.ElideRight
                                                        antialiasing: Theme.textAa
                                                        renderType: Theme.textRenderType
                                                    }
                                                    Text {
                                                        width: parent.width
                                                        text: modelData.desc
                                                        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11)
                                                        color: Theme.textSecondary
                                                        elide: Text.ElideRight
                                                        antialiasing: Theme.textAa
                                                        renderType: Theme.textRenderType
                                                    }
                                                }
                                            }
                                            MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: settingsScope.selectSection(modelData.id) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Item { width: 16; height: parent.height }
                    Rectangle {
                        antialiasing: Theme.shapesAa
                        width: 1
                        height: parent.height - 8
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.divider
                        opacity: 0.8
                    }
                    Item { width: 16; height: parent.height }
                    Item {
                        id: pageWrap
                        width: parent.width - 300 - 1 - 32
                        height: parent.height
                        // Two page slots. The front one holds the current
                        // section; the back one receives the incoming
                        // section and becomes front when the run ends. Both
                        // carry a Motion SharedAxisX driver, so old and new
                        // slide and fade together (30dp, emphasized) — the
                        // M3 lateral-navigation pattern (transition-patterns).
                        property int frontSlot: 0
                        function slot(idx: int): var { return pageSlots.itemAt(idx) }
                        function snap(): void {
                            for (let i = 0; i < pageSlots.count; i++) {
                                const s = pageSlots.itemAt(i)
                                if (s) s.snap()
                            }
                        }
                        function reset(section: string): void {
                            const front = pageWrap.slot(pageWrap.frontSlot)
                            const back = pageWrap.slot(1 - pageWrap.frontSlot)
                            if (back) back.clear()
                            if (front) front.showSection(section)
                            pageWrap.snap()
                        }
                        function switchTo(section: string): void {
                            if (win.shownSection === section) return
                            const backIdx = 1 - pageWrap.frontSlot
                            const back = pageWrap.slot(backIdx)
                            if (!back) {
                                Qt.callLater(() => pageWrap.switchTo(section))
                                return
                            }
                            const idx = settingsScope.sectionIndex(section)
                            win.animDir = idx >= win.lastIdx ? 1 : -1
                            win.lastIdx = idx
                            back.showSection(section)
                            win.shownSection = section
                            pageWrap.frontSlot = backIdx
                        }
                        Repeater {
                            id: pageSlots
                            model: 2
                            delegate: Item {
                                id: slot
                                required property int index
                                anchors.fill: parent
                                property Component sectionComp: null
                                function showSection(sec: string): void {
                                    slot.sectionComp = settingsScope.pageFor(sec)
                                    Qt.callLater(() => pageFlick.contentY = 0)
                                }
                                function clear(): void {
                                    slot.sectionComp = null
                                }
                                function snap(): void { slotMotion.complete() }
                                Motion {
                                    id: slotMotion
                                    active: pageWrap.frontSlot === slot.index
                                    pattern: Motion.SharedAxisX
                                    direction: win.animDir
                                }
                                opacity: slotMotion.opacity
                                x: slotMotion.x
                                visible: opacity > 0.01
                                Flickable {
                                    id: pageFlick
                                    anchors.fill: parent
                                    anchors.rightMargin: 52
                                    clip: true
                                    contentHeight: pageCol.implicitHeight
                                    contentWidth: width
                                    boundsBehavior: Flickable.StopAtBounds
                                    flickableDirection: Flickable.VerticalFlick
                                    Column {
                                        id: pageCol
                                        width: pageFlick.width
                                        spacing: 12
                                        // Loaded synchronously so a click swaps
                                        // content in the same frame (no blank
                                        // races).
                                        Loader {
                                            width: parent.width
                                            active: settingsScope._winVisible
                                            asynchronous: false
                                            sourceComponent: slot.sectionComp
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component { id: globalComp; Pages.GlobalPage {} }
    Component { id: mangoComp; Pages.MangoPage {} }
    Component { id: audioComp; Pages.AudioPage {} }
    Component { id: appsComp; Pages.AppsPage {} }
    Component { id: barComp; Pages.TopBarPage {} }
    Component { id: vitalsComp; Pages.VitalsPage {} }
    Component { id: workspacesComp; Pages.WorkspacesPage {} }
    Component { id: calendarComp; Pages.CalendarPage {} }
    Component { id: notifComp; Pages.NotificationsPage {} }
    Component { id: searchComp; Pages.SearchPage {} }
    Component { id: weatherComp; Pages.WeatherPage {} }
}
