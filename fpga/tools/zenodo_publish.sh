#!/bin/bash
# Trinity Zenodo Publisher — automated DOI minting for releases
# Usage: ZENODO_TOKEN=xxx ./zenodo_publish.sh [version]
# Requires: curl, python3, zip
#
# First run: creates new deposit
# Subsequent: creates new version of existing record
#
# Get token: https://zenodo.org/account/settings/applications/tokens/new/
# Scopes: deposit:write, deposit:actions

set -euo pipefail

# ─── Config ───────────────────────────────────────────────────
VERSION="${1:-v2.0.3}"
RECORD_ID="${ZENODO_RECORD_ID:-18947017}"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
TMP_ZIP="/tmp/trinity-${VERSION}-fpga-llm.zip"

# ─── Preflight ────────────────────────────────────────────────
if [ -z "${ZENODO_TOKEN:-}" ]; then
    echo "❌ ZENODO_TOKEN not set"
    echo "   Get one at: https://zenodo.org/account/settings/applications/tokens/new/"
    echo "   Scopes: deposit:write, deposit:actions"
    echo ""
    echo "   Usage: ZENODO_TOKEN=xxx $0 ${VERSION}"
    exit 1
fi

for cmd in curl python3 zip; do
    command -v "$cmd" >/dev/null || { echo "❌ Missing: $cmd"; exit 1; }
done

API="https://zenodo.org/api"
AUTH="Authorization: Bearer $ZENODO_TOKEN"

echo "🔬 Trinity Zenodo Publisher"
echo "   Version: ${VERSION}"
echo "   Record:  ${RECORD_ID}"
echo "   Root:    ${PROJECT_ROOT}"
echo ""

# ─── Step 1: Create new version draft ─────────────────────────
echo "📝 Creating new version draft..."
DRAFT_RESPONSE=$(curl -sf -X POST \
    "${API}/records/${RECORD_ID}/versions" \
    -H "$AUTH" \
    -H "Content-Type: application/json")

