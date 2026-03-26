# Zenodo v6.1 Upload Automation Guide

**Version:** 1.0.0
**Date:** 2026-03-26
**Purpose:** Complete automation guide for uploading Trinity S³AI Zenodo bundles
**Related:** docs/research/ZENODO_V6.1_RELEASE_NOTES.md, docs/research/ZENODO_SCIENTIFIC_PATTERNS_COMPREHENSIVE_V1.md

---

## Overview

This guide provides automated workflows for uploading all 7 Trinity S³AI Zenodo bundles (B001-B007) plus the parent collection. Automation ensures consistency, reduces manual errors, and speeds up the upload process.

**Bundle Status:** v6.1 — All artifacts ready

| Bundle | DOI | Title | Status |
|--------|-----|-------|--------|
| **B001** | 10.5281/zenodo.19227733 | Ternary Neural Networks | ✅ Ready |
| **B002** | 10.5281/zenodo.19227735 | Zero-DSP FPGA | ✅ Ready |
| **B003** | 10.5281/zenodo.19227737 | TRI-27 ISA | ✅ Ready |
| **B004** | 10.5281/zenodo.19227739 | Queen Lotus Cycle | ✅ Ready |
| **B005** | 10.5281/zenodo.19227741 | Tri Language | ✅ Ready |
| **B006** | 10.5281/zenodo.19227743 | Sacred GF16/TF3 | ✅ Ready |
| **B007** | 10.5281/zenodo.19227745 | VSA Operations | ✅ Ready |
| **PARENT** | 10.5281/zenodo.19227879 | Trinity S³AI Framework | ✅ Ready |

---

## File Checklist

### Per Bundle Files

| Bundle | Files Required | Generated |
|--------|----------------|------------|
| **B001** | Description, 2 figures, 1 data CSV, 1 notebook, Dockerfile | ✅ All |
| **B002** | Description, 2 figures, 1 data CSV, 1 notebook, Dockerfile | ✅ All |
| **B003** | Description, 1 figure, 1 data CSV, Dockerfile | ✅ All |
| **B004** | Description, 1 figure, 1 data CSV, Dockerfile | ✅ All |
| **B005** | Description, 1 figure, 1 data CSV, Dockerfile | ✅ All |
| **B006** | Description, 2 figures, 1 data CSV, Dockerfile | ✅ All |
| **B007** | Description, 2 figures, 2 data CSV, 1 notebook, Dockerfile | ✅ All |

### Parent Collection Files

| File | Purpose | Status |
|------|---------|--------|
| README.md | Main index | ✅ |
| CITATION.cff | Citation metadata | ✅ |
| LICENSE | CC-BY-4.0 | ✅ |
| Cross-reference DOIs | Bundle links | ✅ |

---

## Upload Workflow

### Phase 1: Pre-Upload Validation (5 minutes)

```bash
# 1. Check all files exist
cd docs/research

python3 << 'EOF'
from pathlib import Path
import json

# Check figures
figures_dir = Path("figures")
png_count = len(list(figures_dir.glob("*.png")))
svg_count = len(list(figures_dir.glob("*.svg")))
print(f"✓ Figures: {png_count} PNG + {svg_count} SVG")

# Check data files
data_dir = Path("data")
csv_count = len(list(data_dir.glob("*.csv")))
print(f"✓ Data files: {csv_count} CSV")

# Check notebooks
notebooks_dir = Path("notebooks")
ipynb_count = len(list(notebooks_dir.glob("*.ipynb")))
print(f"✓ Notebooks: {ipynb_count} Jupyter")

# Check metadata
metadata_files = sorted(Path(".").glob(".zenodo.B*_v6.0.json"))
print(f"✓ Metadata files: {len(metadata_files)}")

# Validate JSON files
for meta_file in metadata_files:
    with open(meta_file) as f:
        data = json.load(f)
        required = ["title", "creators", "description", "keywords", "license"]
        missing = [r for r in required if r not in data]
        if missing:
            print(f"⚠ {meta_file.name}: Missing {missing}")
        else:
            print(f"✓ {meta_file.name}: Valid")
EOF
```

### Phase 2: Manual Upload (30-45 minutes)

For each bundle B001-B007:

