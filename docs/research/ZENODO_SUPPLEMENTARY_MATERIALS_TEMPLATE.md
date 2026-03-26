# Zenodo Supplementary Materials Template 2026

**Author:** Dmitrii Vasilev
**Date:** 2026-03-26
**Version:** 1.0
**Purpose:** Standardized supplementary materials for Trinity Zenodo bundles
**Status:** Ready for use

---

## Overview

This template provides standardized supplementary materials for all Trinity Zenodo bundles, ensuring consistency and completeness for conference artifact evaluation.

---

## Required Files Structure

```
zenodo_bundle/
├── README.md                 # Main description (use v5.2 template)
├── SUPPLEMENTARY.md          # This file (supplementary materials index)
├── CITATION.cff              # Citation metadata
├── LICENSE                   # MIT License
├── CODE/
│   ├── build.sh             # Build instructions
│   ├── run.sh              # Run instructions
│   └── SHA256SUMS          # File checksums
├── DATA/
│   ├── README.md           # Data provenance
│   └── SHA256SUMS         # Data checksums
├── RESULTS/
│   ├── tables/            # Result tables (CSV/LaTeX)
│   ├── figures/           # Publication figures (PDF/SVG)
│   └── logs/              # Training/experiment logs
└── SUPPLEMENT/
    ├── Appendix_A_Methods.pdf
    ├── Appendix_B_Additional_Results.pdf
    ├── Appendix_C_Statistical_Analysis.pdf
    └── Appendix_D_Code_Overview.pdf
```

---

## SUPPLEMENTARY.md Template

```markdown
# Supplementary Materials for [Bundle Name]

**Bundle Version:** v5.2
**DOI:** 10.5281/zenodo.XXXXXXX
**Corresponding Author:** Dmitrii Vasilev

---

## Contents

### Code

- **Location:** `CODE/`
- **Languages:** Zig (0.15.x), Python (3.10+)
- **Lines of Code:** ~[N]K LOC
- **Dependencies:** Zig std only (zero external deps)
- **Build:** See `CODE/build.sh`
- **Run:** See `CODE/run.sh`

### Data

- **Location:** `DATA/`
- **Dataset:** [Dataset name]
- **Source:** [URL or citation]
- **Size:** [N samples]
- **Checksum:** See `DATA/SHA256SUMS`

### Results

- **Location:** `RESULTS/`
- **Tables:** `RESULTS/tables/`
- **Figures:** `RESULTS/figures/`
- **Logs:** `RESULTS/logs/`

### Supplementary Materials

- **Appendix A:** Methods (detailed experimental protocol)
- **Appendix B:** Additional Results (ablation studies, etc.)
- **Appendix C:** Statistical Analysis (full test results)
- **Appendix D:** Code Overview (architecture documentation)

---

## Appendix A: Methods

### Experimental Setup

[Detailed description of experimental setup]

### Statistical Analysis

[Full statistical methods, effect sizes, confidence intervals]

### Computational Resources

[Hardware, software, runtime estimates]

---

## Appendix B: Additional Results

### Ablation Studies

| Component | Ablation | ΔPPL | ΔParams | ΔMemory |
|-----------|----------|------|---------|---------|
| [Comp1]   | [Removed] | +X.X | -Y.YK  | -Z.ZMB  |

### Additional Experiments

[Results from additional experiments not in main paper]

---

## Appendix C: Statistical Analysis

### Full Test Results

| Test | Statistic | p-value | Effect Size | 95% CI | Interpretation |
|------|-----------|---------|-------------|---------|----------------|
| [Test1] | t = X.XX | p = 0.XX | d = X.XX | [X.XX, X.XX] | [Interpretation] |

### Multiple Testing Correction

[Details of correction method, original vs corrected p-values]

---

## Appendix D: Code Overview

### Architecture

[High-level architecture description]

### Key Modules

| Module | LOC | Purpose |
|--------|-----|---------|
| [Mod1]  | NNN | [Purpose] |
| [Mod2]  | NNN | [Purpose] |

### Reproduction

**Step 1:** Clone repository
```bash
git clone https://github.com/gHashTag/trinity
cd trinity
git checkout [commit hash]
```

**Step 2:** Build
```bash
zig build
```

**Step 3:** Run
```bash
./zig-out/bin/[binary] [args]
```

---

## Contact

For questions about these materials:
- GitHub Issues: https://github.com/gHashTag/trinity/issues
- Email: [corresponding author email]

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| v5.2 | 2026-03-26 | Initial release with enhanced scientific documentation |
| v5.1 | 2026-03-20 | Added effect size analysis |
| v5.0 | 2026-03-15 | Added NeurIPS/ICLR compliance |
