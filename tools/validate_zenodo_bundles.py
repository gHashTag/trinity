#!/usr/bin/env python3
"""Validate all Zenodo bundle JSON files."""

import json
import os
import sys

def validate_bundle(json_path):
    """Validate a single Zenodo bundle JSON file."""
    errors = []
    warnings = []

    try:
        with open(json_path, 'r') as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        return False, [f"❌ JSON decode error: {e}"], []

    # Required fields check
    required_fields = ["title", "creators", "description", "publication_date", "license"]
    for field in required_fields:
        if field not in data:
            errors.append(f"❌ Missing required field: {field}")

    # References format check
    if "references" in data:
        refs = data["references"]
        for i, ref in enumerate(refs):
            if isinstance(ref, dict):
                errors.append(f"❌ Reference {i}: malformed object (should be string)")
            elif not isinstance(ref, str):
                warnings.append(f"⚠️  Reference {i}: unexpected type {type(ref).__name__}")

    # DOI check
    if "doi" in data:
        doi = data["doi"]
        if not doi.startswith("10.5281/zenodo."):
            errors.append(f"❌ Invalid DOI format: {doi}")

    # Version check
    if "version" in data:
        version = data["version"]
        try:
            float(version)
        except ValueError:
            warnings.append(f"⚠️  Version '{version}' not a number")

    return len(errors) == 0, errors, warnings

def validate_all_bundles():
    """Validate all 8 Zenodo bundle JSON files."""
    bundles = [
        "docs/research/.zenodo.B001_v8.0.json",
        "docs/research/.zenodo.B002_v8.0.json",
        "docs/research/.zenodo.B003_v8.0.json",
        "docs/research/.zenodo.B004_v8.0.json",
        "docs/research/.zenodo.B005_v8.0.json",
        "docs/research/.zenodo.B006_v8.0.json",
        "docs/research/.zenodo.B007_v8.0.json",
        "docs/research/.zenodo.PARENT_v8.0.json",
    ]

    print("🔍 Validating all Zenodo bundle JSON files...")
    print("=" * 60)

    all_valid = True
    for bundle_path in bundles:
        if not os.path.exists(bundle_path):
            print(f"❌ {bundle_path}: file not found")
            all_valid = False
            continue

        valid, errors, warnings = validate_bundle(bundle_path)
        name = os.path.basename(bundle_path)

        if valid:
            print(f"✅ {name}: VALID")
        else:
            print(f"❌ {name}: INVALID")
            all_valid = False

        for err in errors:
            print(f"  {err}")
        for warn in warnings:
            print(f"  {warn}")

    print("=" * 60)
    if all_valid:
        print("✅ All bundles validated successfully!")
        return 0
    else:
        print("❌ Some bundles have validation errors")
        return 1

if __name__ == "__main__":
    sys.exit(validate_all_bundles())