1. **Visit Zenodo:** https://zenodo.org/deposit/new
2. **Select Upload Type:** "New upload"
3. **Fill Basic Information:**
   - Copy title from `.zenodo.B*_v6.0.json`
   - Copy description from `zenodo_B*_enhanced_v5.2.md`
   - Upload type: Software
4. **Upload Files:**
   - Enhanced description markdown
   - All figures (PNG + SVG)
   - Data CSV files
   - Jupyter notebooks (B001, B002, B007)
   - Dockerfile (optional)
5. **Enter Metadata:**
   - Authors: Copy from JSON
   - Keywords: Copy from JSON
   - License: CC-BY-4.0 (recommended)
   - Publication date: 2026-03-26
   - Version: 6.1
6. **Related Identifiers:**
   - Link to parent collection DOI
   - Link to GitHub repository
7. **Review and Publish:**
   - Check all metadata
   - Click "Publish"
   - Note new version DOI

### Phase 3: Parent Collection Update (10 minutes)

1. **Create new version** of parent collection (v5.0 → v6.1)
2. **Update README** with new bundle DOIs
3. **Add cross-references** to all 7 bundles
4. **Update CITATION.cff** with all DOIs
5. **Publish** parent collection

---

## API Automation (Optional)

### Zenodo API Setup

```python
# Required: pip3 install requests
import requests

ZENODO_API = "https://zenodo.org/api/deposit/depositions"
ACCESS_TOKEN = "YOUR_TOKEN"  # Get from: https://zenodo.org/account/settings/applications/tokens/new
```

### Upload Script Template

```python
#!/usr/bin/env python3
"""Zenodo API uploader for Trinity v6.1 bundles."""

import requests
import json
from pathlib import Path

# Configuration
ZENODO_API = "https://zenodo.org/api/deposit/depositions"
ACCESS_TOKEN = input("Enter Zenodo access token: ")

headers = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {ACCESS_TOKEN}"
}

def upload_bundle(bundle_id, metadata_file, description_file):
    """Upload a single bundle to Zenodo."""
    # Load metadata
    with open(metadata_file) as f:
        metadata = json.load(f)

    # Create new deposition
    response = requests.post(
        ZENODO_API,
        headers=headers,
        json={
            "metadata": metadata
        }
    )

    if response.status_code != 201:
        print(f"❌ Failed to create deposition: {response.text}")
        return None

    deposition_id = response.json()["id"]
    bucket_url = response.json()["links"]["bucket"]

    print(f"✓ Created deposition {deposition_id} for {bundle_id}")

    # Upload files
    upload_files(bucket_url, bundle_id)

    # Publish
    publish_url = f"{ZENODO_API}/{deposition_id}/actions/publish"
    publish_response = requests.post(publish_url, headers=headers)

    if publish_response.status_code == 202:
        print(f"✓ Published {bundle_id}")
        new_doi = publish_response.json().get("doi", "pending")
        print(f"  New DOI: {new_doi}")
    else:
        print(f"❌ Failed to publish: {publish_response.text}")

def upload_files(bucket_url, bundle_id):
    """Upload all files for a bundle."""
    figures_dir = Path("figures")
    data_dir = Path("data")
    notebooks_dir = Path("notebooks")

    # Upload description
    desc_file = Path(f"zenodo_{bundle_id.lower()}_enhanced_v5.2.md")
    with open(desc_file) as f:
        requests.put(
            f"{bucket_url}/{desc_file.name}",
            data=f,
            headers=headers
        )
    print(f"  ✓ Uploaded {desc_file.name}")

    # Upload figures
    for fig in figures_dir.glob(f"{bundle_id}-Fig*"):
        with open(fig) as f:
            requests.put(
                f"{bucket_url}/{fig.name}",
                data=f,
                headers=headers
            )
        print(f"  ✓ Uploaded {fig.name}")

    # Upload data files
    # ... similar pattern for CSV and notebooks

if __name__ == "__main__":
    bundles = ["B001", "B002", "B003", "B004", "B005", "B006", "B007"]
    for bundle_id in bundles:
        upload_bundle(bundle_id, f".zenodo.{bundle_id}_v6.0.json", None)
```

---

## Quality Assurance

### Pre-Upload Checklist

