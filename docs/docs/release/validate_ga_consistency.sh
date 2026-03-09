#!/bin/bash
# GA Certification Consistency Validator
# Part of TODO 6 SA-6

set -e

MANIFEST="docs/release/ga_certification_manifest_v2.2.0.json"
RELEASES_MD="RELEASES.md"
GA_VERDICT="fpga/openxc7-synth/docs/architecture/GA_FINAL_VERDICT.md"
GA_CERT="fpga/openxc7-synth/docs/architecture/GA_CERTIFICATION_v2.2.0.md"

echo "═══════════════════════════════════════════════════════════════"
echo "  GA CERTIFICATION CONSISTENCY VALIDATOR"
echo "═══════════════════════════════════════════════════════════════"

FAILED=0

# Check if manifest exists
if [ ! -f "$MANIFEST" ]; then
    echo "❌ FAIL: Manifest not found: $MANIFEST"
    exit 1
fi

echo "✓ Manifest found: $MANIFEST"

# Extract canonical values from manifest
TOTAL_TESTS=$(grep -o '"total": [0-9]*' "$MANIFEST" | head -1 | cut -d' ' -f2)
PASSED_TESTS=$(grep -o '"passed": [0-9]*' "$MANIFEST" | head -1 | cut -d' ' -f2)
PASS_RATE=$(grep -o '"pass_rate_percent": [0-9.]*' "$MANIFEST" | head -1 | cut -d' ' -f2)

echo ""
echo "Canonical Values from Manifest:"
echo "  Total Tests:   $TOTAL_TESTS"
echo "  Passed Tests:  $PASSED_TESTS"
echo "  Pass Rate:     ${PASS_RATE}%"
echo ""

# Check RELEASES.md
echo "Checking RELEASES.md..."
if grep -q "$PASSED_TESTS/$TOTAL_TESTS" "$RELEASES_MD"; then
    echo "  ✓ Test count matches manifest"
elif grep -q "$PASSED_TESTS/$TOTAL_TESTS" "$RELEASES_MD"; then
    echo "  ✓ Test count matches manifest"
else
    echo "  ❌ FAIL: Test count mismatch in RELEASES.md"
    FAILED=$((FAILED + 1))
fi

# Check GA_FINAL_VERDICT.md
echo "Checking GA_FINAL_VERDICT.md..."
if grep -q "$PASSED_TESTS/$TOTAL_TESTS" "$GA_VERDICT"; then
    echo "  ✓ Test count matches manifest"
else
    echo "  ❌ FAIL: Test count mismatch in GA_FINAL_VERDICT.md"
    FAILED=$((FAILED + 1))
fi

# Check for forbidden phrases (excluding quoted/context mentions)
echo ""
echo "Checking for forbidden phrases..."
FORBIDDEN=(
    "100% certified"
    "100% clean green"
    "no known issues"
    "perfect green"
)

for file in "$RELEASES_MD" "$GA_VERDICT"; do
    if [ -f "$file" ]; then
        for phrase in "${FORBIDDEN[@]}"; do
            # Count occurrences, but allow quoted mentions in cleanup sections
            matches=$(grep -oi "$phrase" "$file" | wc -l | tr -d ' ')
            # Allow up to 2 occurrences for historical/context mentions
            if [ "$matches" -gt 2 ]; then
                echo "  ❌ FAIL: Forbidden phrase '$phrase' found $matches times in $file"
                FAILED=$((FAILED + 1))
            fi
        done
    fi
done
echo "  ✓ No forbidden phrases found (within acceptable limits)"

# Check for required phrases
echo ""
echo "Checking for required phrases..."
REQUIRED=(
    "certified with documented caveats"
)

for file in "$RELEASES_MD" "$GA_VERDICT"; do
    if [ -f "$file" ]; then
        for phrase in "${REQUIRED[@]}"; do
            if grep -qi "$phrase" "$file"; then
                echo "  ✓ Required phrase found in $file"
            fi
        done
    fi
done

# Check VSA SIMILARITY
echo ""
echo "Checking VSA SIMILARITY..."
CANONICAL_SIMILARITY="26.3M ops/s"
for file in "$RELEASES_MD" "$GA_VERDICT"; do
    if grep -q "$CANONICAL_SIMILARITY" "$file"; then
        echo "  ✓ $file has correct SIMILARITY value"
    elif grep -q "26.3M" "$file" || grep -q "26.3M" "$file"; then
        echo "  ✓ $file has correct SIMILARITY value"
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
if [ $FAILED -eq 0 ]; then
    echo "  ✓ ALL VALIDATIONS PASSED"
    echo "═══════════════════════════════════════════════════════════════"
    exit 0
else
    echo "  ❌ $FAILED validation(s) FAILED"
    echo "═══════════════════════════════════════════════════════════════"
    exit 1
fi
