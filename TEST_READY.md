# TEST_READY: Omarchy Dock E2E Test Suite (Dual Track)

## 1. Readiness Declaration
- **Status**: READY
- **Date**: 2026-11-05
- **Integrity**: Dual Track Opaque-Box E2E Suite (Zero modification to plugin code outside `tests/`)
- **Total Tests**: 144 tests (100 Qt6 QML tests + 44 Python unittest tests)
- **Pass Rate**: 100% (144 passed, 0 failed, 0 errors, 0 skipped)

## 2. Test Coverage Matrix

| Tier | Focus / Scope | Requirements Covered | Test Files | Tests Count | Status |
|---|---|---|---|---|---|
| **Tier 1** | Feature Coverage (>=5 tests per feature) | R1: 50 Languages<br>R2: 3 Tray States<br>R3: Minimize & IPC | `tests/test_tier1_localization_feature.py`<br>`tests/test_tier1_tray_sync_feature.py`<br>`tests/test_tier1_window_minimize_feature.py`<br>`tests/tst_Tier1_Localization.qml`<br>`tests/tst_Tier1_TraySync.qml` | 27 tests | PASS |
| **Tier 2** | Boundary & Corner Cases | R1: RTL Languages<br>R2: Corrupted configs<br>R3: Edge queries & fallback | `tests/test_tier2_boundary_corner_cases.py` | 6 tests | PASS |
| **Tier 3** | Cross-Feature Combinations | R1 + R2 + R3 pairwise interactions | `tests/test_tier3_cross_feature_combinations.py` | 5 tests | PASS |
| **Tier 4** | Real-World Application Scenarios | User lifecycle workflows (Cold boot, lifecycle, settings, hot-reload) | `tests/test_tier4_real_world_scenarios.py` | 4 tests | PASS |
| **Baseline** | Regression & Logic Modules | R3: Unit test baseline (DockMatcher, Settings, Widgets, Minimize) | `tests/test_dock_minimize.py`<br>`tests/tst_DockMatcher.qml`<br>`tests/tst_DockSettings.qml`<br>`tests/tst_DockWidgets.qml` | 102 tests | PASS |
| **Total** | **Comprehensive E2E Suite** | **R1, R2, R3** | **11 test artifacts + runner** | **144 tests** | **100% PASS** |

## 3. Requirement Traceability
- **R1: 50 Languages & Dynamic i18n**:
  - `tests/test_tier1_localization_feature.py`: 50 registered locales from `/usr/share/omarchy/default/i18n/locales.json`, dialect fallback cascade (`pt-BR` -> `pt` -> `en`), CLDR plural rules (en, ru, ar, ja), decimal formatting.
  - `tests/tst_Tier1_Localization.qml`: QML translation bindings, RTL direction detection, `%1` argument substitutions, auto-naming category mapping.
  - `tests/test_tier2_boundary_corner_cases.py`: RTL languages identification (`ar`, `fa`, `he`, `ur`), rapid sequential language switching.
- **R2: 3 Tray States Synchronization**:
  - `tests/test_tier1_tray_sync_feature.py`: 3-state detection precedence (`shell.barConfig` > `shell.json` > legacy `transparent` > `opaque`), property computations (opaque alpha 1.0, glassy alpha 0.35 + blur, none alpha 0.0 + zero border), dynamic transitions.
  - `tests/tst_Tier1_TraySync.qml`: QML tray state precedence, alpha/border metrics, corrupted values fallback.
  - `tests/test_tier2_boundary_corner_cases.py`: Invalid config fallback, unhandled background values fallback.
  - `tests/test_tier3_cross_feature_combinations.py`: RTL language + glassy tray, transparent tray + overlay mode, autohide + tray styling.
- **R3: Codebase Audit & Window Minimization**:
  - `tests/test_tier1_window_minimize_feature.py`: Address queries, index selectors, active vs minimized target priority, `special:minimized` workspace detection, safe desktop file resolution.
  - `tests/test_tier2_boundary_corner_cases.py`: Edge inputs, bare hex identifiers vs `0x` addresses, out-of-bounds index fallback, empty candidates.
  - `tests/test_tier4_real_world_scenarios.py`: Full cold-boot initialization, minimize-to-special and restore cycle, settings toggle hot-reload.

## 4. Execution Commands
```bash
# Execute entire test suite (unified runner)
./tests/run_all_tests.sh

# Run only Python tests
python3 -m unittest discover -s tests -v

# Run only Qt6 QML tests
/usr/lib/qt6/bin/qmltestrunner -import /usr/lib/qt6/qml -import /usr/share/omarchy/shell
```
