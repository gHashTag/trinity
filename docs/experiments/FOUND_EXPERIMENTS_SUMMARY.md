# Found Experiments Summary — Trinity HSLM

**Date:** 2026-04-20
**Source:** Git history analysis across all branches and tags
**Status:** ✅ Complete — 25+ experiments found

---

## Table of Contents

1. [NTP Experiments](#ntp-experiments)
2. [JEPA/T-JEPA Experiments](#jepat-jepa-experiments)
3. [NCA Experiments](#nca-experiments)
4. [Hybrid Experiments](#hybrid-experiments)
5. [EXP-001 to EXP-025 Log](#exp-001-to-exp-025-log)
6. [Wave 8.5 G1–G8 Parameters](#wave-85-g1g8-parameters)
7. [Simulation Scenarios S1-S10](#simulation-scenarios-s1-s10)

---

## NTP Experiments

### EXP-001: Context Length Discovery
**Impact:** CRITICAL | **Date:** 2026-03-13

**Parameters:**
- ctx=18 (Wave 3-4 baseline) → PPL 5.58
- ctx=27 (Wave 5) → PPL 2.96
- **Result:** ctx=27 = 3³ aligns with ternary architecture → 1.89x improvement

**Config:**
```
LAMB 1e-3
cosine schedule
batch=66
ctx=27 vs ctx=18
```

### EXP-010: Non-Monotonic Scaling
**Impact:** CRITICAL | **Date:** 2026-03-13

**Parameters:**
- ctx=54 (2×27) → PPL 6.05 (WORSE than ctx=27)
- ctx=27 → PPL 2.96-5.55
- ctx=18 → PPL 5.5-5.6

**Lesson:** Powers of 3 (3ᵏ) are optimal. Non-3ᵏ context lengths degrade performance.

### EXP-012: Square Attention Theorem
**Impact:** CRITICAL | **Date:** 2026-03-13

**Finding:** ctx MUST equal head_dim (or a power-of-3 divisor)
- Square attention (ctx=head_dim) → full rank
- Rectangular attention (ctx>head_dim) → rank deficient

### EXP-014: Resonance Law
**Impact:** CRITICAL | **Date:** 2026-03-13

**Finding:** Ternary scaling follows RESONANCE curve, not power law
- Optimal ctx: 3ᵏ "orbitals" (9, 27, 81)
- Values between orbitals: "forbidden zones"

### EXP-025: Early Kill Thresholds
**Impact:** HIGH | **Date:** 2026-03-15

**Parameters:**
```zig
// Old → New thresholds (72/72 W7 runs killed by aggressive thresholds)
kill_ppl_10k: 200 → 500
kill_ppl_30k: 50 → 200
kill_ppl_60k: — → 100
kill_ppl_80k: — → 50
```

**Env vars:**
- `HSLM_KILL_PPL_10K=500`
- `HSLM_KILL_PPL_30K=200`
- `HSLM_KILL_PPL_60K=100`
- `HSLM_KILL_PPL_80K=50`

**Features:**
- 4 configurable kill stages
- Force-save checkpoint at 32K (historical PPL minimum)
- `checkpoint_best` keeper (never deleted)
- `tri farm recycle --fresh` (HSLM_FRESH=1)
- `tri farm recycle --seed-start N` (was hardcoded 601)

---

## JEPA/T-JEPA Experiments

### T-JEPA Architecture Parameters

**Files:** `src/hslm/tjepa.zig`, `src/hslm/ema.zig`, `src/hslm/mask.zig`, `src/hslm/mse_loss.zig`

#### Mask Configuration
```zig
pub const MaskConfig = struct {
    mask_ratio: f32 = 0.3,   // 30% masked
    min_span: usize = 3,      // 3^1
    max_span: usize = 9,      // 3^2
    num_spans: usize = 2,     // 2 spans fit in ctx=81
};
```

#### EMA Sync Configuration
```zig
pub const EmaSync = struct {
    decay_start: f32 = 0.996,  // Initial decay (more online influence)
    decay_end: f32 = 1.0,      // Final decay (target freezes)
};

// Decay schedule
step 0   → decay 0.996 (99.6% online)
step 20K → decay 0.998 (99.8% online)
step 40K → decay 0.999 (99.9% online)
```

**Env vars:**
- `HSLM_EMA_DECAY_START=0.996`
- `HSLM_EMA_DECAY_END=1.0`

#### Predictor Configuration
```zig
// 1 TrinityBlock + Linear projection
// Parameters: ~650K (591K block + 59K projection)
// Forward: assemble → block → project masked positions
```

#### MSE Loss Configuration
```zig
// L2-normalized before MSE (anti-collapse)
// L = (1/N) Σ ||pred - target||² (L2-normalized)
```

**Env vars:**
- `HSLM_MASK_RATIO=0.3`
- `HSLM_PREDICTOR_LR_MULT=2.0`

#### Objective Multipliers (from simulation)
```zig
ntp       → 1.0 (baseline)
jepa      → 1.4 (40% slower convergence)
nca-ntp   → 1.6 (60% slower)
hybrid    → 1.2 (20% slower)
```

---

## NCA Experiments

### NCA (Neural Cellular Automata) Parameters

**File:** `src/hslm/nca.zig`
**Paper:** MIT arXiv 2603.10055

#### NcaConfig
```zig
pub const NcaConfig = struct {
    grid_size: u8 = 9,           // 9×9 = 81 = CONTEXT_LEN
    num_states: u8 = 9,          // K=9 states per cell
    rollout_steps: u16 = 128,    // T timesteps per trajectory
    token_offset: u16 = 4,       // skip PAD/BOS/EOS/UNK
    min_entropy: f32 = 1.5,      // reject too-simple trajectories
    max_entropy: f32 = 2.8,      // reject too-random (log2(9)=3.17)
    seed: u64 = 42,
};
```

#### Env vars
- `HSLM_NCA_STEPS=15000` (default pre-pre-training steps)
- `HSLM_NCA_GRID=9`
- `HSLM_NCA_STATES=9`
- `HSLM_NCA_ROLLOUT=128`
- `HSLM_NCA_ENTROPY_MIN=1.5`
- `HSLM_NCA_ENTROPY_MAX=2.8`
- `HSLM_JEPA_STEPS=0` (0 = auto: 40K for nca-jepa-ntp, 20K for v2)

#### NCA Objectives
```zig
enum { ntp, jepa, hybrid, nca_ntp, nca_jepa_ntp, nca_jepa_ntp_v2 }

// nca_jepa_ntp:    NCA 15K → JEPA 40K → NTP
// nca_jepa_ntp_v2: NCA 15K → JEPA 20K → NTP (faster)
```

#### Wave 8.5 G1–G8 Entropy Band

**CLI flags:**
```
--nca-entropy-min <float>  (default 1.5)
--nca-entropy-max <float>  (default 2.8)
```

**Example G1–G8 sweep:**
```
G1: entropy=[1.0, 1.5]  (very simple)
G2: entropy=[1.2, 1.8]
G3: entropy=[1.4, 2.0]
G4: entropy=[1.5, 2.3]  (default)
G5: entropy=[1.7, 2.5]
G6: entropy=[2.0, 2.7]
G7: entropy=[2.3, 2.9]
G8: entropy=[2.5, 3.0]  (max log2(9)=3.17)
```

---

## Hybrid Experiments

### Wave 8-Hybrid (W8-hybrid)
**Command:** `tri farm evolve watch --objective hybrid`

**Parameters:**
```zig
objective = .hybrid  // 3-way: ntp + jepa + nca-ntp
```

**Env vars (set by inject/watch):**
- `HSLM_OBJECTIVE=hybrid`
- `HSLM_EMA_DECAY_START=0.996`
- `HSLM_EMA_DECAY_END=1.0`
- `HSLM_MASK_RATIO=0.3`
- `HSLM_PREDICTOR_LR_MULT=2.0`

### S4-S5-S5 Objective Weights

**S4 dePIN (Byzantine + Microglia):**
```zig
objectives = &.{
    .{ .name = "ntp", .weight = 0.50 },
    .{ .name = "jepa", .weight = 0.25 },
    .{ .name = "nca-ntp", .weight = 0.25 },
};
crash_rate = 0.10
byzantine_rate = 0.05
microglia_interval = 30
```

**S5 dePIN NoImmunity (Byzantine only):**
```zig
objectives = &.{
    .{ .name = "ntp", .weight = 0.50 },
    .{ .name = "jepa", .weight = 0.25 },
    .{ .name = "nca-ntp", .weight = 0.25 },
};
crash_rate = 0.10
byzantine_rate = 0.05
microglia_interval = 0  // No immunity
```

**S6 JEPA-heavy (35% JEPA):**
```zig
// Demonstrates risk of objective monoculture
// JEPA-dominated S6 fails under combined crash+byzantine stress
```

---

## EXP-001 to EXP-025 Log

### EXP-001 | DISCOVERY | 2026-03-13 | architecture
**Finding:** ctx=27=3³ achieves PPL 2.96 vs ctx=18 PPL 5.58 → 1.89x improvement
**Action:** Test ctx=81 (3⁴) and ctx=243 (3⁵)

### EXP-002 | FAILURE | 2026-03-13 | deployment
**Issue:** HSLM_FRESH=1 wiped checkpoints on R5 (PPL 2.96 KING) and R23v2 (PPL 2.9)
**Fix:** Added _final.bin preservation in clearCheckpoints()

### EXP-003 | FAILURE | 2026-03-13 | deployment
**Issue:** Git push to main triggered Railway rebuild → 4 PRIMARY services FAILED
**Fix:** .dockerignore, deploymentRedeploy from previous image

### EXP-004 | DISCOVERY | 2026-03-13 | training
**Finding:** PHI+restart at ctx=21 achieves PPL 3.10 (competitive with ctx=27)
**Action:** Implement lr_phi_restart as first-class schedule

### EXP-005 | DISCOVERY | 2026-03-13 | training
**Finding:** Context length >> optimizer choice. AdamW vs LAMB: similar at same ctx

### EXP-006 | WARNING | 2026-03-13 | training
**Finding:** Seed variance ~157x between best and worst in ternary models
**Action:** Run 5+ seeds per config, report median PPL

### EXP-007 | SUCCESS | 2026-03-13 | training
**Finding:** Characteristic plateau around PPL 100-120 breaks at ~50K steps
**Action:** Set minimum run length to 60K steps

### EXP-008 | SUCCESS | 2026-03-13 | training
**Finding:** 68% seeds reach PPL < 15 within 30K steps, 8% achieve PPL < 5
**Action:** Early stopping for PPL > 30 at step 20K

### EXP-009 | FAILURE | 2026-03-13 | deployment
**Issue:** ReleaseFast uses >2GB RAM → OOM on Railway
**Fix:** Switch to ReleaseSmall (later Debug)

### EXP-010 | DISCOVERY | 2026-03-13 | architecture
**Finding:** ctx=54 is WORSE than ctx=27 despite 2× more context
**Reason:** Non-3ᵏ breaks ternary alignment, creates non-square attention

### EXP-011 | FAILURE | 2026-03-13 | deployment
**Issue:** GraphQL variableUpsert triggers deploy per var → cascading failures
**Fix:** Use MCP set-variables with skipDeploys

### EXP-012 | DISCOVERY | 2026-03-13 | architecture
**Theorem:** Square Attention — ctx=head_dim for full rank

### EXP-013 | DISCOVERY | 2026-03-13 | architecture
**Principle:** Ternary Resonance — all dimensions must be 3ᵏ

### EXP-014 | DISCOVERY | 2026-03-13 | architecture
**Law:** Resonance Law — discrete 3ᵏ orbitals, not continuous scaling

### EXP-015 | FAILURE | 2026-03-13 | deployment
**Issue:** ReleaseSmall still OOMs on Railway (needs >1GB)
**Fix:** Switch to Debug optimization

---

## Wave 8.5 G1–G8 Parameters

**CLI:**
```bash
tri farm evolve inject \
  --target <service> \
  --objective nca-jepa-ntp \
  --nca-steps 15000 \
  --nca-entropy-min 1.5 \
  --nca-entropy-max 2.8
```

**G1–G8 Entropy Sweep:**
| Group | Min Entropy | Max Entropy | Notes |
|-------|-------------|-------------|-------|
| G1 | 1.0 | 1.5 | Very simple CA rules |
| G2 | 1.2 | 1.8 | Simple → moderate |
| G3 | 1.4 | 2.0 | Moderate complexity |
| G4 | 1.5 | 2.3 | Default band |
| G5 | 1.7 | 2.5 | Above default |
| G6 | 2.0 | 2.7 | Near max |
| G7 | 2.3 | 2.9 | High entropy |
| G8 | 2.5 | 3.0 | Max (log2(9)=3.17) |

**NCA 25% Quotas:**
- 25% of training slots allocated to NCA objectives
- Cell parser agent support for NCA trajectory analysis

---

## Simulation Scenarios S1-S10

**File:** `src/brain/evolution_simulation.zig`

| Scenario | Workers | Crash | Byzantine | Objectives (weights) | Seeds |
|----------|---------|-------|-----------|---------------------|-------|
| S1 MultiObj | 100 | 0.05 | 0 | ntp=0.70, jepa=0.15, nca-ntp=0.15 | 1966 |
| S2 Crash | 100 | 0.15 | 0 | ntp=1.0 | 3178 |
| S3 MultiObj+Microglia | 100 | 0.05 | 0 | ntp=0.70, jepa=0.15, nca-ntp=0.15 | 5142 |
| S4 dePIN | 100 | 0.10 | 0.05 | ntp=0.50, jepa=0.25, nca-ntp=0.25 | 8317 |
| S5 dePIN NoImmunity | 100 | 0.10 | 0.05 | ntp=0.50, jepa=0.25, nca-ntp=0.25 | 13460 |
| S6 JEPA-heavy | 100 | 0.10 | 0.05 | 35% JEPA | 21800 |
| S7 High-Diversity | 100 | — | — | — | 8450 |
| S8 Low-Crash | 100 | — | — | — | 13692 |
| S9 Byzantine-Heavy | 100 | — | — | — | 22134 |
| S10 Energy-Optimal | 100 | — | — | — | 35780 |

**PPL Model Calibration:**
```zig
pub const PplModel = struct {
    A: f32 = 500.0,        // Initial scale
    alpha: f32 = 0.35,     // Decay exponent
    floor: f32 = 4.6,      // Theoretical minimum (r33)
    noise_std: f32 = 0.05, // 5% stochastic noise
};
// PPL(step) = A * step^(-alpha) + floor
```

---

## Complete Parameter Reference

### Trinity Constants
```zig
VOCAB_SIZE = 729 = 3^6
HIDDEN_DIM = 729 = 3^6
EMBED_DIM = 243 = 3^5
CONTEXT_LEN = 81 = 3^4
NUM_BLOCKS = 9 = 3^2
HEADS = 9 = 3^2
HEAD_DIM = 27 = 3^3
```

### Training Defaults
```zig
steps = 50000
lr = 3e-4
batch_size = 66
grad_accum = 1
weight_decay = 0.01
dropout = 0.1
```

### Optimizer Configs
```zig
// LAMB (Layer-wise Adaptive Moments)
lamb_clamp = 10.0
stable_ratio = 0.02

// LR Schedule
lr_min = 1e-5
lr_schedule = cosine
restart_period = 0  // 0 = no restart
```

### Ternary Flags
```zig
ternary_grads = false
adaptive_sparsity_flag = false
ternary_schedule_flag = false
full_ternary = false
init_zero = false
```

### Data Config
```zig
data_shard = 0
num_shards = 1
total_lines = 15_600_056  // TinyStories
val_split = 0.0  // 0 = disabled
```

### Gradient Clipping
```zig
grad_clip_val = 1.0
```

---

## Git References

**Key Commits:**
- `75cd7a8de` — EXP-025: Early kill thresholds + T-JEPA objective
- `669e054cf` — T-JEPA modules (EMA, mask, MSE, JEPA encoder, trainer)
- `67a1e5f8b` — NCA pre-pre-training (3 objectives)
- `17ba5f427` — --objective hybrid support + JEPA env vars
- `3a235c5e1` — Wave 8.5 G1–G8 entropy band plumbing
- `aa065927e` — S6 JEPA-heavy scenario

**Key Tags:**
- `zig-hslm-f16-utils-from-codeberg` — JEPA/NCA commits
- `v6.2.0` — EXPERIENCE_LOG.md snapshot

**Key Files (from git history):**
- `EXPERIENCE_LOG.md` — EXP-001 to EXP-025
- `src/hslm/tjepa.zig` — T-JEPA main module
- `src/hslm/ema.zig` — EMA synchronization
- `src/hslm/mask.zig` — Span masking
- `src/hslm/mse_loss.zig` — L2-normalized MSE
- `src/hslm/nca.zig` — Neural Cellular Automata
- `src/hslm/cli.zig` — CLI with all parameters
- `src/brain/evolution_simulation.zig` — S1-S10 scenarios

---

## Research Documents Found

1. `TJEPA_MATHEMATICAL_ANALYSIS_V1.md` — 6 theorems, 5 algorithm boxes
2. `CONSCIOUSNESS_AND_TJEPA_MATHEMATICAL_ANALYSIS_V1.md` — Consciousness gate analysis
3. `TJEPA_COMPREHENSIVE_ANALYSIS_V2.md` — 950+ LOC analysis
4. `TJEPA_SCIENTIFIC_VALIDATION.md` — Experimental validation
5. `TJEPA_VSA_UNIFIED_ANALYSIS_SESSION33.md` — VSA integration
6. `discovery/p8_tjepa.md` — P8 discovery file

---

**End of Found Experiments Summary**
