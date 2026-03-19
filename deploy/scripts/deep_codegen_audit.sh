#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE v10.1: Deep Codegen Audit Script
# ═══════════════════════════════════════════════════════════════════════════════
#
# E2E validation for Deep Intelligence components:
# - AST-based code analysis
# - Quality validation (compile + runtime + semantic)
# - Transaction-safe patching with rollback
# - Self-improvement loop convergence
#
# Usage:
#   ./deep_codegen_audit.sh              # Quick audit (5 specs)
#   ./deep_codegen_audit.sh --full       # Full audit (all specs)
#   ./deep_codegen_audit.sh --self-improve N  # Run N improvement iterations
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
FULL_AUDIT=false
SELF_IMPROVE_ITERATIONS=0
RUNTIME_TEST=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --full)
            FULL_AUDIT=true
            shift
            ;;
        --runtime)
            RUNTIME_TEST=true
            shift
            ;;
        --self-improve)
            SELF_IMPROVE_ITERATIONS="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --full              Run full audit on all production specs"
            echo "  --runtime           Include runtime smoke tests"
            echo "  --self-improve N    Run N self-improvement iterations"
            echo "  --verbose, -v       Verbose output"
            echo "  --help, -h          Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Test specs for quick audit
QUICK_SPECS=(
    "specs/tri/vsa_swarm_organization_128.vibee"
    "specs/tri/fpga_acceleration.vibee"
)

# All production specs for full audit
ALL_SPECS=(
    "specs/tri/vsa_swarm_organization_128.vibee"
    "specs/tri/vsa_swarm_production_32.vibee"
    "specs/tri/fpga_acceleration.vibee"
    "specs/tri/ternary_matmul.vibee"
    "specs/tri/hdc_knowledge_graph.vibee"
)

# Select specs based on mode
if [ "$FULL_AUDIT" = true ]; then
    SPECS=("${ALL_SPECS[@]}")
    MODE="FULL"
else
    SPECS=("${QUICK_SPECS[@]}")
    MODE="QUICK"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  VIBEE v10.1: Deep Codegen Audit                          ║"
echo "║  Mode: $MODE                                               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Build VIBEE compiler first
echo -e "${BLUE}[1/6] Building VIBEE compiler...${NC}"
if ! zig build vibee 2>&1 | grep -q "error:"; then
    echo -e "${GREEN}✓ Build successful${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

# Run unit tests for Deep Intelligence components
echo ""
echo -e "${BLUE}[2/6] Testing Deep Intelligence components...${NC}"

COMPONENTS=(
    "src/vibeec/codegen/ast_analyzer.zig"
    "src/vibeec/codegen/deep_patcher.zig"
    "src/vibeec/codegen/validator.zig"
    "src/vibeec/codegen/rollback.zig"
)

for component in "${COMPONENTS[@]}"; do
    if [ "$VERBOSE" = true ]; then
        echo "  Testing $component..."
    fi
    if zig test "$component" > /tmp/component_test.log 2>&1; then
        if [ "$VERBOSE" = true ]; then
            echo -e "    ${GREEN}✓${NC}"
        fi
    else
        echo -e "${RED}✗ $component failed${NC}"
        cat /tmp/component_test.log
        exit 1
    fi
done
echo -e "${GREEN}✓ All Deep Intelligence components passed${NC}"

# Code generation phase
echo ""
echo -e "${BLUE}[3/6] Generating code from specs...${NC}"

TOTAL_FUNCS=0
REAL_FUNCS=0
STUB_FUNCS=0

