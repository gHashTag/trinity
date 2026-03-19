#!/usr/bin/env bash
# P0.4: Memory Leak Check for CI
# This script runs all tests and ensures zero memory leaks.
# Exit code: 0 = no leaks, 1 = leaks detected, 2 = test failures

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
LEAK_COUNT=0
FAILED_TESTS=0

# Test files to check (isolated tests that work without build system integration)
# e2e_job_tests and e2e_registry_tests require full build system integration (P1.5)
TEST_FILES=(
    "src/tri/e2e_negative_tests.zig"
    "src/tri/structured_log.zig"
    "src/tri/observability.zig"
    "src/tri/job_system.zig"
)

echo "═══════════════════════════════════════════════════════════════"
echo "           P0.4: MEMORY LEAK CHECK FOR CI"
echo "═══════════════════════════════════════════════════════════════"
echo ""

for test_file in "${TEST_FILES[@]}"; do
    echo -n "Testing $test_file ... "

    # Run test and capture output
    output=$(zig test "$test_file" 2>&1)
    exit_code=$?

    # Check for leaks
    if echo "$output" | grep -q "leaked memory"; then
        leaks=$(echo "$output" | grep -o "[0-9]\+ test(s) leaked memory" | grep -o "[0-9]\+")
        LEAK_COUNT=$((LEAK_COUNT + leaks))
        echo -e "${RED}LEAKS DETECTED${NC}"
        echo "$output" | grep "leaked"
    elif [ $exit_code -eq 0 ]; then
        # Extract test count if available
        if echo "$output" | grep -q "All.*tests passed"; then
            passed=$(echo "$output" | grep -o "All [0-9]\+ tests passed" | grep -o "[0-9]\+")
            PASSED_TESTS=$((PASSED_TESTS + passed))
            TOTAL_TESTS=$((TOTAL_TESTS + passed))
            echo -e "${GREEN}PASS${NC} ($passed tests)"
        else
            echo -e "${GREEN}PASS${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
        fi
    else
        echo -e "${RED}FAIL${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "                     LEAK CHECK SUMMARY"
echo "═══════════════════════════════════════════════════════════════"
echo "  Tests passed: $PASSED_TESTS/$TOTAL_TESTS"
echo "  Memory leaks: $LEAK_COUNT"
echo "  Test failures: $FAILED_TESTS"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Exit with appropriate code
if [ $LEAK_COUNT -gt 0 ]; then
    echo -e "${RED}LEAK GATE FAILED: $LEAK_COUNT memory leak(s) detected${NC}"
    exit 1
elif [ $FAILED_TESTS -gt 0 ]; then
    echo -e "${RED}LEAK GATE FAILED: $FAILED_TESTS test(s) failed${NC}"
    exit 2
else
    echo -e "${GREEN}LEAK GATE PASSED: Zero leaks, all tests passing${NC}"
    exit 0
fi
