# Zenodo v6.0 Quick Reference

**Status:** ✅ Implementation Complete | **Build:** Passing

---

## What Was Created

### 1. Figures (14 ready to generate)
```bash
cd docs/research/figures
pip install matplotlib seaborn numpy
python3 generate_all_figures.py
```
Output: `B001-Fig1_*.png/svg`, `B002-Fig1_*.png/svg`, ...

### 2. Supplementary Data (9 CSV files)
Located in `docs/research/data/`:
- `B001_training.csv` — Training curve with CI
- `B002_fpga_synthesis.csv` — FPGA resources
- `B003_tri27_registers.csv` — 27 register spec
- `B004_lotus_cycle.csv` — Retrieval accuracy
- `B005_language_features.csv` — Feature coverage
- `B006_gf16_accuracy.csv` — Round-trip error
- `B007_simd_benchmarks.csv` — SIMD performance
- `B007_noise_resilience.csv` — Noise robustness

### 3. Dockerfiles (7 reproducibility containers)
Located in `docs/research/docker/`:
- `Dockerfile.B001` — HSLM training
- `Dockerfile.B002` — FPGA synthesis
- `Dockerfile.B003` — TRI-27 emulator
- `Dockerfile.B004` — Queen agent
- `Dockerfile.B005` — Tri compiler
- `Dockerfile.B006` — GF16/TF3 tools
- `Dockerfile.B007` — VSA benchmarks

### 4. Metadata v6.0 (8 JSON files)
Located in `docs/research/`:
- `.zenodo.B001_v6.0.json` through `.zenodo.B007_v6.0.json`
- `.zenodo.parent_v6.0.json`

Enhanced with:
- ✅ ORCID field (placeholder: update with real ORCID)
- ✅ MeSH keywords (AI, Neural Networks, etc.)
- ✅ ACM CCS categories
- ✅ arXiv tags (cs.AI, cs.LG, cs.AR, cs.NE, cs.PL)
- ✅ Cross-bundle DOI references

---

## Before Uploading to Zenodo

### 1. Update ORCID
```bash
# Replace placeholder in all v6.0 JSON files
sed -i '' 's/0000-0000-0000-0000/YOUR_REAL_ORCID/g' \
  docs/research/.zenodo.*_v6.0.json
```

### 2. Generate Figures
```bash
cd docs/research/figures
python3 generate_all_figures.py
```

### 3. Verify Build
```bash
zig build && zig build test
```

---

## Upload Checklist

For each bundle (B001-B007):
- [ ] Markdown description (existing v5.2 files)
- [ ] Metadata JSON (new v6.0 files)
- [ ] Figures (PNG/SVG from script)
- [ ] Data CSV (supplementary materials)
- [ ] Dockerfile (reproducibility)

For parent collection:
- [ ] README.md (v6.0 version)
- [ ] Parent metadata JSON

---

## File Locations Summary

```
docs/research/
├── figures/
│   ├── generate_all_figures.py  ← Run this to generate figures
│   └── [output: B001-Fig1_*.png, B001-Fig1_*.svg, ...]
├── data/
│   ├── B001_training.csv
│   ├── B002_fpga_synthesis.csv
│   └── ...
├── docker/
│   ├── Dockerfile.B001
│   └── ...
├── .zenodo.B001_v6.0.json       ← Use for upload
├── .zenodo.B002_v6.0.json
├── ...
├── .zenodo.parent_v6.0.json     ← Use for parent
├── ZENODO_V6.0_README.md        ← Use for parent
└── ZENODO_V6.0_QUICKSTART.md    ← This file
```

---

## Citations (v6.0)

### Parent Collection
```
Vasilev, D. (2026). Trinity S³AI Framework: Complete Research Collection v6.0.
Zenodo. https://doi.org/10.5281/zenodo.19227879
```

### Individual Bundles
- B001: `doi:10.5281/zenodo.19227733`
- B002: `doi:10.5281/zenodo.19227735`
- B003: `doi:10.5281/zenodo.19227737`
- B004: `doi:10.5281/zenodo.19227739`
- B005: `doi:10.5281/zenodo.19227741`
- B006: `doi:10.5281/zenodo.19227743`
- B007: `doi:10.5281/zenodo.19227745`

---

**φ² + 1/φ² = 3 | TRINITY**
