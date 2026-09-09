pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../themes"
import Quickshell.Widgets
import Quickshell.Services.Notifications

Item {
    id: delegateRoot
    required property var modelData
    property real listWidth: 340
    property var n: null
    width: listWidth
    readonly property bool isMinimal: Theme.minimalTheme
    readonly property bool singleLineToast: cachedBody.length === 0
    property real cachedDelegateHeight: 0
    height: isDismissing ? cachedDelegateHeight : childrenRect.height
    clip: true

    property int timeoutMs: 5000
    readonly property int slideDir: {
        try { let p = Theme.notifPosition; return (p === "top-left" || p === "bottom-left") ? -1 : 1 } catch(e) { return 1 }
    }
    property int cachedUrgency: 1
    property string cachedSummary: ""
    property string cachedBody: ""
    property string cachedAppName: "Notification"
    property string cachedAppIcon: ""
    property string cachedImage: ""
    property var cachedActions: []
    property bool cachedHasInlineReply: false
    property string cachedInlinePlaceholder: ""
    property bool cachedResident: false
    Component.onCompleted: {
        try {
            n = modelData
            try { exitDir = slideDir } catch(e2) { }
            let t = n ? n.expireTimeout : -1
            let u = n ? n.urgency : NotificationUrgency.Normal
            cachedUrgency = u
            if (t > 0) {
                if (t >= 100) timeoutMs = t
                else timeoutMs = Math.round(t * 1000)
            } else if (t === 0) timeoutMs = 0
            else {
                if (u === NotificationUrgency.Critical) timeoutMs = 0
                else {
                    let dflt = 5000
                    try { dflt = Math.max(0, Math.min(30, Math.round(Theme.notifTimeout))) * 1000 } catch(e) { }
                    timeoutMs = dflt
                }
            }
            cachedSummary = n && n.summary ? n.summary : ""
            cachedBody = n && n.body ? n.body : ""
            cachedAppName = n && n.appName ? n.appName : "Notification"
            cachedAppIcon = n && n.appIcon ? n.appIcon : ""
            cachedImage = n && n.image ? n.image : ""
            cachedActions = n && n.actions ? n.actions : []
            cachedHasInlineReply = n ? n.hasInlineReply : false
            cachedInlinePlaceholder = n ? n.inlineReplyPlaceholder : ""
            cachedResident = n ? n.resident : false
            if (timeoutMs > 0) { progressAnim.duration = timeoutMs; progressAnim.start() }
            Qt.callLater(() => { try { cachedDelegateHeight = childrenRect.height } catch(e) { } })
        } catch(e) { }
    }
    property int stackIndex: 0
    property int stackCount: 1
    readonly property bool isBottom: {
        try { let p = Theme.notifPosition; return p === "bottom-left" || p === "bottom-center" || p === "bottom-right" } catch(e) { return false }
    }
    property bool entered: false
    property bool leaving: false
    property int exitDir: 1
    readonly property real targetOpacity: leaving ? 0 : entered ? 1 : 0
    readonly property real targetScale: leaving ? 0.94 : entered ? 1.0 : 0.92
    readonly property real baseSlideX: leaving ? 56 * exitDir : entered ? 0 : 32 * slideDir
    readonly property real baseSlideY: leaving ? 0 : entered ? 0 : (isBottom ? 14 : -14)
    readonly property real dragFade: {
        let d = Math.abs(dragProxy.x)
        if (d <= 0.5) return 1.0
        return Math.max(0.35, 1.0 - (d / Math.max(1, delegateRoot.width)) * 0.9)
    }
    property bool isDismissing: false
    onIsDismissingChanged: {
        try { progressAnim.stop() } catch(e) { }
        if (isDismissing && cachedDelegateHeight === 0) {
            try { cachedDelegateHeight = childrenRect.height } catch(e) { }
        }
    }
    Behavior on cachedDelegateHeight {
        NumberAnimation { duration: Theme.panelAnimCollapse; easing.type: Theme.easingSmooth }
    }
    Timer {
        id: enterTimer
        repeat: false
        onTriggered: delegateRoot.entered = true
    }
    function armEntrance(): void {
        let d = 0
        try { d = Math.max(0, delegateRoot.stackIndex) * Theme.animStagger } catch(e) { d = 0 }
        if (!Theme.animationsEnabled) { delegateRoot.entered = true; return }
        enterTimer.interval = d
        enterTimer.restart()
    }
    function requestDismiss(toExpire: bool, dir: int): void {
        if (delegateRoot.isDismissing || delegateRoot.leaving) return
        delegateRoot.exitDir = (dir === -1 || dir === 1) ? dir : delegateRoot.slideDir
        delegateRoot.leaving = true
        delegateRoot.isDismissing = true
        collapseTimer.toExpire = !!toExpire
        let wait = 0
        try { wait = Theme.animationsEnabled ? Theme.panelAnimExit + 20 : 0 } catch(e) { wait = 0 }
        collapseTimer.interval = wait
        collapseTimer.restart()
    }
    Timer {
        id: collapseTimer
        repeat: false
        property bool toExpire: false
        onTriggered: {
            try { delegateRoot.cachedDelegateHeight = 0 } catch(e) { }
            finishTimer.toExpire = toExpire
            let wait = 0
            try { wait = Theme.animationsEnabled ? Theme.panelAnimCollapse + 30 : 0 } catch(e) { wait = 0 }
            finishTimer.interval = wait
            finishTimer.restart()
        }
    }
    Timer {
        id: finishTimer
        repeat: false
        property bool toExpire: false
        onTriggered: delegateRoot.safeClose(toExpire)
    }
    property real progress: 0

    function safeClose(expire) {
        if (!delegateRoot.n) return
        try {
            if (!delegateRoot.n.tracked) return
        } catch(e) { return }
        try {
            if (expire) delegateRoot.n.expire()
            else delegateRoot.n.dismiss()
        } catch(e) { }
    }

    Item {
        id: dragProxy
        x: 0
        y: 0
        Behavior on x {
            enabled: !bgMouse.drag.active
            NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingStandard }
        }
    }

    Rectangle {
        antialiasing: Theme.shapesAa
        id: card
        width: parent.width
        property real cachedHeight: 0
        readonly property bool isCritical: delegateRoot.cachedUrgency === NotificationUrgency.Critical
        readonly property bool isMinimal: Theme.minimalTheme
        implicitHeight: delegateRoot.isDismissing && cachedHeight > 0 ? cachedHeight : inner.implicitHeight + 26
        color: isCritical ? Theme.error_container : (isMinimal ? Theme.bg : Theme.panelBg)
        Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
        Connections {
            target: delegateRoot
            function onIsDismissingChanged() {
                if (delegateRoot.isDismissing && card.cachedHeight === 0) {
                    try { card.cachedHeight = inner.implicitHeight + 26 } catch(e) { }
                }
            }
        }
        border.color: isCritical ? Theme.errorColor : (card.isMinimal ? Theme.accent : Theme.panelBorderColor)
        border.width: card.isMinimal || isCritical ? 2 : 1
        radius: card.isMinimal ? 0 : Theme.cornerRadius
        clip: true
        scale: entranceScale
        opacity: delegateRoot.targetOpacity * delegateRoot.dragFade
        transformOrigin: delegateRoot.slideDir < 0 ? Item.Left : Item.Right
        Behavior on opacity {
            enabled: !bgMouse.drag.active
            NumberAnimation {
                duration: delegateRoot.leaving ? Theme.panelAnimExit : Theme.panelAnimFade
                easing.type: delegateRoot.leaving ? Theme.panelEasingExit : Theme.panelEasingFade
            }
        }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }

        property real entranceScale: 0.92
        readonly property real slideX: baseSlideX + dragProxy.x
        property real baseSlideX: delegateRoot.baseSlideX
        property real baseSlideY: delegateRoot.baseSlideY
        Behavior on baseSlideX {
            NumberAnimation {
                duration: delegateRoot.leaving ? Theme.panelAnimExit : Theme.panelAnimSlide
                easing.type: Theme.easingBezier
                easing.bezierCurve: delegateRoot.leaving ? Theme.curveEmphasizedAccelerate : Theme.curveEmphasizedDecelerate
            }
        }
        Behavior on baseSlideY {
            NumberAnimation {
                duration: delegateRoot.leaving ? Theme.panelAnimExit : Theme.panelAnimSlide
                easing.type: Theme.easingBezier
                easing.bezierCurve: delegateRoot.leaving ? Theme.curveEmphasizedAccelerate : Theme.curveEmphasizedDecelerate
            }
        }
        Behavior on entranceScale {
            NumberAnimation {
                duration: delegateRoot.leaving ? Theme.panelAnimExit : Theme.panelAnimScale
                easing.type: delegateRoot.leaving ? Theme.panelEasingExit : Theme.panelEasingScale
                easing.overshoot: delegateRoot.leaving ? 0 : Theme.panelOvershootScale
            }
        }
        Binding { target: card; property: "entranceScale"; value: delegateRoot.targetScale }
        transform: Translate { x: card.slideX; y: card.baseSlideY }

        HoverHandler { id: hover }
        property bool isHovered: hover.hovered
        onIsHoveredChanged: {
            if (card.isHovered) { if (progressAnim.running) progressAnim.pause() }
            else if (progressAnim.paused && !delegateRoot.isDismissing && !bgMouse.drag.active) progressAnim.resume()
        }

        NumberAnimation {
            id: progressAnim
            target: delegateRoot
            property: "progress"
            from: 0
            to: 1
            easing.type: Easing.Linear
            onFinished: delegateRoot.requestDismiss(true, delegateRoot.slideDir)
        }

        Component.onCompleted: {
            delegateRoot.armEntrance()
            Qt.callLater(() => { try { cachedHeight = inner.implicitHeight + 26 } catch(e) { } })
        }

        ColumnLayout {
            id: inner
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: delegateRoot.isMinimal && delegateRoot.singleLineToast ? 7 : 10
            anchors.bottomMargin: delegateRoot.isMinimal && delegateRoot.singleLineToast ? 7 : (delegateRoot.isMinimal ? 10 : 12)
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Item {
                    id: iconSlot
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    visible: slotSource !== "" || iconFailed
                    readonly property string slotSource: {
                        if (delegateRoot.cachedImage !== "") return delegateRoot.cachedImage
                        let ic = delegateRoot.cachedAppIcon
                        if (!ic || ic === "") return ""
                        if (ic.startsWith("/") || ic.startsWith("file://") || ic.startsWith("image://")) return ic
                        if (Quickshell.hasThemeIcon(ic)) return Quickshell.iconPath(ic)
                        let lc = ic.toLowerCase()
                        if (Quickshell.hasThemeIcon(lc)) return Quickshell.iconPath(lc)
                        return Quickshell.iconPath(ic)
                    }
                    property bool iconFailed: false
                    onSlotSourceChanged: iconFailed = false
                    Image {
                        anchors.fill: parent
                        source: iconSlot.slotSource
                        sourceSize.width: 80
                        sourceSize.height: 80
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        visible: !iconSlot.iconFailed && iconSlot.slotSource !== ""
                        onStatusChanged: if (status === Image.Error) iconSlot.iconFailed = true
                    }
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        anchors.centerIn: parent
                        visible: iconSlot.iconFailed
                        text: (delegateRoot.cachedAppName || "?").charAt(0).toUpperCase()
                        color: card.isCritical ? Theme.on_error_container : Theme.textPrimary
                        font.family: delegateRoot.isMinimal ? Theme.iconFontFamily : Theme.fontFamily
                        font.pixelSize: Theme.fs(16)
                        font.weight: Font.Medium
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 10
                    spacing: 2
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        visible: delegateRoot.cachedSummary.length > 0
                        Layout.fillWidth: true
                        text: delegateRoot.cachedSummary
                        color: card.isCritical ? Theme.on_error_container : Theme.textPrimary
                        font.family: delegateRoot.isMinimal ? Theme.iconFontFamily : Theme.fontFamily
                        font.pixelSize: Theme.fs(14)
                        font.weight: Font.Bold
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        id: bodyText
                        Layout.fillWidth: true
                        visible: delegateRoot.cachedBody.length > 0
                        text: delegateRoot.cachedBody
                        color: card.isCritical ? Theme.withAlpha(Theme.on_error_container, 0.85) : Theme.textSecondary
                        font.family: delegateRoot.isMinimal ? Theme.iconFontFamily : Theme.fontFamily
                        font.pixelSize: Theme.fs(14)
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        textFormat: {
                            let b = delegateRoot.cachedBody
                            if (!b || b.length === 0) return Text.PlainText
                            if (b.includes("<") && b.includes(">")) return Text.RichText
                            return Text.PlainText
                        }
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: delegateRoot.cachedActions.length > 0

                Repeater {
                    model: delegateRoot.cachedActions
                    delegate: Rectangle {
                        id: actBtn
                        required property var modelData
                        property var act: modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        color: card.isCritical ? Theme.withAlpha(Theme.on_error_container, actMouse.containsMouse ? 0.28 : 0.18)
                                              : actMouse.containsMouse ? Theme.withAlpha(Theme.textPrimary, 0.14) : Theme.withAlpha(Theme.textPrimary, 0.08)
                        border.color: Theme.divider
                        border.width: 1
                        radius: Theme.cornerRadiusSmall
                        scale: Theme.animationsEnabled && actMouse.pressed ? Theme.pressScale : (actMouse.containsMouse ? 1.02 : 1.0)
                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }
                        Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }

                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            anchors.centerIn: parent
                            text: actBtn.act ? actBtn.act.text : ""
                            color: card.isCritical ? Theme.on_error_container : Theme.textPrimary
                            font.family: delegateRoot.isMinimal ? Theme.iconFontFamily : Theme.fontFamily
                            font.pixelSize: Theme.fs(11)
                            font.weight: Font.Medium
                            elide: Text.ElideMiddle
                            width: parent.width - 16
                            horizontalAlignment: Text.AlignHCenter
                        }
                        MouseArea {
                            id: actMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                try {
                                    if (actBtn.act) actBtn.act.invoke()
                                } catch(e) { console.error(e) }
                                if (!delegateRoot.cachedResident) {
                                    delegateRoot.requestDismiss(false, delegateRoot.slideDir)
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                visible: delegateRoot.cachedHasInlineReply
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    antialiasing: Theme.shapesAa
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    color: card.isCritical ? Theme.withAlpha(Theme.on_error_container, 0.12) : Theme.withAlpha(Theme.textPrimary, 0.08)
                    border.color: replyInput.activeFocus ? (card.isCritical ? Theme.on_error_container : Theme.accent) : Theme.divider
                    border.width: 1
                    radius: Theme.cornerRadiusSmall
                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.easingBezier; easing.bezierCurve: Theme.curveEmphasized } }

                    TextInput {
                        id: replyInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: Text.AlignVCenter
                        color: card.isCritical ? Theme.on_error_container : Theme.textPrimary
                        font.family: delegateRoot.isMinimal ? Theme.iconFontFamily : Theme.fontFamily
                        font.pixelSize: Theme.fs(12)
                        clip: true
                        selectByMouse: true
                        property string placeholder: delegateRoot.cachedInlinePlaceholder
                        Keys.onReturnPressed: {
                            if (text.length > 0 && delegateRoot.n) {
                                try { delegateRoot.n.sendInlineReply(text) } catch(e) { }
                                delegateRoot.requestDismiss(false, delegateRoot.slideDir)
                            }
                        }
                    }
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: replyInput.placeholder.length > 0 ? replyInput.placeholder : "Antworten…"
                        color: card.isCritical ? Theme.withAlpha(Theme.on_error_container, 0.7) : Theme.textMuted
                        font.family: delegateRoot.isMinimal ? Theme.iconFontFamily : Theme.fontFamily
                        font.pixelSize: Theme.fs(12)
                        visible: replyInput.text.length === 0 && !replyInput.activeFocus
                    }
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: Theme.cornerRadiusSmall
                    color: card.isCritical ? Theme.on_error_container : Theme.textPrimary
                    scale: Theme.animationsEnabled && sendMa.pressed ? Theme.pressScale : (sendMa.containsMouse ? Theme.iconPopScale : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animBounce; easing.type: Theme.easingBounce; easing.overshoot: Theme.hoverOvershoot } }
                    Text {
                        antialiasing: Theme.textAa
                        renderType: Theme.textRenderType
                        anchors.centerIn: parent
                        text: "↩"
                        color: card.isCritical ? Theme.error_container : Theme.bg
                        font.pixelSize: Theme.fs(14)
                    }
                    MouseArea {
                        id: sendMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (replyInput.text.length > 0 && delegateRoot.n) {
                                try { delegateRoot.n.sendInlineReply(replyInput.text) } catch(e) { }
                                delegateRoot.requestDismiss(false, delegateRoot.slideDir)
                            }
                        }
                    }
                }
            }
        }

        Item {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 3
            anchors.rightMargin: 3
            width: 18
            height: 18
            visible: opacity > 0
            opacity: card.isHovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
            Text {
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
                anchors.centerIn: parent
                text: "✕"
                color: hoverCloseMa.containsMouse ? (card.isCritical ? Theme.on_error_container : Theme.textPrimary) : Theme.textMuted
                font.pixelSize: Theme.fs(10)
            }
            MouseArea {
                id: hoverCloseMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (delegateRoot.isDismissing) return
                    delegateRoot.requestDismiss(false, delegateRoot.slideDir)
                }
            }
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.bottomMargin: 8
            height: 3
            clip: false
            visible: delegateRoot.timeoutMs > 0 && !delegateRoot.isMinimal
            Rectangle {
                antialiasing: Theme.shapesAa
                id: progressTrack
                anchors.fill: parent
                radius: height / 2
                color: card.isCritical ? Theme.withAlpha(Theme.on_error_container, 0.22)
                                       : Theme.withAlpha(Theme.accent, 0.25)
                clip: true
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: parent.width * (1 - delegateRoot.progress)
                    radius: parent.radius
                    color: card.isCritical ? Theme.on_error_container : Theme.accent
                }
            }
        }

        MouseArea {
            id: bgMouse
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            enabled: !delegateRoot.leaving
            drag.target: dragProxy
            drag.axis: Drag.XAxis
            drag.minimumX: -delegateRoot.width
            drag.maximumX: delegateRoot.width
            drag.smoothed: false
            hoverEnabled: false
            onPressed: {
                if ((mouse.buttons & Qt.LeftButton) || (mouse.buttons & Qt.RightButton)) {
                    if (progressAnim.running) progressAnim.pause()
                }
            }
            onReleased: {
                let dx = 0
                try { dx = dragProxy.x } catch(e) { dx = 0 }
                if (Math.abs(dx) > 90) {
                    delegateRoot.requestDismiss(false, dx >= 0 ? 1 : -1)
                } else {
                    try { dragProxy.x = 0 } catch(e) { }
                    if (!delegateRoot.isDismissing && !card.isHovered && delegateRoot.timeoutMs > 0 && progressAnim.paused) progressAnim.resume()
                }
            }
            onCanceled: {
                try { dragProxy.x = 0 } catch(e) { }
                if (!delegateRoot.isDismissing && !card.isHovered && delegateRoot.timeoutMs > 0 && progressAnim.paused) progressAnim.resume()
            }
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    delegateRoot.requestDismiss(false, delegateRoot.slideDir)
                    return
                }
                try { if (Math.abs(dragProxy.x) > 8) return } catch(e) { }
                delegateRoot.requestDismiss(false, delegateRoot.slideDir)
            }
        }
    }
}