DRAFT_ID=$(echo "$DRAFT_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
echo "   Draft ID: ${DRAFT_ID}"

# ─── Step 2: Update metadata ──────────────────────────────────
echo "📋 Updating metadata..."
DESCRIPTION="HSLM: 1.95M-parameter ternary language model with zero-DSP FPGA inference.

Key Results (${VERSION}):
- Training: PPL=125 on TinyStories (best of 5 runs, 100K steps)
- Architecture: vocab=729(3^6), embed=243(3^5), hidden=729(3^6), 3 blocks, 3 heads
- FPGA: Full autoregressive pipeline (embed→4×TrinityBlock→LM_head→argmax)
- Resources: 6,864 LUT (10.8%), 128 BRAM36 (95%), 0 DSP48
- Latency: 28.5ms FPGA / 0.39ms Railway 48-vCPU / 1.27ms M1 Pro
- Throughput: 20,351 tok/s (Railway) / 6,318 (M1) / 35 (FPGA @ 0.5W)
- Ternary weights: 1,872KB (20× compression vs float32)
- Mathematical foundation: phi^2 + 1/phi^2 = 3
- 6-stage synthesis pipeline with Verilator lint + Iverilog simulation
- 100% open-source toolchain (Yosys + nextpnr + prjxray)"

# Build JSON payload with python3 to handle escaping
METADATA_JSON=$(python3 -c "
import json
print(json.dumps({
    'metadata': {
        'title': f'gHashTag/trinity: Trinity ${VERSION} — FPGA Autoregressive Ternary LLM + Training Results',
        'description': '''${DESCRIPTION}''',
        'creators': [{'person_or_org': {'family_name': 'Vasilev', 'given_name': 'Dmitrii', 'type': 'personal'}}],
        'publication_date': '$(date +%Y-%m-%d)',
        'version': '${VERSION}',
        'resource_type': {'id': 'software'},
        'publisher': 'Zenodo',
        'related_identifiers': [
            {
                'identifier': 'https://github.com/gHashTag/trinity',
                'relation_type': {'id': 'issupplementto'},
                'scheme': 'url'
            }
        ]
    }
}))
")

curl -sf -X PUT \
    "${API}/records/${DRAFT_ID}/draft" \
    -H "$AUTH" \
    -H "Content-Type: application/json" \
    -d "$METADATA_JSON" > /dev/null

echo "   ✅ Metadata updated"

# ─── Step 3: Remove old files ─────────────────────────────────
echo "🗑️  Removing old files from draft..."
OLD_FILES=$(curl -sf "${API}/records/${DRAFT_ID}/draft/files" \
    -H "$AUTH" \
    | python3 -c "import sys,json; [print(f['key']) for f in json.load(sys.stdin).get('entries',[])]" 2>/dev/null || true)

for f in $OLD_FILES; do
    echo "   Deleting: $f"
    curl -sf -X DELETE \
        "${API}/records/${DRAFT_ID}/draft/files/${f}" \
        -H "$AUTH" > /dev/null || true
done

# ─── Step 4: Build archive ────────────────────────────────────
echo "📦 Building archive..."
cd "$PROJECT_ROOT"

# Collect files that exist
FILES_TO_ZIP=""
for pattern in \
    README.md CLAUDE.md LICENSE build.zig build.zig.zon \
    "src/hslm/*.zig" src/vsa.zig src/vm.zig src/hybrid.zig \
    fpga/README.md "fpga/openxc7-synth/*.v" "fpga/openxc7-synth/*.xdc" \
    "fpga/openxc7-synth/*.bit" fpga/tools/fpga_eye.py \
    "docs/lab/papers/hslm/*.md" \
    "specs/tri/*.tri"; do
    # shellcheck disable=SC2086
    FOUND=$(ls $pattern 2>/dev/null || true)
    if [ -n "$FOUND" ]; then
        FILES_TO_ZIP="$FILES_TO_ZIP $FOUND"
    fi
done

if [ -z "$FILES_TO_ZIP" ]; then
    echo "❌ No files found to archive"
    exit 1
fi

# shellcheck disable=SC2086
zip -r "$TMP_ZIP" $FILES_TO_ZIP > /dev/null
ZIP_SIZE=$(ls -lh "$TMP_ZIP" | awk '{print $5}')
echo "   Archive: ${TMP_ZIP} (${ZIP_SIZE})"

# ─── Step 5: Upload archive ───────────────────────────────────
ZIP_NAME="trinity-${VERSION}-fpga-llm.zip"
echo "📤 Uploading ${ZIP_NAME}..."

# Initiate upload
curl -sf -X POST \
    "${API}/records/${DRAFT_ID}/draft/files" \
    -H "$AUTH" \
    -H "Content-Type: application/json" \
    -d "[{\"key\": \"${ZIP_NAME}\"}]" > /dev/null

# Upload content
curl -sf -X PUT \
    "${API}/records/${DRAFT_ID}/draft/files/${ZIP_NAME}/content" \
    -H "$AUTH" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@${TMP_ZIP}" > /dev/null

# Commit file
curl -sf -X POST \
    "${API}/records/${DRAFT_ID}/draft/files/${ZIP_NAME}/commit" \
    -H "$AUTH" > /dev/null

echo "   ✅ Upload complete"

# ─── Step 6: Publish ──────────────────────────────────────────
echo ""
echo "🚀 Publishing..."
PUBLISH_RESPONSE=$(curl -sf -X POST \
    "${API}/records/${DRAFT_ID}/draft/actions/publish" \
    -H "$AUTH")

DOI=$(echo "$PUBLISH_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['doi'])")
DOI_URL=$(echo "$PUBLISH_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['links']['doi'])")

echo ""
echo "═══════════════════════════════════════════════════"
echo "✅ Published to Zenodo!"
echo ""
echo "   DOI:     ${DOI}"
echo "   URL:     ${DOI_URL}"
echo "   Record:  https://zenodo.org/records/${DRAFT_ID}"
echo "   Version: ${VERSION}"
echo "═══════════════════════════════════════════════════"

# Cleanup
rm -f "$TMP_ZIP"
echo ""
echo "💡 Add to paper: \\cite{trinity_${VERSION//./_}}"
echo "   BibTeX: https://zenodo.org/records/${DRAFT_ID}/export/bibtex"
