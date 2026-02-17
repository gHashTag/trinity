#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# RALPH PERFORMANCE GUARD (FIXED)
# ═══════════════════════════════════════════════════════════════════════════════

BASELINE=".ralph/memory/benchmark_baseline.json"
THRESHOLD=110 # Allow 10% degradation before failing

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Running Performance Verification...${NC}"

# Run benchmarks and save to temp file to avoid pipe issues
TMP_BENCH=$(mktemp)
zig build bench > "$TMP_BENCH" 2>&1

RESULTS=$(grep -A 6 "Summary:" "$TMP_BENCH")

check_perf() {
    name=$1
    current=$2
    baseline=$3
    
    if [ -z "$current" ]; then
        echo -e "${RED}ERROR: Could not parse metric for $name${NC}"
        return 1
    fi

    limit=$((baseline * THRESHOLD / 100))
    
    echo -n "Checking $name ($current ns vs $baseline ns)... "
    if [ "$current" -le "$limit" ]; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL (Degradation > 10%)${NC}"
        return 1
    fi
}

FAILED=0

# Parse current values
BIND=$(echo "$RESULTS" | grep "Bind:" | awk -F: '{print $2}' | grep -o '[0-9]\+')
BUNDLE=$(echo "$RESULTS" | grep "Bundle3:" | awk -F: '{print $2}' | grep -o '[0-9]\+')
SIM=$(echo "$RESULTS" | grep "Similarity:" | awk -F: '{print $2}' | grep -o '[0-9]\+')
DOT=$(echo "$RESULTS" | grep "Dot:" | awk -F: '{print $2}' | grep -o '[0-9]\+')
PERM=$(echo "$RESULTS" | grep "Permute:" | awk -F: '{print $2}' | grep -o '[0-9]\+')

# Parse baseline values
B_BIND=$(python3 -c "import json; print(json.load(open('$BASELINE'))['baseline_ns']['bind'])")
B_BUNDLE=$(python3 -c "import json; print(json.load(open('$BASELINE'))['baseline_ns']['bundle3'])")
B_SIM=$(python3 -c "import json; print(json.load(open('$BASELINE'))['baseline_ns']['similarity'])")
B_DOT=$(python3 -c "import json; print(json.load(open('$BASELINE'))['baseline_ns']['dot'])")
B_PERM=$(python3 -c "import json; print(json.load(open('$BASELINE'))['baseline_ns']['permute'])")

check_perf "Bind" "$BIND" "$B_BIND" || FAILED=1
check_perf "Bundle" "$BUNDLE" "$B_BUNDLE" || FAILED=1
check_perf "Similarity" "$SIM" "$B_SIM" || FAILED=1
check_perf "Dot" "$DOT" "$B_DOT" || FAILED=1
check_perf "Permute" "$PERM" "$B_PERM" || FAILED=1

rm "$TMP_BENCH"

if [ "$FAILED" -eq 1 ]; then
    echo -e "\n${RED}✘ Performance Regression Detected!${NC}"
    exit 1
else
    echo -e "\n${GREEN}✔ Performance within limits.${NC}"
    exit 0
fi
