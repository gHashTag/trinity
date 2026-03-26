# Zenodo v6.2 Publication Guide

**Date:** 2026-03-27
**Version:** 6.2
**Status:** Ready for Upload

---

## Quick Start

```bash
# 1. Create GitHub release tag v6.2.0
gh release create v6.2.0 --title "v6.2.0 — Zenodo Publication" --notes "See Zenodo bundles"

# 2. Upload to Zenodo Web UI (8 depositions)
# Visit: https://zenodo.org/deposit
```

---

## Bundle Inventory

### Parent Collection
| File | Description |
|------|-------------|
| `ZENODO_README.md` | Parent collection overview |
| `.zenodo.PARENT_v6.2.json` | Metadata (DOI: 10.5281/zenodo.19227879) |

### Individual Bundles (7)

| Bundle | DOI | Files | LOC | Description |
|--------|-----|-------|-----|-------------|
| **B001** | 10.5281/zenodo.19227865 | 5 figures, 1 CSV | 520+ | HSLM Language Model |
| **B002** | 10.5281/zenodo.19227867 | 2 figures, 1 CSV | 470+ | FPGA Zero-DSP |
| **B003** | 10.5281/zenodo.19227869 | 1 figure, 1 CSV | 480+ | TRI-27 Ternary ISA |
| **B004** | 10.5281/zenodo.19227739 | 1 figure, 1 CSV | 450+ | Lotus Orchestration |
| **B005** | 10.5281/zenodo.19227741 | 1 figure, 1 CSV | 480+ | VIBEE Code Gen |
| **B006** | 10.5281/zenodo.19227743 | 2 figures, 1 CSV | 420+ | Sacred Formats |
| **B007** | 10.5281/zenodo.19227745 | 2 figures, 2 CSV | 460+ | VSA Vector Symbolic |

**Total LOC:** ~3280 lines across 7 bundles

---

## What's New in v6.2

### Enhanced Scientific Documentation
- ✅ **Statistical Rigor**: 95% confidence intervals, p-values, effect sizes
- ✅ **Calibration Metrics**: ECE, Brier score, reliability diagrams
- ✅ **Algorithm Boxes**: NeurIPS/ICLR compliant pseudocode
- ✅ **Hyperparameter Tables**: Complete with ablation results
- ✅ **Dataset Documentation**: Preprocessing, splits, provenance

### Format Improvements
- ✅ **LaTeX + Markdown**: Dual format for all bundles
- ✅ **Code Listings**: Syntax-highlighted Zig examples
- ✅ **Multi-Panel Figures**: Subfigure layouts with captions
- ✅ **Mathematical Proofs**: Theorem statements with formal verification

---

## Upload Procedure (Web UI)

### Step 1: Parent Collection

1. Visit https://zenodo.org/deposit
2. Select "New upload"
3. Upload `ZENODO_README.md`
4. Copy metadata from `.zenodo.PARENT_v6.2.json`
5. **DOI:** 10.5281/zenodo.19227879
6. Publish

### Step 2: Individual Bundles

For each bundle (B001-B007):

1. **Files to Upload:**
   ```
   zenodo_B{XXX}_enhanced_v6.2.md
   figures/B{XXX}-Fig*.png
   figures/B{XXX}-Fig*.svg
   data/B{XXX}_*.csv
   docker/Dockerfile.B{XXX}
   .zenodo.B{XXX}_v6.2.json
   ```

2. **Metadata:**
   - Copy from `.zenodo.B{XXX}_v6.2.json`
   - Verify ORCID: 0000-0000-0000-0000
   - Check keywords (MeSH + ACM CCS)

3. **DOI Assignment:**
   - Use existing DOIs from v5.0 → v6.2 upgrade
   - Or create new version of existing deposition

---

## Verification Checklist

Before publishing each bundle:

- [ ] Title matches `.zenodo.json`
- [ ] Authors: Dmitrii Vasilev (ORCID: 0000-0000-0000-0000)
- [ ] Affiliation: Trinity Research Collective
- [ ] License: CC-BY-4.0
- [ ] Version: 6.2
- [ ] Keywords present (11-14 terms)
- [ ] Related identifiers point to parent DOI
- [ ] Community: neurips, iclr, mlsys
- [ ] Figures uploaded (PNG + SVG)
- [ ] Data files uploaded (CSV)
- [ ] Code availability section present
- [ ] Build instructions tested
- [ ] Statistical analysis complete (CI, p-values, effect sizes)
- [ ] Algorithm boxes present
- [ ] Calibration metrics included

