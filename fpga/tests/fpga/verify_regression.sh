#!/bin/bash
# FPGA Verify Regression Test
# 
# Tests the LED detector on synthetic golden samples with known frequencies.
#
# Usage:
#   ./verify_regression.sh [--verbose]

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="/tmp/led_venv"
DETECTOR="/tmp/led_detector.py"
GENERATOR="/tmp/generate_golden_sample.py"
TEST_DIR="${SCRIPT_DIR}"

# Default values
VERBOSE="${VERBOSE:-0}"
MIN_CONFIDENCE=0.3     # Minimum confidence for PASS

# Test cases: (name, freq_hz, duration_sec)
TEST_CASES=(
    "1Hz,1.0,5"
    "3Hz,3.0,5"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Activate virtual environment
activate_venv() {
    if [ ! -d "$VENV" ]; then
        error "Virtual environment not found: $VENV"
        exit 1
    fi
    source "$VENV/bin/activate"
}

# Run single test case
run_test() {
    local name="$1"
    local freq_hz="$2"
    local duration="$3"
    
    local video_file="${TEST_DIR}/golden_${name}.mp4"
    
    log "Testing: $name (expected ${freq_hz} Hz)"
    
    # Generate golden sample if not exists
    if [ ! -f "$video_file" ]; then
        python "$GENERATOR" \
            --output "$video_file" \
            --freq "$freq_hz" \
            --duration "$duration" \
            > /dev/null 2>&1 || {
            error "Failed to generate golden sample: $name"
            return 1
        }
    fi
    
    # Run detector and capture output
    local output
    output=$(python "$DETECTOR" \
        "$video_file" \
        --expected-freq "$freq_hz" \
        --threshold "$MIN_CONFIDENCE" \
        2>/dev/null)
    
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        error "FAILED: $name - detector returned non-zero"
        if [ "$VERBOSE" = "1" ]; then
            echo "$output"
        fi
        return 1
    fi
    
    # Parse JSON using grep
    local verdict=$(echo "$output" | grep -o '"verdict": "[A-Z]*"' | cut -d'"' -f4)
    
    if [ "$verdict" != "PASS" ]; then
        error "FAILED: $name - verdict: $verdict"
        if [ "$VERBOSE" = "1" ]; then
            echo "$output"
        fi
        return 1
    fi
    
    local detected=$(echo "$output" | grep -o '"frequency_hz": [0-9.]*' | cut -d' ' -f2)
    local conf=$(echo "$output" | grep -o '"confidence": [0-9.]*' | cut -d' ' -f2)
    
    log "PASSED: $name (${detected} Hz, confidence: ${conf})"
    return 0
}

# Main
main() {
    log "FPGA Verify Regression Test"
    log "=============================="
    log ""
    
    activate_venv
    
    local passed=0
    local failed=0
    
    for test_case in "${TEST_CASES[@]}"; do
        IFS=',' read -r name freq duration <<< "$test_case"
        
        if run_test "$name" "$freq" "$duration"; then
            ((passed++))
        else
            ((failed++))
        fi
    done
    
    log ""
    log "=============================="
    log "Results: $passed passed, $failed failed"
    
    if [ "$failed" -eq 0 ]; then
        log "All tests PASSED!"
        return 0
    else
        error "Some tests FAILED!"
        return 1
    fi
}

main "$@"
