# ICLR 2027 Preparation — Roadmap

**Target Submission:** ICLR 2027 (Deadline: ~September 15, 2026)

**Current Date:** March 26, 2026
**Time Remaining:** ~6 months until deadline

---

## Overview

This roadmap provides a 7-month timeline for preparing a competitive ICLR 2027 submission, incorporating experimental gaps identified and feedback from NeurIPS 2026 review.

---

## Phase 1: Foundation (March - May 2026)

### March 2026: Planning and Setup

**Week 1-2:**
- [ ] Finalize paper angle (Theory vs Systems vs Robustness)
- [ ] Review ICLR 2025 accepted papers (what works?)
- [ ] Set up compute resources (GPU cluster access)
- [ ] Identify experimental gaps (see EXPERIMENT_GAPS.md)

**Week 3-4:**
- [ ] Acquire datasets for cross-modal experiments
  - CIFAR-10 (vision)
  - LibriSpeech subset (speech)
  - TinyStories (already have)
- [ ] Set up training pipelines for new datasets
- [ ] Run initial baselines (FP32 on all datasets)

**Deliverables:**
- Paper angle decision
- Compute resources secured
- Datasets downloaded

---

### April 2026: GPU Comparison Experiments

**Week 1-2:**
- [ ] Set up GPU benchmarking infrastructure
- [ ] Measure RTX 3080/4090 throughput (tokens/second)
- [ ] Measure GPU power consumption (power meter)
- [ ] Calculate energy efficiency (tokens/Joule)

**Week 3-4:**
- [ ] Compare FPGA vs GPU (throughput, energy)
- [ ] Generate comparison figures and tables
- [ ] Document methodology

**Deliverables:**
- GPU throughput measurements
- Energy efficiency comparison
- Comparison table (Trinity vs GPU)

---

### May 2026: Statistical Validation

