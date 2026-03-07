#!/bin/bash
# FORGE Regression Runner v2 — Simplified
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TESTS_DIR="$SCRIPT_DIR/tests"
FORGE_BIN="$1/bin/forge"
PROJECT_ROOT="$2"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ ! -f "$FORGE_BIN" ]; then
    echo "Error: FORGE binary not found: $FORGE_BIN"
    echo "Usage: $0 <zig_out_dir> <project_root>"
    echo "Example: $0 /Users/playra/trinity-w1/zig-out /Users/playra/trinity-w1"
    exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  FORGE REGRESSION v2${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Simple test list with existing files from openxc7-synth
TESTS=(
    "blink_correct:blink_correct"
    "blink_slow:blink_slow"
    "singularity_test:singularity_d6_top"
)

PASS=0
FAIL=0

for test in "${TESTS[@]}"; do
    base=$(echo $test | cut -d':' -f1)
    top=$(echo $test | cut -d':' -f2)

    json_file="$SCRIPT_DIR/../openxc7-synth/${base}.json"
    xdc_file="$SCRIPT_DIR/../openxc7-synth/${base}.xdc"

    if [ ! -f "$json_file" ]; then
        echo -e "${RED}[SKIP] ${base}${NC} — JSON not found"
        continue
    fi

    echo -ne "${base}... "

    if "$FORGE_BIN" run \
        --input "$json_file" \
        --device xc7a100t \
        --constraints "$xdc_file" \
        --output "$SCRIPT_DIR/results/${base}_forge.bit" > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((PASS++))
    else
        echo -e "${RED}FAIL${NC}"
        ((FAIL++))
    fi
done

echo ""
echo "Results: $PASS pass, $FAIL fail"
