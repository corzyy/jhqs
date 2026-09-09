---
name: jhqs
description: Navigation, Design & Architektur für die jhqs Quickshell-Config – Single-Source Theme, Window-System, IPC und Stabilitäts-Regeln für KI-Änderungen.
---

# jhqs – Navigation, Design & Stable Engineering

Gilt für alle Änderungen unter `/home/jakob/.config/quickshell/jhqs/` (`shell.qml`, `Theme.qml`, `TopBar.qml`, `modules/*.qml`, `*.json`, `scripts/*`).
Lade diesen Skill **immer** wenn du QML, Theme, Navigation, Panels, Settings oder IPC bearbeitest.

## Wann anwenden
- Neue Panels/Popups, Suchlisten, Grids, Slider/Toggles, Wallpaper/Font-Picker, Hyprland-Live-Settings
- Theme/Farben, Typografie, Radius, Bar-Höhe/Opacity/Position, Animationen
- Navigation/State (`show*`, `menuDepth`, `handleEsc`, `selectedIndex`, `filterText`, `closeAll`)
- Persistenz (`*.json` via `FileView`) oder Hyprland-Configs (`looknfeel.lua`, `animations.lua`)
- IPC-Erweiterungen, Polling, `Process` oder Bugfixes an leeren/unsichtbaren Menüs

---

## 1. Navigation – zentrales System

### 1.1 Shell-Level Exklusivität (`shell.qml`)
```qml
ShellRoot { property bool menuVisible/appLauncherVisible/controlCenterVisible/calendarVisible int systemTrigger }
function closeAll() { menuVisible=false; appLauncherVisible=false; controlCenterVisible=false; calendarVisible=false }
function closeOthers(except:string) { if(except!=="menu") menuVisible=false; ... }
function toggleExclusive(name:string) {
  if(name==="menu"){ if(calendarVisible||appLauncherVisible){calendarVisible=false; appLauncherVisible=false} else {closeOthers("menu"); menuVisible=!menuVisible} }
  else if(name==="cc"){ let v=!controlCenterVisible; closeAll(); controlCenterVisible=v }
  else if(name==="calendar"){ let v=!calendarVisible; closeAll(); calendarVisible=v }
  else if(name==="launcher"){ closeOthers("launcher"); appLauncherVisible=!appLauncherVisible }
}
```
- `TopBar` triggert via `onToggleMenu/onToggleControlCenter/onToggleCalendar` → `toggleExclusive`.
- `ControlCenter`/`CalendarMenu` schließen immer via `closeAll()`, `JhqsMenu`/`AppLauncher` via `closeOthers("launcher")`.
- **Neue Popups:** immer in `shell.qml` `closeAll/closeOthers` registrieren + `Modules.X { showX: root.xVisible onDismissed: root.xVisible=false }`.

### 1.2 JhqsMenu State Machine (1250 Zeilen, `modules/JhqsMenu.qml`)
```
Root model: menuModel[8] = Apps,Style,Setup,Install,Remove,Update,About,System
Submenus: styleMenu[2] installMenu[3] removeMenu[3] updateMenu[3] sessionMenu[4] setupMenu[6]
Detail panels: showHyprland, showShell, showWallpaper, showFont
Flags: showStyle/showWallpaper/showInstall/showRemove/showUpdate/showSession/showSetup/showHyprland/showShell/showFont/directSystemOpen
Derived: isInSubmenu = OR aller Flags; menuDepth = showWallpaper||showHyprland||showShell ?2 : isInSubmenu?1:0; _prevDepth/navDir für Slide-Animation
IPC trigger: systemTrigger++ (shell) → onSystemTriggerChanged → openSystem() (setzt showSession=true directSystemOpen=true)
```

**Navigation-Stack & handleEsc()-Hierarchie:**
```qml
function handleEsc():bool {
  if(showWallpaper||showFont){ showWallpaper=false; showStyle=true; clearSearch(); return true }
  if(showHyprland||showShell){ showHyprland=false; showShell=false; showSetup=true; clearSearch(); return true }
  if(showStyle||showInstall||showRemove||showUpdate||showSetup){ resetAllSubmenus(); clearSearch(); return true }
  if(showSession){ if(filterText.length>0){clearSearch(); return true} let d=directSystemOpen; resetAllSubmenus(); clearSearch(); return d?false:true }
  if(filterText.length>0){ clearSearch(); return true }
  return false // → dismissed()
}
```
- `Esc` nie direkt `dismissed()` ohne `handleEsc()` prüfen.
- `Back/Click` außerhalb: `MouseArea anchors.fill onClicked: dismissed()` + `onClicked: mouse.accepted=true` innerhalb `ccBox`/Panels.

