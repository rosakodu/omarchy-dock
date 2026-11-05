# Project: Omarchy Dock Production Upgrade

## Architecture
- Module boundaries:
  - `DockPanel.qml`: Core layer-shell window service, background rendering, tray sync, window management.
  - `BarWidget.qml`: Tray/bar settings popup and controls.
  - `components/`: Popups (`WidgetPickerPopup.qml`, `FolderPopup.qml`, `FolderMenu.qml`), notifications (`NotificationTracker.qml`).
  - `i18n/`: 50 translation JSON catalogs, integrated via `Commons.Translations`.
  - JS modules: `DockModel.js`, `DockMatcher.js`, `DockPinned.js`, `DockAutoName.js`, `DockSettings.js`, `DockWidgets.js`, `DockLauncher.js`.
  - Scripts: `scripts/dock-minimize.py` (Hyprland window minimization).
  - Tests: `tests/` (`tst_*.qml`, `test_dock_minimize.py`, E2E test harness).

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | F1.1: 50 Language Translations | 50 JSON catalogs in i18n/ from Omarchy locale specs | M3_Localization | ORIGINAL_REQUEST R1 / Survey 1 |
| 2 | F1.2: Dynamic Language Switching | Dynamic reactivity to ~/.config/omarchy/language without restart | M3_Localization | ORIGINAL_REQUEST R1 / Survey 1 |
| 3 | F1.3: UI String Localization | Replace hardcoded English strings in BarWidget, WidgetPickerPopup, FolderPopup, FolderMenu, DockAutoName | M3_Localization | ORIGINAL_REQUEST R1 / Survey 1 |
| 4 | F2.1: 3 Tray States Detection | Reactive detection of bar.background ("opaque", "glassy", "none") from shell.json and shell.barConfig | M2_TrayStyleSync | ORIGINAL_REQUEST R2 / Survey 2 |
| 5 | F2.2: Tray Style Adaptation | Apply 100% opaque, 35% glassy background with solid crisp border (per user refinement), and 0% transparent with animations | M2_TrayStyleSync | ORIGINAL_REQUEST R2 / User Refinement |
| 6 | F3.1: Color Property Fix | Replace 26 invalid calls to Color.text with Color.foreground | M1_AuditFixes | ORIGINAL_REQUEST R3 / Survey 3 |
| 7 | F3.2: DockModel.js Export Fix | Replace var method export with typed function wrappers to fix qmllint warnings | M1_AuditFixes | ORIGINAL_REQUEST R3 / Survey 3 |
| 8 | F3.3: Comma Expression Fix | Clean up hacky comma expression in FolderPopup.qml | M1_AuditFixes | ORIGINAL_REQUEST R3 / Survey 3 |
| 9 | F3.4: Existing Test Pass | Verify all 100 existing unit tests pass cleanly in Qt6 | M1_AuditFixes | ORIGINAL_REQUEST R3 / Survey 3 |
| 10 | F4.1: E2E Test Suite Creation | Build 4-tier opaque-box test suite covering R1, R2, R3 and publish TEST_READY.md | E2E_Testing | ORIGINAL_REQUEST AC / Dual Track |
| 11 | F4.2: Full E2E & Adversarial Hardening | 100% pass of E2E suite and Tier 5 adversarial testing | M4_FinalValidation | Dual Track Final Milestone |
| 12 | F2.3: Suppress System Dock | Suppress built-in omarchy.dock on init, restore on destruction, toggle in DockSettings and BarWidget with i18n | M3_Localization | User Request (omarchy.dock suppression) |
| 13 | F3.5: Import Omarchy Pinned Apps | Fallback on empty dock-pinned.json to shell.json / defaults, plus import menu action dock.importOmarchyPins in 50 languages | M3_Localization | User Request (pinned apps import) |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | M1_AuditFixes | Fix Color.text, DockModel.js exports, FolderPopup comma expr, clean qmllint warnings, pass existing 100 tests | none | DONE |
| 2 | M2_TrayStyleSync | Implement reactive 3-state tray background detection (opaque, glassy, none) and styling in DockPanel.qml | M1_AuditFixes | DONE |
| 3 | M3_Localization | Create i18n catalogs for 50 languages, integrate Commons.Translations, bind UI strings and auto-naming, import Omarchy pins fallback | M1_AuditFixes | DONE |
| 4 | M4_FinalValidation | Verify 100% E2E test pass, adversarial test hardening, visual and runtime checks | M1_AuditFixes, M2_TrayStyleSync, M3_Localization, E2E_Testing | IN_PROGRESS |

## Interface Contracts
### M1 ↔ M2 / M3
- Color singleton accessed via `Color.foreground` (or `Commons.Color`).
- `DockModel.js` exposes clean function definitions for `setDetectedCliApps`, `parsePinned`, etc.

### M2 ↔ DockPanel / Shell
- `DockPanel.qml`: `readonly property string barStyleState`: reads `shell.barConfig.background` with fallback to `FileView` on `~/.config/omarchy/shell.json`.
- Values: `"opaque"`, `"glassy"`, `"none"`.

### M3 ↔ UI Components & Omarchy Shell
- `Commons.Translations` singleton initialized with `directory: Qt.resolvedUrl("i18n")`.
- UI strings use `strings.t("key")` binding for instantaneous dynamic reactivity (including `dock.importOmarchyPins`).
- Fallback for pinned apps reads `shell.shellConfig.dock.pinned` -> `shell.defaultsConfig.dock.pinned` -> `["org.gnome.Nautilus", "chromium", "foot", "omacalc", "omawrite", "X", "YouTube"]`.


## Code Layout
- `DockPanel.qml` — primary service and background styling
- `BarWidget.qml` — tray button and settings panel
- `components/` — sub-widgets and popups
- `i18n/` — 50 JSON translation files `<code].json`
- `scripts/` — python helper scripts
- `tests/` — unit and E2E test suites
