#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# RALPH QUALITY GATE
# ═══════════════════════════════════════════════════════════════════════════════

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Running Ralph Quality Gate...${NC}"

# 1. Branch Check
BRANCH=$(git branch --show-current)
echo -n "Checking branch safety... "
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
    echo -e "${RED}FAILED${NC}"
    echo "Error: Committed to private branch ($BRANCH). Please use ralph/<task-slug>."
    exit 1
fi
echo -e "${GREEN}OK ($BRANCH)${NC}"

# 2. Build Check
echo -n "Checking build... "
if zig build > /dev/null 2>&1; then
    echo -e "${GREEN}PASSED${NC}"
else
    echo -e "${RED}FAILED${NC}"
    zig build
    exit 1
fi

# 3. Test Check
echo -n "Checking tests... "
if zig build test > /dev/null 2>&1; then
    echo -e "${GREEN}PASSED${NC}"
else
    echo -e "${RED}FAILED${NC}"
    zig build test
    exit 1
fi

# 4. Format Check
echo -n "Checking formatting... "
if zig fmt --check src/ > /dev/null 2>&1; then
    echo -e "${GREEN}CLEAN${NC}"
else
    echo -e "${RED}FAILED${NC}"
    echo "Action required: Run 'zig fmt src/'"
    exit 1
fi

echo -e "\n${GREEN}✔ Quality Gate Passed!${NC} (φ² + 1/φ² = 3)"