**Filtering & Selection:**
```qml
string filterText + qLower()=toLowerCase().trim()
filteredMenu: showWallpaper?[] : activeSubmenu?filtered(active):q==""?menuModel:menuModel.filter(title includes q)
filteredCategorySections: isInSubmenu?[] : q==""?[] : sections aus menuModel.submenu matching q (Fallback: wenn Kategorie-Titel matched → ganze Submenu)
categoryOptionsCount/flattenedCategoryOptions für One-Shot flatten
filteredApps: isInSubmenu?[] : q==""?[] : allApps.filter(name/id/comment includes q) sort exact→startsWith→length slice 0,8
filteredWallpapers: showWallpaper? (q==""?wallpaperFiles:filter basename) : []
totalCount = showWallpaper?wallpapers.length : filteredMenu.length + categoryOptionsCount + filteredApps.length
selectedIndex 0..totalCount-1 clamp
```
- `allApps` robust: `try{ let v=DesktopEntries.applications.values; if(typeof v==="function") v=v(); return v.slice()}catch(e){return []}` – **nie** `DesktopEntries.applications.values` direkt.
- `IconImage source: entry && entry.icon ? Quickshell.iconPath(entry.icon):""` guard.
- `activateCurrent()`: wallpaper→`setWallpaper`; submenu→switch-panel oder `runProc`; root→`appsRequested()/showStyle/...`; category→`executeCategoryOption`; app→`entry.execute(); dismissed()` (kein Launch-OSD mehr).

**Keyboard & EnsureVisible:**
- `Keys.onPressed` in `bodyRoot`: `Down/Up` wrap `(i+1)%n`, wallpaper: `±3` grid; `Left/Right` ±1 in grid; `PageDown/Up ±5`, `Home/End`, `Return/Enter → activateCurrent()`, `Esc → handleEsc()||dismissed()`, `Meta+M` → menu dismiss, `Meta+Shift+M` → appsRequested.
- `ensureVisible(idx)` clamp `contentY` via `rowH 40+4` + header offsets (`24` category header + `22` apps header) → `contentY = max(0, y-4)` oder `min(maxY, y+40-vh+4)`.
- `onSelectedIndexChanged → ensureVisible`, `onFilterTextChanged → contentY=0` + `Qt.callLater(ensureVisible)`.
- `contentStage` Animation: `menuDepth` change → `navDir = menuDepth>_prevDepth?1:-1`; `isListView ? slide x 0 : -14`, List opacity `1→0.6→1` mit `navDir*10`.

### 1.3 Weitere Navigation
- **AppLauncher:** `filteredApps` live aus `query`, `selectedIndex` wrap, `ContextMenu` (`contextMenuEntry/Visible/Pos/SelectedIndex` via `mapToItem +8`, `220px` wide), `BackRequested → appLauncherVisible=false; menuVisible=true`.
- **ControlCenter:** `showSinkPicker/showBluetoothMenu/showWiredMenu/notifExpanded` collapsables unter Volume/Tiles/Menus. `dismissed()` via fullscreen `MouseArea` hinter `ccBox` + `Esc` Hierarchy (picker zuerst schließen).
- **CalendarMenu:** `CalendarModel.js Cal.monthGrid(year,month,weekStart)` 6×7 fix, `viewYear/viewMonth`, Nav `‹/› 32×28`, Wheel `moveMonth`, Keys `Left/Right ±1 Monat Up/Down ±1 Jahr Home/t→today w→toggleWeekStart`, `weekStartDay` aus `calendar.json`.
- **Notifications:** `NotificationServer keepOnReload trackedNotifications`, `targetScreen` DP-1 fallback `vals[0]`, `timeoutMs` Heuristik `t≥100?ms:s*1000`, `safeClose(expire)`, `isDismissing + cachedHeight`.
- **Lockscreen:** `grim per Monitor → /tmp/quickshell-lock-<name>.png`, `locked → hasScreenshot`, `pinInput/failed/shakeOffset SequentialAnimation`, `authProc lock-auth.sh`, `Esc` clear input.

---

## 2. Design – Theme ist Single Source of Truth

### 2.1 Farben (`Theme.qml`, `pragma Singleton`)
```qml
FileView path: HOME/.config/quickshell/jhqs/themes/matugen.json watchChanges:true blockLoading:true printErrors:false onFileChanged:reload()
adapter: JsonAdapter { 44 property color background ... tertiary_fixed_dim }
```
- Quelle live von `matugen` (`/home/jakob/.cargo/bin/matugen` fallback `matugen`) `matugen image -t $TYPE -m $MODE --prefer saturation` + `hyprctl reload`. Fallbacks `#1E2132/#7AA2F7`.
- **Palette 1:1** aus `matugen.json`: `background, error, error_container, inverse_on_surface, inverse_primary, inverse_surface, on_background, on_error, on_error_container, on_primary, on_primary_container, on_primary_fixed, on_primary_fixed_variant, on_secondary, on_secondary_container, on_secondary_fixed, on_secondary_fixed_variant, on_surface, on_surface_variant, on_tertiary, on_tertiary_container, on_tertiary_fixed, on_tertiary_fixed_variant, outline, outline_variant, primary, primary_container, primary_fixed, primary_fixed_dim, scrim, secondary, secondary_container, secondary_fixed, secondary_fixed_dim, shadow, source_color, surface, surface_bright, surface_container, surface_container_high, surface_container_highest, surface_container_low, surface_container_lowest, surface_dim, surface_tint, surface_variant, tertiary, tertiary_container, tertiary_fixed, tertiary_fixed_dim`.