- [ ] All 22 figures generated (11 PNG + 11 SVG)
- [ ] All 8 data CSV files present
- [ ] All 3 Jupyter notebooks present
- [ ] All 7 Dockerfiles present
- [ ] All 7 enhanced description files ready
- [ ] All 7 metadata JSON files validated
- [ ] ORCID placeholder replaced with actual ORCID
- [ ] CITATION.cff updated with new DOIs

### Post-Upload Validation

For each bundle:

- [ ] DOI resolves (test with `curl -L https://doi.org/10.5281/zenodo.XXXXXX`)
- [ ] All files accessible
- [ ] Metadata displays correctly
- [ ] Related identifiers link correctly
- [ ] Parent collection links to bundle

### DOI Resolution Testing

```bash
# Test all DOIs
dois=(
    "10.5281/zenodo.19227733"  # B001
    "10.5281/zenodo.19227735"  # B002
    "10.5281/zenodo.19227737"  # B003
    "10.5281/zenodo.19227739"  # B004
    "10.5281/zenodo.19227741"  # B005
    "10.5281/zenodo.19227743"  # B006
    "10.5281/zenodo.19227745"  # B007
    "10.5281/zenodo.19227879"  # PARENT
)

for doi in "${dois[@]}"; do
    status=$(curl -Ls -o /dev/null -w "%{http_code}" https://doi.org/$doi 2>/dev/null)
    if [ "$status" = "200" ]; then
        echo "✓ $doi resolves"
    else
        echo "⚠ $doi returns $status"
    fi
done
```

---

## Troubleshooting

### Issue 1: File Size Too Large

**Symptom:** Upload fails with "file too large" error

**Solution:**
- Zenodo limit: 50 GB per upload
- If exceeded, compress files: `tar czf bundle.tar.gz files/`
- Upload compressed archive

### Issue 2: Metadata Validation Error

**Symptom:** "Invalid metadata" error

**Solution:**
- Check JSON syntax: `python3 -m json.tool .zenodo.B001_v6.0.json`
- Verify required fields present
- Check creator format: `"name": "Last, First"`

### Issue 3: DOI Conflict

**Symptom:** "DOI already exists" error

**Solution:**
- Zenodo DOI is reserved after upload
- Create new upload, not new version
- Contact Zenodo support if needed

### Issue 4: Figures Not Displaying

**Symptom:** Images don't show in Zenodo UI

**Solution:**
- Check file extension: must be `.png`, `.jpg`, `.svg`
- Verify MIME type: `file --mime-type figure.png`
- Ensure < 10 MB per file

---

## Quick Reference

### File Paths

```
docs/research/
├── figures/               # 22 files (11 PNG + 11 SVG)
│   ├── B001-Fig1_*.png/svg
│   ├── B002-Fig1_*.png/svg
│   └── ...
├── data/                  # 8 CSV files
│   ├── B001_training.csv
│   └── ...
├── notebooks/             # 3 Jupyter notebooks
│   ├── B001_Training_Analysis.ipynb
│   └── ...
├── zenodo_B*_enhanced_v5.2.md   # 7 description files
├── .zenodo.B*_v6.0.json        # 7 metadata JSON files
├── CITATION.cff            # Citation metadata
└── README_INDEX_V2.md        # Research index
```

### Zenodo URLs

| Action | URL |
|--------|-----|
| New upload | https://zenodo.org/deposit/new |
| My uploads | https://zenodo.org/deposit |
| Account settings | https://zenodo.org/account/settings |
| Token management | https://zenodo.org/account/settings/applications/tokens/new |
| Community | https://zenodo.org/communities/trinity-s3ai |

---

## Summary

This automation guide provides:

1. **Complete file checklist** for all 7 bundles
2. **Step-by-step upload workflow** with estimated time
3. **API automation template** for programmatic uploads
4. **Quality assurance checklists** for validation
5. **Troubleshooting guide** for common issues

**Estimated Total Time:**
- Pre-upload validation: 5 minutes
- Manual uploads (7 bundles): 30-45 minutes
- Parent collection: 10 minutes
- **Total: 45-60 minutes**

**φ² + 1/φ² = 3 | TRINITY**

**Document Control:** ZENODO-AUTO-001
**Status:** Active — Automation guide for Zenodo v6.1 uploads
