# Zenodo v6.0 — Complete Upload Guide

**Date:** 2026-03-26
**Version:** 6.0
**Purpose:** Step-by-step guide for uploading all 8 bundles to Zenodo

---

## Overview

This guide provides complete instructions for uploading the Trinity S³AI Framework v6.0 to Zenodo, including all 7 bundles (B001-B007) and the parent collection.

---

## Pre-Upload Checklist

### Step 1: Update ORCID (REQUIRED)

All `.zenodo.*_v6.0.json` files contain placeholder ORCID `0000-0000-0000-0000`. Before uploading, you MUST update these with your real ORCID.

**Command:**
```bash
cd docs/research
# Update ORCID placeholder in all metadata files
sed -i '' 's/0000-0000-0000-0000/YOUR_REAL_ORCID/g' .zenodo.*_v6.0.json

# Verify changes
grep "orcid" .zenodo.*_6.0.json
```

**Files to Update:**
- `.zenodo.B001_v6.0.json`
- `.zenodo.B002_v6.0.json`
- `.zenodo.B003_v6.0.json`
- `.zenodo.B004_v6.0.json`
- `.zenodo.B005_v6.0.json`
- `.zenodo.B006_v6.0.json`
- `.zenodo.B007_v6.0.json`
- `.zenodo.parent_v6.0.json`

### Step 2: Verify Package Contents

```bash
cd docs/research

# Check all files exist
ls -la interactive/*.html  # Should show 8 HTML files
ls -la figures/B*-Fig*.{png,svg}  # Should show 22 figures
ls -la data/*.csv  # Should show 8 CSV files
```

**Expected Files:**

| Category | Count | Status |
|----------|-------|--------|
| Interactive HTML | 8 | ✅ |
| Figures (PNG+SVG) | 22 | ✅ |
| CSV Data | 8 | ✅ |
| Metadata JSON | 8 | ✅ |
| Bundle Descriptions | 7 | ✅ |
| Parent README | 1 | ✅ |

---

## Upload Instructions

### Part A: Upload Individual Bundles (B001-B007)

For each bundle B001 through B007:

1. **Go to Zenodo Deposit**
   - Visit: https://zenodo.org/deposit/new
   - Log in with your ORCID account

2. **Select Upload Type**
   - Choose: **Software**

3. **Fill Basic Information**
   - Title: Auto-filled from metadata
   - Upload Type: Software

4. **Upload Files**

   For each bundle, upload the following files:

   | File Type | Files to Upload |
   |-----------|----------------|
   | **Description** | `zenodo_B*_enhanced_v5.2.md` |
   | **Figures** | All `figures/B*-Fig*.{png,svg}` for that bundle |
   | **Data** | All `data/B*_*.csv` for that bundle |
   | **Interactive** | All `interactive/*_Viewer.html` (can upload as supplementary) |

5. **Fill Metadata from JSON**

   Open the corresponding `.zenodo.B*_v6.0.json` file and copy the values:

   - **Title:** Copy from JSON
   - **Authors:** Copy from JSON (update ORCID first!)
   - **Description:** Copy from JSON (already formatted)
   - **Keywords:** Copy from JSON
   - **License:** CC-BY-4.0 (already selected)

6. **Communities**
   - Add: `trinity-s3ai`

7. **Publication Date**
   - Use: 2026-03-26

8. **Related Identifiers**
   - Add parent collection: `10.5281/zenodo.19227879`

9. **Save as Draft**
   - Click "Save" to create the draft

10. **Publish**
    - Review all information
    - Click "Publish" to get new DOI

**Repeat for all 7 bundles (B001-B007).**

---

### Part B: Update Parent Collection

After all 7 bundles are published:

1. **Go to Parent Collection**
   - Visit: https://zenodo.org/record/10.5281/19227879

2. **Edit Record**
   - Click "Edit"

3. **Update Related Identifiers**
   - Add all new v6.0 DOIs from B001-B007
   - Format: Each should be "isPartOf" relationship

4. **Update Description**
   - Add reference to all 7 bundles
   - Note that this is v6.0 with interactive viewers

5. **Publish Update**
   - Click "Publish" to save changes

---

## Post-Upload Verification

### Verify All DOIs

After upload, you should have 8 new DOIs:

| Bundle | DOI |
|--------|-----|
| B001 | 10.5281/zenodo.19227733 |
| B002 | 10.5281/zenodo.19227735 |
| B003 | 10.5281/zenodo.19227737 |
| B004 | 10.5281/zenodo.19227739 |
| B005 | 10.5281/zenodo.19227741 |
| B006 | 10.5281/zenodo.19227743 |
| B007 | 10.5281/zenodo.19227745 |
| PARENT | 10.5281/zenodo.19227879 |

### Test DOIs

```bash
# Test each DOI (should return 200)
curl -I https://doi.org/10.5281/zenodo.19227733
curl -I https://doi.org/10.5281/zenodo.19227735
# ... etc for all DOIs
```

---

## File Inventory Reference

### B001: Ternary Neural Networks

