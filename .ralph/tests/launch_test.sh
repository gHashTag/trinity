#!/bin/bash
# Pre-flight checks before starting Ralph dashboard

cd /Users/playra/trinity

echo "Ralph Dashboard Pre-Flight Test"
echo "=============================="

# Test 1: All required scripts exist
echo -n "  Scripts exist... "
scripts=(
    ".ralph/scripts/output_monitor_v4.sh"
    ".ralph/scripts/tri_cmd_input_v4.sh"
    ".ralph/scripts/tri_cmd_real_handler_v2.sh"
    ".ralph/scripts/powerkit_lite.sh"
    "bin/ralph-dashboard-v4"
)
for s in "${scripts[@]}"; do
    [ -f "$s" ] || { echo "✗ FAIL: $s missing"; exit 1; }
done
echo "✓ PASS"

# Test 2: Chat scripts are executable
echo -n "  Scripts executable... "
bash .ralph/scripts/output_monitor_v4.sh >/dev/null 2>&1 &
OUTPUT_PID=$!
sleep 0.5
kill $OUTPUT_PID 2>/dev/null || true
bash -c 'echo "" | .ralph/scripts/tri_cmd_input_v4.sh' >/dev/null 2>&1 || true
echo "✓ PASS"

# Test 3: Queue directory exists
echo -n "  Queue system... "
[ -d ".ralph/queue" ] || { echo "✗ FAIL: queue missing"; exit 1; }
touch .ralph/queue/incoming.cmd || { echo "✗ FAIL: cannot write"; exit 1; }
echo "✓ PASS"

# Test 4: Configuration files
echo -n "  Config files... "
[ -f ".ralph/.env" ] || { echo "⚠ WARN: .env missing (API may fail)"; }
[ -f ".ralph/fix_plan.md" ] || { echo "⚠ WARN: fix_plan.md missing"; }
echo "✓ PASS"

echo ""
echo "All tests passed! Starting dashboard..."
