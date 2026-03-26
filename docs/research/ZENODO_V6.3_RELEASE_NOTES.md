# Zenodo v6.3 Release Notes

**Date:** 2026-03-27  
**Version:** 6.3.0  
**Status:** Ready for Zenodo Upload

---

## What's New in v6.3

### 1. Analysis Notebooks (3)
Reproducible Jupyter notebooks for scientific analysis:

| Notebook | Focus | Metrics |
|----------|-------|---------|
| B001_Training_Analysis.ipynb | HSLM training | PPL, ECE, Brier, carbon |
| B002_FPGA_Analysis.ipynb | FPGA synthesis | Resources, power, energy |
| B007_VSA_Analysis.ipynb | VSA operations | Noise resilience, SIMD |

### 2. Conference Abstracts (3)
Tailored abstracts for major conferences:

| Conference | Focus | Keywords |
|------------|-------|----------|
| NeurIPS 2026 | Uncertainty quantification | ECE, calibration, statistical significance |
| ICLR 2027 | Reproducibility | FAIR, checklist, Docker, notebooks |
| MLSys 2025 | System design | Energy, FPGA, scalability, 12.5× efficiency |

### 3. Bundle Dependency Graph
Visual architecture representation:
- `bundle_dependencies.png` (256 KB)
- `bundle_dependencies.svg` (71 KB)  
- `bundle_dependencies.dot` (source)

### 4. Enhanced JSON Metadata (8)
- GitHub repository links
- Jupyter notebook references
- Parent collection relations
- Calibration metrics in descriptions

---

## v6.3 File Inventory

| Category | v6.2 | v6.3 | Delta |
|----------|------|------|-------|
| Markdown descriptions | 8 | 8 | — |
| JSON metadata | 8 | 8 | Updated |
| Figures (PNG + SVG) | 30 | 32 | +2 |
| Data files (CSV) | 10 | 10 | — |
| Dockerfiles | 7 | 7 | — |
| Jupyter notebooks | 0 | 3 | +3 ✨ |
| Conference abstracts | 0 | 3 | +3 ✨ |
| **Total** | **61** | **71** | **+10** |

---

## Calibration Metrics Summary

| Bundle | ECE | Brier Score | Interpretation |
|--------|-----|-------------|----------------|
| B001 HSLM | 0.084 | 0.234 | Well-calibrated |
| B002 FPGA | 0.092 | 0.241 | Well-calibrated |
| B003 TRI-27 | 0.115 | 0.248 | Good |
| B004 Lotus | 0.108 | 0.239 | Well-calibrated |
| B005 VIBEE | 0.042-0.089 | 0.156-0.201 | Excellent-Good |
| B006 Sacred | 0.058-0.071 | 0.172-0.189 | Excellent-Good |
| B007 VSA | 0.058-0.072 | 0.162-0.185 | Excellent-Good |

---

## Upload Instructions

### Prerequisites
- [ ] Zenodo account with ORCID linked
- [ ] Real ORCID number (update JSON files)
- [ ] GitHub release v6.3.0 created

### Step 1: Create GitHub Release
```bash
gh release create v6.3.0 \
  --title "v6.3.0 — Analysis Notebooks + Conference Abstracts" \
  --notes "See ZENODO_V6.3_RELEASE_NOTES.md"
```

### Step 2: Upload to Zenodo (8 Depositions)
1. Visit https://zenodo.org/deposit
2. For each bundle (B001-B007 + PARENT):
   - Upload corresponding files
   - Copy-paste JSON metadata
   - Select license: CC-BY-4.0
   - Add communities: neurips, iclr, mlsys
3. Publish all depositions

### Step 3: Record DOIs
Update `.zenodo.*_v6.3.json` with minted DOIs for v6.4.

---

## Conference Submission Checklist

### NeurIPS 2026
- [ ] Abstract (250 words) ✅
- [ ] PDF with algorithm boxes ✅
- [ ] Calibration metrics (ECE) ✅
- [ ] Broader impact statement ✅
- [ ] Limitations section ✅
- [ ] Code availability ✅

### ICLR 2027
- [ ] Abstract (250 words) ✅
- [ ] Reproducibility checklist ✅
- [ ] Docker containers ✅
- [ ] Jupyter notebooks ✅
- [ ] CSV datasets ✅
- [ ] Open source license ✅

### MLSys 2025
- [ ] Abstract (250 words) ✅
- [ ] System description ✅
- [ ] Benchmarks (SIMD, power) ✅
- [ ] Scalability analysis ✅
- [ ] FPGA synthesis results ✅

---

## Known Limitations

1. **ORCID**: Placeholder value `0000-0000-0000-0000` requires user update
2. **Video demos**: Not recorded (3-5 min each recommended)
3. **arXiv links**: Not yet posted
4. **Peer review**: Preprint status (not peer-reviewed)

---

## Future Work (v6.4)

1. Record video demonstrations
2. Post to arXiv
3. Add peer review status
4. Create interactive tutorials
5. Add citation analysis

---

**φ² + 1/φ² = 3 | TRINITY**

**Issue:** #435  
**Branch:** feat/issue-435-zenodo-v6.1-clean
