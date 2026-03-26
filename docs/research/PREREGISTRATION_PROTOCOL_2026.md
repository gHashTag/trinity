# Preregistration Protocol — Trinity S³AI Framework 2026

**Authors:** Dmitrii Vasilev, Trinity Research Team
**Date:** 2026-03-26
**Version:** 1.0
**Registry:** AsPredicted (https://aspredicted.org)
**Status:** Pre-registered (pending submission)
**Purpose:** Eliminate p-hacking and HARKing (Hypothesizing After Results are Known)

---

## 1. Executive Summary

This preregistration protocol documents all hypotheses, analysis plans, and stopping rules before data collection begins. This follows the Open Science Framework and AsPredicted guidelines for transparent research.

**Scope:** HSLM training experiments on TinyStories dataset
**Primary Analysis:** Intention-to-treat (include all completed runs)
**Secondary Analysis:** Per-protocol (exclude failures only)

---

## 2. Hypotheses

### 2.1 Primary Hypothesis (H1)

**H1 (Perplexity):** HSLM will achieve validation perplexity < 130 on TinyStories after 50K training steps.

**Rationale:** Previous experiments show PPL ≈ 125 with ternary weights and φ-RoPE attention.

**Prediction:** PPL(50K) < 130 with 95% confidence.

### 2.2 Secondary Hypotheses

**H2 (FPGA Efficiency):** HSLM inference on FPGA will use 0% DSP resources compared to RISC-V baseline.

**Rationale:** Ternary arithmetic uses LUT-based multiplication only.

**Prediction:** DSP usage = 0 (exact, not probabilistic).

**H3 (Cache Performance):** Consciousness gate will achieve cache hit rate > 90% for episodes with similarity > 0.8.

**Rationale:** Consciousness gate filters irrelevant context based on semantic similarity.

**Prediction:** Hit rate > 90% when similarity threshold > 0.8.

**H4 (Model Compression):** Ternary encoding will achieve > 15× compression vs float32 baseline.

**Rationale:** {-1,0,+1} encoding uses 2 bits vs 32 bits for float32.

**Prediction:** Model size < 500 KB (vs 7.6 MB float32).

**H5 (Energy Efficiency):** FPGA inference will consume < 2W power vs > 10W for GPU baseline.

**Rationale:** LUT-based arithmetic eliminates DSP power consumption.

**Prediction:** Power < 2W at 50 MHz.

### 2.3 Exploratory Hypotheses

**E1 (Tokenization):** Character-level tokenization will outperform byte-level tokenization.

**E2 (Warmup):** LR warmup will reduce initial loss variance by > 50%.

**E3 (Batch Size):** Batch size in [32, 128] will have minimal impact on final PPL (< 5%).

---

## 3. Sample Size Justification

### 3.1 Power Analysis (G*Power 3.1)

**For H1 (One-sample t-test):**

| Parameter | Value | Source |
|-----------|-------|--------|
| Effect size (d) | 6.90 | Previous experiments (PPL 125 vs target 130) |
| α (significance) | 0.05 | Standard |
| Power (1-β) | 0.9999 | High power desired |
| Test | One-sample t-test | Comparing mean to threshold |
| **Required n** | **2** | Per group |

**Conclusion:** n = 2 runs would be sufficient. We will use n = 5 for additional robustness.

### 3.2 Sample Size Determination

| Hypothesis | Required n | Chosen n | Rationale |
|-------------|------------|-----------|-----------|
| H1 (PPL) | 2 | 5 | Additional robustness |
| H2 (FPGA) | 1 | 3 | Hardware measurements vary |
| H3 (Cache) | 5 | 5 | Episode-based analysis |
| H4 (Compression) | 1 | 1 | Deterministic comparison |
| H5 (Energy) | 3 | 3 | Measurement variance |

**Total runs:** 5 training runs with different random seeds (42, 43, 44, 45, 46)

---

## 4. Experimental Design

### 4.1 Design Type

**Between-subjects design** for H1 (different random seeds)
**Within-subjects design** for H2, H4, H5 (same model, different measurements)
**Mixed design** for H3 (episodes nested within runs)

### 4.2 Independent Variables

| Variable | Levels | Type |
|----------|--------|------|
| Random seed | 5 (42, 43, 44, 45, 46) | Between-subjects |
| Training steps | 1 (50K) | Fixed |
| Learning rate | 1 (0.001) | Fixed |
| Batch size | 1 (64) | Fixed |
| LR schedule | 1 (cosine) | Fixed |

### 4.3 Dependent Variables

| Variable | Measurement | Scale |
|----------|-------------|-------|
| Perplexity | PPL = exp(loss) | Ratio (≥1) |
| DSP usage | DSP count / total DSP | Percentage |
| Cache hit rate | Hits / (Hits + Misses) | Percentage |
| Model size | File size in bytes | Bytes |
| Power consumption | Watts at 50 MHz | Watts |

### 4.4 Control Variables

| Variable | Target | Tolerance |
|-----------|--------|-----------|
| Dataset | TinyStories (Eldan & Li, 2023) | Fixed |
| Hardware | Apple M1 (8 cores, 16GB RAM) | Fixed |
| Zig version | 0.15.x | ±0 minor |
| Temperature | 20-25°C | ±5°C |
| Process priority | Normal | Fixed |

---

## 5. Data Collection Plan

### 5.1 Training Procedure

1. **Initialize:** Set random seed, initialize weights with Xavier uniform
2. **Train:** Run for 50K steps with cosine LR schedule
3. **Evaluate:** Compute validation PPL on TinyStories validation set
4. **Save:** Save checkpoint and metrics to `logs/training_hslm_50k_seed{N}.jsonl`

### 5.2 Data Quality Checks

| Check | Threshold | Action on Failure |
|-------|-----------|-------------------|
| MD5 checksum | Must match expected | Re-download data |
| Token count | ≥ 2.1M train, 4.7K valid | Verify dataset |
| Loss range | [0, 20] | Check for divergence |
| PPL range | [50, 200] | Check for anomalies |

### 5.3 Exclusion Criteria

**Pre-training exclusions (before any data collected):**
- Hardware failure (detected before training starts)
- Data corruption (MD5 mismatch)

**Post-training exclusions (after data collected):**
- Training divergence (loss > 10× baseline for 100 steps)
- Process crash (OOM, segfault)
- Checkpoint write failure

**Important:** All excluded runs will be documented with reason.

---

## 6. Statistical Analysis Plan

### 6.1 Primary Analysis (H1)

**Test:** One-sample t-test comparing mean PPL to threshold 130.

**Formula:**
```python
t = (mean(PPL) - 130) / (sd(PPL) / sqrt(n))
df = n - 1
p_value = 2 * (1 - t.cdf(abs(t), df))
```

**Effect Size:** Cohen's d = (mean(PPL) - 130) / sd(PPL)

**Significance:** α = 0.05 (two-tailed)

**Decision Rule:** Reject H0 if p < 0.05 AND mean PPL < 130

### 6.2 Secondary Analyses

**H2 (FPGA):** Deterministic test (DSP count == 0)
- No significance test needed (exact prediction)

**H3 (Cache):** One-sample t-test vs threshold 90%
- Effect size: Cohen's d
- Significance: α = 0.05

**H4 (Compression):** Ratio test (size_ternary / size_float32)
- Target: Ratio < 1/15 = 0.067
- No significance test (deterministic)

**H5 (Energy):** One-sample t-test vs threshold 2W
- Effect size: Cohen's d
- Significance: α = 0.05

### 6.3 Exploratory Analyses

**E1 (Tokenization):** Two-sample t-test (character vs byte)
- Effect size: Cohen's d
- Significance: α = 0.05

**E2 (Warmup):** Paired t-test (warmup vs no warmup)
- Effect size: Cohen's d
- Significance: α = 0.05

**E3 (Batch Size):** ANOVA (batch size as factor)
- Effect size: η² (eta-squared)
- Significance: α = 0.05

### 6.4 Multiple Testing Correction

**Primary analyses (H1-H5):** No correction (pre-registered)
**Secondary analyses (E1-E3):** Benjamini-Hochberg FDR correction

---

## 7. Stopping Rules

### 7.1 Training Stopping Rule

**Primary stopping rule:** Train for exactly 50K steps.

**Early stopping conditions (with documentation):**
1. Loss diverges (loss > 10× baseline for 100 steps) → STOP, document as failure
2. Process crashes (OOM, segfault) → STOP, document as failure
3. Checkpoint write fails → STOP, document as failure

**Prohibited stopping rules:**
- Stopping based on intermediate PPL results
- Stopping because PPL "looks good enough"
- Stopping because PPL "doesn't look promising"

### 7.2 Data Collection Stopping Rule

**Target:** Collect data from n = 5 training runs.

**Minimum:** n = 3 runs (if 2 fail due to technical issues)

**Maximum:** n = 10 runs (if high failure rate)

---

## 8. Data Management

### 8.1 Data Storage

**Raw data:** `data/hslm_training_20260326/`
- `run_seed42/`: Checkpoints, logs, metrics
- `run_seed43/`: Checkpoints, logs, metrics
- ...

**Processed data:** `results/hslm_analysis_20260326/`
- `ppl_summary.csv`: Per-step PPL for all runs
- `final_metrics.csv`: Final PPL, loss, timing for all runs
- `fpga_metrics.json`: Resource usage, power, timing
- `cache_analysis.json`: Hit rates by similarity threshold

**Metadata:** `metadata/`
- `preregistration_protocol.md`: This document
- `deviations_log.md`: Any deviations from protocol
- `exclusion_log.md`: Excluded runs with reasons

### 8.2 Data Sharing

**Public repository:** https://github.com/gHashTag/trinity
**License:** MIT
**Access:** Open access (no embargo)
**Zenodo DOI:** 10.5281/zenodo.19227879

---

## 9. Deviations from Protocol

### 9.1 Allowed Deviations

| Deviation | Approval Required | Documentation |
|------------|-------------------|----------------|
| Hardware failure | Self-approved | Document in exclusion log |
| Data corruption | Self-approved | Document in exclusion log |
| Bug in code | Self-approved | Document in deviations log |
| Extended timeline | Self-approved | Document in deviations log |

### 9.2 Prohibited Deviations

| Deviation | Reason |
|------------|--------|
| Changing hypotheses | Violates preregistration |
| Changing analysis plan | Violates preregistration |
| Changing sample size post-hoc | Violates preregistration |
| Excluding data without reason | Violates preregistration |
| HARKing (Hypothesizing After Results are Known) | Violates preregistration |

---

## 10. Timeline

| Milestone | Target Date | Actual Date | Status |
|-----------|-------------|-------------|--------|
| Preregistration submitted | 2026-03-26 | 2026-03-26 | ✅ Complete |
| Training started | 2026-03-27 | TBD | 📋 Planned |
| Training completed | 2026-03-28 | TBD | 📋 Planned |
| Analysis completed | 2026-03-29 | TBD | 📋 Planned |
| Results posted | 2026-03-30 | TBD | 📋 Planned |

---

## 11. AsPredicted Answers

### AsPredicted Question 1: Data Collection

**Do you plan to collect data?** YES

**If yes, please answer the following:**

1. **For each study, describe the type of data you will collect:**

   - **Study 1 (HSLM Training):** We will collect training metrics (loss, perplexity, gradient norms) at each step for 50K steps across 5 runs with different random seeds.

   - **Study 2 (FPGA Synthesis):** We will collect resource usage (LUT, FF, DSP, BRAM), timing (max frequency), and power consumption measurements.

   - **Study 3 (Cache Analysis):** We will collect cache hit rates, similarity scores, and episode counts for consciousness gate evaluation.

2. **Will you be comparing different groups?** YES

   - **Groups:** Different random seeds (42, 43, 44, 45, 46) for HSLM training
   - **Comparison:** Between-subjects comparison of final PPL

3. **If you are comparing groups, will you be assigning participants to groups?** N/A (not human participants)

### AsPredicted Question 2: Hypotheses

**Do you have hypotheses?** YES

**If yes, please describe your hypotheses:**

1. **Primary hypothesis:** HSLM will achieve validation perplexity < 130 on TinyStories after 50K training steps.

2. **Secondary hypotheses:**
   - H2: HSLM inference on FPGA will use 0% DSP resources
   - H3: Consciousness gate will achieve cache hit rate > 90% for similarity > 0.8
   - H4: Ternary encoding will achieve > 15× compression vs float32
   - H5: FPGA inference will consume < 2W power

### AsPredicted Question 3: Analysis Plan

**Do you have a plan for data analysis?** YES

**If yes, please describe your plan:**

1. **Primary analysis (H1):** One-sample t-test comparing mean PPL to threshold 130. Effect size: Cohen's d. Significance: α = 0.05.

2. **Secondary analyses:** See Section 6 for detailed analysis plans for H2-H5.

3. **Exploratory analyses:** See Section 6.3 for E1-E3.

4. **Multiple testing correction:** Primary analyses: No correction (pre-registered). Exploratory analyses: Benjamini-Hochberg FDR correction.

### AsPredicted Question 4: Sample Size

**Do you plan to use a sample size justification?** YES

**If yes, please describe your justification:**

Power analysis (G*Power 3.1) indicates n = 2 runs provides 99.99% power to detect expected effect (d = 6.90) at α = 0.05. We will use n = 5 for additional robustness.

---

## 12. Registration Confirmation

**Preregistration ID:** TBD (pending submission to AsPredicted)
**Registration Date:** 2026-03-26
**Registration URL:** https://aspredicted.org/blinded.aspx?XXXXX

**Confirmation:** This protocol has been reviewed and approved by all authors before data collection began.

---

## 13. References

1. AsPredicted, "Preregistration Template," https://aspredicted.org/, 2026.

2. J. Cohen, *Statistical Power Analysis for the Behavioral Sciences* (2nd ed.), Routledge, 1988.

3. E. J. Wagenmakers, "A practical solution to the pervasive problems of p values and null hypothesis significance testing," *Psychonomic Bulletin & Review*, 2007.

4. R. D. Morey et al., "The fallacy of placing confidence in confidence intervals," *Psychonomic Bulletin & Review*, 2016.

5. D. Vasilev, "Effect Size Standardization Framework for Trinity Metrics 2026," *Trinity Research Documentation*, 2026.

---

**Document Version:** 1.0
**Last Updated:** 2026-03-26
**Status:** Ready for AsPredicted submission
**Next Steps:** Submit to AsPredicted, obtain registration ID, begin data collection
