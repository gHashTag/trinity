#!/usr/bin/env python3
"""
Zenodo Metadata Validator

Validates .zenodo.json files against Zenodo API requirements.
Usage: python3 validate_zenodo_metadata.py
"""

import json
import sys
from pathlib import Path
from typing import Dict, List

# Required fields by Zenodo
REQUIRED_FIELDS = [
    "title",
    "creators",
    "description",
    "keywords",
    "license",
    "publication_date",
    "upload_type"
]

# Recommended fields
RECOMMENDED_FIELDS = [
    "version",
    "doi",
    "related_identifiers",
    "references"
]

def validate_creators(creators: List[Dict]) -> List[str]:
    """Validate creator fields."""
    errors = []
    for i, creator in enumerate(creators):
        if "name" not in creator:
            errors.append(f"Creator {i}: missing 'name'")
    return errors

def validate_related_identifiers(rel_ids: List[Dict]) -> List[str]:
    """Validate related identifier fields."""
    errors = []
    required = ["relation", "identifier"]
    for i, rel in enumerate(rel_ids):
        for field in required:
            if field not in rel:
                errors.append(f"Related identifier {i}: missing '{field}'")
    return errors

def validate_zenodo_json(filepath: Path) -> List[str]:
    """Validate a single .zenodo.json file."""
    errors = []
    
    try:
        with open(filepath, 'r') as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        return [f"Invalid JSON: {e}"]
    except Exception as e:
        return [f"Error reading file: {e}"]
    
    # Check required fields
    for field in REQUIRED_FIELDS:
        if field not in data:
            errors.append(f"Missing required field: '{field}'")
    
    # Validate creators
    if "creators" in data:
        errors.extend(validate_creators(data["creators"]))
    
    # Validate related_identifiers
    if "related_identifiers" in data:
        errors.extend(validate_related_identifiers(data["related_identifiers"]))
    
    # Check description length
    if "description" in data:
        desc_len = len(data["description"])
        if desc_len < 50:
            errors.append(f"Description too short: {desc_len} chars (min 50)")
        if desc_len > 100000:
            errors.append(f"Description too long: {desc_len} chars (max 100000)")
    
    # Check keywords count
    if "keywords" in data:
        if len(data["keywords"]) < 3:
            errors.append(f"Too few keywords: {len(data['keywords'])} (min 3)")
        if len(data["keywords"]) > 50:
            errors.append(f"Too many keywords: {len(data['keywords'])} (max 50)")
    
    # Check date format
    if "publication_date" in data:
        date = data["publication_date"]
        try:
            year, month, day = map(int, date.split("-"))
            if not (1900 <= year <= 2100):
                errors.append(f"Invalid year: {year}")
        except:
            errors.append(f"Invalid date format: {date} (expected YYYY-MM-DD)")
    
    return errors

def main():
    research_dir = Path(__file__).parent
    zenodo_files = list(research_dir.glob(".zenodo.*.json"))
    
    if not zenodo_files:
        print("❌ No .zenodo.json files found")
        sys.exit(1)
    
    print(f"Found {len(zenodo_files)} .zenodo.json files\n")
    
    all_valid = True
    for filepath in sorted(zenodo_files):
        errors = validate_zenodo_json(filepath)
        
        if errors:
            all_valid = False
            print(f"❌ {filepath.name}")
            for error in errors:
                print(f"   - {error}")
        else:
            print(f"✅ {filepath.name}")
    
    # Check recommended fields
    print("\n--- Recommended Fields ---")
    for filepath in sorted(zenodo_files):
        with open(filepath, 'r') as f:
            data = json.load(f)
        
        missing = [f for f in RECOMMENDED_FIELDS if f not in data]
        if missing:
            print(f"⚠️  {filepath.name}: missing {missing}")
        else:
            print(f"✅ {filepath.name}: all recommended fields present")
    
    if all_valid:
        print("\n✅ All .zenodo.json files are valid!")
        sys.exit(0)
    else:
        print("\n❌ Some files have validation errors")
        sys.exit(1)

if __name__ == "__main__":
    main()
