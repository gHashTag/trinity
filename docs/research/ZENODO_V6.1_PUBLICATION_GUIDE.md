# Zenodo v6.1 Publication Guide

**Date:** 2026-03-27
**Version:** 6.1
**Status:** Ready for Upload

---

## Quick Start

```bash
# 1. Create GitHub release tag v6.1.0
gh release create v6.1.0 --title "v6.1.0 — Zenodo Publication" --notes "See Zenodo bundles"

# 2. Upload to Zenodo Web UI (8 depositions)
# Visit: https://zenodo.org/deposit
```

---

## Bundle Inventory

### Parent Collection
| File | Description |
|------|-------------|
| `ZENODO_README.md` | Parent collection overview |
| `.zenodo.PARENT_v6.1.json` | Metadata (DOI: 10.5281/zenodo.19227879) |

### Individual Bundles (7)

| Bundle | DOI | Files | LOC |
|--------|-----|-------|-----|
| **B001** | 10.5281/zenodo.19227865 | 5 figures, 1 CSV | 511 |
| **B002** | 10.5281/zenodo.19227867 | 2 figures, 1 CSV | 461 |
| **B003** | 10.5281/zenodo.19227869 | 1 figure, 1 CSV | 469 |
| **B004** | 10.5281/zenodo.19227739 | 1 figure, 1 CSV | 443 |
| **B005** | 10.5281/zenodo.19227741 | 1 figure, 1 CSV | 479 |
| **B006** | 10.5281/zenodo.19227743 | 2 figures, 1 CSV | 412 |
| **B007** | 10.5281/zenodo.19227745 | 2 figures, 2 CSV | 454 |

---

## Upload Procedure (Web UI)

### Step 1: Parent Collection

1. Visit https://zenodo.org/deposit
2. Select "New upload"
3. Upload `ZENODO_README.md`
4. Copy metadata from `.zenodo.PARENT_v6.1.json`
5. **DOI:** 10.5281/zenodo.19227879
6. Publish

### Step 2: Individual Bundles

For each bundle (B001-B007):

1. **Files to Upload:**
   ```
   zenodo_B{XXX}_enhanced_v6.1.md
   figures/B{XXX}-Fig*.png
   figures/B{XXX}-Fig*.svg
   data/B{XXX}_*.csv
   docker/Dockerfile.B{XXX}
   .zenodo.B{XXX}_v6.1.json
   ```

2. **Metadata:**
   - Copy from `.zenodo.B{XXX}_v6.1.json`
   - Verify ORCID: 0000-0000-0000-0000
   - Check keywords (MeSH + ACM CCS)

3. **DOI Assignment:**
   - Use existing DOIs from v5.0 → v6.1 upgrade
   - Or create new version of existing deposition

---

## Verification Checklist

Before publishing each bundle:

- [ ] Title matches `.zenodo.json`
- [ ] Authors: Dmitrii Vasilev (ORCID: 0000-0000-0000-0000)
- [ ] Affiliation: Trinity Research Collective
- [ ] License: CC-BY-4.0
- [ ] Version: 6.1
- [ ] Keywords present (11-14 terms)
- [ ] Related identifiers point to parent DOI
- [ ] Community: neurips, iclr, mlsys
- [ ] Figures uploaded (PNG + SVG)
- [ ] Data files uploaded (CSV)
- [ ] Code availability section present
- [ ] Build instructions tested

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
     title={Trinity S³AI Framework v6.1},
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
   gh issue close 435 --comment "✅ Zenodo v6.1 published. DOIs: https://doi.org/10.5281/zenodo.19227879"
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
.zenodo.PARENT_v6.1.json
.zenodo.B001_v6.1.json
.zenodo.B002_v6.1.json
.zenodo.B003_v6.1.json
.zenodo.B004_v6.1.json
.zenodo.B005_v6.1.json
.zenodo.B006_v6.1.json
.zenodo.B007_v6.1.json
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

### ICLR 2027
- ✅ Open data policy (CSV files)
- ✅ Reproducibility (Dockerfiles)
- ✅ Code review checklist
- ✅ Experimental protocol

### MLSys 2025
- ✅ System description
- ✅ Performance benchmarks
- ✅ Resource utilization
- ✅ Scalability analysis

---

**φ² + 1/φ² = 3 | TRINITY**
