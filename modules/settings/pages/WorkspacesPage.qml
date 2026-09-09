pragma ComponentBehavior: Bound
import QtQuick
import "../../../themes"
import "../../bar" as Bar
import ".."

Column {
    id: root
    width: parent ? parent.width : 400
    spacing: 10

    SettingsSection {
        title: "Style"
        SettingsDropdown {
            label: "Style"
            options: ["Default", "Default2", "M3"]
            current: Theme.workspaceStyle === "m3" ? "M3" : Theme.workspaceStyle === "default2" ? "Default2" : "Default"
            onPicked: v => Theme.setWorkspaceStyle((v || "").toLowerCase())
        }
        Bar.Workspaces {
            width: parent.width
            height: 24 * Theme.workspaceScale + 8
        }
    }

    SettingsSection {
        title: "Spacing"
        SettingsSliderRow { label: "Distance"; from: 0; to: 24; stepSize: 1; unit: "px"; value: Theme.workspaceSpacing; onMoved: v => Theme.setWorkspaceSpacing(Math.round(v)); onApplied: v => Theme.setWorkspaceSpacing(Math.round(v)) }
    }

    SettingsSection {
        title: "Scale"
        SettingsSliderRow { label: "Widget Scale"; from: 50; to: 200; stepSize: 5; unit: "%"; value: Theme.workspaceScale * 100; onMoved: v => Theme.setWorkspaceScale(v / 100); onApplied: v => Theme.setWorkspaceScale(v / 100) }
    }
}
