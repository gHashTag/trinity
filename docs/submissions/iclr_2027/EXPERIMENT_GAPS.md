# ICLR 2027 Preparation — Experimental Gaps

**Target Submission:** ICLR 2027 (September 2026 deadline)

**Purpose:** Identify missing experiments and data needed for competitive ICLR 2027 submission

---

## Critical Gaps (Must Address)

### Gap 1: Larger Model Validation

**Current Status:** Trinity validated on 1.95M parameter models only. No evidence for 7B+ parameter models.

**Why This Matters:**
- ICLR reviewers expect scaling analysis (how do results scale?)
- BitNet and other ternary papers show 7B+ results
- Without scaling data, claims about "ternary effectiveness" are limited

**Evidence Needed:**
- [ ] Train 7B+ ternary model (or 100M if compute limited)
- [ ] Compare PPL vs FP32 baseline at same scale
- [ ] Measure compression ratio at scale
- [ ] Document training stability

**Time Estimate:** 3-6 months (compute-intensive)
- Training 7B model: ~2-4 weeks on H100 cluster
- Evaluation: ~1 week

**Resources Needed:**
- GPU cluster (H100 or A100 equivalent)
- ~100 GB RAM per GPU
- Storage: ~50 GB for checkpoints

---

### Gap 2: Cross-Modal Validation

**Current Status:** Only language modeling experiments (TinyStories). No vision, speech, or multimodal results.

**Why This Matters:**
- ICLR reviewers prefer broad applicability
- Ternary quantization may affect vision differently
- Cross-modal results strengthen "general method" claim

**Evidence Needed:**
- [ ] CIFAR-10/100 image classification
- [ ] Speech recognition (LibriSpeech subset)
- [ ] Multimodal (text+image) task

**Time Estimate:** 2-3 months
- CIFAR-10: 1 week training, 1 week evaluation
- Speech: 2 weeks training, 1 week evaluation
- Multimodal: 3-4 weeks

**Resources Needed:**
- GPU for training (single A100 sufficient)
- Datasets (all public)
- Evaluation scripts

---

### Gap 3: Direct GPU Comparison

**Current Status:** No direct GPU throughput comparison. Claims about energy efficiency are calculated, not measured.

**Why This Matters:**
- Need to demonstrate "37.5× energy efficiency" claim
- Reviewers may question calculated vs measured power
- Direct comparison strengthens FPGA advantage

**Evidence Needed:**
- [ ] GPU benchmark: RTX 3080 or 4090 (throughput, power)
- [ ] Energy efficiency measurement: tokens/Joule
- [ ] Latency comparison: ms/token

**Time Estimate:** 1 month
- GPU access: 1 week
- Benchmarking: 2 weeks
- Measurement: 1 week

**Resources Needed:**
- NVIDIA GPU (RTX 3080/4090 or A100)
- Power meter (for GPU measurement)
- Benchmark scripts

---

## Important Gaps (Should Address)

### Gap 4: Statistical Validation

**Current Status:** Ablation results based on 5 runs. Need more trials for statistical significance.

**Evidence Needed:**
- [ ] 10+ trials per ablation variant
- [ ] Two-tailed t-test (α=0.05)
- [ ] 95% confidence intervals
- [ ] Effect size (Cohen's d)

**Time Estimate:** 2 months
- Training: 6 weeks (10 runs × 6 ablations)
- Analysis: 2 weeks

**Action:** Run before NeurIPS 2026 to strengthen submission.

---

### Gap 5: Reasoning Benchmarks

**Current Status:** VSA operations integrated but not evaluated on reasoning tasks.

**Evidence Needed:**
- [ ] Design 3 compositional reasoning tasks
- [ ] Benchmark VSA vs standard attention
- [ ] Measure code density advantage
- [ ] Human evaluation of interpretability

**Time Estimate:** 2-3 months
- Task design: 1 month
- Implementation: 1 month
- Evaluation: 1 month

**Action:** Consider for ICLR 2027 submission (not NeurIPS 2026).

---

### Gap 6: Formal Verification Integration

**Current Status:** Proofs are format-level, not trained model verification.

**Evidence Needed:**
- [ ] SMT-based verification of trained small model
- [ ] Property specification (robustness, fairness)
- [ ] Verification tool integration (Marabou, alpha-beta-CROWN)

**Time Estimate:** 2-3 months
- Literature review: 2 weeks
- Tool setup: 2 weeks
- Experiments: 2 months

**Action:** Consider for extended version or future work.

---

## Minor Gaps (Can Defer)

### Gap 7: Additional FPGA Platforms

**Current Status:** XC7A100T only. No Intel or Lattice results.

**Evidence Needed:**
- [ ] Synthesis on Intel Cyclone V
- [ ] Synthesis on Lattice iCE40
- [ ] Resource comparison across platforms

**Time Estimate:** 1 month
- Access to boards: 2 weeks
- Synthesis: 2 weeks

**Action:** Future work.

---

### Gap 8: ASIC Feasibility Study

**Current Status:** No ASIC implementation or analysis.

**Evidence Needed:**
- [ ] Area estimation (mm²)
- [ ] Power comparison (ASIC vs FPGA)
- [ ] Cost analysis (per-unit manufacturing)

**Time Estimate:** 2 months
- Synopsys/Cadence tools: 4 weeks
- Analysis: 4 weeks

**Action:** Future work.

---

## Gap Prioritization Matrix

| Gap | Impact | Feasibility | Time | Priority |
|------|--------|-------------|------|----------|
| 1. Larger models | High | Medium | 3-6 mo | High |
| 2. Cross-modal | High | High | 2-3 mo | High |
| 3. GPU comparison | Medium | High | 1 mo | Medium |
| 4. Statistical validation | Medium | High | 2 mo | Medium |
| 5. Reasoning benchmarks | Low | High | 2-3 mo | Low |
| 6. Formal verification | Medium | Low | 2-3 mo | Low |
| 7. Other FPGA | Low | Medium | 1 mo | Low |
| 8. ASIC study | Low | Low | 2 mo | Low |

**Recommendation:** Focus on Gaps 1-4 for ICLR 2027.

---

## Timeline for ICLR 2027

### March-May 2026: Gap 3 (GPU Comparison)
- Acquire GPU access
- Run benchmarks
- Measure power

### June-August 2026: Gap 4 (Statistical Validation)
- Run additional ablation trials
- Statistical analysis
- Update paper

### September 2026: Gap 2 (Cross-Modal) - Start
- Acquire datasets
- Set up training pipelines

### October-November 2026: Gap 2 (Cross-Modal) - Continue
- Run experiments
- Analyze results

### December 2026 - February 2027: Gap 1 (Larger Models)
- Acquire compute
- Train larger models
- Evaluate

### March 2027: Paper Writing
- Incorporate new results
- Revise abstract
- Finalize submission

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-------------|
| Cannot acquire compute for 7B model | Medium | High | Use 100M model instead |
| Cross-modal results weaker than LM | Medium | Medium | Focus on LM, mention cross-modal as future |
| GPU comparison unfavorable | Low | Medium | Present FPGA advantages regardless |
| Statistical validation fails | Low | Low | Use Bayesian intervals as fallback |

---

## Minimum Viable Package

If time is limited, address at minimum:

1. **Gap 3 (GPU comparison):** 1 month, high impact
2. **Gap 4 (Statistical validation):** 2 months, medium impact

This provides:
- Direct energy efficiency claim validation
- Statistically significant ablation results

Both are addressable before NeurIPS 2026 submission.

---

**Document Control:** ICLR-GAPS-001
**Status:** Draft — Created March 2026
