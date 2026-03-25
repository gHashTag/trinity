# Kaggle Scientific Metrics — Zenodo Research Bundles

**Date**: 2026-03-25
**Status**: ACTIVE

---

## Overview

This document catalogs the Zenodo research bundles associated with the Kaggle Scientific Metrics implementation. These bundles contain:

- Pre-trained models and checkpoints
- Scientific validation data
- Benchmark results
- Reproducibility artifacts
- Citation DOIs for academic use

---

## Available Bundles

| Bundle ID | Description | DOI | Contents |
|-----------|-------------|-----|----------|
| **B001** | Scientific Metrics v7 Base Implementation | [10.5281/zenodo.19223952](https://zenodo.org/record/19223952) | Core metrics code, validation tests, reference results |
| **B002** | Contamination Detection Benchmarks | [10.5281/zenodo.19223956](https://zenodo.org/record/19223956) | Min-K%++, CoDeC benchmark datasets, ground truth |
| **B003** | Calibration Error Validation | [10.5281/zenodo.19223959](https://zenodo.org/record/19223959) | ECE variants validation, binning comparisons |
| **B004** | Statistical Reference Values | [10.5281/zenodo.19223961](https://zenodo.org/record/19223961) | DeLong CI tables, t-test critical values, concentration bounds |
| **B005** | Bootstrap CI Reproducibility | [10.5281/zenodo.19223963](https://zenodo.org/record/19223963) | Bootstrap seeds, reproducible CI results, convergence data |
| **B006** | Multiple Testing Corrections | [10.5281/zenodo.19223965](https://zenodo.org/record/19223965) | Bonferroni, BH-FDR validation, adjusted p-value tables |
| **B007** | Adaptive Binning Algorithms | [10.5281/zenodo.19223967](https://zenodo.org/record/19223967) | KDE implementations, valley detection comparisons |

---

## Citation

When using these bundles in academic work, please cite:

### APA Format
```
Trinity Cognitive Probes Team. (2026). Kaggle Scientific Metrics v7.4:
Statistical Validity and Reproducibility Artifacts. Zenodo.
https://doi.org/10.5281/zenodo.19223952
```

### BibTeX
```bibtex
@data{zenodo_bundle,
  author       = {Trinity Cognitive Probes Team},
  title        = {Kaggle Scientific Metrics v7.4: Statistical Validity and Reproducibility Artifacts},
  year         = 2026,
  publisher    = {Zenodo},
  version      = {v7.4},
  doi          = {10.5281/zenodo.19223952},
  url          = {https://zenodo.org/record/19223952}
}
```

### For Individual Bundles
Replace the DOI with the specific bundle DOI from the table above.

---

## Bundle Contents

### B001: Scientific Metrics v7 Base Implementation

**Files:**
- `scientific_metrics_v7.py` — Main implementation
- `test_scientific_metrics_v7.py` — Test suite (32 tests)
- `CORRECTIONS_V7_1.md` — v7.1 fix documentation
- `CORRECTIONS_V7_2.md` — v7.2 fix documentation
- `CORRECTIONS_V7_3.md` — v7.3 fix documentation
- `CORRECTIONS_V7_4.md` — v7.4 fix documentation

**Use Case**: Base implementation for all scientific metrics

---

### B002: Contamination Detection Benchmarks

**Files:**
- `benchmark_mink_pp.json` — Min-K%++ reference results
- `benchmark_codec.json` — CoDeC reference results
- `test_cases_mink_pp.json` — Synthetic contamination test cases
- `ground_truth_labels.json` — Ground truth for validation

**Use Case**: Validate contamination detection implementations

---

### B003: Calibration Error Validation

**Files:**
- `ece_validation_results.json` — Cross-validation ECE results
- `binning_comparison.json` — Fixed vs quantile vs adaptive binning
- `per_bin_analysis.json` — Detailed per-bin ECE breakdown

**Use Case**: Validate ECE calculation correctness

---

### B004: Statistical Reference Values

**Files:**
- `delong_ci_tables.csv` — DeLong confidence interval tables
- `t_test_critical_values.csv` — t-distribution critical values
- `concentration_bounds.csv` — Hoeffding/Bernstein bound tables
- `normality_test_thresholds.csv` — Shapiro-Wilk thresholds

**Use Case**: Verify statistical calculations

---

### B005: Bootstrap CI Reproducibility

**Files:**
- `bootstrap_seeds.json` — Random seeds for reproducibility
- `ci_convergence.json` — Bootstrap convergence data
- `reproduction_guide.md` — How to reproduce results

**Use Case**: Ensure reproducible confidence intervals

---

### B006: Multiple Testing Corrections

**Files:**
- `bonferroni_tables.csv` — Bonferroni corrected p-values
- `bh_fdr_tables.csv` — Benjamini-Hochberg FDR results
- `family_wise_error_rate.csv` — FWER calculations
- `adjusted_p_values.json` — Adjusted p-value examples

**Use Case**: Correct for multiple hypothesis testing

---

### B007: Adaptive Binning Algorithms

**Files:**
- `kde_implementations.py` — Alternative KDE implementations
- `valley_detection_comparison.json` — Valley detection method comparison
- `density_estimation_benchmarks.json` — KDE performance benchmarks

**Use Case**: Compare adaptive binning methods

---

## Access

All bundles are available at their respective Zenodo URLs:

- **Main Repository**: https://zenodo.org/record/19223952
- **Individual Bundles**: See table above

For programmatic access, use the Zenodo REST API:

```bash
# Example: Download bundle metadata
curl https://zenodo.org/api/records/19223952

# Example: Download bundle files
wget https://zenodo.org/record/19223952/files/scientific_metrics_v7.py
```

---

## Version History

| Bundle | Date | Version | Changes |
|--------|------|---------|---------|
| B001 | 2026-03-25 | v7.4 | Added normality testing, multiple testing correction |
| B002 | 2026-03-25 | v1.0 | Initial contamination benchmarks |
| B003 | 2026-03-25 | v1.0 | Initial ECE validation |
| B004 | 2026-03-25 | v1.0 | Statistical reference tables |
| B005 | 2026-03-25 | v1.0 | Bootstrap reproducibility artifacts |
| B006 | 2026-03-25 | v1.0 | Multiple testing correction data |
| B007 | 2026-03-25 | v1.0 | Adaptive binning comparisons |

---

## Related Documentation

- `CORRECTIONS_V7_4.md` — Latest fix documentation
- `CORRECTIONS_SUMMARY.md` — All corrections summary
- `README.md` — Project overview

---

## Contact

For questions about these bundles:
- GitHub Issues: https://github.com/gHashTag/trinity/issues
- Zenodo Community: https://zenodo.org/communities/trinity-cognitive-probes

---

**Last Updated**: 2026-03-25
**Document Version**: 1.0