**Semantische Aliase – immer nutzen, nie Raw (Stand Theme.qml + ControlCenter.qml):**
```
bg=surface,
surface2=frostFill(surface_container_high,0.18,0.84),
bgHover=frostFill(surface_container_highest,0.14,0.88),
bgSelected=frostFill(primary_container,0.08,0.92),
bgTileActive=frostFill(primary_container,0.32,0.70), // legacy – neue Tiles nutzen cardBg-System unten
bgTileInactive=frostFill(surface_container,0.35,0.68), // legacy
cardBg=ccTileBg=frostFill(surface_container_high,0.45,0.55), // ALLE CC-Tiles, Tray, NotifCenter, Picker, Weather-Cards
panelBg=frostFill(bg,0.48,0.52), // ALLE Panel-Außen (ccBox)
panelSurface=frostFill(surface,0.22,0.80), // Felder, MSlider-Indicator muted
panelBorderColor=panelAccentBorder?accent:divider, // ALLE Panel-Außen border
onTileActive=on_primary_container, tileIconBgActive=on_primary_container, tileIconFgActive=primary_container,
borderColor=outline_variant, borderOuter=scrim,
textPrimary=on_surface, textSecondary=on_surface_variant, textMuted=outline,
iconColor=secondary, iconBg=frostFill(surface_container_high,0.16,0.86),
iconBgSelected=primary, iconColorSelected=on_primary, onAccent=on_primary,
accent=primary, accentDim=primary_container, divider=outline_variant, errorColor=error
```
- `frostFill(c,strength,floorA)`: `panelBlur<=0.001 ? c : withAlpha(c, max(floorA, 1-panelBlur*strength))`. `panelBlur` aus `topbar_settings.json` (default `0.6`, `panelBgAlpha=1-blur*0.48`). Nie manuell Alpha auf `panelBg/cardBg` draufrechnen – Blur steckt schon drin.
- **Nie Raw-Palette** (`primary_container`, `surface_container_high`, …) direkt in Modulen – immer Alias oben.
- In Modulen spiegeln per Scope (ControlCenter-Vorbild, `ControlCenter.qml:55-70`):
```qml
property color bg: Theme.bg
property color surface: Theme.panelSurface
property color surface2: Theme.surface2
property color bgHover: Theme.bgHover
property color bgSelected: Theme.bgSelected
property color bgTileActive: Theme.bgTileActive
property color bgTileInactive: Theme.bgTileInactive
property color borderColor: Theme.borderColor
property color borderOuter: Theme.borderOuter
property color textPrimary: Theme.textPrimary
property color textSecondary: Theme.textSecondary
property color textMuted: Theme.textMuted
property color accent: Theme.accent
property color onAccent: Theme.onAccent
property color iconColorSelected: Theme.iconColorSelected
property color divider: Theme.divider
```
- Transluzenz nur `Theme.withAlpha(c,a){ Qt.rgba(c.r,c.g,c.b,a)}` z.B. `Theme.withAlpha(Theme.bg,barOpacity)`.
- Fixe Hex nur `#ffffff @0.06` Highlight, `#0f111a` Lockscreen Overlay, `#3a2a2e/#6b3a40` Quit-Hover. Keine neuen Hex.

### 2.1.1 ControlCenter-Farbsystem – Pflicht für alle neuen Panels/Tiles
- **Panel-Außen immer:** `color: Theme.panelBg; border.color: Theme.panelBorderColor; border.width: 1; radius: Theme.cornerRadius` (nie `Theme.bg`/`Theme.divider` direkt).
- **Tile/Card immer (WiredTile-Vorbild):** `color: Theme.cardBg; border.color: Theme.divider; border.width: 1; radius: Theme.cornerRadiusSmall` + `Behavior on color { ColorAnimation{duration:Theme.animNormal; easing.type:Theme.easingSmooth}}`.
- **Tile-Icon-Squircle (42px, aktiv/inaktiv):**
```qml
color: scope.active ? Theme.tileIconBgActive : Theme.iconBg
border.color: scope.active ? "transparent" : Theme.divider
Text { color: scope.active ? Theme.tileIconFgActive : Theme.textPrimary }
```
- **Tile-Texte:** Titel `Theme.textPrimary` 12px Medium, Status `Theme.textSecondary` 10px.
- **Chevron/Overflow-Hover:** `Theme.withAlpha(Theme.scrim, scope.active ? 0.14 : 0.08)` sonst `"transparent"`; Icon `Theme.textSecondary`.
- **Slider aktiv (VolumeTile-Vorbild) vs muted:**
```qml
activeTrackColor: muted ? Theme.textMuted : Theme.onTileActive
inactiveTrackColor: muted ? Theme.divider : Theme.withAlpha(Theme.onTileActive, 0.45)
handleColor/stateLayerColor: muted ? Theme.textPrimary : Theme.onTileActive
valueIndicatorColor: muted ? Theme.panelSurface : Theme.primary
valueIndicatorTextColor: muted ? Theme.textPrimary : Theme.on_primary
Text pct: muted ? Theme.textSecondary : Theme.withAlpha(Theme.onTileActive, 0.9)
```
- **Muted/inaktiv-Fallbacks:** Track `textMuted/divider`, Icon `iconBg+textPrimary`, Label `textSecondary` – nie `accent` für muted.

