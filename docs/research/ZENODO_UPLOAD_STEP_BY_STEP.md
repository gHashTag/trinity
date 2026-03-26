# Zenodo Upload Guide — Step by Step

**Version:** 6.1
**Date:** 2026-03-26
**Target:** All 7 bundles + parent collection

φ² + 1/φ² = 3 | TRINITY

---

## Prerequisites

### Account Setup
1. Visit https://zenodo.org
2. Sign in with ORCID (recommended)
3. Go to Account Settings → verify email

### Required Files per Bundle
- [ ] Description markdown (.md)
- [ ] Metadata JSON (.json) — for reference
- [ ] Figures (PNG + SVG) — 2-4 per bundle
- [ ] Data files (CSV) — 1-2 per bundle
- [ ] Dockerfile — 1 per bundle
- [ ] Jupyter notebook (.ipynb) — 1 per bundle (B001, B002, B007)

---

## Step 1: Navigate to Upload Page

1. Go to https://zenodo.org/deposit
2. Click "New upload" (top right)

---

## Step 2: Upload Files

### 2.1 File Upload Order (Recommended)

1. **Description file first** (drag & drop)
   - Example: `zenodo_B001_enhanced_v5.2.md`
   - This becomes the main description

2. **Figures second** (PNG + SVG pairs)
   - Upload all PNG files
   - Upload all SVG files
   - Example: `B001-Fig1_training_curve.png`, `B001-Fig1_training_curve.svg`

3. **Data files third** (CSV)
   - Example: `B001_training.csv`

4. **Dockerfile** (no extension needed)
   - Rename to `Dockerfile` for clarity
   - Or keep as `Dockerfile.B001`

5. **Jupyter notebooks** (if applicable)
   - Example: `B001_Training_Analysis.ipynb`

### 2.2 File Organization

Zenodo will organize files alphabetically. Consider this naming:

```
B001_Figures/
├── B001-Fig1_training_curve.png
├── B001-Fig1_training_curve.svg
├── B001-Fig2_format_comparison.png
└── B001-Fig2_format_comparison.svg

B001_Data/
└── B001_training.csv

B001_Code/
└── Dockerfile
```

---

## Step 3: Enter Metadata

### 3.1 Basic Information

| Field | Value for B001 |
|-------|----------------|
| **Title** | Trinity B001: Ternary Neural Networks — HSLM-1.95M Scientific Framework |
| **Upload Type** | Software |
| **Publication Date** | 2026-03-26 |
| **DOI** | 10.5281/zenodo.19227733 (for new version) |

### 3.2 Authors/Creators

```
Name: Vasilev, Dmitrii
ORCID: 0000-0000-0000-0000  ← Replace with your ORCID
Affiliation: Trinity Open Source Project
```

### 3.3 Description

Copy the entire content of `zenodo_B001_enhanced_v5.2.md` into the description field.

**Note:** Markdown formatting is supported.

### 3.4 Keywords

Copy from `.zenodo.B001_v6.0.json`:

```
Artificial Intelligence, Neural Networks, Computer Simulation, Algorithms,
ternary computing, balanced ternary, HSLM, 1.58-bit LLM, TinyStories,
perplexity, memory compression, sacred attention, phi-based scaling,
T-JEPA, cosine learning rate, ternary SGD, TF3, Zig, pure Zig,
zero dependencies, Computing methodologies--Neural networks,
Hardware--Emerging technologies, cs.AI, cs.LG, cs.AR, cs.NE, cs.PL
```

### 3.5 License

- **Select:** MIT License
- **OR** CC-BY-4.0 (for documentation)

### 3.6 Communities

- **Add:** `trinity-s3ai` (if community exists)

---

## Step 4: Related Work

### 4.1 Related Identifiers

Add each from `.zenodo.B001_v6.0.json`:

| Type | Identifier | Relation |
|------|-----------|----------|
| DOI | 10.5281/zenodo.19227879 | Is part of (parent collection) |
| URL | https://github.com/gHashTag/trinity | Is supplemented by |
| DOI | 10.48550/arXiv.2402.17764 | Cites |
| DOI | 10.48550/arXiv.2305.07759 | Uses data |
| DOI | 10.48550/arXiv.2502.16473 | Compares with |

### 4.2 References

Add manually (copy from JSON):

```
[1] Ma et al., The Era of 1-bit LLMs: All Large Language Models are in 1.58 Bits, arXiv:2402.17764 (2024)
[2] Eldan & Li, TinyStories: How Small Can Language Models Be and Still Speak Coherent English?, arXiv:2305.07759 (2023)
[3] Ma et al., TerEffic: Highly Efficient Ternary LLM Inference on FPGA, arXiv:2502.16473 (2025)
[4] Livio, The Golden Ratio: The Story of Phi, Broadway Books (2008)
```

---

## Step 5: Review and Publish

### 5.1 Pre-Publish Checklist

- [ ] All files uploaded
- [ ] Description is complete
- [ ] ORCID is correct (not placeholder)
- [ ] Keywords include MeSH + ACM CCS
- [ ] Related identifiers point to correct DOIs
- [ ] License is appropriate
- [ ] No typos in title or author name

### 5.2 Publish

1. Click "Publish" (bottom right)
2. Confirm: "Yes, publish this upload"
3. Wait for DOI minting (~30 seconds)
4. Record new DOI (if creating new version)

---

## Step 6: Parent Collection Update

### 6.1 Create New Version

