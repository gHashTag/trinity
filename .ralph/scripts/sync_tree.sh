#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TECH TREE SYNC
# ═══════════════════════════════════════════════════════════════════════════════

SPEC="specs/tri/tech_tree_strategy.vibee"
OUTPUT=".ralph/TECH_TREE.md"

if [ ! -f "$SPEC" ]; then
    echo "Error: Spec file $SPEC not found"
    exit 1
fi

echo "Syncing Tech Tree from $SPEC..."

# Write Header
cat << EOF > "$OUTPUT"
# Tech Tree — Ralph Navigation

> Source of truth: \`$SPEC\`
> Last sync: $(date +%Y-%m-%d)

---

## 🏗 In Progress
| ID | Name | Branch | Progress | Gain |
|----|------|--------|----------|------|
EOF

# Extract In Progress (using simplified grep/awk for VIBEE YAML)
grep -B 7 "status: \"in_progress\"" "$SPEC" | perl -0777 -ne 'while(/- id: "([^"]+)"\s+name: "([^"]+)"\s+branch: "([^"]+)"\s+complexity: (\d+)\s+potential_gain: "([^"]+)"/g){ print "|$1|$2|$3|$4/5|$5|\n" }' >> "$OUTPUT"

echo -e "\n## 🚀 Available Nodes" >> "$OUTPUT"
echo "| ID | Name | Branch | Complexity | Gain |" >> "$OUTPUT"
echo "|----|------|--------|------------|------|" >> "$OUTPUT"
grep -B 7 "status: \"available\"" "$SPEC" | perl -0777 -ne 'while(/- id: "([^"]+)"\s+name: "([^"]+)"\s+branch: "([^"]+)"\s+complexity: (\d+)\s+potential_gain: "([^"]+)"/g){ print "|$1|$2|$3|$4/5|$5|\n" }' >> "$OUTPUT"

echo -e "\n## ✅ Recently Completed" >> "$OUTPUT"
echo "| ID | Name | Branch | Gain |" >> "$OUTPUT"
echo "|----|------|--------|------|" >> "$OUTPUT"
grep -B 7 "status: \"completed\"" "$SPEC" | perl -0777 -ne 'while(/- id: "([^"]+)"\s+name: "([^"]+)"\s+branch: "([^"]+)"\s+complexity: (\d+)\s+potential_gain: "([^"]+)"/g){ print "|$1|$2|$3|$5|\n" }' >> "$OUTPUT"

echo -e "\n---\nφ² + 1/φ² = 3 | TRINITY" >> "$OUTPUT"

echo "✔ Done! Updated $OUTPUT"
