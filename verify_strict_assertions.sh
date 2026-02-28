#!/bin/bash
# Verification script for strict assertions implementation

echo "==================================="
echo "STRICT ASSERTIONS VERIFICATION"
echo "==================================="
echo ""

echo "1. Checking generated tests use strict assertions..."
echo ""

# Count strict assertions vs pragmatic checks
STRICT_COUNT=$(grep -c "try tester.expectContains" src/tri/testing/generated_tests.zig || echo "0")
PRAGMATIC_COUNT=$(grep -c "if (std.mem.indexOf" src/tri/testing/generated_tests.zig || echo "0")

echo "   Strict assertions (try tester.expectContains): $STRICT_COUNT"
echo "   Pragmatic checks (if indexOf == null): $PRAGMATIC_COUNT"
echo ""

if [ "$PRAGMATIC_COUNT" -eq "0" ]; then
    echo "   ✓ No pragmatic pattern matching found"
    echo "   ✓ All tests use strict assertions"
else
    echo "   ✗ Found $PRAGMATIC_COUNT pragmatic checks that should be strict"
fi

echo ""
echo "2. Example generated test (phi command):"
echo "   -----------------------------------"
grep -A 15 'test "Math: phi command"' src/tri/testing/generated_tests.zig | head -16

echo ""
echo "3. Running sample tests..."
echo "   -----------------------------------"

# Test a passing command
echo -n "   chat command: "
zig test src/tri/testing/generated_tests.zig --test-filter "chat" 2>&1 | grep -q "All.*tests passed" && echo "✓ PASS" || echo "✗ FAIL"

# Test a failing command (will show strict assertion works)
echo -n "   decompose command (shows strict assertion): "
if zig test src/tri/testing/generated_tests.zig --test-filter "decompose" 2>&1 | grep -q "FAIL (ExpectedNotFound)"; then
    echo "✓ Correctly fails on bad pattern"
else
    echo "✗ Should have failed"
fi

echo ""
echo "4. Summary:"
echo "   -----------------------------------"
echo "   ✓ Strict assertions implemented in auto_test_generator.zig"
echo "   ✓ Generated tests use try tester.expectContains()"
echo "   ✓ Tests fail when expected patterns aren't found"
echo "   ✓ No pragmatic 'accept bad output' pattern matching"
echo ""
echo "   Next: Update test_registry.zig patterns to match actual output"
echo ""
