#!/bin/bash
# UI Tests — verify display works

cd /Users/playra/trinity

echo "Testing UI components..."

# Test 1: status script runs
echo -n "  tmux_status_v4.sh compact... "
if bash .ralph/scripts/tmux_status_v4.sh compact | grep -q "RALPH v4"; then
    echo "✓ PASS"
else
    echo "✗ FAIL"
    exit 1
fi

# Test 2: output monitor exists and is executable
echo -n "  output_monitor_v4.sh exists... "
if [ -x ".ralph/scripts/output_monitor_v4.sh" ]; then
    echo "✓ PASS"
else
    echo "✗ FAIL"
    exit 1
fi

# Test 3: dashboard exists and is executable
echo -n "  ralph-dashboard-v4 exists... "
if [ -x "bin/ralph-dashboard-v4" ]; then
    echo "✓ PASS"
else
    echo "✗ FAIL"
    exit 1
fi

# Test 4: input script exists
echo -n "  tri_cmd_input_v4.sh exists... "
if [ -x ".ralph/scripts/tri_cmd_input_v4.sh" ]; then
    echo "✓ PASS"
else
    echo "✗ FAIL"
    exit 1
fi

echo ""
echo "All tests passed! ✓"