**Week 1-4:**
- [ ] Run 10 trials per ablation variant (6 ablations)
- [ ] Total: 60 training runs (10 trials × 6 variants)
- [ ] Collect PPL, loss curves for each run
- [ ] Compute mean ± std, 95% confidence intervals
- [ ] Perform two-tailed t-tests (α=0.05)
- [ ] Calculate effect sizes (Cohen's d)

**Deliverables:**
- Statistically validated ablation study
- Updated tables with confidence intervals
- Statistical methods section

---

## Phase 2: Cross-Modal Experiments (June - August 2026)

### June 2026: Vision Experiments

**Week 1-2:**
- [ ] Train ternary CNN on CIFAR-10
- [ ] Compare to FP32 baseline
- [ ] Measure accuracy, model size

**Week 3-4:**
- [ ] Ablation study (sacred formats on vision)
- [ ] Analyze results
- [ ] Document vision findings

**Deliverables:**
- CIFAR-10 results
- Cross-modal validation (vision)

---

### July - August 2026: Speech Experiments

**Week 1-2:**
- [ ] Train ternary model on LibriSpeech subset
- [ ] Compare to FP32 baseline
- [ ] Measure WER (word error rate)

**Week 3-8:**
- [ ] If time permits: multimodal experiments
- [ ] Analyze all cross-modal results
- [ ] Update paper with cross-modal section

**Deliverables:**
- Speech recognition results
- Cross-modal validation (speech)
- Multimodal results (if time)

---

## Phase 3: Larger Models (September 2026 - February 2027)

### September - October 2026: Setup

**Week 1-2:**
- [ ] Acquire compute for 7B+ model (or 100M if limited)
- [ ] Set up distributed training infrastructure
- [ ] Initialize hyperparameters

**Week 3-4:**
- [ ] Train FP32 baseline (100M or 7B)
- [ ] Establish baseline PPL
- [ ] Document baseline results

**Deliverables:**
- Compute access secured
- Baseline established

---

### November 2026 - January 2027: Training

**Ongoing:**
- [ ] Train ternary model at same scale
- [ ] Monitor training stability
- [ ] Compare PPL vs baseline
- [ ] Document scaling behavior

**Deliverables:**
- Large-scale training results
- Scaling analysis

---

### February 2027: Analysis

**Week 1-4:**
- [ ] Analyze scaling results
- [ ] Generate scaling plots
- [ ] Document scaling behavior
- [ ] Update paper if needed

**Deliverables:**
- Scaling analysis complete
- Paper updated

---

## Phase 4: Paper Writing (March - May 2027)

### March 2027: First Draft

**Week 1-2:**
- [ ] Write introduction
- [ ] Write related work
- [ ] Write methods section

**Week 3-4:**
- [ ] Write experiments section
- [ ] Generate all figures and tables
- [ ] Write discussion section

**Deliverables:**
- Complete first draft
- All figures and tables

---

### April 2027: Revision

**Week 1-2:**
- [ ] Internal review (PI + external collaborators)
- [ ] Revise based on feedback
- [ ] Check all claims against evidence

**Week 3-4:**
- [ ] Polishing (grammar, clarity, conciseness)
- [ ] Finalize abstract
- [ ] Format for ICLR template

**Deliverables:**
- Revised draft
- Final abstract

---

### May 2027: Final Polish

**Week 1-4:**
- [ ] Final proofreading
- [ ] Supplemental material preparation
- [ ] Code repository preparation (anonymous)
- [ ] Reproducibility package (Docker)

**Deliverables:**
- Submission-ready paper
- Supplemental material
- Code repository

---

## Phase 5: Submission (June 2027)

### June 2027: ICLR 2027 Submission

**Week 1 (Abstract Deadline):**
- [ ] Submit abstract via ICLR portal
- [ ] Confirm submission details

**Week 2-3 (Paper Deadline):**
- [ ] Submit full paper via ICLR portal
- [ ] Upload supplemental material
- [ ] Upload code (anonymized GitHub)

**Week 4:**
- [ ] Confirm receipt
- [ ] Relax and wait for reviews!

**Deliverables:**
- ICLR 2027 submission complete

---

## Milestones

| Milestone | Target Date | Dependencies | Status |
|-----------|-------------|-------------|--------|
| Paper angle selected | March 31 | None | Pending |
| Compute resources secured | March 31 | Budget approval | Pending |
| GPU comparison complete | April 30 | GPU access | Pending |
| Statistical validation complete | May 31 | GPU comparison | Pending |
| Vision experiments complete | June 30 | Datasets | Pending |
| Speech experiments complete | August 31 | Vision | Pending |
| Large model baseline | October 31 | Compute | Pending |
| Large model ternary | February 28 | Baseline | Pending |
| First draft complete | March 31 | All experiments | Pending |
| Submission ready | May 31 | Internal review | Pending |
| ICLR submission | June 15 | Paper complete | Pending |

---

## Risk Management

### Risk 1: Compute Access

**Risk:** Cannot secure GPU cluster for 7B model training

**Probability:** Medium
**Impact:** High (would limit scaling claims)

**Mitigation:**
- Use 100M parameter model instead (requires less compute)
- Focus on cross-modal and statistical validation
- Present 1.95M + 100M as evidence (not 7B)

**Fallback:** If 7B not feasible, present scaling analysis up to 100M and discuss extrapolation to 7B.

### Risk 2: Cross-Modal Results Weak

**Risk:** Ternary underperforms on vision/speech tasks

**Probability:** Medium
**Impact:** Medium (weakens broad applicability claim)

**Mitigation:**
- Focus on language modeling as primary contribution
- Present cross-modal as exploratory
- Discuss in limitations: "Cross-modal validation left for future work"

### Risk 3: NeurIPS 2026 Rejection

**Risk:** NeurIPS 2026 rejects paper

**Probability:** High (NeurIPS acceptance rate ~20%)
**Impact:** Low (ICLR 2027 is backup)

**Mitigation:**
- Use NeurIPS feedback to improve paper
- Address reviewer concerns in ICLR version
- Consider different track for ICLR (Systems vs Theory)

### Risk 4: Time Constraints

**Risk:** Insufficient time to complete all experiments

**Probability:** Medium
**Impact:** Medium (weaker submission)

**Mitigation:**
- Prioritize: GPU comparison > Statistical validation > Cross-modal > Large models
- If time runs out, submit with available results
- Document gaps clearly in limitations section

---

## Success Criteria

**Minimum Viable ICLR 2027 Submission:**
- [ ] Paper angle clearly defined (Theory or Systems)
- [ ] All claims supported by experimental evidence
- [ ] Comparison to prior work (BitNet, FINN, etc.)
- [ ] Limitations section clearly stated
- [ ] Reproducibility package (Docker, code, data)
- [ ] Formal proofs included (if Theory track)

**Strong Submission:**
- [ ] All minimum viable criteria
- [ ] Cross-modal validation (vision + speech)
- [ ] Larger model validation (100M+ params)
- [ ] Direct GPU comparison (power, throughput)
- [ ] Statistically significant ablations
- [ ] Novel contribution clearly differentiated

---

## Summary

**Timeline:** 15 months (March 2026 - June 2027)

**Critical Path:**
1. Paper angle selection (March)
2. GPU comparison (April)
3. Statistical validation (May)
4. Paper writing (March-May 2027)

**Buffer:** 1 month between phases for contingencies

**Key Decision Point:** August 2026 — Assess progress and adjust scope if needed

---

**Document Control:** ICLR-ROADMAP-001
**Status:** Draft — Created March 2026
