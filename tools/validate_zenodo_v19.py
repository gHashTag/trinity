#!/usr/bin/env python3
"""
Zenodo Metadata Validation Tool
Validates all bundle metadata against scientific best practices.

Usage:
    python3 tools/validate_zenodo_v19.py
    python3 tools/validate_zenodo_v19.py --bundle B001
"""

import json
import sys
from pathlib import Path
from typing import Dict, List, Any
from dataclasses import dataclass, field

BUNDLES = {
    "B001": {"json": "docs/research/.zenodo.B001_v9.0.json", "doi": "10.5281/zenodo.19227865"},
    "B002": {"json": "docs/research/.zenodo.B002_v9.0.json", "doi": "10.5281/zenodo.19227867"},
    "B003": {"json": "docs/research/.zenodo.B003_v9.0.json", "doi": "10.5281/zenodo.19227869"},
    "B004": {"json": "docs/research/.zenodo.B004_v9.0.json", "doi": "10.5281/zenodo.19227871"},
    "B005": {"json": "docs/research/.zenodo.B005_v9.0.json", "doi": "10.5281/zenodo.19227873"},
    "B006": {"json": "docs/research/.zenodo.B006_v9.0.json", "doi": "10.5281/zenodo.19227875"},
    "B007": {"json": "docs/research/.zenodo.B007_v9.0.json", "doi": "10.5281/zenodo.19227877"},
    "PARENT": {"json": "docs/research/.zenodo.PARENT_v9.0.json", "doi": "10.5281/zenodo.19227879"},
}

VALID_LICENSES = {
    "MIT", "Apache-2.0", "GPL-3.0", "LGPL-3.0", "BSD-3-Clause", "BSD-2-Clause",
    "CC-BY-4.0", "CC-BY-SA-4.0", "CC0-1.0", "ISC", "Unlicense", "MPL-2.0",
}

@dataclass
class ValidationResult:
    bundle: str
    is_valid: bool = True
    score: float = 100.0
    errors: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)
    details: Dict[str, Any] = field(default_factory=dict)

    def print_report(self):
        status = "✅ VALID" if self.is_valid else "❌ INVALID"
        emoji = "🟢" if self.score >= 90 else "🟡" if self.score >= 70 else "🔴"

        print(f"\n{'='*60}")
        print(f"{emoji} {self.bundle}: {status} (Score: {self.score:.0f}/100)")
        print(f"{'='*60}")

        if self.errors:
            print("\n❌ ERRORS:")
            for err in self.errors:
                print(f"  - {err}")

        if self.warnings:
            print("\n⚠️  WARNINGS:")
            for warn in self.warnings:
                print(f"  - {warn}")

        if self.details:
            print("\n📊 Details:")
            for key, value in self.details.items():
                print(f"  - {key}: {value}")

def validate_metadata(bundle_id: str, metadata: Dict[str, Any]) -> ValidationResult:
    result = ValidationResult(bundle=bundle_id)

    # Title validation
    title = metadata.get("title", "")
    result.details["Title length"] = len(title)
    if len(title) < 10:
        result.errors.append(f"Title too short: {len(title)} chars (min 10)")
        result.score -= 20
    elif len(title) > 200:
        result.errors.append(f"Title too long: {len(title)} chars (max 200)")
        result.score -= 10
    else:
        result.details["Title"] = f"✓ {len(title)} chars"

    # Creators validation
    creators = metadata.get("creators", [])
    result.details["Creators"] = len(creators)
    if len(creators) == 0:
        result.errors.append("No creators specified")
        result.score -= 30
    else:
        has_orcid = 0
        for creator in creators:
            if creator.get("orcid"):
                has_orcid += 1
        if has_orcid < len(creators):
            result.warnings.append(f"{len(creators) - has_orcid} creators missing ORCID")
            result.score -= (len(creators) - has_orcid) * 5
        result.details["ORCID coverage"] = f"{has_orcid}/{len(creators)}"

    # Description validation
    description = metadata.get("description", "")
    result.details["Description length"] = f"{len(description)} chars"
    if len(description) < 50:
        result.errors.append(f"Description too short: {len(description)} chars (min 50)")
        result.score -= 15
    elif len(description) < 200:
        result.warnings.append(f"Description could be longer: {len(description)} chars")
        result.score -= 5

    # Keywords validation
    keywords = metadata.get("keywords", [])
    result.details["Keywords"] = len(keywords)
    if len(keywords) < 3:
        result.errors.append(f"Too few keywords: {len(keywords)} (min 3)")
        result.score -= 10
    elif len(keywords) > 15:
        result.warnings.append(f"Many keywords: {len(keywords)} (3-8 recommended)")

    # License validation
    license_str = metadata.get("license", "")
    result.details["License"] = license_str
    if license_str not in VALID_LICENSES:
        result.errors.append(f"Invalid SPDX license: {license_str}")
        result.score -= 25

    # DOI validation
    doi = metadata.get("doi", "")
    result.details["DOI"] = doi
    if doi and not doi.startswith("10.5281/zenodo."):
        result.warnings.append(f"Unusual DOI format: {doi}")

    # Related identifiers
    related = metadata.get("related_identifiers", [])
    result.details["Related works"] = len(related)
    if len(related) == 0:
        result.warnings.append("No related identifiers")
        result.score -= 5

    # Version
    version = metadata.get("version", "")
    result.details["Version"] = version or "N/A"

    result.is_valid = len(result.errors) == 0
    return result

def main():
    import argparse

    parser = argparse.ArgumentParser(description="Validate Zenodo v9.0 metadata")
    parser.add_argument("--bundle", "-b", help="Bundle ID (B001-B007, PARENT)")
    parser.add_argument("--all", "-a", action="store_true", help="Validate all bundles")
    parser.add_argument("--score", "-s", action="store_true", help="Show scores only")
    args = parser.parse_args()

    bundles = []
    if args.all:
        bundles = list(BUNDLES.keys())
    elif args.bundle:
        bundles = [args.bundle.upper()]
    else:
        bundles = list(BUNDLES.keys())

    results = []
    total_score = 0

    for bundle_id in bundles:
        if bundle_id not in BUNDLES:
            print(f"❌ Unknown bundle: {bundle_id}")
            continue

        config = BUNDLES[bundle_id]
        json_path = Path(config["json"])

        if not json_path.exists():
            print(f"❌ File not found: {json_path}")
            continue

        with open(json_path) as f:
            metadata = json.load(f)

        result = validate_metadata(bundle_id, metadata)
        results.append(result)
        total_score += result.score

        if not args.score:
            result.print_report()

    # Summary
    print(f"\n{'='*60}")
    print(f"SUMMARY")
    print(f"{'='*60}")

    avg_score = total_score / len(results) if results else 0
    print(f"Average Score: {avg_score:.0f}/100")

    for result in results:
        status = "✅" if result.is_valid else "❌"
        print(f"  {status} {result.bundle}: {result.score:.0f}/100")

    # Overall status
    if all(r.is_valid for r in results):
        print(f"\n✅ All bundles VALID!")
        return 0
    else:
        invalid = [r.bundle for r in results if not r.is_valid]
        print(f"\n❌ Invalid bundles: {', '.join(invalid)}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
