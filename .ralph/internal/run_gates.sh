#!/bin/bash
# Quality gates for Ralph
set -e
echo "=== Gate 1: Build ==="
zig build
echo "BUILD: PASS"

echo "=== Gate 2: Test ==="
zig build test
echo "TEST: PASS"

echo "=== Gate 3: Format ==="
zig fmt --check src/
echo "FORMAT: PASS"

echo "=== ALL GATES PASSED ==="
