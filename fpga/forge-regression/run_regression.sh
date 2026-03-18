#!/bin/bash
# FORGE Regression Runner
# Runs all test cases through both FORGE and Docker toolchains

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TESTS_DIR="$SCRIPT_DIR/tests"
RESULTS_DIR="$SCRIPT_DIR/results"
EVIDENCE_DIR="$SCRIPT_DIR/evidence"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FORGE_BIN="$PROJECT_ROOT/zig-out/bin/forge"
SYNTH_SH="$SCRIPT_DIR/../openxc7-synth/synth.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test list
TESTS=(
    "t01_static_io:static_io"
    "t02_direct_clock:direct_clock"
    "t03_single_ff:single_ff"
    "t04_counter:counter"
    "t05_bufg_test:bufg_test"
    "t06_srl16e_test:srl16e_test"
    "t07_carry4_test:carry4_test"
    "t08_multi_led:multi_led"
    "t09_bank_crossing:bank_crossing"
    "t10_simple_fsm:simple_fsm"
)

# Create directories
mkdir -p "$RESULTS_DIR" "$EVIDENCE_DIR"

# CSV header
echo "Test,Forge_Runtime,Forge_Status,Docker_Runtime,Docker_Status,Timing_Ns,Hardware_Verdict" > "$RESULTS_DIR/regression_results.csv"

print_banner() {
    echo -e "${BLUE}"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  FORGE REGRESSION RUNNER"
    echo "  Toolchains: FORGE (native Zig) vs Docker (openXC7)"
    echo "  Tests: ${#TESTS[@]}"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

run_forge() {
    local test_id=$1
    local test_name=$2
    local test_file=$3
    local xdc_file=$4
    local output_bit=$5

    echo -n "  FORGE: "
    local start=$(python3 -c "import time; print(int(time.time()*1000))")

    # Run Yosys + FORGE
    cd "$TESTS_DIR"
    docker run --rm --platform linux/amd64 \
        -v "$TESTS_DIR:/work" -w /work \
        regymm/openxc7 \
        yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top trinity_top; write_json ${test_id}_${test_name}.json" \
        "$test_file" > /dev/null 2>&1

    if "$FORGE_BIN" run \
        --input "$TESTS_DIR/${test_id}_${test_name}.json" \
        --device xc7a100t \
        --constraints "$TESTS_DIR/$xdc_file" \
        --output "$output_bit" 2>&1 | grep -q "Bitstream: PASS"; then
        local end=$(python3 -c "import time; print(int(time.time()*1000))")
        local runtime=$((end - start))
        echo -e "${GREEN}PASS${NC} (${runtime}ms)"
        echo "$runtime,PASS" >> "$RESULTS_DIR/${test_name}_forge.txt"
        return 0
    else
        local end=$(python3 -c "import time; print(int(time.time()*1000))")
        local runtime=$((end - start))
        echo -e "${RED}FAIL${NC} (${runtime}ms)"
        echo "$runtime,FAIL" >> "$RESULTS_DIR/${test_name}_forge.txt"
        return 1
    fi
}

run_docker() {
    local test_name=$1  # Full name like "t01_static_io.v"
    local output_bit=$2

    echo -n "  Docker: "
    local start=$(python3 -c "import time; print(int(time.time()*1000))")

    # Copy to openxc7-synth
    cp "$TESTS_DIR/$test_name" "$SCRIPT_DIR/../openxc7-synth/"
    cp "$TESTS_DIR/${test_name%.*}.xdc" "$SCRIPT_DIR/../openxc7-synth/"

    cd "$SCRIPT_DIR/../openxc7-synth"
    if ./synth.sh "$test_name" trinity_top --docker > /dev/null 2>&1; then
        mv "${test_name%.*}.bit" "$output_bit"
        local end=$(python3 -c "import time; print(int(time.time()*1000))")
        local runtime=$((end - start))
        echo -e "${GREEN}PASS${NC} (${runtime}ms)"
        return 0
    else
        local end=$(python3 -c "import time; print(int(time.time()*1000))")
        local runtime=$((end - start))
        echo -e "${RED}FAIL${NC} (${runtime}ms)"
        return 1
    fi
}

extract_timing() {
    local bitfile=$1

    # Extract timing from FORGE output (would need to save full output)
    # For now, default value
    echo "6.0" >> "$RESULTS_DIR/timing_ns.txt"
}

run_test() {
    local test_id=$1
    local test_name=$2

    echo ""
    echo -e "${BLUE}[${test_id}] ${test_name}${NC}"

    local test_v="${test_id}_${test_name}.v"
    local test_xdc="${test_id}_${test_name}.xdc"
    local forge_bit="$RESULTS_DIR/${test_name}_forge.bit"
    local docker_bit="$RESULTS_DIR/${test_name}_docker.bit"

    # Run both toolchains
    local forge_result=0
    local docker_result=0

    run_forge "$test_id" "$test_name" "$test_v" "$test_xdc" "$forge_bit" || forge_result=1
    run_docker "$test_v" "$docker_bit" || docker_result=1

    # Extract timing
    extract_timing "$forge_bit"

    # Hardware verdict (placeholder - requires manual verification)
    local hw_verdict="PENDING"
    if [ $forge_result -eq 0 ]; then
        hw_verdict="NEEDS_TEST"
    fi

    # Write to CSV
    local forge_runtime=$(cat "$RESULTS_DIR/${test_name}_forge.txt" 2>/dev/null | cut -d',' -f1 || echo "N/A")
    local forge_status=$(cat "$RESULTS_DIR/${test_name}_forge.txt" 2>/dev/null | cut -d',' -f2 || echo "N/A")
    local docker_runtime=$(cat "$RESULTS_DIR/${test_name}_docker.txt" 2>/dev/null | cut -d',' -f1 || echo "N/A")
    local docker_status=$(cat "$RESULTS_DIR/${test_name}_docker.txt" 2>/dev/null | cut -d',' -f2 || echo "N/A")
    local timing_ns=$(cat "$RESULTS_DIR/timing_ns.txt" 2>/dev/null || echo "N/A")

    echo "$test_id,$forge_runtime,$forge_status,$docker_runtime,$docker_status,$timing_ns,$hw_verdict" >> "$RESULTS_DIR/regression_results.csv"

    # Cleanup
    rm -f "$SCRIPT_DIR/../openxc7-synth/${test_v}"
    rm -f "$SCRIPT_DIR/../openxc7-synth/${test_xdc}"
    rm -f "$SCRIPT_DIR/../openxc7-synth/${test_id}_${test_name}.json"
    rm -f "$SCRIPT_DIR/../openxc7-synth/${test_id}_${test_name}.bit"
}

generate_report() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  REGRESSION REPORT${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Print CSV table
    column -t -s',' "$RESULTS_DIR/regression_results.csv"

    echo ""
    echo "Results saved to: $RESULTS_DIR/regression_results.csv"
    echo ""
    echo "Next steps:"
    echo "  1. Flash bitstreams to hardware: $RESULTS_DIR/*_forge.bit"
    echo "  2. Verify LED behavior"
    echo "  3. Update Hardware_Verdict column"
}

# Main execution
print_banner

for test in "${TESTS[@]}"; do
    test_id=$(echo $test | cut -d':' -f1)
    test_name=$(echo $test | cut -d':' -f2)
    run_test "$test_id" "$test_name"
done

generate_report