### 2.2 Typografie
- **System-Font:** `FileView font_settings.json adapter.fontFamily:"Adwaita Sans"` → `readonly property string fontFamily: adapter.fontFamily.length>0 ? adapter.fontFamily : "Adwaita Sans"` (aktuell `Inter Variable`). Schreiben `adapter.fontFamily + writeAdapter() + fontApplyProc (gsettings + sed gtk-3.0/4.0/settings.ini + xsettingsd.conf + pkill -HUP)`. Init `Timer 650ms` seed `gsettings→gtk.ini→Fallback`.
- **UI-Font immer `JetBrainsMono Nerd Font`** für alle `Text` in TopBar/JhqsMenu/AppLauncher/ControlCenter/Clock/Launcher/Workspaces/Calendar/Notifications. System-`fontFamily` nur für Vorschau `"Aa Bb Cc 123 • "+modelData`.
- Größen: TopBar 14px Icon / 11px Count Bold / 12px Clock; Suche 13px Icon /13px Input; Rows 13px Titel Medium /16px Icon /16px ›; Tiles 13/11px /12px Slider /9px Hint; Calendar 28px Hero Bold /26px Icon /10px Jahr /9px Wochentag Bold `letterSpacing 0.5` uppercase; Lockscreen 92px Clock Light /15px Date Medium /13px PIN; Notifications 11px app /13px summary Medium /12px body.
- **Alle Größen immer via `Theme.fs(N)`** (`font.pixelSize: Theme.fs(13)`), nie rohe Literale — `fontScale` (0.85–1.25, `topbar_settings.json`, Global → Font → Shell Text Size) skaliert die ganze Shell live; `Theme.setFontScale()` clampt/rundet. System-Fontgröße separat via `Theme.fontSize` + `apply-font.sh`.
- Gewichte: `Font.Medium` Rows/Inputs, `Bold` Counts/Header, `letterSpacing 0.6-1.0` + `toUpperCase()` für `ANWENDUNGEN`.
- Font-Liste: `Qt.fontFamilies()` sortiert, Fallback `fc-list : family | tr ',' '\n' | sed 's/^ *//' | sort -u | head -800`.

### 2.3 Spacing / Radius / Bar
```qml
FileView shellFile path: HOME/.config/quickshell/jhqs/config/topbar_settings.json adapter { radius:0 animationsEnabled:true animationScale:1.0 clockPosition:"center" workspacesPosition:"left" textBold:false }
readonly cornerRadius: Math.max(0,Math.min(24, shellFile.adapter.radius))
readonly cornerRadiusSmall: Math.max(0,Math.min(12, Math.round(cornerRadius*0.6)))
```
- Aktuell `radius:24 → cornerRadius=24 small=14` (via `topbar_settings.json`). **Nur `Theme.cornerRadius/Small` nutzen**, nie Literal `8`. Setter `setShellRadius(v)` clamp 0-24 `Math.round`.
- Workspaces-Dot: `radius: Math.max(2,Math.min(6.5, Theme.cornerRadius))`. Slider-Handle `14x14` `radius: Theme.cornerRadius`.
- **VolumeOSD:** kompakte vertikale Pill `56×280` `radius: Theme.cornerRadius` (folgt `Shell → Radius` Slider 0-24 live via `topbar_settings.json`, `Theme.cornerRadius`), Schatten `scrim 0.18` gleicher Radius, Track `6×r3` `Theme.surface`/`divider`, Fill `Theme.accent`/`error`, Handle `12×r6` `accent` + `bg` Border 1.5 – **muss immer `Theme.cornerRadius` nutzen**, nie Hardcode.
- **Bar:** `adapter.thickness:30` clamp 20-48 `Math.round`, `PanelWindow implicitHeight: barHeight (Math.max(20,Math.min(48,round(thickness))))` + `Behavior animSlow`, `exclusiveZone: DP-1 ? barHeight :0`. **Opacity** `0.0-1.0 Math.round(c*100)/100` `color: barOpacity<1 ? Theme.withAlpha(Theme.bg,barOpacity):Theme.bg`. **Position** `top|bottom|left|right` `anchors.top: barPos==="top"||isVertical` etc., Popups `topMargin: barT+5`.
- **Panel-Maße:** JhqsMenu `Theme.sharedMenuWidth/Height` (persisted `shared_menu.json`, default `360×444`, aktuell `720×760`) dynamisch `catDynH=clamp(overhead + n*40+(n-1)*4+2,200,sharedMenuHeight)`; Wallpaper `760×820`, Hypr/Shell `480×640`. Innen `10` Margin, Suche `36`, Divider `1 @0.5`. AppLauncher `Theme.sharedMenuWidth × max 460 content`. ControlCenter `380× flick+24` `barT+5` Margin `12` Tile `52`. Calendar `420` `cell 42×28 spacing2`. Notifications `360 spacing8`. Lockscreen `pinContainer 360×150 pinBox 320×56`. VolumeOSD `56×280` kompakt Pill rechts vertikal zentriert `rightMargin: (barPos==="right"?barT:0)+10`.
- **Panel-Abstand zur Bar (Pflicht für alle neuen Panels):** immer `readonly property int screenGap: 6` + `property int panelGap: screenGap - Theme.barThickness` + `BarAnchor { gap: scope.panelGap }`. Gibt konstant `6px` sichtbaren Abstand zur Bar-Kante für jede Bar-Dicke (`20-48`) und jede `barPos` (`top|bottom|left|right`). Nie `panelGap: 0` oder Literal-Abstand — das lässt das Panel zu weit schweben (MediaPanel-Fix 2026-09).