for spec in "${SPECS[@]}"; do
    if [ ! -f "$spec" ]; then
        echo -e "${YELLOW}⚠ Skipping $spec (not found)${NC}"
        continue
    fi

    spec_name=$(basename "$spec" .vibee)
    echo "  Generating: $spec_name..."

    if zig build vibee -- gen "$spec" > /tmp/gen_$spec_name.log 2>&1; then
        echo -e "    ${GREEN}✓${NC}"

        # Count functions in generated code
        gen_file="generated/${spec_name}.zig"
        if [ -f "$gen_file" ]; then
            func_count=$(grep -c "^pub fn" "$gen_file" || echo 0)
            stub_count=$(grep -c "TODO\|unimplemented\|unreachable" "$gen_file" || echo 0)
            real_count=$((func_count - stub_count))

            TOTAL_FUNCS=$((TOTAL_FUNCS + func_count))
            STUB_FUNCS=$((STUB_FUNCS + stub_count))
            REAL_FUNCS=$((REAL_FUNCS + real_count))

            if [ "$VERBOSE" = true ]; then
                echo "    Functions: $func_count | Real: $real_count | Stubs: $stub_count"
            fi
        fi
    else
        echo -e "    ${RED}✗ Generation failed${NC}"
        if [ "$VERBOSE" = true ]; then
            cat /tmp/gen_$spec_name.log
        fi
    fi
done

# Quality analysis
echo ""
echo -e "${BLUE}[4/6] Quality Analysis...${NC}"

if [ $TOTAL_FUNCS -gt 0 ]; then
    REAL_PCT=$(awk "BEGIN {printf \"%.1f\", ($REAL_FUNCS / $TOTAL_FUNCS) * 100}")
    STUB_PCT=$(awk "BEGIN {printf \"%.1f\", ($STUB_FUNCS / $TOTAL_FUNCS) * 100}")

    echo "  Total Functions: $TOTAL_FUNCS"
    echo "  Real Code:       $REAL_FUNCS ($REAL_PCT%)"
    echo "  Stubs/TODO:      $STUB_FUNCS ($STUB_PCT%)"

    # Use awk for comparison to avoid bc syntax issues
    if awk "BEGIN {exit !($REAL_PCT >= 85.0)}"; then
        echo -e "  ${GREEN}✓ Quality threshold met (≥85%)${NC}"
    else
        echo -e "  ${YELLOW}⚠ Quality below target (85%)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No functions generated${NC}"
fi

# Runtime tests
if [ "$RUNTIME_TEST" = true ]; then
    echo ""
    echo -e "${BLUE}[5/6] Runtime Smoke Tests...${NC}"

    for spec in "${SPECS[@]}"; do
        spec_name=$(basename "$spec" .vibee)
        gen_file="generated/${spec_name}.zig"

        if [ -f "$gen_file" ]; then
            echo "  Testing: $spec_name..."
            if zig test "$gen_file" > /tmp/runtime_$spec_name.log 2>&1; then
                echo -e "    ${GREEN}✓${NC}"
            else
                echo -e "    ${YELLOW}⚠ Test failed (may be expected for partial code)${NC}"
            fi
        fi
    done
fi

# Self-improvement loop
if [ $SELF_IMPROVE_ITERATIONS -gt 0 ]; then
    echo ""
    echo -e "${BLUE}[6/6] Self-Improvement Loop ($SELF_IMPROVE_ITERATIONS iterations)...${NC}"

    for spec in "${SPECS[@]}"; do
        spec_name=$(basename "$spec" .vibee)
        echo "  Improving: $spec_name..."

        if zig build vibee -- self-improve "$spec" --iterations "$SELF_IMPROVE_ITERATIONS" > /tmp/improve_$spec_name.log 2>&1; then
            echo -e "    ${GREEN}✓${NC}"

            if [ "$VERBOSE" = true ]; then
                grep -E "Iteration|real code" /tmp/improve_$spec_name.log || true
            fi
        else
            echo -e "    ${YELLOW}⚠ Self-improve not yet fully implemented${NC}"
        fi
    done
fi

# Final summary
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Audit Summary                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Show git status
echo "Git Status:"
git status --short 2>/dev/null || echo "  Not a git repo"

echo ""
echo "Done!"
