#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=========================================================="
echo " Starting Omarchy Dock Unified E2E Test Suite"
echo " Project Root: $PROJECT_ROOT"
echo "=========================================================="

FAILED=0

echo ""
echo ">> [1/2] Running Python Unittest Test Suite (Tiers 1-4)..."
if python3 -m unittest discover -s "$SCRIPT_DIR" -v; then
    echo ">> [PASS] Python test suite completed successfully."
else
    echo ">> [FAIL] Python test suite encountered errors."
    FAILED=1
fi

echo ""
echo ">> [2/2] Running Qt6 QML Test Suite (qmltestrunner)..."
if /usr/lib/qt6/bin/qmltestrunner -import /usr/lib/qt6/qml -import /usr/share/omarchy/shell; then
    echo ">> [PASS] Qt6 QML test suite completed successfully."
else
    echo ">> [FAIL] Qt6 QML test suite encountered errors."
    FAILED=1
fi

echo ""
echo "=========================================================="
if [ "$FAILED" -eq 0 ]; then
    echo " ALL TESTS PASSED (Exit code: 0)"
    echo "=========================================================="
    exit 0
else
    echo " TEST SUITE FAILED (Exit code: 1)"
    echo "=========================================================="
    exit 1
fi
