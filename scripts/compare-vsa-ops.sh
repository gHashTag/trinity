#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# compare-vsa-ops.sh - Compare manual vs self-hosted VSA operation hashes
# ═══════════════════════════════════════════════════════════════════════════════════════
#
# This script demonstrates using tri hash-fn to verify that manually written
# VSA operations match the self-hosted generated versions.
#
# Usage: ./scripts/compare-vsa-ops.sh
#
# ═══════════════════════════════════════════════════════════════════════════════════════

set -e

TRI_BIN="${TRI_BIN:-./zig-out/bin/tri}"

echo "Comparing VSA operation hashes between manual and self-hosted builds..."
echo ""

# VSA operations to compare
OPS=(
    "vsa.ops.bind"
    "vsa.ops.unbind"
    "vsa.ops.bundle2"
    "vsa.ops.bundle3"
    "vsa.ops.similarity"
)

MISMATCHES=0

for op in "${OPS[@]}"; do
    echo -n "Checking $op ... "

    MANUAL=$(TRINITY_SELF_HOSTED=0 "$TRI_BIN" hash-fn "$op" 2>/dev/null | grep 'sha256:' | cut -d: -f2)
    SELF=$(TRINITY_SELF_HOSTED=1 "$TRI_BIN" hash-fn "$op" 2>/dev/null | grep 'sha256:' | cut -d: -f2)

    if [ -z "$MANUAL" ] || [ -z "$SELF" ]; then
        echo "ERROR (failed to compute hash)"
        MISMATCHES=$((MISMATCHES + 1))
        continue
    fi

    if [ "$MANUAL" = "$SELF" ]; then
        echo "✓ OK"
    else
        echo "✗ MISMATCH"
        echo "  Manual:   $MANUAL"
        echo "  Self-host: $SELF"
        MISMATCHES=$((MISMATCHES + 1))
    fi
done

echo ""
if [ $MISMATCHES -eq 0 ]; then
    echo "All operations matched! ✓"
    exit 0
else
    echo "$MISMATCHES operation(s) differed. ✗"
    exit 1
fi
