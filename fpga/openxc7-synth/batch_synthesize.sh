#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# BATCH BITSTREAM GENERATION
# ═══════════════════════════════════════════════════════════════════════════════
#
# Generates bitstreams for all .vibee specs at multiple consciousness levels.
# Outputs: trinity/output/fpga/<design>_<level>.bit
#
# φ² + 1/φ² = 3 = TRINITY
#
# Usage:
#   ./batch_synthesize.sh [--all-levels] [--docker]
#
# Options:
#   --all-levels    Generate for all 6 consciousness levels
#   --docker        Use Docker for synthesis (requires regymm/openxc7)
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RESET='\033[0m'

# Configuration
SPECS_DIR="../../specs/fpga"
OUTPUT_DIR="trinity/output/fpga"
TRI_BIN="../../zig-out/bin/tri"

# Consciousness levels to test
LEVELS=("conscious")
ALL_LEVELS=("dormant" "awakening" "conscious" "aware" "enlightened" "transcendent")

# Parse arguments
USE_DOCKER=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --all-levels)
            LEVELS=("${ALL_LEVELS[@]}")
            shift
            ;;
        --docker)
            USE_DOCKER=true
            shift
            ;;
        --help)
            echo "Usage: $0 [--all-levels] [--docker]"
            echo ""
            echo "Generates bitstreams for all .vibee specs."
            echo ""
            echo "Options:"
            echo "  --all-levels    Generate for all 6 consciousness levels"
            echo "  --docker        Use Docker for synthesis"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Ensure TRI is built
if [ ! -f "$TRI_BIN" ]; then
    echo -e "${RED}Error:${RESET} TRI binary not found. Building..."
    cd ../.. && zig build tri && cd fpga/openxc7-synth
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Find all .vibee specs
SPECS=($(find "$SPECS_DIR" -name "*.vibee" -type f))

if [ ${#SPECS[@]} -eq 0 ]; then
    echo -e "${RED}Error:${RESET} No .vibee files found in $SPECS_DIR"
    exit 1
fi

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}  BATCH BITSTREAM GENERATION${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${YELLOW}Specs found:${RESET} ${#SPECS[@]}"
echo -e "${YELLOW}Consciousness levels:${RESET} ${LEVELS[*]}"
echo -e "${YELLOW}Total jobs:${RESET} $(( ${#SPECS[@]} * ${#LEVELS[@]} ))"
echo ""

# Track results
PASS=0
FAIL=0
SKIP=0

# Process each spec and level
for spec in "${SPECS[@]}"; do
    spec_name=$(basename "$spec" .vibee)
    spec_file="$spec"

    echo -e "${CYAN}Processing:${RESET} $spec_name"

    for level in "${LEVELS[@]}"; do
        echo -ne "  [$level] ... "

        # Generate Verilog and XDC with TRI
        if ! $TRI_BIN fpga gen "$spec_file" --$level > /dev/null 2>&1; then
            echo -e "${RED}FAIL${RESET} (TRI gen)"
            ((FAIL++))
            continue
        fi

        # Copy generated files to work directory
        cp "trinity-nexus/output/lang/fpga/$spec_name.v" .
        cp "trinity/output/fpga/$spec_name.xdc" .

        # Run synthesis (if Docker available)
        if [ "$USE_DOCKER" = true ]; then
            if ./synth_conscious.sh --$level "${spec_name}.v" "$spec_name" > /dev/null 2>&1; then
                # Rename bitstream with consciousness level
                mv "${spec_name}.bit" "${OUTPUT_DIR}/${spec_name}_${level}.bit"
                echo -e "${GREEN}OK${RESET}"
                ((PASS++))
            else
                echo -e "${RED}FAIL${RESET} (synthesis)"
                ((FAIL++))
            fi
        else
            echo -e "${YELLOW}SKIP${RESET} (no Docker)"
            ((SKIP++))
        fi

        # Clean up intermediate files
        rm -f "${spec_name}.v" "${spec_name}.xdc" "${spec_name}.json" \
              "${spec_name}.fasm" "${spec_name}.frames" "${spec_name}_temp.xdc"
    done

    echo ""
done

# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}  SUMMARY${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "  ${GREEN}Passed:${RESET}  $PASS"
echo -e "  ${RED}Failed:${RESET}  $FAIL"
echo -e "  ${YELLOW}Skipped:${RESET} $SKIP"
echo ""

if [ $PASS -gt 0 ]; then
    echo -e "${GREEN}Generated bitstreams:${RESET}"
    ls -la "$OUTPUT_DIR"/*.bit 2>/dev/null | awk '{print "  " $9}'
    echo ""
fi

# Exit with appropriate code
if [ $FAIL -gt 0 ]; then
    echo -e "${RED}✗ Some jobs failed${RESET}"
    exit 1
elif [ $PASS -eq 0 ] && [ $SKIP -gt 0 ]; then
    echo -e "${YELLOW}⚠ No jobs run (use --docker for synthesis)${RESET}"
    exit 0
else
    echo -e "${GREEN}✓ All jobs passed${RESET}"
    echo ""
    echo -e "${CYAN}φ² + 1/φ² = 3 = TRINITY${RESET}"
    exit 0
fi
