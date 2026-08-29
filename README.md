# Omarchy Dock

![Omarchy Dock](./preview.png)

A modern, highly polished, and fully native application dock plugin for **Omarchy Quattro** (Hyprland + Quickshell), featuring app stacks (folders), iOS-style edit wiggle animations, multi-window management, dynamic orientation, and seamless theme integration.

---

## ✨ Features

- 🧩 **Integrated Dock Widgets** — Move native system widgets (Weather, Volume & Audio, Bluetooth, Network, Power/Battery, Display, Clock/Calendar, Tailscale VPN) directly into the dock. Choose widget placement (Left or Right) via the dedicated widget configuration popup. When clicked, all widget panels appear centered on screen with clean system spacing.
- 📁 **App Stacks (Folders)** — Organize apps into folders with multi-column grids. Create folders by simply dragging one icon onto another. Customize folder icons with built-in Nerd Font glyphs, edit titles inline, and enjoy marquee text scrolling for long names. Folders seamlessly remain open when launching or switching applications.
- ✨ **iOS-Style Edit Mode (Wiggle)** — Long-press (450ms) any icon to enter edit mode with smooth physical wobbling ($\pm 3.8^\circ$, 105ms). Quickly toggle favorite pins (`•`), dissolve folders (`-`), remove dock widgets (`-`), or reorder apps.
- 🔀 **Fluid 1D & 2D Drag & Drop** — Smooth rail displacement physics when dragging apps across the dock or within folder grids. Effortlessly extract apps from folders back to the main dock.
- 🔄 **Multi-Instance Sliding Viewport (Infinite Wheel Scrolling)** — Hover over any running app with duplicate windows and scroll the mouse wheel to cycle through instances. The status capsule uses a smooth 3-slot sliding viewport: the original app is always a distinct wide dash (`━`), while duplicates are round dots (`•`). As you scroll deeper into duplicates, the original dash smoothly scrolls out of view and reappears when looping back.
- 🎯 **Real-Time Hyprland IPC Focus Sync** — Moving the mouse cursor over any window tile on the desktop (`follow_mouse = 1`) or switching focus instantly syncs and highlights the corresponding slot on the dock in real time without lag.
- ⚡ **Dedicated Controls (LMB & Middle-Click)** — Left-click opens closed apps or focuses/activates running windows. Middle-click (pressing the mouse wheel) instantly spawns a new duplicate instance anytime.
- 👁️ **Smart Cursor Hiding** — The mouse cursor is automatically hidden (`Qt.BlankCursor`) during mouse wheel scrolling and folder title hover to ensure an unobstructed view of the status capsule and animations.
- 🌐 **Full Web Apps (PWA) Support** — Automatic domain matching for Chrome/Chromium web apps (Google Maps, Google Contacts, WhatsApp, YouTube, Discord, etc.) with native GTK theme icons.
- ⚡ **Zero-Flicker Boot & Tile Lift** — Two-phase initialization instantly reserves Hyprland exclusive space to lift tiled windows smoothly, followed by a monolithic fade-in once all vector theme icons are loaded.
- 🧭 **Dynamic Auto-Positioning** — Automatically adapts its position opposite to the Omarchy status bar (top $\leftrightarrow$ bottom, left $\leftrightarrow$ right) and draws a dock on every connected monitor.
- ⏱️ **Flexible Visibility** — Keep the dock visible, reveal it from the screen edge, or toggle it through a Hyprland keybinding.
- 🪟 **Native Overlay Mode** — Float the dock above full-screen/tiling windows without shifting Hyprland window arrangements (macOS / Dash to Dock behavior).
- 🔔 **Real-Time Notification Badges** — Dynamic unread badges on app icons aggregated from D-Bus notifications, Hyprland dwell timers, and window titles.
- 🎛️ **Status Bar Settings Widget (`BarWidget`)** — Native top bar menu for dock visibility, workspace targeting, Overlay Mode, folder titles, notification badges, and dock widgets.
- 🎨 **100% Native Theme Sync** — Clean borderless status capsules that automatically react to Omarchy colors (`Color.accent`, `Color.bar.background`), system fonts, and window corner radius tokens.
- 🔤 **Subpixel Vector Glyphs (`DockGlyph`)** — GPU-accelerated vector curve rendering without font hinting distortion or pixel jitter during animations.

