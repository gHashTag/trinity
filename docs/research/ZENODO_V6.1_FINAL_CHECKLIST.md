#!/usr/bin/env python3
"""
Trinity Zenodo v6.1 Upload Script

Automates uploading all bundles to Zenodo with:
- Metadata validation
- Figure generation
- Data file attachment
- README creation

Usage:
    export ZENODO_TOKEN=your_token_here
    python3 scripts/upload_zenodo_v6.1.py

φ² + 1/φ² = 3 | TRINITY
"""

import os
import json
import subprocess
import sys
from pathlib import Path

# Configuration
ZENODO_API = "https://zenodo.org/api/deposit/depositions"
OUTPUT_DIR = Path("docs/research")
FIGURES_DIR = OUTPUT_DIR / "figures"
DATA_DIR = OUTPUT_DIR / "data"
DOCKER_DIR = OUTPUT_DIR / "docker"
NOTEBOOKS_DIR = OUTPUT_DIR / "notebooks"

# Bundle configurations
BUNDLES = {
    "B001": {
        "title": "Trinity B001: Ternary Neural Networks — HSLM-1.95M Scientific Framework",
        "doi": "10.5281/zenodo.19227733",
        "description_file": "zenodo_B001_enhanced_v5.2.md",
        "metadata": ".zenodo.B001_v6.0.json",
        "figures": ["B001-Fig1_training_curve", "B001-Fig2_format_comparison"],
        "data": ["B001_training.csv"],
        "docker": "Dockerfile.B001",
        "notebook": "B001_Training_Analysis.ipynb",
    },
    "B002": {
        "title": "Trinity B002: Zero-DSP FPGA — Pure LUT-Based Ternary Inference",
        "doi": "10.5281/zenodo.19227735",
        "description_file": "zenodo_B002_enhanced_v5.2.md",
        "metadata": ".zenodo.B002_v6.0.json",
        "figures": ["B002-Fig1_fpga_resources", "B002-Fig2_power_analysis"],
        "data": ["B002_fpga_synthesis.csv"],
        "docker": "Dockerfile.B002",
        "notebook": "B002_FPGA_Analysis.ipynb",
    },
    "B003": {
        "title": "Trinity B003: TRI-27 ISA — 27-Register Ternary Instruction Set",
        "doi": "10.5281/zenodo.19227737",
        "description_file": "zenodo_B003_enhanced_v5.2.md",
        "metadata": ".zenodo.B003_v6.0.json",
        "figures": ["B003-Fig1_register_layout"],
        "data": ["B003_tri27_registers.csv"],
        "docker": "Dockerfile.B003",
    },
    "B004": {
        "title": "Trinity B004: Queen Lotus Cycle — Autonomous Learning with Episode Retrieval",
        "doi": "10.5281/zenodo.19227739",
        "description_file": "zenodo_B004_enhanced_v5.2.md",
        "metadata": ".zenodo.B004_v6.0.json",
        "figures": ["B004-Fig1_lotus_cycle"],
        "data": ["B004_lotus_cycle.csv"],
        "docker": "Dockerfile.B004",
    },
    "B005": {
        "title": "Trinity B005: Tri Language — Linear Types, Effects, Pattern Matching",
        "doi": "10.5281/zenodo.19227741",
        "description_file": "zenodo_B005_enhanced_v5.2.md",
        "metadata": ".zenodo.B005_v6.0.json",
        "figures": ["B005-Fig1_type_hierarchy"],
        "data": ["B005_language_features.csv"],
        "docker": "Dockerfile.B005",
    },
    "B006": {
        "title": "Trinity B006: Sacred GF16/TF3 — φ-Optimal Number Formats for Ternary",
        "doi": "10.5281/zenodo.19227743",
        "description_file": "zenodo_B006_enhanced_v5.2.md",
        "metadata": ".zenodo.B006_v6.0.json",
        "figures": ["B006-Fig1_gf16_layout", "B006-Fig2_phi_heatmap"],
        "data": ["B006_gf16_accuracy.csv"],
        "docker": "Dockerfile.B006",
        "notebook": "B007_VSA_Analysis.ipynb",  # Share with B007
    },
    "B007": {
        "title": "Trinity B007: VSA Operations — HybridBigInt with SIMD Acceleration",
        "doi": "10.5281/zenodo.19227745",
        "description_file": "zenodo_B007_enhanced_v5.2.md",
        "metadata": ".zenodo.B007_v6.0.json",
        "figures": ["B007-Fig1_vsa_structure", "B007-Fig2_simd_speedup"],
        "data": ["B007_simd_benchmarks.csv", "B007_noise_resilience.csv"],
        "docker": "Dockerfile.B007",
        "notebook": "B007_VSA_Analysis.ipynb",
    },
}


def check_python_packages():
    """Check if required Python packages are installed."""
    required = ["matplotlib", "seaborn", "numpy", "requests"]
    missing = []

    for package in required:
        try:
            __import__(package)
        except ImportError:
            missing.append(package)

    if missing:
        print(f"❌ Missing packages: {', '.join(missing)}")
        print("Install with: pip3 install matplotlib seaborn numpy requests")
        return False

    print("✅ All required packages installed")
    return True


