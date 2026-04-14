#!/usr/bin/env bash
# Ambxst Test Runner
# Run QML unit tests using Qt Quick Test

set -e

# Configuration
QML_IMPORT_PATH="${QML2_IMPORT_PATH:-}"
TEST_DIR="$(cd "$(dirname "$0")" && pwd)"

# Find quickshell or qml runner
if command -v qs &> /dev/null; then
    QML_RUNNER="qs"
elif command -v qml &> /dev/null; then
    QML_RUNNER="qml"
else
    echo "Error: Neither qs nor qml found in PATH"
    exit 1
fi

# Parse arguments
VERBOSE=""
FILTER=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        -f|--filter)
            FILTER="-f $2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -v, --verbose    Verbose output"
            echo "  -f, --filter      Run only tests matching filter"
            echo "  -h, --help        Show this help"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# Build import path
IMPORT_PATHS=(
    "$TEST_DIR/.."
    "$TEST_DIR/config"
    "$TEST_DIR/modules"
    "$TEST_DIR/modules/components"
    "$TEST_DIR/modules/globals"
    "$TEST_DIR/modules/services"
    "$TEST_DIR/modules/theme"
)

IMPORT_FLAGS=""
for path in "${IMPORT_PATHS[@]}"; do
    if [[ -d "$path" ]]; then
        IMPORT_FLAGS="$IMPORT_FLAGS -I $path"
    fi
done

echo "Running Ambxst QML tests..."
echo "Test directory: $TEST_DIR"
echo "Import paths: $IMPORT_FLAGS"
echo ""

# Run tests
# Note: Qt Quick Test requires a C++ harness, so this is a placeholder
# In production, you'd use a CMake-based test runner or Qt Creator
if [[ "$QML_RUNNER" == "qml" ]]; then
    # Attempt to run with qml (limited support)
    find "$TEST_DIR" -name "tst_*.qml" | head -5 | while read testfile; do
        echo "Found test: $testfile"
    done
    echo ""
    echo "Note: Full QML test execution requires Qt Quick Test harness (CMake/qmake)"
else
    echo "Quickshell detected. Tests should be run via:"
    echo "  - CMake add_executable with qt_add_test"
    echo "  - Qt Creator test project"
fi

echo "Available test files:"
find "$TEST_DIR" -name "tst_*.qml" -type f 2>/dev/null | while read f; do
    echo "  - $(basename "$f")"
done