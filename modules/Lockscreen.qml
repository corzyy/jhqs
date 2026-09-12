pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../themes"
import QtQuick.Effects

Scope {
    id: lockScope
    property bool locked: false
    property string pinInput: ""
    property bool failed: false
    property string errorText: ""
    property int lockGen: 0
    property bool hasScreenshot: false

    signal unlocked()
    signal lockRequested()

    function lock(): void {
        if (locked) return
        pinInput = ""
        failed = false
        errorText = ""
        lockGen++
        hasScreenshot = false
        if (!grimProc.running) grimProc.running = true
        else hasScreenshot = true
    }
    function unlock(): void {
        locked = false
        pinInput = ""
        failed = false
        errorText = ""
        hasScreenshot = false
        if (!cleanupProc.running) cleanupProc.running = true
        unlocked()
    }
    function submitPin(): void {
        if (pinInput.length === 0) return
        failed = false
        errorText = ""
        authProc.command = ["/home/jakob/.config/quickshell/jhqs/scripts/lock-auth.sh", pinInput]
        if (!authProc.running) authProc.running = true
    }

    Process {
        id: cleanupProc
        command: ["bash", "-c", "rm -f /tmp/quickshell-lock-*.png &"]
    }
    Process {
        id: grimProc
        command: ["bash", "-c", "rm -f /tmp/quickshell-lock-*.png; mons=$(mmsg get all-monitors 2>/dev/null | jq -r '.monitors[]?.name' 2>/dev/null); if [ -z \"$mons\" ]; then mons=\"DP-1\"; fi; for mon in $mons; do grim -o \"$mon\" \"/tmp/quickshell-lock-${mon}.png\" 2>/dev/null || grim \"/tmp/quickshell-lock-${mon}.png\" 2>/dev/null || true; done; grim /tmp/quickshell-lock-fallback.png 2>/dev/null || true; echo done"]
        stdout: StdioCollector {
            onStreamFinished: {
                lockScope.hasScreenshot = true
                lockScope.locked = true
            }
        }
        onExited: (code) => {
            if (!lockScope.locked) {
                lockScope.hasScreenshot = true
                lockScope.locked = true
            }
        }
    }

    Process {
        id: authProc
        stdout: StdioCollector { }
        stderr: StdioCollector { }
        onExited: (code) => {
            if (code === 0) {
                lockScope.failed = false
                lockScope.errorText = ""
                lockScope.unlock()
            } else {
                lockScope.failed = true
                lockScope.errorText = "Falscher PIN"
                lockScope.pinInput = ""
                failTimer.restart()
            }
        }
    }
    Timer {
        id: failTimer
        interval: 1500
        onTriggered: { lockScope.failed = false; lockScope.errorText = "" }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: lockScope.locked
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "lockscreen"
            WlrLayershell.keyboardFocus: modelData.name === "DP-1" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true; bottom: true }

            Item {
                id: contentRoot
                anchors.fill: parent
                clip: false
                opacity: lockScope.locked ? 1 : 0

                Image {
                    smooth: Theme.imageSmooth
                    mipmap: Theme.imageMipmap
                    id: bgImage
                    anchors.fill: parent
                    anchors.margins: -64
                    source: lockScope.locked && lockScope.hasScreenshot ? "file:///tmp/quickshell-lock-" + modelData.name + ".png" : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    sourceSize.width: 960
                    sourceSize.height: 540
                    scale: lockScope.locked ? 1.0 : 1.06
                    opacity: lockScope.locked ? 1 : 0.85
                    // PERF: blur only while locked AND decoded (was live
                    // fullscreen blur pass per screen while locked).
                    layer.enabled: lockScope.locked && status === Image.Ready
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 0.6
                        blurMax: 8
                        autoPaddingEnabled: true
                    }
                    onStatusChanged: {
                        if (status === Image.Error) {
                            let fb = "file:///tmp/quickshell-lock-fallback.png"
                            if (source !== fb && source !== "") {
                                source = fb
                            }
                        }
                    }
                }
                Connections {
                    target: lockScope
                    function onLockedChanged() {
                        if (lockScope.locked && lockScope.hasScreenshot) {
                            let src = "file:///tmp/quickshell-lock-" + modelData.name + ".png"
                            bgImage.source = ""
                            Qt.callLater(() => bgImage.source = src)
                        } else if (!lockScope.locked) {
                            bgImage.source = ""
                        }
                    }
                    function onHasScreenshotChanged() {
                        if (lockScope.locked && lockScope.hasScreenshot) {
                            let src = "file:///tmp/quickshell-lock-" + modelData.name + ".png"
                            bgImage.source = src
                        }
                    }
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    id: fallbackBg
                    anchors.fill: parent
                    color: Theme.bg
                    visible: bgImage.status !== Image.Ready || bgImage.source === ""
                }
                Rectangle {
                    antialiasing: Theme.shapesAa
                    anchors.fill: parent
                    color: Theme.scrim
                    opacity: lockScope.locked ? 0.20 : 0
                }

                Item {
                    id: topClock
                    visible: modelData.name === "DP-1"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 110
                    width: clockCol.implicitWidth
                    height: clockCol.implicitHeight
                    opacity: lockScope.locked ? 1 : 0
                    scale: lockScope.locked ? 1 : 0.96
                    transform: Translate { y: lockScope.locked ? 0 : -18 }
                    SystemClock { id: lockClock; enabled: lockScope.locked && modelData.name === "DP-1"; precision: SystemClock.Minutes }
                    Column {
                        id: clockCol
                        anchors.centerIn: parent
                        spacing: 10
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(lockClock.date, "HH:mm")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(92)
                            font.weight: Font.Light
                            font.letterSpacing: -3.2
                            lineHeight: 0.95
                            horizontalAlignment: Text.AlignHCenter
                            opacity: 0.97
                        }
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 32; height: 2
                            radius: Theme.cornerRadiusSmall
                            color: Theme.primary
                            opacity: 0.65
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(lockClock.date, "dddd  •  dd MMMM")
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(15)
                            font.weight: Font.Medium
                            font.letterSpacing: 1.2
                            opacity: 0.72
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                    // PERF: shadow passes gated on locked (were 3 always-on
                    // offscreen passes, even when the lockscreen hid).
                    layer.enabled: lockScope.locked
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Theme.withAlpha(Theme.scrim, 0.40)
                        shadowBlur: 0.9
                        shadowOpacity: 0.38
                        shadowVerticalOffset: 6
                    }
                }

                TextInput {
                    id: pinField
                    anchors.fill: parent
                    visible: false
                    focus: lockScope.locked && modelData.name === "DP-1"
                    activeFocusOnTab: modelData.name === "DP-1"
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    text: lockScope.pinInput
                    onTextChanged: if (text !== lockScope.pinInput) lockScope.pinInput = text
                    Connections {
                        target: lockScope
                        function onPinInputChanged() { if (pinField.text !== lockScope.pinInput) pinField.text = lockScope.pinInput }
                    }
                    onAccepted: lockScope.submitPin()
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            lockScope.pinInput = ""
                            pinField.text = ""
                            event.accepted = true
                        }
                    }
                }
                MouseArea { anchors.fill: parent; onClicked: pinField.forceActiveFocus() }
                onVisibleChanged: if (visible) Qt.callLater(() => pinField.forceActiveFocus())
                Connections {
                    target: lockScope
                    function onLockedChanged() { if (lockScope.locked) Qt.callLater(() => pinField.forceActiveFocus()) }
                }

                Item {
                    id: pinContainer
                    visible: modelData.name === "DP-1"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 185
                    width: 360; height: 150
                    opacity: lockScope.locked ? 1 : 0
                    scale: lockScope.locked ? 1 : 0.96
                    property real shakeOffset: 0
                    transform: Translate { y: lockScope.locked ? 0 : 24; x: pinContainer.shakeOffset }
                    ColumnLayout {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        spacing: 18
                        width: parent.width
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            Layout.alignment: Qt.AlignHCenter
                            width: 44; height: 44; radius: Theme.cornerRadius
                            color: Theme.withAlpha(Theme.surface2, lockScope.failed ? 0.85 : 0.52)
                            border.color: lockScope.failed ? Theme.errorColor : Theme.withAlpha(Theme.outline, 0.18)
                            border.width: 1
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                anchors.centerIn: parent
                                text: "󰌾"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(16)
                                color: lockScope.failed ? Theme.errorColor : Theme.textPrimary
                                opacity: lockScope.failed ? 1.0 : 0.9
                            }
                        }
                        Rectangle {
                            antialiasing: Theme.shapesAa
                            id: pinBox
                            Layout.alignment: Qt.AlignHCenter
                            width: 320; height: 56
                            radius: Theme.cornerRadius
                            color: lockScope.failed ? Theme.withAlpha(Theme.error, 0.18) : Theme.withAlpha(Theme.surface2, 0.62)
                            border.color: lockScope.failed ? Theme.errorColor : (pinField.activeFocus ? Theme.primary : Theme.withAlpha(Theme.outline, 0.22))
                            border.width: lockScope.failed || pinField.activeFocus ? 1.6 : 1
                            layer.enabled: lockScope.locked
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: Theme.withAlpha(Theme.scrim, 0.25)
                                shadowBlur: 0.7
                                shadowOpacity: 0.28
                                shadowVerticalOffset: 4
                            }
                            Row {
                                id: dotRow
                                anchors.centerIn: parent
                                spacing: 14
                                visible: lockScope.pinInput.length > 0
                                // PERF: fixed 12 dots (was model: pinInput.length,
                                // creating/destroying delegates per keystroke).
                                Repeater {
                                    model: 12
                                    delegate: Rectangle {
                                        required property int index
                                        width: 12; height: 12; radius: Theme.cornerRadiusSmall
                                        color: lockScope.failed ? Theme.errorColor : Theme.textPrimary
                                        opacity: 0.95
                                        visible: index < lockScope.pinInput.length
                                    }
                                }
                            }
                            Text {
                                antialiasing: Theme.textAa
                                renderType: Theme.textRenderType
                                anchors.centerIn: parent
                                visible: lockScope.pinInput.length === 0
                                text: lockScope.failed ? lockScope.errorText : "PIN eingeben  •  Enter"
                                color: lockScope.failed ? Theme.errorColor : Theme.withAlpha(Theme.textPrimary, 0.62)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(13)
                                font.weight: Font.Medium
                                font.letterSpacing: 0.4
                                horizontalAlignment: Text.AlignHCenter
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: pinField.forceActiveFocus() }
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            Layout.alignment: Qt.AlignHCenter
                            visible: lockScope.failed
                            text: lockScope.errorText
                            color: Theme.errorColor
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(12)
                            font.weight: Font.Medium
                            opacity: 0.95
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            antialiasing: Theme.textAa
                            renderType: Theme.textRenderType
                            Layout.alignment: Qt.AlignHCenter
                            visible: !lockScope.failed && lockScope.pinInput.length === 0
                            text: "Entsperren mit PIN oder System-Passwort"
                            color: Theme.withAlpha(Theme.textPrimary, 0.42)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(11)
                            font.letterSpacing: 0.2
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "lockscreen"
        function lock(): void { lockScope.lock() }
        function unlock(): void { lockScope.unlock() }
        function toggle(): void { if (lockScope.locked) lockScope.unlock(); else lockScope.lock() }
        function isLocked(): string { return lockScope.locked ? "true" : "false" }
    }
}
