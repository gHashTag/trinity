# Trinity S³AI — Supplementary Materials Template v6.0

**Date:** 2026-03-26
**Version:** 6.0
**Purpose:** Template for supplementary materials in academic submissions

---

## Supplementary Materials Structure

For academic submission (NeurIPS, ICLR, MLSys, etc.), include:

### 1. Additional Figures (22 files)

**Location:** `docs/research/figures/`

**Format:** PNG (300 DPI) + SVG (vector)

**List:**
- B001-Fig1_training_curve.{png,svg}
- B001-Fig2_format_comparison.{png,svg}
- B002-Fig1_fpga_resources.{png,svg}
- B002-Fig2_power_analysis.{png,svg}
- B003-Fig1_register_layout.{png,svg}
- B004-Fig1_lotus_cycle.{png,svg}
- B005-Fig1_type_hierarchy.{png,svg}
- B006-Fig1_gf16_layout.{png,svg}
- B006-Fig2_phi_heatmap.{png,svg}
- B007-Fig1_vsa_structure.{png,svg}
- B007-Fig2_simd_speedup.{png,svg}

### 2. Data Files (8 CSV)

**Location:** `docs/research/data/`

**Format:** CSV with headers

**List:**
- `B001_training.csv` — Training curves (step, PPL, loss, CI, LR, throughput)
- `B002_fpga_synthesis.csv` — FPGA resource usage (LUT, DSP, FF, BRAM)
- `B003_tri27_registers.csv` — TRI-27 register layout (bank, reg, encoding)
- `B004_lotus_cycle.csv` — Episode data (phase, success, reward, time)
- `B005_language_features.csv` — Language feature matrix (feature, support, LOC)
- `B006_gf16_accuracy.csv` — Format accuracy (format, error, retention)
- `B007_simd_benchmarks.csv` — SIMD performance (op, scalar_ns, simd_ns, speedup)

### 3. Algorithm Pseudocode

**Location:** `docs/research/ALGORITHM_PSEUDOCODE.md`

**Algorithms:**
1. Sacred Attention (O(n²) → O(n log n) with φ-RoPE)
2. Ternary SGD (convergence proof)
3. Consciousness Gate (dual-system switching)
4. Lotus Cycle (6-phase orchestration)
5. VSA Binding/Unbinding (algebraic properties)
6. VSA Bundling (majority voting)
7. GF16 Encoding/Decoding
8. Sacred Scaling computation

### 4. LaTeX Source for Figures

**Location:** `docs/research/latex/`

**Files:**
- `arxiv2026_b001_hslm.tex` — Main paper source
- `references.bib` — Bibliography
- `README.md` — Compilation instructions

### 5. Reproducibility Scripts

**Location:** `deploy/Dockerfile.B*`

**Containers:**
- B001: HSLM training
- B002: FPGA synthesis
- B003: TRI-27 assembly
- B004: Queen Lotus Cycle
- B005: VIBEE compiler
- B006: GF16/TF3 arithmetic
- B007: VSA operations

**Usage:**
```bash
cd docs/research
docker-compose --profile training up b001-hslm
docker-compose --profile fpga up b002-fpga
docker-compose --profile test up test-all
```

### 6. Mathematical Proofs

**Location:** `docs/research/TRINITY_FORMAL_PROOFS_V6.0.md`

**Theorems:**
1. Trinity Identity (φ² + φ⁻² = 3)
2. Lucas Connection (Lₙ = φⁿ + φ⁻ⁿ)
3. Optimal Trit Entropy (H = log₂3)
4. Ternary SGD Convergence
5. Sacred Scale Bounds
6. Gradient Strength Enhancement
7. VSA Binding/Unbinding
8. VSA Bundle Majority
9. TF3 Information Density

### 7. Statistical Analysis

**Location:** `docs/research/EXPERIMENTAL_META_ANALYSIS_V6.0.md`

**Analyses:**
- Effect sizes (Cohen's d) for 32 metrics
- Bayesian analysis with Bayes Factors
- Cross-platform validation
- 95% confidence intervals
- p-values and significance testing

### 8. Citation Guide

**Location:** `docs/research/ZENODO_V6.0_CITATION_GUIDE.md`

**Formats:**
- APA 7th Edition
- MLA 9th Edition
- IEEE
- Chicago 17th Edition
- BibTeX
- EndNote XML
- RIS

---

## Supplementary Materials Checklist

### For Conference Submission

- [ ] All figures included (PNG + SVG)
- [ ] All data files included (CSV)
- [ ] Algorithm pseudocode included
- [ ] Mathematical proofs included
- [ ] Reproducibility scripts included
- [ ] Citation information included
- [ ] License specified (CC-BY-4.0)
- [ ] DOI placeholder (to be updated)
- [ ] ORCID placeholder (to be updated)
- [ ] Code availability statement included

### For Journal Submission

Additional requirements:
- [ ] Supplementary PDF with all figures
- [ ] Video demos (optional, 2-5 min each)
- [ ] Hyperlinked references
- [ ] Conflict of interest statement
- [ ] Funding acknowledgment
- [ ] Ethical considerations statement

---

## File Naming Convention

```
{Bundle}-{Type}_{Index}.{ext}

Examples:
B001-Fig1_training_curve.png
B001-Fig2_format_comparison.svg
B002-Table1_resource_comparison.csv
B003-Algorithm1_trit_encoding.txt
```

---

## Metadata Template

For each supplementary file, include:

```json
{
  "filename": "B001-Fig1_training_curve.png",
  "title": "Training curve showing perplexity vs steps",
  "description": "HSLM-1.95M training on TinyStories with 95% CI",
  "type": "figure",
  "format": "png",
  "resolution": "300 DPI",
  "dimensions": "1200x800",
  "bundle": "B001",
  "version": "6.0",
  "doi": "10.5281/zenodo.19227733",
  "license": "CC-BY-4.0"
}
```

---

## Compression and Archiving

### For Submission

Create a single archive:

```bash
cd docs/research
tar czf trinity_supplementary_v6.0.tar.gz \
  figures/*.png \
  figures/*.svg \
  data/*.csv \
  latex/*.tex \
  latex/*.bib \
  ../deploy/Dockerfile.B* \
  ../TRINITY_FORMAL_PROOFS_V6.0.md \
  ../EXPERIMENTAL_META_ANALYSIS_V6.0.md
```

**Expected size:** ~10-15 MB (compressed)

---

## Video Demos (Optional)

### Script Template

Each video should include:

1. **Title Slide** (3 sec)
   - Bundle name and version
   - Author and institution

2. **Overview** (30 sec)
   - Architecture diagram
   - Key innovations

3. **Demo** (2-3 min)
   - Code walkthrough
   - Running example
   - Results display

4. **Results** (30 sec)
   - Performance metrics
   - Comparison with baselines

5. **Citation Slide** (5 sec)
   - DOI and license
   - GitHub repository

**Total duration:** 3-5 minutes per bundle

**Tools:**
- OBS Studio (free)
- QuickTime Player (macOS)
- ffmpeg (command line)

---

## Contact

For questions about supplementary materials:

**Author:** Dmitrii Vasilev
**GitHub:** https://github.com/gHashTag/trinity
**Email:** [to be specified]

---

**φ² + 1/φ² = 3 | TRINITY**