| File | Purpose |
|------|---------|
| `zenodo_B001_enhanced_v5.2.md` | Main description |
| `figures/B001-Fig1_training_curve.{png,svg}` | Training curve |
| `figures/B001-Fig2_format_comparison.{png,svg}` | Format comparison |
| `data/B001_training.csv` | Training data |
| `interactive/B001_Training_Viewer.html` | Interactive viewer |

### B002: Zero-DSP FPGA

| File | Purpose |
|------|---------|
| `zenodo_B002_enhanced_v5.2.md` | Main description |
| `figures/B002-Fig1_fpga_resources.{png,svg}` | Resource usage |
| `figures/B002-Fig2_power_analysis.{png,svg}` | Power analysis |
| `data/B002_fpga_synthesis.csv` | Synthesis data |
| `interactive/B002_FPGA_Viewer.html` | Interactive viewer |

### B003: TRI-27 ISA

| File | Purpose |
|------|---------|
| `zenodo_B003_enhanced_v5.2.md` | Main description |
| `figures/B003-Fig1_register_layout.{png,svg}` | Register layout |
| `figures/B003-Fig2_opcode_table.{png,svg}` | Opcode table |
| `data/B003_tri27_registers.csv` | Register data |
| `interactive/B003_TRI27_Viewer.html` | Interactive viewer |

### B004: Queen Lotus Cycle

| File | Purpose |
|------|---------|
| `zenodo_B004_enhanced_v5.2.md` | Main description |
| `figures/B004-Fig1_lotus_cycle.{png,svg}` | Lotus cycle diagram |
| `figures/B004-Fig2_quality_distribution.{png,svg}` | Quality distribution |
| `data/B004_lotus_cycle.csv` | Episode data |
| `interactive/B004_Lotus_Cycle_Viewer.html` | Interactive viewer |

### B005: Tri Language

| File | Purpose |
|------|---------|
| `zenodo_B005_enhanced_v5.2.md` | Main description |
| `figures/B005-Fig1_type_hierarchy.{png,svg}` | Type hierarchy |
| `figures/B005-Fig2_vibee_pipeline.{png,svg}` | VIBEE pipeline |
| `data/B005_language_features.csv` | Feature matrix |
| `interactive/B005_Tri_Language_Viewer.html` | Interactive viewer |

### B006: GF16/TF3

| File | Purpose |
|------|---------|
| `zenodo_B006_enhanced_v5.2.md` | Main description |
| `figures/B006-Fig1_gf16_layout.{png,svg}` | GF16 layout |
| `figures/B006-Fig2_phi_heatmap.{png,svg}` | φ-distance heatmap |
| `data/B006_gf16_accuracy.csv` | Accuracy data |
| `interactive/B006_GF16_TF3_Viewer.html` | Interactive viewer |

### B007: VSA Operations

| File | Purpose |
|------|---------|
| `zenodo_B007_enhanced_v5.2.md` | Main description |
| `figures/B007-Fig1_vsa_structure.{png,svg}` | VSA structure |
| `figures/B007-Fig2_simd_speedup.{png,svg}` | SIMD speedup |
| `data/B007_simd_benchmarks.csv` | SIMD data |
| `data/B007_noise_resilience.csv` | Noise tolerance |
| `interactive/B007_VSA_Operations_Viewer.html` | Interactive viewer |

---

## Troubleshooting

### ORCID Not Found

**Error:** "ORCID not found"

**Solution:**
1. Go to https://orcid.org/register
2. Create an ORCID account
3. Get your ORCID (format: 0000-0000-0000-0000)
4. Update `.zenodo.*_v6.0.json` files
5. Re-upload

### File Size Limit

**Error:** "File too large"

**Solution:**
- Zenodo has a 50GB file size limit
- Our total package is ~220MB (well under limit)
- Upload each bundle separately if needed

### License Selection

**Required:** CC-BY-4.0

**Do NOT use:**
- CC0 (requires attribution waiver)
- CC-BY-NC (non-commercial not allowed)
- CC-BY-SA (share-alike not needed)

---

## Citation Examples

### APA 7th Edition (All Bundles)

```
Vasilev, D. (2026). Trinity S³AI Framework: Ternary Symbolic AI (Version 6.0)
[Zenodo]. https://doi.org/10.5281/zenodo.19227879
```

### BibTeX (Complete)

```bibtex
@software{trinity_s3ai_v6_0_2026,
  author       = {Vasilev, Dmitrii},
  title        = {Trinity S³AI Framework: Ternary Symbolic AI},
  year         = 2026,
  version      = {6.0},
  doi          = {10.5281/zenodo.19227879},
  url          = {https://doi.org/10.5281/zenodo.19227879},
  publisher    = {Zenodo},
  license      = {CC-BY-4.0},
  keywords     = {ternary, VSA, hyperdimensional, FPGA, Zig, consciousness}
}
```

---

## Support

For issues or questions:
- GitHub Issues: https://github.com/gHashTag/trinity/issues
- Email: [via GitHub contact form]

---

**φ² + 1/φ² = 3 | TRINITY**

**Status: 🚀 Ready for Zenodo v6.0 Upload**