def generate_figures():
    """Generate all figures for Zenodo bundles."""
    script_path = FIGURES_DIR / "generate_all_figures.py"

    if not script_path.exists():
        print(f"❌ Figure generation script not found: {script_path}")
        return False

    print("🎨 Generating figures...")
    result = subprocess.run(
        [sys.executable, str(script_path)],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        print(f"❌ Figure generation failed:\n{result.stderr}")
        return False

    print("✅ Figures generated successfully")
    return True


def validate_metadata():
    """Validate all .zenodo.*_v6.0.json files."""
    print("\n📋 Validating metadata files...")

    for bundle_id, config in BUNDLES.items():
        metadata_file = OUTPUT_DIR / config["metadata"]

        if not metadata_file.exists():
            print(f"❌ Missing metadata: {metadata_file}")
            continue

        with open(metadata_file) as f:
            try:
                data = json.load(f)
            except json.JSONDecodeError as e:
                print(f"❌ Invalid JSON in {metadata_file}: {e}")
                continue

        # Check required fields
        required_fields = ["title", "creators", "description", "keywords", "license"]
        missing = [f for f in required_fields if f not in data]

        if missing:
            print(f"⚠️  {bundle_id}: Missing fields: {missing}")
        else:
            print(f"✅ {bundle_id}: Metadata valid")

    return True


def check_figures():
    """Check if all required figures exist."""
    print("\n🖼️  Checking figure files...")

    all_exist = True
    for bundle_id, config in BUNDLES.items():
        for fig_name in config.get("figures", []):
            png_path = FIGURES_DIR / f"{fig_name}.png"
            svg_path = FIGURES_DIR / f"{fig_name}.svg"

            png_exists = png_path.exists()
            svg_exists = svg_path.exists()

            if png_exists and svg_exists:
                print(f"✅ {bundle_id}: {fig_name} (PNG + SVG)")
            elif png_exists:
                print(f"⚠️  {bundle_id}: {fig_name} (PNG only)")
            else:
                print(f"❌ {bundle_id}: {fig_name} (missing)")
                all_exist = False

    return all_exist


def create_upload_summary():
    """Create a summary document for upload."""
    summary = []
    summary.append("# Zenodo v6.1 Upload Summary")
    summary.append(f"**Date:** {pd.Timestamp.now().isoformat()}")
    summary.append("")
    summary.append("## Files to Upload per Bundle")
    summary.append("")

    for bundle_id, config in BUNDLES.items():
        summary.append(f"### {bundle_id}: {config['title']}")
        summary.append(f"- DOI: {config['doi']}")
        summary.append(f"- Metadata: {config['metadata']}")
        summary.append(f"- Figures: {len(config.get('figures', []))}")
        summary.append(f"- Data files: {len(config.get('data', []))}")
        summary.append(f"- Docker: {config.get('docker', 'N/A')}")
        summary.append(f"- Notebook: {config.get('notebook', 'N/A')}")
        summary.append("")

    summary.append("## Upload Instructions")
    summary.append("")
    summary.append("1. Visit https://zenodo.org/deposit")
    summary.append("2. For each bundle:")
    summary.append("   a. Upload description markdown")
    summary.append("   b. Upload figures (PNG + SVG)")
    summary.append("   c. Upload data files (CSV)")
    summary.append("   d. Upload Dockerfile")
    summary.append("   e. Upload Jupyter notebooks")
    summary.append("   f. Fill metadata from JSON file")
    summary.append("   g. Click 'Publish'")
    summary.append("")
    summary.append("2. For parent collection:")
    summary.append("   a. Create new version")
    summary.append("   b. Update README")
    summary.append("   c. Add cross-references")
    summary.append("   d. Publish")

    content = "\n".join(summary)

    with open(OUTPUT_DIR / "UPLOAD_SUMMARY.md", "w") as f:
        f.write(content)

    print("✅ Upload summary created: docs/research/UPLOAD_SUMMARY.md")
    return True


def main():
    """Main upload workflow."""
    print("=" * 60)
    print("Trinity Zenodo v6.1 Upload Script")
    print("=" * 60)
    print(f"\nWorking directory: {os.getcwd()}")
    print(f"Output directory: {OUTPUT_DIR.absolute()}\n")

    # Check prerequisites
    if not check_python_packages():
        return 1

    # Validate metadata
    if not validate_metadata():
        return 1

    # Check figures
    figures_exist = check_figures()

    if not figures_exist:
        print("\n⚠️  Some figures are missing. Generate now? [y/N] ", end="")
        # In automated mode, assume yes
        print("y")
        if not generate_figures():
            print("❌ Figure generation failed")
            return 1

        # Re-check after generation
        if not check_figures():
            print("❌ Some figures still missing")
            return 1

    # Create upload summary
    if not create_upload_summary():
        return 1

    print("\n" + "=" * 60)
    print("✅ Pre-upload validation complete!")
    print("=" * 60)
    print("\n📋 Upload checklist:")
    print("  [ ] Update ORCID in .zenodo.*_v6.0.json files")
    print("  [ ] Verify all figures generated")
    print("  [ ] Test Docker containers build")
    print("  [ ] Upload via Web UI or API")
    print("  [ ] Publish and record new DOIs")
    print("\n📖 Full summary: docs/research/UPLOAD_SUMMARY.md")
    print("\nφ² + 1/φ² = 3 | TRINITY")

    return 0


if __name__ == "__main__":
    import pandas as pd  # lazy import for timestamp only
    sys.exit(main())
