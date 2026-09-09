pragma ComponentBehavior: Bound

import QtQuick
import "../themes"

Item {
    id: root
    visible: false

    required property string moduleId
    property string barPos: "top"
    property real panelWidth: 380
    property real panelHeight: 400
    property real screenWidth: 0
    property real screenHeight: 0
    property real gap: 0
    property real margin: 12
    property real fallbackX: 0
    property real fallbackY: 0

    readonly property var anchor: Theme.barAnchor(moduleId)
    readonly property bool valid: anchor !== null
    readonly property real cx: valid ? anchor.x + anchor.w / 2 : fallbackX + panelWidth / 2
    readonly property real cy: valid ? anchor.y + anchor.h / 2 : fallbackY + panelHeight / 2
    readonly property bool isVertical: barPos === "left" || barPos === "right"

    readonly property var winRect: Theme.barWindowRect
    readonly property real barExcl: (isVertical ? Theme.barEffectiveWidth : Theme.barEffectiveHeight) + Theme.barTopDistance
    readonly property real fullW: screenWidth + (isVertical ? barExcl : 0)
    readonly property real fullH: screenHeight + (isVertical ? 0 : barExcl)
    readonly property real winEdge: {
        try {
            let r = winRect
            if (r && r.w > 0 && r.h > 0) {
                if (barPos === "bottom") return fullH - r.y
                if (barPos === "left") return r.x + r.w
                if (barPos === "right") return fullW - r.x
                return r.y + r.h
            }
        } catch (e) { }
        let base = isVertical ? Theme.barEffectiveWidth : Theme.barEffectiveHeight
        return base + Theme.barTopDistance
    }
    readonly property real edgeOffset: winEdge + gap - Theme.barTopDistance

    readonly property real panelX: {
        if (barPos === "left") return edgeOffset
        if (barPos === "right") return screenWidth - panelWidth - edgeOffset
        if (!valid) return fallbackX
        return Math.max(margin, Math.min(cx - panelWidth / 2, screenWidth - panelWidth - margin))
    }
    readonly property real panelY: {
        if (isVertical) {
            if (!valid) return fallbackY
            return Math.max(margin, Math.min(cy - panelHeight / 2, screenHeight - panelHeight - margin))
        }
        if (barPos === "bottom") return screenHeight - panelHeight - edgeOffset
        return edgeOffset
    }

    readonly property int origin: {
        if (isVertical) {
            let third = screenHeight / 3
            let topZone = cy < third
            let bottomZone = cy > screenHeight - third
            if (barPos === "left") return topZone ? Item.TopLeft : bottomZone ? Item.BottomLeft : Item.Left
            return topZone ? Item.TopRight : bottomZone ? Item.BottomRight : Item.Right
        }
        let third = screenWidth / 3
        let bottom = barPos === "bottom"
        if (cx < third) return bottom ? Item.BottomLeft : Item.TopLeft
        if (cx > screenWidth - third) return bottom ? Item.BottomRight : Item.TopRight
        return bottom ? Item.Bottom : Item.Top
    }

    readonly property real slideFromX: barPos === "left" ? -Theme.panelSlideOffset : barPos === "right" ? Theme.panelSlideOffset : 0
    readonly property real slideFromY: barPos === "top" ? -Theme.panelSlideOffset : barPos === "bottom" ? Theme.panelSlideOffset : 0
}