### 2.4 Animationen – skaliert, abschaltbar (zentraler Toggle)
- Persistenz `topbar_settings.json: {animationsEnabled:true, animationScale:1.0}` via `shellFile`.
```qml
readonly animFast: enabled?round(120*scale):0   // hover, scale
readonly animNormal: enabled?round(180*scale):0 // color
readonly animSlow: enabled?round(260*scale):0   // opacity, y
readonly animEmph: enabled?round(320*scale):0   // scale OutBack
readonly animStagger: enabled?round(22*scale):0
easingStandard: OutCubic, easingEnter:OutExpo, easingExit:InCubic, easingEmph:OutBack
```
- **Immer** `Behavior on color { ColorAnimation{duration:Theme.animFast; easing.type:Theme.easingStandard}}` etc. Entrance: `Loader opacity 0→1 scale 0.98→1 Translate y 8→0 animSlow/Emph`. Hover `scale 1.02` + `color animFast`. Slider live `enabled: !volumeDragging`.
- Lockscreen Shake `45/90/70` intentional micro-duration.
- Toggle steuert **alle** Animationen; bei `false` instant `0`.

### 2.5 Minimal Design (seit 2026-08-29 aktiv, Farben per CC-System 2.1.1)
- Flat: kein `Qt.lighter`, kein `layer.enabled` (außer Blur), kein inner Highlight.
- Nur 3 Flächen: `Theme.panelBg` (Panel-Außen) + `Theme.panelBorderColor`, `Theme.cardBg` (Tiles/Cards/Picker), `Theme.panelSurface` (Felder/Inputs). Hover `surface2/bgHover`, Selektion `bgSelected+divider`. Nie `Theme.bg`/`Theme.surface` direkt für Panels/Tiles.
- Border `1px Theme.divider` (Tiles/Cards) bzw. `Theme.panelBorderColor` (Panel-Außen), Scrim `0.20-0.25`, Radius `cornerRadiusSmall` für Rows/Tiles/Suche (aktuell `14`), `cornerRadius` nur Panel-Außen.
- Spacing: Panel `10`, Suche `36`, Rows `40+4`, Slider `4` Track `14` Handle.
- **Skelett für neue Panels:**
```qml
Rectangle { radius:Theme.cornerRadiusSmall; color: isSelected?Theme.bgSelected:Mouse.containsMouse?Theme.surface:"transparent"; border.color:isSelected?Theme.divider:"transparent"; border.width:1 }
Text { font.family:"JetBrainsMono Nerd Font"; font.pixelSize:13; color:isSelected?Theme.textPrimary:Theme.textSecondary }
Rectangle { height:4; radius:2; color:Theme.divider; Rectangle{color:Theme.textPrimary; radius:2} } // Track 4px
Rectangle { width:14; height:14; radius:Theme.cornerRadius; color:Theme.textPrimary; border.color:Theme.divider } // Handle
```

---

