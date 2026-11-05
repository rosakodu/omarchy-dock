# Omarchy Dock Test Infrastructure Specification

## 1. Overview
Dual-track opaque-box E2E testing framework for the Omarchy Dock plugin.
The test harness verifies functional requirements, edge cases, cross-feature interactions, and real-world desktop workflows across Qt6 QML and Python runtimes without altering plugin implementation code.

## 2. Test Runtimes & Frameworks
- **Qt6 QmlTest (`/usr/lib/qt6/bin/qmltestrunner`)**:
  - Target: QML components, JavaScript business logic, dynamic bindings, and state transitions.
  - Import paths: `/usr/lib/qt6/qml`, `/usr/share/omarchy/shell`.
- **Python 3 `unittest`**:
  - Target: IPC window management, localization catalogs, tray state derivation, schema validation, configuration fault tolerance, and end-to-end integration workflows.

## 3. Directory Layout
```
tests/
├── run_all_tests.sh                     # Unified test suite runner (exit code 0 on pass)
├── test_dock_minimize.py                # Unit tests for scripts/dock-minimize.py (14 tests)
├── tst_DockMatcher.qml                  # Unit tests for DockMatcher.js (18 tests)
├── tst_DockSettings.qml                 # Unit tests for DockSettings.js (63 tests)
├── tst_DockWidgets.qml                  # Unit tests for DockWidgets.js (5 tests)
├── tst_Tier1_TraySync.qml               # Tier 1 QML tests for tray 3-state styling logic
├── tst_Tier1_Localization.qml           # Tier 1 QML tests for dynamic translation bindings
├── test_tier1_localization_feature.py   # Tier 1 tests for 50 Omarchy locales (R1)
├── test_tier1_tray_sync_feature.py      # Tier 1 tests for 3 tray states adaptation (R2)
├── test_tier1_window_minimize_feature.py# Tier 1 tests for window minimize & IPC (R3)
├── test_tier2_boundary_corner_cases.py  # Tier 2 tests for RTL, corrupted configs, edge inputs
├── test_tier3_cross_feature_combinations.py # Tier 3 tests for pairwise feature interactions
└── test_tier4_real_world_scenarios.py   # Tier 4 tests for user workflows and session lifecycle
```

## 4. Test Tier Architecture
- **Tier 1 — Feature Coverage**: Minimum 5 tests per requirement (R1: 50 languages, R2: 3 tray states, R3: window minimize & IPC).
- **Tier 2 — Boundary & Corner Cases**: RTL languages, language change during animation, invalid/corrupted configs, fallback cascades, extreme inputs.
- **Tier 3 — Cross-Feature Combinations**: Pairwise interactions (language + tray style + window switching; RTL + tray none; malformed config resilience).
- **Tier 4 — Real-World Application Scenarios**: Cold boot initialization, rapid window minimize/restore cycles, settings panel toggling, on-the-fly language updates.

## 5. Execution Commands
```bash
# Execute entire test suite (Python + Qt6 QML)
./tests/run_all_tests.sh

# Run only Python unit and E2E tests
python3 -m unittest discover -s tests -v

# Run only Qt6 QML tests
/usr/lib/qt6/bin/qmltestrunner -import /usr/lib/qt6/qml -import /usr/share/omarchy/shell
```

## 6. Exit Code Contract
- Exit code `0`: All test suites passed without errors or failures.
- Non-zero exit code: One or more test assertions failed, blocking release gates.