---

## Post-Publication

1. **Verify DOIs:**
   ```bash
   for doi in 19227865 19227867 19227869 19227739 19227741 19227743 19227745 19227879; do
     curl -L "https://doi.org/10.5281/zenodo.$doi"
   done
   ```

2. **Update README.md:**
   ```markdown
   ## Citation
   ```bibtex
   @misc{vasilev2026trinity,
     title={Trinity S³AI Framework v6.2},
     author={Vasilev, Dmitrii},
     year={2026},
     month={March},
     doi={10.5281/zenodo.19227879},
     url={https://doi.org/10.5281/zenodo.19227879}
   }
   ```
   ```

3. **Close Issue #435:**
   ```bash
   gh issue close 435 --comment "✅ Zenodo v6.2 published. DOIs: https://doi.org/10.5281/zenodo.19227879"
   ```

---

## Asset Manifest

### Figures (28 files)
```
figures/B001-Fig1_training_curve.{png,svg}
figures/B001-Fig2_format_comparison.{png,svg}
figures/B001-Fig3_fpga_resources.{png,svg}
figures/B001-Fig4_attention_heatmap.{png,svg}
figures/B001-Fig5_scaling_laws.{png,svg}
figures/B002-Fig1_fpga_resources.{png,svg}
figures/B002-Fig2_power_analysis.{png,svg}
figures/B003-Fig1_register_layout.{png,svg}
figures/B004-Fig1_lotus_cycle.{png,svg}
figures/B005-Fig1_type_hierarchy.{png,svg}
figures/B006-Fig1_gf16_layout.{png,svg}
figures/B006-Fig2_phi_heatmap.{png,svg}
figures/B007-Fig1_vsa_structure.{png,svg}
figures/B007-Fig2_simd_speedup.{png,svg}
```

### Data (10 files)
```
data/B001_training.csv
data/B002_fpga_synthesis.csv
data/B003_tri27_registers.csv
data/B004_lotus_cycle.csv
data/B005_language_features.csv
data/B005_productivity.csv
data/B006_gf16_accuracy.csv
data/B006_roundtrip_precision.csv
data/B007_noise_resilience.csv
data/B007_simd_benchmarks.csv
```

### Dockerfiles (7 files)
```
docker/Dockerfile.B001
docker/Dockerfile.B002
docker/Dockerfile.B003
docker/Dockerfile.B004
docker/Dockerfile.B005
docker/Dockerfile.B006
docker/Dockerfile.B007
```

### Metadata (8 files)
```
.zenodo.PARENT_v6.2.json
.zenodo.B001_v6.2.json
.zenodo.B002_v6.2.json
.zenodo.B003_v6.2.json
.zenodo.B004_v6.2.json
.zenodo.B005_v6.2.json
.zenodo.B006_v6.2.json
.zenodo.B007_v6.2.json
```

---

## Conference Submission Readiness

### NeurIPS 2026
- ✅ Abstract (5-sentence format)
- ✅ Algorithm boxes
- ✅ Statistical analysis (95% CI, p-values)
- ✅ Broader Impact statement
- ✅ Limitations section
- ✅ Code availability
- ✅ Calibration metrics

### ICLR 2027
- ✅ Open data policy (CSV files)
- ✅ Reproducibility (Dockerfiles)
- ✅ Code review checklist
- ✅ Experimental protocol
- ✅ Hyperparameter tables

### MLSys 2025
- ✅ System description
- ✅ Performance benchmarks
- ✅ Resource utilization
- ✅ Scalability analysis

---

## CLI Integration

Generate bundle metadata and upload scripts:

```bash
# Generate all bundle metadata
tri zenodo generate --version 6.2

# Create parent collection metadata
tri zenodo parent --version 6.2

# Verify bundle completeness
tri zenodo verify B001 B002 B003 B004 B005 B006 B007

# Generate upload checklist
tri zenodo checklist --version 6.2
```

---

**φ² + 1/φ² = 3 | TRINITY**