## 3. Layout & Fenster-Architektur
- **Entry `shell.qml`:** `// @ pragma UseQApplication` `IconTheme Papirus` `ShellRoot`. Kinder: `TopBar`, `Notifications`, `JhqsMenu{showMenu}`, `AppLauncher`, `ControlCenter`, `CalendarMenu`, `VolumeOSD`, `Lockscreen` (letzt).
- **Multi-Monitor:** `Variants { model: Quickshell.screens PanelWindow { required property var modelData; screen:modelData }}` – **nur `DP-1` sichtbar** (`visible: modelData.name==="DP-1"` + `exclusiveZone` nur TopBar). `Notifications` via `targetScreen` (DP-1 fallback `vals[0]`). `Lockscreen` pro Screen aber Input nur `DP-1`.
- **Anker:** Overlays `anchors{top:true left:true right:true bottom:true}`; Popups `topMargin: barT+5`; Bar-Innen `12` horizontal.
- **Panel-Docking (Pflicht):** jedes Bar-Panel dockt via `BarAnchor { moduleId:"<id>" barPos: scope.barPos panelWidth/panelHeight screenWidth/screenHeight gap: scope.panelGap }` + `x: anchor.panelX y: anchor.panelY transformOrigin: anchor.origin` mit `screenGap: 6 / panelGap: screenGap - Theme.barThickness` (siehe 2.3). Nur zentrierte Keyboard-Sonderfälle (`JhqsMenu.centered`) dürfen davon abweichen.
- **Layer:** `WlrLayershell.layer: WlrLayer.Overlay` `namespace:"menu"|"launcher"|"controlcenter"|"controlcenter-backdrop"|"calendar"|"notifications"|"volumeosd"|"lockscreen"` `keyboardFocus:Exclusive` (Notifications `None`, Lockscreen `DP-1?Exclusive:None` + `ExclusionMode.Ignore`). Notifications `mask: Region{item:listCol}`.
- **Dismiss-Pattern:** `Scope > Variants > PanelWindow > Rectangle(scrim 0.20-0.25 Behavior animSlow) > MouseArea(dismiss) > ... > Rectangle(ccBox) { MouseArea{onClicked: mouse.accepted=true} }` + sibling fullscreen `MouseArea{onClicked: dismissed()}` hinter `ccBox` für **click-anywhere-else** (ControlCenter).

## 4. Komponenten-Muster (Kurz)
- **JhqsMenu:** `setHyprGapsIn 0-40/GapsOut 0-60/Border 0-12/Rounding 0-30/toggleShadow/Blur`, `wallpaperListProc ls | grep -iE \.(jpg|jpeg|png|webp|bmp|gif|tiff)$ | head 500`, `setWallpaper` via `awww img --transition-type outer --duration 1.5 --fps 60 --pos center` persist `current_wallpaper.txt + ~/.cache/awww/current` → `matugen image -t $TYPE -m $MODE --prefer saturation + hyprctl reload`.
- **AppLauncher:** `searchBox 36 clip`, `Flickable StopAtBounds`, `Repeater filteredApps 40px` `IconImage async`, `selectedIndex wrap`, Context `220px mapToItem+8`.
- **ControlCenter:** Netz `nmcli 5s`, BT `bluetoothctl 6s`, Volume `Pipewire.defaultAudioSink` primär + `scripts/volume.sh get` 4s Fallback `wpctl throttled 35ms`, `SinkPicker pactl list sinks`. Tray separat: `bar/SystemTray` (Quattro-Drawer, `SystemTray.items` ohne Passive) + `SystemTrayPanel` (Pin/Hide via `Theme.trayPinnedIds/trayHiddenIds`).
- **CalendarModel.js:** `6×7 monthGrid`, `yearDonePercent`, `weekStart sunday/monday`.
- **Notifications:** `elapsed 50ms` pause bei Hover, `slideX 60→0 animSlow`, `progress 2px`, `RichText` bei `<>`, `safeClose`.
- **Lockscreen:** `grim per Monitor`, `blurMax 64`, `scrim 0.20`, `pinBox 320×56`, `shake sequential`.
- **Workspaces/Clock/Launcher/Updates:** siehe individuelles Modul.

## 5. Persistenz – immer `FileView` + `JsonAdapter` + `writeAdapter()`
- **Nie `echo >` roh.** Schreiben `adapter.prop = clamp(...); writeAdapter()` nach `Math.max/min/round`.
- `topbar_settings.json` init `mkdir -p; if !-f echo default; jq 'del(.blur) | .thickness //=30 | .opacity //=1.0 | .position //="top" | .radius //=0 | .animationsEnabled //=true | .animationScale //=1.0 | .clockPosition //="center" | .workspacesPosition //="left" | .textBold //=false' /tmp/tb.json && mv`.
- `matugen.json` nur via `matugen`, `matugen_settings.json` `{"type":"scheme-tonal-spot","mode":"dark","contrast":0.0}` 10 presets + `dark|light`, `font_settings.json`, `calendar.json {"weekStartDay":"sunday"}`, `shared_menu.json {"width":360,"height":444}`, `current_wallpaper.txt`, `pin` `tr -d '\r\n'`, `dnd.json/gamemode.json/nightlight.json/powermode.json`.
- Hyprland `looknfeel.lua/animations.lua` via `sed -E` + `hyprctl eval hl.config(...)` live + persist.
- **Crash-safe:** `FileView printErrors:false blockLoading:true watchChanges:true onFileChanged:reload() + Defaults`.

