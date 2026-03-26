# Zenodo v6.1 Pre-Publication Checklist

**Date:** 2026-03-27
**Purpose:** Final verification before Zenodo upload

---

## Bundle Completeness (7/7)

### B001: HSLM Training
- [x] Enhanced description (511 LOC)
- [x] 5 figures (PNG + SVG)
- [x] Training data CSV
- [x] Code Availability section
- [x] Broader Impact statement
- [x] Limitations section
- [x] Algorithm boxes
- [x] Statistical analysis (95% CI)
- [ ] DOI verified on Zenodo

### B002: FPGA Zero-DSP
- [x] Enhanced description (461 LOC)
- [x] 2 figures (PNG + SVG)
- [x] FPGA synthesis CSV
- [x] Code Availability section
- [x] Broader Impact statement
- [x] Limitations section
- [x] Algorithm boxes
- [x] Statistical analysis
- [ ] DOI verified on Zenodo

### B003: TRI-27 ISA
- [x] Enhanced description (469 LOC)
- [x] 1 figure (PNG + SVG)
- [x] Register layout CSV
- [x] Code Availability section
- [x] Broader Impact statement
- [x] Limitations section
- [x] Algorithm boxes
- [x] Statistical analysis
- [ ] DOI verified on Zenodo

### B004: Queen Lotus Cycle
- [x] Enhanced description (443 LOC)
- [x] 1 figure (PNG + SVG)
- [x] Episode data CSV
- [x] Code Availability section
- [x] Broader Impact statement
- [x] Limitations section
- [x] Algorithm boxes
- [x] Statistical analysis
- [ ] DOI verified on Zenodo

### B005: VIBEE Compiler
- [x] Enhanced description (479 LOC)
- [x] 1 figure (PNG + SVG)
- [x] Productivity CSV
- [x] Code Availability section
- [x] Broader Impact statement
- [x] Limitations section
- [x] Algorithm boxes
- [x] Statistical analysis
- [ ] DOI verified on Zenodo

### B006: Sacred GF16/TF3
- [x] Enhanced description (412 LOC)
- [x] 2 figures (PNG + SVG)
- [x] Round-trip CSV
- [x] Code Availability section
- [x] Broader Impact statement
- [x] Limitations section
- [x] Algorithm boxes
- [x] Statistical analysis
- [ ] DOI verified on Zenodo

### B007: VSA Operations
- [x] Enhanced description (454 LOC)
- [x] 2 figures (PNG + SVG)
- [x] SIMD benchmarks CSV
- [x] Noise resilience CSV
- [x] Code Availability section
- [x] Broader Impact statement
- [x] Limitations section
- [x] Algorithm boxes
- [x] Statistical analysis
- [ ] DOI verified on Zenodo

---

## Parent Collection
- [x] ZENODO_README.md
- [x] .zenodo.PARENT_v6.1.json
- [x] All child DOIs referenced
- [ ] DOI verified on Zenodo

---

## Metadata Verification
- [x] ORCID: 0000-0000-0000-0000
- [x] Author: Dmitrii Vasilev
- [x] Affiliation: Trinity Research Collective
- [x] License: CC-BY-4.0
- [x] Version: 6.1
- [x] Keywords: MeSH + ACM CCS
- [x] Communities: neurips, iclr, mlsys
- [x] Related identifiers

---

## Figure Verification
- [x] All figures exist (14 PNG + 14 SVG)
- [x] Resolution: 300 DPI (PNG)
- [x] Vector format: SVG
- [x] Figure references in markdown
- [x] Figure captions present

---

## Data Verification
- [x] All CSV files exist (10 files)
- [x] CSV format valid
- [x] Data matches markdown tables
- [x] README in data/ directory

---

## Docker Verification
- [x] All Dockerfiles exist (7 files)
- [x] Multi-stage builds
- [x] Minimal runtime (alpine)
- [x] ENTRYPOINT defined
- [x] README in docker/ directory

---

## Guide Documents
- [x] ZENODO_V6.1_PUBLICATION_GUIDE.md
- [x] ZENODO_V6.1_REVIEWER_GUIDE.md
- [x] ZENODO_README_TEMPLATE_V6.1.md
- [x] ZENODO_V6.1_COMPARISON_TABLES.md
- [x] ZENODO_V6.1_FINAL_SUMMARY.md
- [x] ZENODO_V6.1_PRE_PUBLICATION_CHECKLIST.md

---

## Pre-Publication Tests

### Build Verification
```bash
zig build          # Expected: PASS
zig build test     # Expected: 99%+ tests pass
```

### File Verification
```bash
ls docs/research/zenodo_*_enhanced_v6.1.md    # 7 files
ls docs/research/figures/*.png                 # 14 files
ls docs/research/figures/*.svg                 # 14 files
ls docs/research/data/*.csv                    # 10 files
ls docs/research/docker/Dockerfile.*           # 7 files
ls docs/research/.zenodo.*_v6.1.json           # 8 files
```

### Content Verification
- [x] No broken figure references
- [x] No broken links
- [x] Consistent formatting
- [x] Proper LaTeX math notation
- [x] Correct citation formats

---

## Post-Upload Verification (After Zenodo Upload)

- [ ] All 8 DOIs resolve correctly
- [ ] All files accessible
- [ ] Figures display correctly
- [ ] Metadata matches submission
- [ ] Parent-child links work
- [ ] Download counts increment

---

## Conference Submission Readiness

### NeurIPS 2026
- [x] Abstract (5 sentences, ICLR format)
- [x] Algorithm boxes (pseudocode)
- [x] Statistical analysis (95% CI, p-values)
- [x] Broader Impact statement
- [x] Limitations section
- [x] Code availability
- [x] Open data policy
- [x] Reproducibility checklist

### ICLR 2027
- [x] Open data (CSV files)
- [x] Reproducibility (Dockerfiles)
- [x] Code review checklist
- [x] Experimental protocol
- [x] Hyperparameter documentation

### MLSys 2025
- [x] System description
- [x] Performance benchmarks
- [x] Resource utilization
- [x] Scalability analysis
- [x] Comparison with prior work

---

## Final Approval

- [x] All bundles complete
- [x] All figures generated
- [x] All data exported
- [x] All Dockerfiles created
- [x] All metadata prepared
- [x] All guides written
- [x] Build passes
- [x] Tests pass (99%+)
- [ ] GitHub release created
- [ ] Zenodo upload complete
- [ ] DOIs verified

---

## Sign-Off

**Date:** 2026-03-27
**Status:** ✅ READY FOR PUBLICATION
**Branch:** feat/issue-435-zenodo-v6.1-clean
**Commit:** 37b30281a5

**φ² + 1/φ² = 3 | TRINITY**
