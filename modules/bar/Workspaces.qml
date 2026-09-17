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

    // Repeater werden über die konstante Länge modelliert und binden ihre
    // Inhalte über diesen Zugriff: Inhaltsänderungen (Fokus/Belegung) ändern
    // dann nur Bindings, der Repeater zerstört keine Delegates mehr — nur so
    // können die Behavior-Animationen überhaupt abspielen.
    function workspaceAt(index: int): var {
        const items = visibleWorkspaces
        return (index >= 0 && index < items.length) ? items[index] : null
    }

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
            out.push({ id: i, name: "" + i, focused: focused, active: focused, occupied: false, clients: 0, shown: true })
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
            // PERF/UX: im Dynamic-Mode bleiben verborgene Tags im Modell, aber
            // kollabieren animiert (reveal) statt sofort zerstört zu werden.
            visible.push({
                id: tag.index,
                name: "" + tag.index,
                focused: !!tag.active,
                active: !!tag.active,
                occupied: (tag.clients || 0) > 0,
                clients: tag.clients || 0,
                shown: !dynamicMode || isTagVisible(tag)
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
        const dist = Math.abs(index - hoveredIndex)
        if (dist === 0)
            return 1.08
        return dist === 1 ? 1.03 : 1.0
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
            if (ch.reveal !== undefined && ch.reveal < 0.5)
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

        // Dynamic-Mode: verborgene Tags kollabieren animiert (reveal 0) statt
        // sofort zu verschwinden; sichtbare expandieren mit Overshoot.
        readonly property bool shown: workspace ? workspace.shown !== false : true
        // ready erzwingt beim Erzeugen einen Lauf von 0 -> 1 (Entry-Cascade).
        property bool ready: false
        property real reveal: ready && shown ? 1 : 0
        property bool pressed: false

        Component.onCompleted: ready = true
        onShownChanged: if (!shown) root.leaveWorkspace(delegateIndex)

        // M3-Pille: Länge hängt vom Zustand ab, Orientierung dreht nur die Achse.
        // Leer (8 -> 10) = Kreis: Breite entspricht der Dicke.
        readonly property real pillLength: ((root.isM3 ? (focused ? 28 : occupied ? 14 : 10) + 2 : 20)) * root.uiScale
        readonly property real pillThickness: 10 * root.uiScale

        // Abstand steckt in der Delegate-Breite (Layout-spacing = 0), damit
        // kollabierte Tags auch ihren Zwischenraum animiert freigeben.
        readonly property real baseWidth: isVertical ? 24 * root.uiScale : pillLength + (root.isDefault2 ? 0 : 2 * Theme.workspaceSpacing) * root.uiScale
        readonly property real baseHeight: isVertical ? pillLength + (root.isDefault2 ? 0 : 2 * Theme.workspaceSpacing) * root.uiScale : 24 * root.uiScale

        implicitWidth: baseWidth * reveal
        implicitHeight: baseHeight * reveal

        readonly property real revealScale: 0.35 + 0.65 * reveal

        opacity: (root.isM3 ? 1.0 : (occupied || focused ? 1.0 : 0.5)) * reveal
        scale: root.hoverScaleFor(delegateIndex) * revealScale * (pressed ? Theme.pressScale : 1)

        // Caelestia workspace motion: focus/hover fades ride the effects
        // curve, hover scale the fast-spatial curve, and siblings glide when
        // the row reflows (ActiveIndicator trailing-pill equivalent).
        Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultEffects } }
        Behavior on scale { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
        Behavior on x { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial } }
        Behavior on y { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial } }
        Behavior on implicitWidth { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial } }
        Behavior on implicitHeight { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durDefaultSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDefaultSpatial } }

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
            visible: root.isDefault2
            opacity: ((delegate.focused || root.hoveredIndex === delegate.delegateIndex) ? 1 : 0) * delegate.reveal
            Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastEffects } }
            Behavior on color { enabled: Theme.animationsEnabled; ColorAnimation { duration: Theme.durSlowEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSlowEffects } }
        }

        Text {
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
            anchors.centerIn: parent
            text: delegate.workspace ? delegate.workspace.name : ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(14) * root.uiScale
            font.weight: root.isDefault2 ? ((delegate.focused || root.hoveredIndex === delegate.delegateIndex) ? Theme.barTextWeightEmphasis : Theme.barTextWeight) : Theme.barTextWeight
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
            id: hLine
            antialiasing: Theme.shapesAa
            visible: root.isDefault2 && !delegate.isVertical
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2 * root.uiScale
            y: parent.height - height - 2 + (Theme.barThickness - 24 * root.uiScale) / 2
            color: Theme.accent
            opacity: delegate.focused ? 1 : 0
            transform: Scale {
                origin.x: hLine.width / 2
                origin.y: hLine.height / 2
                xScale: delegate.focused ? 1 : 0.3
                Behavior on xScale { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
            }
            Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastEffects } }
        }
        Rectangle {
            id: vLine
            antialiasing: Theme.shapesAa
            visible: root.isDefault2 && delegate.isVertical
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 2 * root.uiScale
            x: Theme.barPosition === "right" ? parent.width - width - 2 + (Theme.barThickness - 24 * root.uiScale) / 2 : 2 - (Theme.barThickness - 24 * root.uiScale) / 2
            color: Theme.accent
            opacity: delegate.focused ? 1 : 0
            transform: Scale {
                origin.x: vLine.width / 2
                origin.y: vLine.height / 2
                yScale: delegate.focused ? 1 : 0.3
                Behavior on yScale { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastSpatial } }
            }
            Behavior on opacity { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durFastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveFastEffects } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            z: 10
            onEntered: root.enterWorkspace(delegate.delegateIndex)
            onExited: root.leaveWorkspace(delegate.delegateIndex)
            onPressed: delegate.pressed = true
            onReleased: delegate.pressed = false
            onCanceled: delegate.pressed = false
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
        spacing: 0
        Repeater {
            // PERF: inaktive Orientierung ohne Delegates (keine doppelte Bindung).
            // Länge statt Array: Inhaltsänderungen erzeugen keine neuen Delegates.
            model: root.vertical ? 0 : root.visibleWorkspaces.length
            delegate: WorkspaceDelegate {
                required property int index
                workspace: root.workspaceAt(index)
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
        spacing: 0
        Repeater {
            model: root.vertical ? root.visibleWorkspaces.length : 0
            delegate: WorkspaceDelegate {
                required property int index
                workspace: root.workspaceAt(index)
                delegateIndex: index
                isVertical: true
            }
        }
        EmptyPlaceholder {
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