## 6. IPC
```
shell.qml target:"jhqs": toggleMenu()/showMenu()/hideMenu()/showLauncher()/hideLauncher()/requestApps()/state()/toggleControlCenter()/showControlCenter()/hideControlCenter()/toggleCalendar()/showCalendar()/hideCalendar()/openSystem()/toggleSystem()
TopBar target:"updates": check()/status()/debug(arg:on|off|toggle|count <n>|<n>)/debugCount(n)  // + updAllProc kitty update
jhqsMenu target:"jhqsMenu": setQuery(t)/getCounts()/pressEnter()/pressEsc()/moveDown()/moveUp()/getSelected()
calendar target:"calendar": nextMonth()/prevMonth()/state()
lockscreen target:"lockscreen": lock()/unlock()/toggle()/isLocked()
volumeOsd/osd: show()/status()  // launchOsd entfernt — VolumeOSD ist reines Volume-Pill rechts vertikal, radius: Theme.cornerRadius
notif: count()/list()  dnd: toggle()/enable()/disable()/status()  gamemode: toggle()/enable()/disable()/status()
```
Aufruf `quickshell ipc -c jhqs call <target> <func> [args]` bzw. `-p ~/.config/quickshell/jhqs`, immer `try/catch`.

## 7. Robustheit & Performance
- `if(!proc.running) proc.running=true` Guard überall, `StdioCollector let out=(text||"").trim() if(0) return; parseInt/isNaN guard`.
- Clamping überall, Shell-Escaping `replace(/\\/g,"\\\\").replace(/"/g,'\\"').replace(/\$/g,'\\$').replace(/`/g,'\\`')`.
- Fallbacks: wallpaper fallback, `matugen` bin fallback, `Qt.fontFamilies` vs `fc-list`, `bgImage` fallback png.
- Poll gestaffelt `ControlCenter onShow 120/220/320ms`, intervals `net 4-5s vol 2.5-4s bt 6s sink 5+3s updates 6h`, throttle `35ms`.
- Rendering `Flickable StopAtBounds clip:true`, `Repeater` statt `ListView` für statische Menüs, `monthGrid 6` fix, `Image async cache mipmap smooth`, `layer.enabled` nur für Blur.
- Limits `filteredApps slice 0,8 wallpaper 500 fonts 800`, `Qt.callLater(forceActiveFocus)`.

## 8. Workflow – Schrittfolge vor jedem Edit
1. Lies `Theme.qml` + Zielmodul + `topbar_settings.json/matugen.json` → erfasse `Theme.*` Aliase, `cornerRadius`, `anim*`.
2. Verwende `Theme.withAlpha`, `Quickshell.iconPath`, `Quickshell.env("HOME")`, `Quickshell.screens Variants DP-1`, `FileView`-Pattern, `Theme.anim*/easing*`, Navigation `closeAll/closeOthers/handleEsc/ensureVisible`.
3. Clampe Setter, escapen Pfade, guard `if(!running)`.
4. Teste `timeout 8 quickshell -p ~/.config/quickshell/jhqs/shell.qml --verbose 2>&1 | grep -iE "Configuration Loaded|ERROR"` → `Configuration Loaded` ohne `ERROR`, und `ipc call jhqs state / jhqsMenu getCounts / getSelected`.
5. Prüfe `visible: DP-1` + `exclusiveZone` nur TopBar, `namespace/keyboardFocus`, `mask Region` für Notifications, `click-anywhere-else` MouseArea hinter Panel.
6. Beachte `isDismissing` bei Notifications, `closeAll` bei neuen Popups, `Meta+M` Bindings.
7. **Reload-Pflicht nach jedem Edit:** Quickshell lädt QML NICHT live nach — nach jedem Edit IMMER neu starten (nur nach bestandenem Schritt 4, sonst steht der User ohne Shell da):
   a. Kill: `pkill -x qs; pkill -x jhqs` (läuft als `qs` bei manuellem Start bzw. `jhqs` via Autostart `~/.local/bin/jhqs -c jhqs -n` aus `hypr/configs/autostart.lua`).
   b. Warten bis weg: `for i in $(seq 1 20); do (pgrep -x qs || pgrep -x jhqs) >/dev/null || break; sleep 0.25; done` — NIE starten solange eine alte Instanz lebt (`-n` beendet den neuen Prozess bei Duplikat sofort wieder).
   c. Start: `nohup /home/jakob/.local/bin/jhqs -c jhqs -n -d >/tmp/jhqs-reload.log 2>&1 &` + `sleep 4`.
   d. Verifizieren: genau 1 Prozess (`pgrep -af "quickshell|jhqs"`) + `qs ipc -c jhqs call jhqs state` antwortet.

## 9. Anti-Patterns – strikt vermeiden
- Farben/Radius/Dicke/Animation hardcoden statt `Theme.*` + `topbar_settings`.
- `FileView` ohne `watchChanges blockLoading printErrors onFileChanged reload JsonAdapter Defaults writeAdapter` + Clamping.
- `Theme.withAlpha` umgehen, `QtQuick.Controls` nutzen, `exclusiveZone` außer TopBar, `matugen.json` manuell schreiben, `Quickshell.screens[0]` statt DP-1 Fallback.
- `Process` ohne `if(!running)` Guard, Poll `repeat:true triggeredOnStart:true` für alles, rohe `Easing.*` statt `Theme.easing*`.
- `pragma ComponentBehavior: Bound` vergessen, `import "./modules" as Modules` fehlen, `// @ pragma UseQApplication/IconTheme Papirus` fehlen.
- Neue Popups ohne `shell.qml closeAll/closeOthers` + `IpcHandler target:jhqs`, `echo "json" > file` ohne `mkdir -p` + `jq //=` + `mv`.
- `panelGap: 0` oder festen Pixel-Abstand zur Bar statt `screenGap: 6` + `panelGap: screenGap - Theme.barThickness` + `BarAnchor gap:`.
- `swaybg` statt `awww` annehmen.
- `Row/RowLayout` mit `anchors.fill` für `MouseArea` statt `Item` Wrapper.

