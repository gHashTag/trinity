#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# RALPH PROJECT AUDIT
# ═══════════════════════════════════════════════════════════════════════════════

MAX_LINES=350 # Rule 13: Modularity (~300 soft limit)

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Running Project Audit...${NC}"

FAILED=0

# 1. Check Modularity (File Size)
echo "Checking modularity (max $MAX_LINES lines)..."
FILES=$(find src -name "*.zig" -o -name "*.vibee")
for f in $FILES; do
    lines=$(wc -l < "$f")
    if [ "$lines" -gt "$MAX_LINES" ]; then
        echo -e "  ${RED}FAIL${NC} $f is too large ($lines lines)"
        FAILED=1
    fi
done

# 2. Check for TODO/FIXME
echo "Checking for unresolved markers..."
MARKERS=$(grep -rnE "TODO|FIXME" src specs | grep -v "audit.sh")
if [ ! -z "$MARKERS" ]; then
    echo -e "  ${YELLOW}WARN${NC} Found markers:"
    echo "$MARKERS" | sed 's/^/    /'
fi

# 3. Check for Binary Names (Anti-pattern detection)
echo "Checking for build system anti-patterns..."
if grep -r "./bin/vibee" .ralph > /dev/null 2>&1; then
    echo -e "  ${RED}FAIL${NC} Found reference to deprecated ./bin/vibee in .ralph/"
    FAILED=1
fi

if [ "$FAILED" -eq 1 ]; then
    echo -e "\n${RED}✘ Audit Failed!${NC}"
    exit 1
else
    echo -e "\n${GREEN}✔ Project Health OK.${NC}"
    exit 0
fi
