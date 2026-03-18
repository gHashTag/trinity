#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY FPGA Simulation Framework — Test Runner
# ═══════════════════════════════════════════════════════════════════════════════
#
# Run FPGA simulation tests without physical hardware
# Output: results.json
#
# Usage: ./run_all_tests.sh [--vsa|--tqnn|--uart|--scheduler|--all]
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Output file
OUTPUT_FILE="${OUTPUT_FILE:-results.json}"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  TRINITY FPGA Simulation Test Runner${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Golden Identity: φ² + 1/φ² = 3"
echo ""

# Check if zig is available
if ! command -v zig &> /dev/null; then
    echo -e "${RED}Error: zig not found. Please install Zig 0.15.x${NC}"
    echo "Download from: https://ziglang.org/download/"
    exit 1
fi

# Display Zig version
ZIG_VERSION=$(zig version 2>&1)
echo "Zig version: $ZIG_VERSION"
echo ""

# Build and run tests
echo -e "${GREEN}Running tests...${NC}"
echo ""

# Run the test runner
if zig run test_runner.zig -- "$@" --output="$OUTPUT_FILE"; then
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✓ Tests completed successfully!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Results saved to: $OUTPUT_FILE"
    echo ""

    # Display summary from JSON
    if command -v jq &> /dev/null; then
        echo "Test Summary:"
        jq '.summary' "$OUTPUT_FILE" 2>/dev/null || echo "  (jq not available for pretty print)"
    else
        echo "Install jq for pretty JSON output: brew install jq"
    fi

    exit 0
else
    echo ""
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  ✗ Tests failed!${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    exit 1
fi