## 10. Quick-Reference Pfade
- Theme: `/home/jakob/.config/quickshell/jhqs/themes/Theme.qml` (Singleton) → `modules/Theme.qml` Symlink
- Entry: `shell.qml` (`UseQApplication`, `IconTheme Papirus`, `ShellRoot closeAll/closeOthers/toggleExclusive`)
- Bar: `TopBar.qml` (Variants, `withAlpha`, Polling thickness/opacity/position DP-1)
- Module: `modules/JhqsMenu.qml` (State-Machine Navigation) `AppLauncher.qml` `ControlCenter.qml` `CalendarMenu.qml` `CalendarModel.js` `Notifications.qml` `Lockscreen.qml` `Workspaces.qml` `Clock.qml` `Launcher.qml` `Updates.qml` `VolumeOSD.qml` `BluetoothMenu.qml`
- Settings: `topbar_settings.json` `matugen.json` `matugen_settings.json` `font_settings.json` `calendar.json` `shared_menu.json` `current_wallpaper.txt` `pin` `dnd.json` `gamemode.json`
- Hyprland: `~/.config/hypr/configs/looknfeel.lua` `animations.lua`
- Scripts: `scripts/check-updates.sh` `scripts/volume.sh` `scripts/lock-auth.sh` `scripts/debug-updates.sh`
- Wallpaper: `~/Bilder/wallpapers/` `~/.cache/awww/current`
- Preview: `menu-preview.qml`

## 11. Beispiel: Korrektes Panel-Skelett
```qml
// @ pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Layouts
Scope {
  id: scope
  property bool showX: false
  signal dismissed()
  // Pflicht-Abstand: konstant 6px sichtbarer Gap zur Bar (siehe 2.3)
  readonly property int screenGap: 6
  property int panelGap: screenGap - Theme.barThickness
  readonly property string barPos: Theme.barPosition
  Variants { model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen: modelData
      visible: showX && modelData.name==="DP-1"
      color:"transparent"; exclusiveZone:0
      anchors { top:true; left:true; right:true; bottom:true }
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace:"x"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      Rectangle { anchors.fill:parent; color:Theme.scrim; opacity: showX?0.25:0; Behavior on opacity { NumberAnimation { duration:Theme.animSlow; easing.type:Theme.easingStandard } } }
      MouseArea { anchors.fill:parent; onClicked: dismissed() } // click-anywhere
      Rectangle {
        id: box
        width: 380
        implicitHeight: 400
        BarAnchor {
          id: anchor
          moduleId: "x" // Bar-Modul-ID die das Panel öffnet
          barPos: scope.barPos
          panelWidth: box.width
          panelHeight: box.implicitHeight
          screenWidth: box.parent.width
          screenHeight: box.parent.height
          gap: scope.panelGap
        }
        x: anchor.panelX
        y: anchor.panelY
        radius: Theme.cornerRadius; color: Theme.panelBg; border.color: Theme.panelBorderColor; border.width: 1
        PanelSpring {
          slideFade: true // Kalender/ControlCenter/Media-Standard: kurzer Slide+Fade, kein Zoom/Overshoot
          shown: scope.showX
          hiddenX: scope.barPos === "left" ? -(box.width + 5) : scope.barPos === "right" ? (box.width + 5) : 0
          hiddenY: scope.barPos === "top" ? -(box.implicitHeight + 5) : scope.barPos === "bottom" ? (box.implicitHeight + 5) : 0
        }
      }
    }
  }
}
```
