#!/usr/bin/env bash
# Documentation Link Checker
# Checks for broken internal and external links in documentation

set -e

DOCS_DIR="docsite/docs"
FAILED=0
CHECKED=0

echo "🔍 Checking documentation links..."
echo "=================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a file exists
check_file() {
    local file="$1"
    local source="$2"

    if [[ "$file" == http* ]]; then
        # External link - skip for now (would require curl/wget)
        return 0
    fi

    # Remove anchor
    local base="${file%%#*}"

    # Try different paths
    local paths=(
        "$DOCS_DIR/$base"
        "$DOCS_DIR/$base.md"
        "${base#../}"
        "${base#./}"
    )

    for path in "${paths[@]}"; do
        if [[ -f "$path" ]]; then
            return 0
        fi
    done

    echo -e "${RED}✗ BROKEN:${NC} $source -> $file"
    ((FAILED++))
    return 1
}

# Find all markdown files
echo "Scanning .md files in $DOCS_DIR..."
for md_file in $(find "$DOCS_DIR" -name "*.md"); do
    ((CHECKED++))

    # Extract all markdown links: [text](target)
    while IFS= read -r line; do
        if [[ "$line" =~ \[.*\]\(([^)]+)\) ]]; then
            target="${BASH_REMATCH[1]}"
            # Skip empty targets and anchors-only
            if [[ -n "$target" ]] && [[ "$target" != "#" ]]; then
                check_file "$target" "$md_file" || true
            fi
        fi
    done < <(grep -o '\[[^]]*\]([^)]*)' "$md_file" | sed 's/.*](//' | sed 's/)$//')
done

echo ""
echo "=================================="
echo -e "Files scanned: ${GREEN}$CHECKED${NC}"
echo -e "Broken links: ${RED}$FAILED${NC}"

if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo -e "${RED}❌ Link check failed!${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}✅ All links OK!${NC}"
    exit 0
fi
