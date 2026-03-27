#!/usr/bin/env python3
"""
Zenodo v8.0 Bundle Upload Script
Uploads enhanced v8.0 bundle metadata to Zenodo.

Usage:
    python3 tools/zenodo_upload_v8.py --bundle B001
    python3 tools/zenodo_upload_v8.py --all
    python3 tools/zenodo_upload_v8.py --dry-run --all
"""

import json
import os
import sys
import subprocess
from pathlib import Path
from typing import Optional

# Bundle configuration
BUNDLES = {
    "B001": {"json": "docs/research/.zenodo.B001_v8.0.json", "alias": "A"},
    "B002": {"json": "docs/research/.zenodo.B002_v8.0.json", "alias": "B"},
    "B003": {"json": "docs/research/.zenodo.B003_v8.0.json", "alias": "C"},
    "B004": {"json": "docs/research/.zenodo.B004_v8.0.json", "alias": "D"},
    "B005": {"json": "docs/research/.zenodo.B005_v8.0.json", "alias": "E"},
    "B006": {"json": "docs/research/.zenodo.B006_v8.0.json", "alias": "F"},
    "B007": {"json": "docs/research/.zenodo.B007_v8.0.json", "alias": "G"},
    "PARENT": {"json": "docs/research/.zenodo.PARENT_v8.0.json", "alias": "PARENT"},
}

ZENODO_API = "https://zenodo.org/api"


def load_token() -> str:
    """Load Zenodo token from .env file or environment."""
    # Try environment first
    token = os.getenv("ZENODO_TOKEN")
    if token:
        return token

    # Try .env file
    env_path = Path(".env")
    if env_path.exists():
        with open(env_path) as f:
            for line in f:
                if line.startswith("ZENODO_TOKEN="):
                    return line.split("=", 1)[1].strip()

    raise RuntimeError("ZENODO_TOKEN not found in environment or .env file")


def load_metadata(bundle_id: str) -> dict:
    """Load metadata JSON for a bundle."""
    config = BUNDLES.get(bundle_id)
    if not config:
        raise ValueError(f"Unknown bundle: {bundle_id}")

    json_path = Path(config["json"])
    if not json_path.exists():
        raise FileNotFoundError(f"Metadata file not found: {json_path}")

    with open(json_path) as f:
        return json.load(f)


def curl_get(url: str, token: str) -> str:
    """Perform GET request via curl."""
    result = subprocess.run(
        ["curl", "-s", "-X", "GET", url, "-H", f"Authorization: Bearer {token}"],
        capture_output=True,
        text=True,
    )
    return result.stdout


def curl_post(url: str, token: str, data: Optional[str] = None) -> str:
    """Perform POST request via curl."""
    cmd = ["curl", "-s", "-X", "POST", url, "-H", f"Authorization: Bearer {token}"]
    if data:
        cmd.extend(["-H", "Content-Type: application/json", "-d", data])
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.stdout


def curl_put(url: str, token: str, data: str) -> str:
    """Perform PUT request via curl."""
    result = subprocess.run(
        ["curl", "-s", "-X", "PUT", url, "-H", f"Authorization: Bearer {token}",
         "-H", "Content-Type: application/json", "-d", data],
        capture_output=True,
        text=True,
    )
    return result.stdout


