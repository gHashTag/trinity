#!/usr/bin/env python3
"""
Trinity S³AI — Zenodo Bundle Validation Script
Validates all 7 Zenodo bundles before upload
"""

from pathlib import Path
import json
import re
import sys
from typing import Dict, List, Tuple

# Configuration
BUNDLES_DIR = Path("docs/research/bundles")
REQUIRED_METADATA_FIELDS = [
    "title", "creators", "description", "keywords", "license"
]
ABSTRACT_PATTERN = r"^.+\.( .+\.){3,} .+\.$"  # 5+ sentences
MAX_TITLE_LENGTH = 200
MIN_KEYWORDS = 5
MAX_KEYWORDS = 15

class ValidationResult:
    def __init__(self, bundle_name: str):
        self.bundle_name = bundle_name
        self.valid = True
        self.errors: List[str] = []
        self.warnings: List[str] = []
        self.info: List[str] = []

    def add_error(self, msg: str):
        self.errors.append(f"❌ {msg}")
        self.valid = False

    def add_warning(self, msg: str):
        self.warnings.append(f"⚠️  {msg}")

    def add_info(self, msg: str):
        self.info.append(f"ℹ️  {msg}")

    def print_report(self):
        if self.valid:
            print(f"✅ {self.bundle_name}: VALID")
        else:
            print(f"❌ {self.bundle_name}: INVALID")

        for msg in self.errors:
            print(f"  {msg}")
        for msg in self.warnings:
            print(f"  {msg}")
        for msg in self.info:
            print(f"  {msg}")

def validate_abstract_structure(description: str) -> Tuple[bool, List[str]]:
    """Validate abstract follows 5-sentence structure."""
    issues = []

    # Split into sentences
    sentences = re.split(r'[.!?]+', description)
    sentences = [s.strip() for s in sentences if s.strip()]

    if len(sentences) < 5:
        issues.append(f"Abstract has {len(sentences)} sentences (minimum 5)")

    # Check word counts
    word_counts = [len(s.split()) for s in sentences]

    for i, count in enumerate(word_counts, 1):
        if count < 10:
            issues.append(f"Sentence {i}: Too short ({count} words)")
        elif count > 40:
            issues.append(f"Sentence {i}: Too long ({count} words)")

    return len(issues) == 0, issues

def validate_bundle(bundle_dir: Path, metadata_filename: str = ".zenodo.json") -> ValidationResult:
    """Validate a single Zenodo bundle."""
    result = ValidationResult(bundle_dir.name)

    # Check metadata JSON
    metadata_file = bundle_dir / metadata_filename
    if not metadata_file.exists():
        result.add_error("Missing .zenodo.json")
        return result

    try:
        with open(metadata_file) as f:
            metadata = json.load(f)
    except json.JSONDecodeError as e:
        result.add_error(f"Invalid JSON: {e}")
        return result

    # Validate required fields
    for field in REQUIRED_METADATA_FIELDS:
        if field not in metadata:
            result.add_error(f"Missing required field: {field}")

    # Validate title
    if "title" in metadata:
        title_len = len(metadata["title"])
        if title_len > MAX_TITLE_LENGTH:
            result.add_warning(f"Title too long ({title_len} > {MAX_TITLE_LENGTH})")
        result.add_info(f"Title: {metadata['title'][:50]}...")

    # Validate creators
    if "creators" in metadata:
        creators = metadata["creators"]
        if not creators:
            result.add_error("No creators specified")
        for creator in creators:
            if "name" not in creator:
                result.add_warning("Creator missing 'name' field")

    # Validate description (abstract)
    if "description" in metadata:
        desc = metadata["description"]
        valid, issues = validate_abstract_structure(desc)
        for issue in issues:
            result.add_warning(f"Abstract: {issue}")
        result.add_info(f"Abstract length: {len(desc.split())} words")

    # Validate keywords
    if "keywords" in metadata:
        keywords = metadata["keywords"]
        if isinstance(keywords, list):
            if len(keywords) < MIN_KEYWORDS:
                result.add_warning(f"Too few keywords ({len(keywords)} < {MIN_KEYWORDS})")
            if len(keywords) > MAX_KEYWORDS:
                result.add_warning(f"Too many keywords ({len(keywords)} > {MAX_KEYWORDS})")
        else:
            result.add_error("Keywords must be a list")

    # Validate license
    if "license" in metadata:
        license_id = metadata["license"]
        if license_id not in ["MIT", "Apache-2.0", "GPL-3.0", "CC-BY-4.0"]:
            result.add_warning(f"Unusual license: {license_id}")

    # Check for figures
    figures_dir = bundle_dir / "figures"
    if figures_dir.exists():
        png_files = list(figures_dir.glob("*.png"))
        svg_files = list(figures_dir.glob("*.svg"))
        result.add_info(f"Figures: {len(png_files)} PNG, {len(svg_files)} SVG")
    else:
        result.add_warning("No figures directory")

    # Check for data files
    data_dir = bundle_dir / "data"
    if data_dir.exists():
        csv_files = list(data_dir.glob("*.csv"))
        result.add_info(f"Data files: {len(csv_files)} CSV")
    else:
        result.add_info("No data directory")

    # Check for notebooks
    notebooks_dir = bundle_dir / "notebooks"
    if notebooks_dir.exists():
        ipynb_files = list(notebooks_dir.glob("*.ipynb"))
        result.add_info(f"Notebooks: {len(ipynb_files)} Jupyter")

    # Check for description markdown
    desc_md = bundle_dir / "description.md"
    if desc_md.exists():
        result.add_info("Has description.md")

    # Check for Dockerfile
    dockerfile = bundle_dir / "Dockerfile"
    if dockerfile.exists():
        result.add_info("Has Dockerfile")

    return result

def main():
    print("Trinity S³AI — Zenodo Bundle Validation")
    print("=" * 50)

    bundles_dir = Path("docs/research")

    # Find all bundle metadata files (B001-B007)
    bundle_files = []
    for i in range(1, 8):
        metadata_file = bundles_dir / f".zenodo.B00{i}_v6.0.json"
        if not metadata_file.exists():
            metadata_file = bundles_dir / f".zenodo.B00{i}.json"
        if metadata_file.exists():
            bundle_files.append(metadata_file)

    if not bundle_files:
        print("No Zenodo metadata files found")
        sys.exit(1)

    print(f"Found {len(bundle_files)} bundle(s)")
    print()

    # Validate each bundle
    all_valid = True
    for metadata_file in sorted(bundle_files):
        # Use parent directory as bundle directory
        bundle_dir = metadata_file.parent
        result = validate_bundle(bundle_dir, metadata_file.name)
        result.print_report()
        print()
        if not result.valid:
            all_valid = False

    # Summary
    print("=" * 50)
    if all_valid:
        print("✅ All bundles VALID")
        sys.exit(0)
    else:
        print("❌ Some bundles INVALID")
        sys.exit(1)

if __name__ == "__main__":
    main()
