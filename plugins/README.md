# jhqs plugins (Omarchy-Quattro-aligned map)

Static map of the jhqs shell onto Omarchy Quattro's `shell/plugins/` layout.
Each subdirectory carries a `manifest.json` (Omarchy schema: `schemaVersion`,
`id`, `kinds`, `entryPoints`) whose `entryPoints` resolve to the real jhqs
module — **no code was moved**: `shell.qml` still loads `modules/*` directly,
so every existing import keeps working.

## Map

| Plugin | id | kinds | jhqs module |
|---|---|---|---|
| Bar | `jhqs.bar` | `bar` | `modules/TopBar.qml` + `modules/bar/*` |
| Menu | `jhqs.menu` | `menu`, `bar-widget` | `modules/JhqsMenu.qml` + `modules/jhqsmenu/` |
| Notifications | `jhqs.notifications` | `service` | `modules/Notifications.qml`, `modules/NotificationCenter.qml`, `services/HistoryService.qml` |
| OSD | `jhqs.osd` | `panel` | `modules/VolumeOSD.qml`, `modules/LaunchOSD.qml` |
| Lock screen | `jhqs.lock` | `service` | `modules/Lockscreen.qml` |
| Polkit agent | `jhqs.polkit` | `service` | `modules/Polkit.qml` |
| Settings | `jhqs.settings` | `panel` | `modules/SettingsPanel.qml` + `modules/settings/` |
| Audio | `jhqs.audio` | `bar-widget` | `modules/VolumePanel.qml` |
| Bluetooth | `jhqs.bluetooth` | `bar-widget` | `modules/BluetoothPanel.qml` |
| Network | `jhqs.network` | `bar-widget` | `modules/NetworkPanel.qml` |
| Weather | `jhqs.weather` | `bar-widget` | `modules/WeatherPanel.qml` |
| Clock | `jhqs.clock` | `bar-widget` | `modules/CalendarMenu.qml` + `modules/calendar/` |
| Power | `jhqs.power` | `bar-widget` | `modules/ControlCenter.qml` + `modules/controlcenter/` |
| Media panel | `jhqs.media-panel` | `bar-widget` | `modules/MediaPanel.qml` |
| Tray | `jhqs.tray` | `bar-widget` | `modules/SystemTrayPanel.qml` (jhqs extra) |
| Updates | `jhqs.updates` | `bar-widget` | `modules/UpdateCenterPanel.qml` (jhqs extra) |
| Media state | `jhqs.media` | `service` | `services/MediaService.qml` |
| Volume state | `jhqs.volume-service` | `service` | `services/VolumeService.qml` |
| Network state | `jhqs.network-service` | `service` | `services/NetworkService.qml` |
| Bluetooth state | `jhqs.bluetooth-service` | `service` | `services/BluetoothService.qml` |
| Update state | `jhqs.updates-service` | `service` | `services/UpdateService.qml` |
| Weather state | `jhqs.weather-service` | `service` | `services/WeatherService.qml` |

## Shared layers

| Omarchy | jhqs | note |
|---|---|---|
| `Commons/` (`Color`, `Style`, `Util`, `Border`) | `Commons/` | `Color`/`Style` are facades over `themes/Theme.qml`, which stays the single source of truth; `Util` adds jhqs shell-escaping guards; `Border` ported verbatim |
| `Ui/` (Panel, Button, …) | `Ui/` (`BarAnchor`, `PanelSpring`, `MSlider`) | jhqs shared primitives moved here (`BarAnchor`/`PanelSpring` from `modules/`, `MSlider` from `components/common/`, which is removed) |
| `services/` (PluginRegistry, BarWidgetRegistry, AppLibrary) | `services/` (8 singletons) | jhqs has no plugin registry; panel exclusivity is the `activePanel` enum in `shell.qml`, persistence is per-file `FileView` + `JsonAdapter` under `config/` |

## Deliberate divergences (do not "fix" toward Omarchy)

- **Theme**: `themes/Theme.qml` (matugen.json, 44 colors + semantic aliases) is the source of truth. Never split it into Color/Style files.
- **Config**: many small `config/*.json` files via `FileView`, not one `shell.json`.
- **Panels**: `activePanel` enum + lazy `Loader`s in `shell.qml`, not `summon`/`hide` + `Instantiator`.
- **Monitors**: only `DP-1` renders panels; `exclusiveZone` only on TopBar.
- **Manifests here are documentation**, not loaded at runtime (no `PluginRegistry`).