---

## 🎮 Controls & Shortcuts

| Action | Control | Description |
| :--- | :--- | :--- |
| **Open / Focus Window** | `Left-Click` / `Enter` | Opens the application if closed, or activates and focuses the chosen window tile/duplicate. |
| **Launch Duplicate** | `Middle-Click` / `Tab` | Instantly spawns a new duplicate instance of the application with immediate focus. |
| **Cycle Duplicates** | `Mouse Wheel` / `←` `→` Arrow Keys | Cycles through duplicate windows via 3-slot sliding viewport (original dash `━` and duplicate dots `•`). |
| **Open Widget Panel** | `Left-Click` *(on Widget)* | Opens the hosted system widget panel (Audio, Wi-Fi, BT, Power, Monitor, etc.) centered on screen. |
| **Enter Edit Mode** | `Long-Press` *(450ms)* | Activates iOS-style physical wobble mode to reorder apps, toggle pins, remove widgets, or dissolve folders. |
| **Reorder & Folders** | `Drag & Drop` | Drag along the rail to reorder. Drag one icon onto another to create a folder (App Stack). |
| **Folder Icon Picker** | `Right-Click` *(on Folder)* | Opens the Nerd Font glyph picker to customize the folder's icon. |
| **Exit Edit Mode / Close Menus** | `Right-Click` / `Escape` | Instantly exits edit mode and dismisses open menus. |
| **Toggle Pin State** | `Click • Badge` *(in Edit Mode)* | Pins or unpins the application to/from favorites. |
| **Dissolve Folder / Remove Widget**| `Click - Badge` *(in Edit Mode)* | Dissolves folder back to dock, or returns widget back to system status bar tray. |

---

## 📦 Installation

Install and enable the dock with a single command:

```bash
omarchy plugin add https://github.com/rosakodu/omarchy-dock.git --enable
```

---

## ⚙️ Configuration

The dock works out of the box with zero configuration required. With `visibleWorkspace` set to `all` (the default), a dock is created on every Hyprland monitor — the same per-output pattern as the Omarchy status bar. Pinning the dock to a specific workspace still shows it only on the monitor that currently displays that workspace.

You can customize options directly via the `···` status bar widget or in `~/.config/omarchy/dock-settings.json`:

```json
{
  "dockEnabled": true,
  "visibilityMode": "always",
  "overlayMode": false,
  "visibleWorkspace": "all",
  "showFolderTitles": true,
  "showBadges": true,
  "widgetsEnabled": true,
  "widgetPosition": "left",
  "dockWidgets": [
    "omarchy.apps"
  ]
}
```

`visibilityMode` accepts `always`, `hover`, or `keybind`. `overlayMode` uses the
native v1.5.0 implementation: `false` reserves screen space and `true` floats
the dock above tiled windows.
`visibleWorkspace` accepts `all`, a numeric workspace ID, or a Hyprland
workspace name. With `all`, a keyboard opening targets the workspace and
monitor containing the focused window and keeps that target until the dock is
closed. With an explicit selector, the dock always targets that workspace and
can open only while the workspace is active on a monitor.

### Keyboard toggle

Keyboard shortcuts belong to Hyprland, so the plugin never edits your Omarchy
bindings automatically. To use `SUPER + SHIFT + D`, add this to
`~/.config/hypr/bindings.lua`:

```lua
-- Omarchy assigns this shortcut to Docker by default, so replace it explicitly.
hl.unbind("SUPER + SHIFT + D")
o.bind("SUPER + SHIFT + D", "Dock", "omarchy-shell -q rosakodu.dock toggleReveal")
```

Choose any other key combination by changing the first argument to `o.bind`.
The shortcut works when `visibilityMode` is `always` or `keybind`; `hover`
accepts only the screen-edge trigger. If the dock is already visible, the first
press closes it without moving it and the next press opens it on the current
target. In `keybind` mode the dock starts hidden and automatically hides after
the same 1.5-second inactivity delay used by hover mode. Keeping the pointer or
a dock popup active pauses the dismissal timer.

Pinned items and folder layouts are automatically saved to `~/.config/omarchy/dock-pinned.json`.

---

## 🗑️ Uninstallation

```bash
omarchy plugin remove rosakodu.dock
```

---

## 📄 License

[MIT](./LICENSE) © 2026 rosakodu