1. Go to parent record: https://zenodo.org/record/19227879
2. Click "New version"
3. Upload updated `ZENODO_README.md`
4. Add all child bundle DOIs to related identifiers

### 6.2 Parent README Template

```markdown
# Trinity S³AI Framework — Complete Collection

**Version:** 6.1
**Publication Date:** 2026-03-26
**DOI:** 10.5281/zenodo.19227879

## Bundles

| ID | Title | DOI | Focus |
|----|-------|-----|-------|
| B001 | Ternary Neural Networks | 10.5281/zenodo.19227733 | HSLM-1.95M |
| B002 | Zero-DSP FPGA | 10.5281/zenodo.19227735 | Pure LUT inference |
| B003 | TRI-27 ISA | 10.5281/zenodo.19227737 | 27-register instruction set |
| B004 | Queen Lotus Cycle | 10.5281/zenodo.19227739 | Autonomous learning |
| B005 | Tri Language | 10.5281/zenodo.19227741 | Linear types, effects |
| B006 | Sacred GF16/TF3 | 10.5281/zenodo.19227743 | φ-optimal number formats |
| B007 | VSA Operations | 10.5281/zenodo.19227745 | HybridBigInt + SIMD |

## Citation

```bibtex
@software{trinity_s3ai_2026,
  title = {Trinity S³AI Framework: Complete Collection},
  author = {Vasilev, Dmitrii},
  doi = {10.5281/zenodo.19227879},
  year = 2026
}
```
```

---

## Step 7: Post-Upload Verification

### 7.1 DOI Resolution

Test each DOI:
```bash
# Should redirect to Zenodo record
curl -L https://doi.org/10.5281/zenodo.19227733
```

### 7.2 File Accessibility

Download each file to verify:
- Description renders correctly
- Figures display at full resolution
- CSV files are valid
- Dockerfiles are syntactically correct

### 7.3 Metadata Display

Check that:
- Author name is correctly formatted
- Keywords are all visible
- Related identifiers link correctly
- Citation preview is accurate

---

## Troubleshooting

### Issue: Upload fails midway
**Solution:** Use Zenodo CLI or split into smaller batches

### Issue: DOI not minting
**Solution:** Wait 5 minutes and refresh, or contact Zenodo support

### Issue: Files not displaying
**Solution:** Check file size (<50MB per file) and format

### Issue: Community not found
**Solution:** Create community first at https://zenodo.org/communities

---

## API Upload (Alternative)

```bash
# Set token
export ZENODO_TOKEN=your_token_here

# Create deposition
curl -X POST https://zenodo.org/api/deposit/depositions \
  --header "Authorization: Bearer $ZENODO_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{"metadata": {...}}'

# Upload files
curl -X POST https://zenodo.org/api/deposition/{id}/files \
  --header "Authorization: Bearer $ZENODO_TOKEN" \
  --header "Content-Type: application/octet-stream" \
  --data-binary @filename

# Publish
curl -X POST https://zenodo.org/api/deposit/depositions/{id}/actions/publish \
  --header "Authorization: Bearer $ZENODO_TOKEN"
```

---

## Quick Reference: File Checklist

### B001 (HSLM)
- [ ] zenodo_B001_enhanced_v5.2.md
- [ ] B001-Fig1_training_curve.png + .svg
- [ ] B001-Fig2_format_comparison.png + .svg
- [ ] B001_training.csv
- [ ] Dockerfile.B001
- [ ] B001_Training_Analysis.ipynb

### B002 (FPGA)
- [ ] zenodo_B002_enhanced_v5.2.md
- [ ] B002-Fig1_fpga_resources.png + .svg
- [ ] B002-Fig2_power_analysis.png + .svg
- [ ] B002_fpga_synthesis.csv
- [ ] Dockerfile.B002
- [ ] B002_FPGA_Analysis.ipynb

### B003 (TRI-27)
- [ ] zenodo_B003_enhanced_v5.2.md
- [ ] B003-Fig1_register_layout.png + .svg
- [ ] B003_tri27_registers.csv
- [ ] Dockerfile.B003

### B004 (Lotus)
- [ ] zenodo_B004_enhanced_v5.2.md
- [ ] B004-Fig1_lotus_cycle.png + .svg
- [ ] B004_lotus_cycle.csv
- [ ] Dockerfile.B004

### B005 (Tri Language)
- [ ] zenodo_B005_enhanced_v5.2.md
- [ ] B005-Fig1_type_hierarchy.png + .svg
- [ ] B005_language_features.csv
- [ ] Dockerfile.B005

### B006 (GF16/TF3)
- [ ] zenodo_B006_enhanced_v5.2.md
- [ ] B006-Fig1_gf16_layout.png + .svg
- [ ] B006-Fig2_phi_heatmap.png + .svg
- [ ] B006_gf16_accuracy.csv
- [ ] Dockerfile.B006

### B007 (VSA)
- [ ] zenodo_B007_enhanced_v5.2.md
- [ ] B007-Fig1_vsa_structure.png + .svg
- [ ] B007-Fig2_simd_speedup.png + .svg
- [ ] B007_simd_benchmarks.csv
- [ ] B007_noise_resilience.csv
- [ ] Dockerfile.B007
- [ ] B007_VSA_Analysis.ipynb

### PARENT
- [ ] ZENODO_README.md (v6.1)
- [ ] CITATION.cff
- [ ] TRINITY_S3AI_UNIFIED_FRAMEWORK.md

---

**φ² + 1/φ² = 3 | TRINITY**
