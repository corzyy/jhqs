# jhqs — Architecture (post-restructure 2026-09-02, Omarchy-Quattro layout 2026-09-09)

## File Tree
```
jhqs/
├── shell.qml              — the ONLY file in the root (entry point: UseQApplication,
│                             IconTheme Papirus, closeAll/closeOthers/toggleExclusive, IpcHandler jhqs)
│
├── Commons/               — Omarchy-Quattro parity: Color/Style facades over
│                             themes/Theme.qml (source of truth stays Theme) +
│                             Util (pure helpers) + Border/BorderGeometry.js (ported)
│
├── Ui/                    — shared visuals: BarAnchor + PanelSpring (from modules/),
│                             MSlider.qml (from components/common/, removed)
│
├── plugins/               — static manifest map onto Omarchy's shell/plugins/
│                             (22x manifest.json + README; entryPoints resolve to
│                             the real modules/*, services/* — no code moved,
│                             nothing loaded from here at runtime)
│
├── config/                — canonical settings & state (FileView watchers point here)
│   ├── topbar_settings.json (thickness/opacity/position/radius/animations/…)
│   ├── calendar.json, dnd.json, gamemode.json, powermode.json
│   ├── font_settings.json, shared_menu.json
│   ├── current_wallpaper.txt, pin
│
├── themes/                — Theme singleton + theme-engine data
│   ├── qmldir             — `singleton Theme 1.0 Theme.qml` (filesystem import)
│   ├── Theme.qml          — 44-color matugen palette + semantic aliases (source of truth)
│   ├── matugen.json       — written by the matugen binary (see ~/.config/matugen/config.toml)
│   ├── matugen_settings.json, theme_engine.json + preset jsons
│
├── services/              — singletons, no UI
│   ├── qmldir             — singleton registrations (History/Update/Network/VolumeService)
│   ├── HistoryService.qml — notification history (max 100)
│   ├── UpdateService.qml  — pacman+aur+flatpak polling, check-updates.sh (menu updates in JhqsMenu)
│   ├── NetworkService.qml — nmcli poll every 4s (bar icon only)
│   └── VolumeService.qml  — Pipewire.defaultAudioSink + fallback volume.sh, OSD trigger
│
├── modules/
│   ├── TopBar.qml         — bar shell (delegates to services + modules/bar/*)
│   ├── bar/               — bar atoms: Workspaces, Clock, Launcher, UpdatesIndicator, WeatherWidget,
│   │                         ControlCenterIcons, MediaWidget, ActiveWindow, SystemTray (Quattro drawer)
│   ├── calendar/          — CalendarModel.js (canonical math) + CalendarHeader/Grid/Footer + MusicPlayer
│   ├── controlcenter/     — NotificationCenter + tiles/ + pickers/ (tray lives in bar/SystemTray + SystemTrayPanel)
│   ├── jhqsmenu/          — ThemeEngine.qml + categories/ + views/
│   ├── notifications/     — NotificationCard.qml (Notifications.qml is the list shell)
│   └── AppLauncher, CalendarMenu, ControlCenter, JhqsMenu, Lockscreen, Notifications, Polkit, VolumeOSD, WeatherPanel, SystemTrayPanel, MediaPanel
│                             (all panels: `import "../Ui"` → BarAnchor/PanelSpring;
│                             sliders: `import "../Ui" as Ui` → Ui.MSlider)
│
├── scripts/
│   ├── check-updates.sh, volume.sh, lock-auth.sh (reads config/pin), run-update.sh,
│   │   debug-updates.sh, test-polkit.sh, render-everforest.py
 │   └── tui/               — flatpak-tui.py, flatpak-tui-remove.py
│
└── docs/                  — this file
```

## Import system (no root qmldir)
The root contains only `shell.qml`. There is no `qs` module anymore — singletons are
registered per-directory via local `qmldir` files and imported as filesystem directories:

- `import "./themes"` (or `"../themes"`, `"../../themes"`, …) → `Theme`
- `import "./services"` → `HistoryService`, `UpdateService`, `NetworkService`, `VolumeService`, `MediaService`, `WeatherService` (+ `WeatherModel.js` helpers)
- `import "./modules" as Modules` → `Modules.TopBar`, `Modules.ControlCenter`, …
- services referencing a sibling singleton use `import "."` (e.g. UpdateService → NetworkService)

Rules learned the hard way:
- Never bare-import a directory whose subdirectory is also bare-imported in the same file
  (nondeterministic "X is not a type" in quickshell) — namespace those imports (`as CC`).
- themes/ and services/ are top-level siblings, safe to bare-import everywhere.

## Settings paths
All FileView watchers and init scripts use `~/.config/quickshell/jhqs/config/<name>.json`
(topbar_settings, calendar, dnd, gamemode, powermode, font_settings, shared_menu) plus
`config/current_wallpaper.txt` and `config/pin`. Theme-engine data stays in `themes/`
(matugen binary writes `themes/matugen.json` per ~/.config/matugen/config.toml).
Init pattern: `mkdir -p ~/.config/quickshell/jhqs/config; if [ ! -f … ]; then echo default;
jq '.key //= default' > /tmp/x.json && mv` — never raw echo over existing json.

## Migration rules (skill jhqs)
- New popups → register in shell.qml closeAll/closeOthers + Modules.X { showX }
- Colors/radius/anim → only Theme.* (never hex literal, no Easing.* raw; fixed exceptions:
  quit-hover #3a2a2e/#6b3a40, #ffffff highlight alpha, theme-preset preview dots)
- Persistence → FileView + JsonAdapter + writeAdapter() + clamp
- Panel dims → Theme.sharedMenuWidth/Height (config/shared_menu.json)
- IPC → `quickshell ipc -c jhqs call <target> <func>`
- DP-1 exclusiveZone only TopBar; others visible: modelData.name==="DP-1"
- Every panel body: Flickable { clip:true; boundsBehavior: StopAtBounds; contentHeight: col.implicitHeight }

## Splits & removals — see git history / earlier reports (2026-09-01 / 2026-09-02)
ControlCenter/CalendarMenu/JhqsMenu split into sections; dead network+airplane polling,
misc/ wrappers, SearchField/StyledPanel, root theme_engine.json + nightlight.json removed.

## Verification
```
timeout 3 quickshell -p ~/.config/quickshell/jhqs/shell.qml --verbose 2>&1 | head -80  # expect "Configuration Loaded", no ERROR
quickshell ipc -c jhqs call jhqs state
quickshell ipc -c jhqs call updates status
```
