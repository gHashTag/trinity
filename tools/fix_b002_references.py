#!/usr/bin/env python3
"""Fix B002.json references format - convert mixed objects+strings to plain strings."""

import json
import sys

def fix_b002_references():
    """Fix B002.json by removing object references and keeping only strings."""
    json_path = "docs/research/.zenodo.B002_v8.0.json"

    # Read the JSON file
    with open(json_path, 'r') as f:
        data = json.load(f)

    # Fix references: keep only string entries, remove object entries
    if "references" in data:
        original = data["references"]
        fixed = []
        for ref in original:
            if isinstance(ref, str):
                fixed.append(ref)
            elif isinstance(ref, dict):
                # Object references are malformed - skip them
                print(f"⚠️  Skipping malformed object reference: {ref}")
        data["references"] = fixed
        print(f"✅ Fixed references: {len(original)} → {len(fixed)} entries")

    # Write back to file
    with open(json_path, 'w') as f:
        json.dump(data, f, indent=2)

    print(f"✅ Fixed {json_path}")
    return 0

if __name__ == "__main__":
    sys.exit(fix_b002_references())
