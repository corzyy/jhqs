pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../themes"
import "../../services"

Item {
    id: root

    // Kompatibilität: wird von außen gesetzt, Anzeige folgt aber bewusst
    // dem fokussierten Monitor (Single-Bar spiegelt den aktiven Screen).
    property var monitor: null
    property bool vertical: false

    implicitWidth: vertical ? 24 : hRow.implicitWidth
    implicitHeight: vertical ? vCol.implicitHeight : hRow.implicitHeight

    // --- Monitor-Auflösung (Single Responsibility: nur Fallback-Kette) ---
    readonly property string screenName: resolveScreenName()

    function resolveScreenName(): string {
        try {
            const focused = MangoService.focusedMonitor
            if (focused && ("" + focused).length > 0)
                return "" + focused
        } catch (e) {}
        try {
            if (monitor && monitor.name)
                return "" + monitor.name
            if (typeof monitor === "string" && ("" + monitor).length > 0)
                return "" + monitor
        } catch (e) {}
        try {
            return Theme.primaryScreenName
        } catch (e) {
            return "DP-1"
        }
    }

    // --- Workspace-Modell ---
    readonly property bool useMango: MangoService.isMango
    readonly property var visibleWorkspaces: collectWorkspaces()
    // Kompatibilitäts-Alias (intern/extern bislang als sortedWorkspaces gelesen).
    readonly property var sortedWorkspaces: visibleWorkspaces

    function collectWorkspaces(): var {
        if (!useMango)
            return []
        try {
            let tags = []
            try {
                tags = MangoService.tagsFor(root.screenName)
            } catch (e) {
                tags = MangoService.tags
            }
            if (!tags || tags.length === 0)
                return fallbackTags()
            return filterVisibleTags(tags)
        } catch (e) {
            return []
        }
    }

    // Fallback, solange der erste mmsg-Poll noch läuft: feste Tag-Anzahl,
    // damit die Bar nie leer bleibt.
    function fallbackTags(): var {
        let count = 10
        try {
            count = MangoService.tagCountFor(root.screenName) || MangoService.tagCount || 10
        } catch (e) {}
        count = Math.max(1, Math.min(20, count))
        const guessed = guessActiveTag()
        const out = []
        for (let i = 1; i <= count; i++) {
            const focused = i === guessed
            out.push({ id: i, name: "" + i, focused: focused, active: focused, occupied: false, clients: 0 })
        }
        return out
    }

    function guessActiveTag(): int {
        try {
            for (const tag of (MangoService.tags || [])) {
                if (tag && tag.active)
                    return tag.index
            }
        } catch (e) {}
        return 1
    }

    // Dynamik-Modus: nur aktive / dringende / belegte / gepinnte Tags zeigen.
    function filterVisibleTags(tags: var): var {
        let dynamicMode = false
        try {
            dynamicMode = MangoService.mangoDynamicTags
        } catch (e) {}
        const visible = []
        for (let i = 0; i < tags.length; i++) {
            const tag = tags[i]
            if (dynamicMode && !isTagVisible(tag))
                continue
            visible.push({
                id: tag.index,
                name: "" + tag.index,
                focused: !!tag.active,
                active: !!tag.active,
                occupied: (tag.clients || 0) > 0,
                clients: tag.clients || 0
            })
        }
        visible.sort((a, b) => a.id - b.id)
        return visible
    }

    function isTagVisible(tag: var): bool {
        if (!tag)
            return false
        if (!!tag.active || !!tag.urgent || (tag.clients || 0) > 0)
            return true
        try {
            return MangoService.isPinned(tag.index)
        } catch (e) {
            return false
        }
    }

    // --- Stil / Hover ---
    readonly property bool isM3: Theme.workspaceStyle === "m3"
    readonly property bool isDefault2: Theme.workspaceStyle === "default2"
    readonly property real uiScale: Theme.workspaceScale
    readonly property bool hoverAnimations: Theme.animationsEnabled && !isDefault2

    property int hoveredIndex: -1

    function hoverScaleFor(index: int): real {
        if (!hoverAnimations || hoveredIndex < 0)
            return 1.0
        return index === hoveredIndex ? 1.08 : 1.0
    }

    function enterWorkspace(index: int): void {
        hoveredIndex = index
    }

    function leaveWorkspace(index: int): void {
        if (hoveredIndex === index)
            hoveredIndex = -1
    }

    function activateWorkspace(workspace: var): void {
        if (!workspace)
            return
        MangoService.activateTag(workspace.id, root.screenName)
    }

    // --- Koordinaten-API (Kompatibilität für BarModule.qml) ---
    // BarModule leitet Bar-Hover/Klicks als (px,py) weiter; intern arbeiten
    // wir index-basiert (s. enterWorkspace/activateWorkspace oben).
    // Ein einziger Hit-Test statt 2x kopierter Schleifen.
    function pickDelegateAt(px: real, py: real): var {
        const container = root.vertical ? vCol : hRow
        for (let i = 0; i < container.children.length; i++) {
            const ch = container.children[i]
            if (!ch || ch.workspace === undefined || ch.delegateIndex === undefined || !ch.visible)
                continue
            const lp = ch.mapFromItem(root, px, py)
            if (lp.x >= 0 && lp.x <= ch.width && lp.y >= 0 && lp.y <= ch.height)
                return ch
        }
        return null
    }

    function setHoverAt(px: real, py: real): void {
        const hit = pickDelegateAt(px, py)
        hoveredIndex = hit ? hit.delegateIndex : -1
    }

    function clearHover(): void {
        hoveredIndex = -1
    }

    function activateAt(px: real, py: real): bool {
        const hit = pickDelegateAt(px, py)
        if (!hit)
            return false
        activateWorkspace(hit.workspace)
        return true
    }

    function cycleWorkspace(down: bool): void {
        if (down)
            MangoService.prevTag(root.screenName)
        else
            MangoService.nextTag(root.screenName)
    }

    // --- Geteilter Delegate (eine Quelle für horizontal + vertikal) ---
    component WorkspaceDelegate: Item {
        id: delegate

        required property var workspace
        required property int delegateIndex
        required property bool isVertical

        readonly property bool occupied: {
            const ws = workspace
            if (!ws)
                return false
            if (ws.occupied !== undefined)
                return !!ws.occupied
            return (ws.clients || 0) > 0
        }
        readonly property bool focused: workspace ? !!workspace.focused : false

        implicitWidth: isVertical ? 24 * root.uiScale : pillLength + (root.isDefault2 ? 0 : Theme.workspaceSpacing) * root.uiScale
        implicitHeight: isVertical ? pillLength + (root.isDefault2 ? 0 : Theme.workspaceSpacing) * root.uiScale : 24 * root.uiScale

        // M3-Pille: Länge hängt vom Zustand ab, Orientierung dreht nur die Achse.
        readonly property real pillLength: ((root.isM3 ? (focused ? 28 : occupied ? 14 : 8) + 2 : 20)) * root.uiScale
        readonly property real pillThickness: 10 * root.uiScale

        opacity: root.isM3 ? 1.0 : (occupied || focused ? 1.0 : 0.5)
        scale: root.hoverScaleFor(delegateIndex)

        // Caelestia workspace motion: focus/hover fades ride the effects
        // curve, hover scale the fast-spatial curve, and siblings glide when
        // the row reflows (ActiveIndicator trailing-pill equivalent).
        Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects } }
        Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
        Behavior on x { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial } }
        Behavior on y { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial } }

        // M3-Indikator (Pille)
        Rectangle {
            antialiasing: Theme.shapesAa
            anchors.centerIn: parent
            visible: root.isM3
            width: delegate.isVertical ? delegate.pillThickness : delegate.pillLength - 2 * root.uiScale
            height: delegate.isVertical ? delegate.pillLength - 2 * root.uiScale : delegate.pillThickness
            radius: (delegate.isVertical ? width : height) / 2
            color: delegate.focused ? Theme.accent : delegate.occupied ? Theme.textSecondary : Theme.divider
            // Pille morphs length + tint when focus/occupancy changes.
            Behavior on width { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial } }
            Behavior on height { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial } }
            Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: Theme.durSlowEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSlowEffects } }
        }

        // Klassischer Fokus-Punkt (alle Stile außer m3 / default2)
        Rectangle {
            antialiasing: Theme.shapesAa
            anchors.centerIn: parent
            width: 13 * root.uiScale
            height: 13 * root.uiScale
            radius: Math.max(2, Math.min(6.5, Theme.cornerRadius))
            color: Theme.textPrimary
            visible: !root.isM3 && !root.isDefault2
            opacity: delegate.focused ? 1 : 0
            scale: delegate.focused ? 1.1 : 0.6
            Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects } }
            Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
        }

        // default2-Hover/Selektionsfläche (Ränder je nach Orientierung)
        Rectangle {
            antialiasing: Theme.shapesAa
            anchors.fill: parent
            anchors.topMargin: delegate.isVertical ? 0 : -(Theme.barThickness - 24 * root.uiScale) / 2
            anchors.bottomMargin: delegate.isVertical ? 0 : -(Theme.barThickness - 24 * root.uiScale) / 2
            anchors.leftMargin: delegate.isVertical ? -(Theme.barThickness - 24 * root.uiScale) / 2 : 0
            anchors.rightMargin: delegate.isVertical ? -(Theme.barThickness - 24 * root.uiScale) / 2 : 0
            color: delegate.focused ? Theme.bgSelected : Theme.bgHover
            border.color: Theme.divider
            border.width: 1
            visible: root.isDefault2 && (delegate.focused || root.hoveredIndex === delegate.delegateIndex)
            opacity: (delegate.focused || root.hoveredIndex === delegate.delegateIndex) ? 1 : 0
        }

        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            anchors.centerIn: parent
            text: delegate.workspace ? delegate.workspace.name : ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(14) * root.uiScale
            font.weight: (root.isDefault2 ? (delegate.focused || root.hoveredIndex === delegate.delegateIndex) : Theme.textBold) ? Font.Medium : Font.Normal
            color: root.hoveredIndex === delegate.delegateIndex ? Theme.primary : (root.isDefault2 ? (delegate.focused ? Theme.accent : Theme.textPrimary) : Theme.textPrimary)
            visible: !root.isM3
            opacity: root.isDefault2 ? 1 : (delegate.focused ? 0 : 1)
            scale: root.isDefault2 ? 1.0 : (delegate.focused ? 0.7 : 1.0)
            Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects } }
            Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
            Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: Theme.durSlowEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSlowEffects } }
        }

        // default2-Unterstrich (horizontal) bzw. Seitenstrich (vertikal)
        Rectangle {
            antialiasing: Theme.shapesAa
            visible: root.isDefault2 && !delegate.isVertical
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2 * root.uiScale
            y: parent.height - height - 2 + (Theme.barThickness - 24 * root.uiScale) / 2
            color: Theme.accent
            opacity: delegate.focused ? 1 : 0
        }
        Rectangle {
            antialiasing: Theme.shapesAa
            visible: root.isDefault2 && delegate.isVertical
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 2 * root.uiScale
            x: Theme.barPosition === "right" ? parent.width - width - 2 + (Theme.barThickness - 24 * root.uiScale) / 2 : 2 - (Theme.barThickness - 24 * root.uiScale) / 2
            color: Theme.accent
            opacity: delegate.focused ? 1 : 0
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            z: 10
            onEntered: root.enterWorkspace(delegate.delegateIndex)
            onExited: root.leaveWorkspace(delegate.delegateIndex)
            onClicked: mouse => {
                mouse.accepted = true
                root.activateWorkspace(delegate.workspace)
            }
            onWheel: wheel => {
                root.cycleWorkspace(wheel.angleDelta.y > 0)
                wheel.accepted = true
            }
        }
    }

    component EmptyPlaceholder: Text {
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
        text: "—"
        color: Theme.textPrimary
        font.pixelSize: Theme.fs(13)
        visible: root.visibleWorkspaces.length === 0
        opacity: visible ? 1 : 0
    }

    RowLayout {
        id: hRow
        anchors.centerIn: parent
        visible: !root.vertical
        spacing: root.isDefault2 ? 0 : Theme.workspaceSpacing
        Repeater {
            // PERF: inaktive Orientierung ohne Delegates (keine doppelte Bindung).
            model: root.vertical ? [] : root.visibleWorkspaces
            delegate: WorkspaceDelegate {
                required property var modelData
                required property int index
                workspace: modelData
                delegateIndex: index
                isVertical: false
            }
        }
        EmptyPlaceholder {}
    }

    ColumnLayout {
        id: vCol
        anchors.centerIn: parent
        visible: root.vertical
        spacing: root.isDefault2 ? 0 : Theme.workspaceSpacing
        Repeater {
            model: root.vertical ? root.visibleWorkspaces : []
            delegate: WorkspaceDelegate {
                required property var modelData
                required property int index
                workspace: modelData
                delegateIndex: index
                isVertical: true
            }
        }
        EmptyPlaceholder {
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
