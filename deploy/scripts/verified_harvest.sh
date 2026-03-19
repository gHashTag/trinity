#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE v10.6: Verified Harvest Script
# ═══════════════════════════════════════════════════════════════════════════════
#
# Automated pipeline for:
# 1. Generating synthetic seeds from specs
# 2. Forging verified seeds through 4-tier validation
# 3. Running semantic deduplication
# 4. Importing verified seeds to Golden DB
#
# φ² + 1/φ² = 3
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Configuration
VIBEE_BIN="${VIBEE_BIN:-./zig-out/bin/vibee}"
MIN_QUALITY="${MIN_QUALITY:-0.8}"
PARALLEL="${PARALLEL:-4}"
DEDUP_THRESHOLD="${DEDUP_THRESHOLD:-0.95}"

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  VIBEE v10.6: Verified Harvest Pipeline                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if VIBEE binary exists
if [ ! -f "$VIBEE_BIN" ]; then
    echo -e "${RED}Error: VIBEE binary not found at $VIBEE_BIN${NC}"
    echo "Run: zig build vibee"
    exit 1
fi

# Step 1: Generate synthetic seeds (Phase 1 quality filter)
echo -e "${CYAN}[1/5] Generating synthetic seeds...${NC}"
if [ -n "$SPEC_FILES" ]; then
    GEN_OUTPUT=$($VIBEE_BIN generate-seeds $SPEC_FILES --min-quality $MIN_QUALITY 2>&1)
else
    GEN_OUTPUT=$($VIBEE_BIN generate-seeds specs/tri/*.vibee --min-quality $MIN_QUALITY 2>&1)
fi
echo "$GEN_OUTPUT"

# Step 2: Forge seeds through 4-tier validation
echo -e "${CYAN}\n[2/5] Forging verified seeds (4-tier verification)...${NC}"
FORGE_OUTPUT=$($VIBEE_BIN forge-seeds --min-quality $MIN_QUALITY --parallel $PARALLEL 2>&1)
echo "$FORGE_OUTPUT"

# Extract verified count from forge output
VERIFIED=$(echo "$FORGE_OUTPUT" | grep "VERIFIED:" | awk '{print $2}')
echo -e "${GREEN}✓ Verified: $VERIFIED seeds${NC}"

# Step 3: Semantic deduplication
echo -e "${CYAN}\n[3/5] Running semantic deduplication...${NC}"
DEDUP_OUTPUT=$($VIBEE_BIN dedupe-seeds --threshold $DEDUP_THRESHOLD 2>&1)
echo "$DEDUP_OUTPUT"

# Extract dedup stats
DUPLICATES=$(echo "$DEDUP_OUTPUT" | grep "Total duplicates:" | awk '{print $3}')
echo -e "${GREEN}✓ Duplicates found: $DUPLICATES${NC}"

# Step 4: Optional merge (set MERGE=1 to actually remove duplicates)
if [ "$MERGE" = "1" ] && [ "$DUPLICATES" -gt "0" ]; then
    echo -e "${YELLOW}\n[MERGE] Removing duplicate seeds...${NC}"
    MERGE_OUTPUT=$($VIBEE_BIN dedupe-seeds --threshold $DEDUP_THRESHOLD --merge 2>&1)
    echo "$MERGE_OUTPUT"
fi

# Step 5: Final report
echo -e "${CYAN}\n[4/5] Final Report...${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"

# Get Golden DB stats
DB_COUNT=$(echo "$DEDUP_OUTPUT" | grep "Total seeds:" | awk '{print $3}')
FILL_RATE=$(echo "$FORGE_OUTPUT" | grep "Verified rate:" | awk '{print $3}')

echo -e "${GREEN}  Golden DB Size:     $DB_COUNT seeds${NC}"
echo -e "${GREEN}  Verified Seeds:     $VERIFIED${NC}"
echo -e "${GREEN}  Verified Rate:      $FILL_RATE${NC}"
echo -e "${GREEN}  Duplicates Removed: $DUPLICATES${NC}"

echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"

echo -e "${NC}"
echo "✨ Harvest complete! Run 'vibee show-rewards' to see $TRI earnings."
