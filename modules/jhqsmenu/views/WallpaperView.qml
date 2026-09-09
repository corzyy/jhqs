pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../../themes"

Item {
    id: root
    required property var scope
    required property var bodyRoot
anchors.fill: parent
anchors.margins: 4
clip: true
opacity: bodyRoot.scope.showWallpaper ? 1 : 0
visible: opacity > 0.01
enabled: bodyRoot.scope.showWallpaper
scale: bodyRoot.scope.showWallpaper ? 1 : 0.97
transformOrigin: Item.Center
Behavior on opacity { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Theme.easingSmooth } }
readonly property var modeLabels: ({ "stretch": "Stretch", "fit": "Fit", "fill": "Fill", "center": "Center", "tile": "Tile" })
function modeLabel(id) { return modeLabels[id] !== undefined ? modeLabels[id] : id }
function cycleMode(dir) {
    let ids = bodyRoot.scope.wallpaperModes
    if (!ids || ids.length === 0) return
    let i = ids.indexOf(bodyRoot.scope.wallpaperMode)
    if (i === -1) i = 0
    bodyRoot.scope.setWallpaperMode(ids[(i + dir + ids.length) % ids.length])
}
GridView {
    id: wallpaperGrid
    visible: !bodyRoot.scope.showWallpaperSettings
    anchors.top: parent.top; anchors.topMargin: 10; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
    clip:true; cellWidth:Math.floor(width/3); cellHeight:185; model: bodyRoot.scope.filteredWallpapers; currentIndex: bodyRoot.selectedIndex; boundsBehavior: Flickable.StopAtBounds
    cacheBuffer: 400
    onCurrentIndexChanged: if(visible) positionViewAtIndex(currentIndex, GridView.Visible)
    delegate: Item {
        id: wpDelegate; required property var modelData; required property int index
        width: wallpaperGrid.cellWidth; height: wallpaperGrid.cellHeight
        property bool isSelected: bodyRoot.selectedIndex === index
        Rectangle {
            antialiasing: Theme.shapesAa
            anchors.fill: parent; anchors.margins:5; radius: Theme.cornerRadiusSmall; clip:true
            color: isSelected?Theme.bgSelected:wpMouse.containsMouse?Theme.bgHover:Theme.panelSurface
            border.color:isSelected?Theme.accent:Theme.divider; border.width:isSelected?2:1
            Column { anchors.fill:parent; anchors.margins:5; spacing:5
                Rectangle { width:parent.width; height:parent.height-18; radius: Theme.cornerRadiusSmall; clip:true; color:"#0f111a"; Image { anchors.fill:parent; source:"file://"+modelData; fillMode:Image.PreserveAspectCrop; asynchronous:true; cache:true; sourceSize.width: 360; sourceSize.height: 167; onStatusChanged:if(status===Image.Error) source=""
                    smooth: Theme.imageSmooth
                    mipmap: Theme.imageMipmap
                }
                    antialiasing: Theme.shapesAa
                }
                Text { width:parent.width; text:modelData.split("/").pop(); color:isSelected?Theme.textPrimary:Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(9); font.weight:isSelected?Font.Medium:Font.Normal; elide:Text.ElideMiddle; horizontalAlignment:Text.AlignHCenter; maximumLineCount:1
                    antialiasing: Theme.textAa
                    renderType: Theme.textRenderType
                }
            }
            MouseArea { id:wpMouse; anchors.fill:parent; hoverEnabled:true; cursorShape:Qt.PointingHandCursor; onClicked:{ bodyRoot.selectedIndex=index; bodyRoot.scope.setWallpaper(modelData) } }
        }
    }
}
ColumnLayout {
    visible: bodyRoot.scope.showWallpaperSettings
    anchors.top: parent.top; anchors.topMargin: 10; anchors.left: parent.left; anchors.right: parent.right
    spacing: 4
    Rectangle {
        antialiasing: Theme.shapesAa
        Layout.fillWidth: true; Layout.preferredHeight: 40; radius: Theme.cornerRadiusSmall
        color: modeRowMouse.containsMouse ? Theme.panelSurface : "transparent"
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
            Text { text: "󰏘"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14); color: Theme.textMuted; Layout.preferredWidth: 18; horizontalAlignment: Text.AlignHCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Text { text: "Modus"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); color: Theme.textSecondary; Layout.fillWidth: true; elide: Text.ElideRight
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Text { text: root.modeLabel(bodyRoot.scope.wallpaperMode); font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11); font.weight: Font.Medium; color: Theme.textPrimary
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Text { text: "›"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14); color: Theme.textMuted
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
        }
        MouseArea { id: modeRowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: mouse => root.cycleMode(mouse.button === Qt.RightButton ? -1 : 1) }
    }
    Rectangle {
        antialiasing: Theme.shapesAa
        Layout.fillWidth: true; Layout.preferredHeight: 40; radius: Theme.cornerRadiusSmall
        color: dirRowMouse.containsMouse ? Theme.panelSurface : "transparent"
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
            Text { text: "󰉋"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14); color: Theme.textMuted; Layout.preferredWidth: 18; horizontalAlignment: Text.AlignHCenter
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Text { text: "Ordner"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(13); color: Theme.textSecondary; Layout.preferredWidth: 64; elide: Text.ElideRight
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Text { text: bodyRoot.scope.wallpaperDirDisplay; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(11); color: Theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideMiddle
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
            Text { visible: (bodyRoot.scope.wallpaperDirectoryConfigured || "") !== ""; text: "›"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(14); color: Theme.textMuted
                antialiasing: Theme.textAa
                renderType: Theme.textRenderType
            }
        }
        MouseArea {
            id: dirRowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            enabled: (bodyRoot.scope.wallpaperDirectoryConfigured || "") !== ""
            onClicked: bodyRoot.scope.setWallpaperDirectory("")
        }
    }
    Text {
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
        Layout.fillWidth: true
        text: "swaybg schaltet ohne Übergang"
        font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); color: Theme.textMuted
        horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
    }
    Rectangle {
        antialiasing: Theme.shapesAa
        Layout.fillWidth: true; Layout.preferredHeight: 36; radius: Theme.cornerRadiusSmall
        color: previewMouse.containsMouse ? Theme.bgHover : Theme.panelSurface
        border.color: Theme.divider; border.width: 1
        Text { anchors.centerIn: parent; text: "Vorschau anwenden"; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); font.weight: Font.Medium; color: Theme.textPrimary
            antialiasing: Theme.textAa
            renderType: Theme.textRenderType
        }
        MouseArea { id: previewMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bodyRoot.scope.previewWallpaperTrans() }
    }
}
Column {
    anchors.centerIn: parent; visible: bodyRoot.scope.filteredWallpapers.length===0 && !bodyRoot.scope.showWallpaperSettings; width:parent.width-20; spacing:8
    Text { text:"󰋩"; font.family: Theme.iconFontFamily; font.pixelSize: Theme.fs(32); color:Theme.textMuted; width:parent.width; horizontalAlignment:Text.AlignHCenter; opacity:0.8
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
    }
    Text { text:bodyRoot.scope.engineWallpapers.length===0?("Keine Wallpaper in " + bodyRoot.scope.wallpaperDirDisplay):"Keine Treffer"; color:Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(12); horizontalAlignment:Text.AlignHCenter; wrapMode:Text.WordWrap; width:parent.width
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
    }
    Text { visible:bodyRoot.scope.engineWallpapers.length===0; text:"Lege Bilder in den Ordner um sie hier zu sehen"; color:Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Theme.fs(10); opacity:0.5; width:parent.width; horizontalAlignment:Text.AlignHCenter
        antialiasing: Theme.textAa
        renderType: Theme.textRenderType
    }
}
                        }