def publish_bundle(bundle_id: str, token: str, dry_run: bool = False) -> dict:
    """Publish a single bundle to Zenodo."""
    print(f"\n{'='*60}")
    print(f"Publishing {bundle_id} to Zenodo...")
    print(f"{'='*60}")

    metadata = load_metadata(bundle_id)
    title = metadata.get("title", "Unknown")

    print(f"Title: {title}")
    print(f"Version: {metadata.get('version', '8.0')}")

    if dry_run:
        print(f"\n[DRY RUN] Would publish {bundle_id}")
        print(f"Metadata keys: {list(metadata.keys())}")
        return {"dry_run": True, "bundle": bundle_id}

    # Step 1: Create deposition
    print("\n[1/4] Creating deposition...")
    create_url = f"{ZENODO_API}/deposit/depositions"

    # Minimal metadata for creation
    create_data = json.dumps({"metadata": {"title": title, "upload_type": "software"}})
    resp = curl_post(create_url, token, create_data)

    try:
        dep_data = json.loads(resp)
    except json.JSONDecodeError:
        print(f"ERROR: Invalid response from Zenodo")
        print(f"Response: {resp[:500]}")
        raise

    dep_id = dep_data.get("id")
    if not dep_id:
        print(f"ERROR: Failed to create deposition")
        print(f"Response: {resp[:500]}")
        raise RuntimeError("Deposition creation failed")

    print(f"     Draft ID: {dep_id}")

    # Step 2: Update metadata
    print(f"\n[2/4] Updating metadata...")
    draft_url = f"{ZENODO_API}/deposit/depositions/{dep_id}"

    # Build full metadata
    full_metadata = {"metadata": metadata}
    meta_data = json.dumps(full_metadata, indent=2)
    resp = curl_put(draft_url, token, meta_data)

    if '"status": 4' in resp or '"status":4' in resp:
        print(f"WARNING: Metadata update may have issues")
        print(f"Response: {resp[:500]}")

    # Step 3: Upload figures
    print(f"\n[3/4] Uploading figures...")
    figures_dir = Path("docs/research/figures")

    figures = [
        "B001-Fig1_training_curve.png",
        "B001-Fig2_format_comparison.png",
        "B002-Fig1_fpga_resources.png",
        "B002-Fig2_power_analysis.png",
        "B003-Fig1_register_layout.png",
        "B004-Fig1_lotus_cycle.png",
        "B005-Fig1_type_hierarchy.png",
        "B006-Fig1_gf16_layout.png",
        "B006-Fig2_phi_heatmap.png",
        "B007-Fig1_vsa_structure.png",
        "B007-Fig2_simd_speedup.png",
    ]

    uploaded = 0
    for fig in figures:
        fig_path = figures_dir / fig
        if not fig_path.exists():
            continue

        # Upload file
        files_url = f"{ZENODO_API}/deposit/depositions/{dep_id}/files"
        file_arg = f"file=@{fig_path}"
        name_arg = f"name={fig}"

        result = subprocess.run(
            ["curl", "-s", "-X", "POST", files_url, "-H", f"Authorization: Bearer {token}",
             "-F", file_arg, "-F", name_arg],
            capture_output=True,
            text=True,
        )

        if result.returncode == 0:
            uploaded += 1

    print(f"     Uploaded {uploaded} figure files")

    # Step 4: Publish
    print(f"\n[4/4] Publishing...")
    pub_url = f"{ZENODO_API}/deposit/depositions/{dep_id}/actions/publish"
    resp = curl_post(pub_url, token)

    try:
        pub_data = json.loads(resp)
    except json.JSONDecodeError:
        print(f"ERROR: Invalid publish response")
        print(f"Response: {resp[:500]}")
        raise

    doi = pub_data.get("doi") or metadata.get("doi", "pending")
    concept_doi = pub_data.get("conceptdoi", "pending")

    print(f"\n{'='*60}")
    print(f"✅ {bundle_id} Published!")
    print(f"{'='*60}")
    print(f"DOI:         {doi}")
    if concept_doi != "pending":
        print(f"Concept DOI: {concept_doi}")
    print(f"URL:         https://doi.org/{doi}")

    return pub_data


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Upload Zenodo v8.0 bundles")
    parser.add_argument("--bundle", "-b", help="Bundle ID (B001-B007, PARENT)")
    parser.add_argument("--alias", "-a", help="Bundle alias (A-G, PARENT)")
    parser.add_argument("--all", action="store_true", help="Publish all bundles")
    parser.add_argument("--dry-run", "-n", action="store_true", help="Dry run (no upload)")
    args = parser.parse_args()

    if args.dry_run and not args.bundle and not args.alias and not args.all:
        parser.error("--dry-run requires --bundle, --alias, or --all")

    try:
        token = load_token()
    except RuntimeError as e:
        print(f"ERROR: {e}")
        print("\nGet your token at: https://zenodo.org/account/settings/applications/tokens/new/")
        sys.exit(1)

    # Determine bundles to publish
    bundles = []
    if args.all:
        bundles = list(BUNDLES.keys())
    elif args.bundle:
        bundles = [args.bundle.upper()]
    elif args.alias:
        alias = args.alias.upper()
        for bid, config in BUNDLES.items():
            if config["alias"] == alias:
                bundles = [bid]
                break
        if not bundles:
            print(f"ERROR: Unknown alias: {alias}")
            sys.exit(1)
    else:
        parser.error("Specify --bundle, --alias, or --all")

    # Publish bundles
    results = []
    for bundle_id in bundles:
        try:
            result = publish_bundle(bundle_id, token, args.dry_run)
            results.append((bundle_id, "success" if not args.dry_run else "dry_run"))
        except Exception as e:
            print(f"ERROR: Failed to publish {bundle_id}: {e}")
            results.append((bundle_id, "failed"))

    # Summary
    print(f"\n{'='*60}")
    print(f"Summary")
    print(f"{'='*60}")
    for bid, status in results:
        emoji = "✅" if status == "success" else "🔵" if status == "dry_run" else "❌"
        print(f"{emoji} {bid}: {status}")


if __name__ == "__main__":
    main()
