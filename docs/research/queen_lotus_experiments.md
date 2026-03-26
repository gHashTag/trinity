# Queen Lotus Cycle — Self-Learning Experiments

## Overview

Queen Lotus Cycle — autonomous orchestrator for Trinity S³AI. 6-phase loop: Experience Recall → Observe → Plan → Act → Evaluate → Self-Learn.

**Goal:** Automatic configuration adaptation based on historical episode data.

---

## Lotus Cycle Phases

### Phase 0: Experience Recall

**File:** `src/tri27/tri27_experience.zig`

**Functions:**
- `loadRecentEpisodes(N)` — Retrieve last N episodes from `.trinity/queen/episodes.jsonl`
- `computeJaccardSimilarity(E1, E2)` — Calculate Jaccard similarity for retrieval

**Jaccard Similarity:**
```
J(A, B) = |A ∩ B| / |A ∪ B|
```

**Parameters:**
- `recall_accuracy` — Target: > 0.8
- `jaccard_threshold` — Similarity threshold: 0.7 (default)

**Metrics:**
- `recall_accuracy` — Precision of top-k retrieval
- `retrieval_count` — Number of episodes retrieved

---

### Phase 1: Observe

**File:** `src/tri/queen/observe.zig`

**Purpose:** Capture current system state for episode storage.

**Captured State:**
- Current configuration (all hyperparameters)
- Farm metrics (active services, crash rates)
- Environment (hardware status)

**Metrics:**
- `state_capture_rate` — % of successful state captures
- `state_completeness` — Number of state variables captured

---

### Phase 2: Plan

**File:** `src/tri/queen/plan.zig`

**Purpose:** Generate configuration changes based on retrieved episodes.

**PolicyDelta Types:**
- `scale_up` — Increase learning rate
- `scale_down` — Decrease learning rate
- `set` — Set specific value
- `wait` — Wait for stability

**PolicyDelta Variants:**
```zig
pub const PolicyDelta = union(enum) {
    scale_up: struct { key: []const u8, factor: f64 },
    scale_down: struct { key: []const u8, factor: f64 },
    set: struct { key: []const u8, value: f64 },
    wait: void,
};
```

---

### Phase 3: Act

**File:** `src/tri/queen/act.zig`

**Purpose:** Apply generated PolicyDelta to Tri27Config.

**Actions:**
- Update learning rate
- Update batch size
- Set specific parameter values
- Wait for convergence

---

### Phase 4: Evaluate

**File:** `src/tri/queen/evaluate.zig`

**Purpose:** Assess episode quality using WindowEvaluation.

**WindowEvaluation Structure:**
```zig
pub const WindowEvaluation = struct {
    total_episodes: usize,
    successful: usize,
    failed: usize,
    crashed: usize,
    byzantine: usize,
    success_rate: f64,
    quality: Quality,
};
```

**Quality Levels:**
- `good` — success_rate >= 0.95
- `unstable` — 0.70 <= success_rate < 0.95
- `bad` — success_rate < 0.70

---

### Phase 5: Self-Learn

**File:** `src/tri/queen/self_learning.zig`

**Purpose:** Close feedback loop — compute new policy deltas.

**Closed-Loop Process:**
1. Generate `WindowEvaluation` from recent episodes
2. Compute quality classification
3. Adapt learning parameters based on quality
4. Store episode for future reference

---

## Experimental Scenarios

### Scenario A: Queen vs No-Queen

**Objective:** Measure Queen impact on farm stability.

**Variables:**
- Independent: `auto_adapt` (bool)
- Dependent: `crash_rate` = crashes / total_episodes
- Controlled: `kill_threshold`, `crash_rate_limit`, `byzantine_rate_limit`

**Setup:**
- Control group: 50 services without Queen
- Experimental group: 50 services with Queen

**Metrics:**
- `crash_rate` — Percentage of services crashing
- `success_rate` — PPL achievement percentage
- `byzantine_rate` — Byzantine failures / total

**Expected Results:**
- Queen enabled: crash_rate < 0.05
- Queen disabled: crash_rate ~ 0.15
- Feedback loop: 2× faster convergence (time_to_stable: ~100 vs ~200 episodes)

---

### Scenario B: Feedback Loop Acceleration

**Objective:** Accelerate stabilization using quality classification.

**Variables:**
- Independent: `time_to_stable` — Episodes to reach quality=good
- Dependent: `queen_trigger_rate` — Kill actions / total evaluations

**Setup:**
- Start with aggressive settings
- Monitor quality transitions
- Scale down on success

**Expected Results:**
- Queen enabled: time_to_stable ~ 100 episodes
- Without feedback: time_to_stable ~ 200 episodes
- Improvement: 2× faster stabilization

---

## Paper 1: Queen Self-Learning (H1-H3)

### H1: Self-Learning reduces crash rate

**Claim:** Tri27Config with `auto_adapt=true` achieves <5% crash rate vs ~15% with fixed config.

**Variables:**
- Independent: `auto_adapt` (bool)
- Dependent: `crash_rate` = byzantine / total
- Controlled: `kill_threshold`, `crash_rate_limit`, `byzantine_rate_limit`

**Experiment:**
```bash
# A/B test: Queen enabled vs disabled
tri farm spawn --config queen_enabled.json --count 10
tri farm spawn --config queen_disabled.json --count 10
tri farm monitor --duration 48h

# Expected results
tri farm metrics --filter byzantine_rate
```

**Metrics:**
- Queen enabled crash_rate
- Queen disabled crash_rate
- Statistical significance (t-test, p < 0.01)

---

### H2: Feedback loop accelerates stabilization

**Claim:** Systems with self-learning reach stable mode in 2× fewer episodes.

**Variables:**
- Independent: `time_to_stable` (episodes)
- Dependent: `queen_trigger_rate` = kills / evaluations

**Experiment:**
```bash
# Run with and without feedback loop
tri queen self-learning --window 50 --monitor
tri queen self-learning --window 200 --monitor
```

**Expected Results:**
- With feedback: ~100 episodes to stable
- Without feedback: ~200 episodes to stable
- Quality classification accuracy: >90%

---

### H3: Auto-adapt prevents byzantine failure

**Claim:** `byzantine_rate_limit` reduces byzantine ratio to <5%.

**Variables:**
- Independent: `auto_adapt` × `byzantine_rate_limit`
- Dependent: `byzantine_rate` = byzantine / total

**Experiment:**
```bash
tri farm inject --config byzantine_stress.json
tri queen self-learning --window 50
tri farm metrics --filter byzantine_rate
```

**Expected Results:**
- With limit: byzantine_rate < 0.05
- Without limit: byzantine_rate ~ 0.15

---

### H4: Reticular Raphe validation

**Claim:** TRI-27 implementation of Reticular Raphe computes correct rolling PPL within error margin <1%.

**Variables:**
- `rolling_ppl_error` = |ppl_tri27 - ppl_reference| / ppl_reference

**Reference Implementation:** `src/tri27/reticular_raphe.t27` — TRI-27 binary computes φ^decay rolling average

**Experiment:**
```bash
# Build reference implementation
tri tri27 assemble src/tri27/reticular_raphe.t27 -o reticular_raphe.tbin

# Run TRI-27 VM
tri tri27 run reticular_raphe.tbin --benchmark 10000

# Dump t0 register
tri tri27 run reticular_raphe.tbin --dump-registers t0 | jq '.[0]'

# Calculate error
tri plot convergence_comparison.jsonl --x steps --y rolling_ppl_error
```

**Expected Results:**
- `rolling_ppl_error` < 1%

---

## H5: φ-decay factor optimization

**Claim:** φ^decay = 0.99 (≈1/φ) achieves optimal PPL convergence speed without overshoot.

**Variables:**
- Independent: `phi_decay` value (0.90 to 0.99)

**Experiment:**
```bash
# Grid search for optimal phi_decay
tri farm grid-search \
  --params phi_decay:0.90,0.95,0.99,0.990,1.00 \
  --count 10 \
  --duration 24h
```

**Expected Results:**
- Optimal: φ_decay = 0.990
- Convergence time: ~150 episodes

---

## H6: PPL clamping prevents Queen panic

**Claim:** PPL clamping to [MIN_PPL, MAX_PPL] prevents Queen from triggering kill_threshold on transient spikes.

**Variables:**
- `enable_clamping` (bool)
- `min_ppl` (f64)
- `max_ppl` (f64)
- `queen_trigger_rate` = kills / evaluations

**Experiment:**
```bash
# Run with clamping enabled and disabled
tri queen self-learning --window 20 --enable-clamping true
tri queen self-learning --window 20 --enable-clamping false
```

**Expected Results:**
- Clamping enabled: queen_trigger_rate < 0.01
- Clamping disabled: queen_trigger_rate ~ 0.15

---

## CLI Commands

### Episode Management

```bash
# List recent episodes
tri queen episode-list --recent 20

# Retrieve specific episode
tri queen episode-list --episode <ID>

# Delete episode
tri queen episode-list --delete <ID>

# Compute Jaccard similarity
tri queen jaccard --episode <ID> --episode <ID>
```

### Self-Learning Control

```bash
# Start autonomous learning cycle
tri queen self-learning --window 20

# Stop learning cycle
tri queen self-learning --stop

# Show current config
tri queen config show

# Set config parameter
tri queen config set <key> <value>
```

### Monitoring

```bash
# Show convergence metrics
tri plot convergence.jsonl --x steps --y quality

# Monitor farm health
tri farm status
```

---

## Status

✅ Phase 0: Experience Recall — Implemented
✅ Phase 1: Observe — Implemented
✅ Phase 2: Plan — Implemented
✅ Phase 3: Act — Implemented
✅ Phase 4: Evaluate — Implemented
✅ Phase 5: Self-Learn — Implemented
✅ CLI Commands — Complete
✅ A/B test infrastructure — Ready
✅ Monitoring tools — Ready
✅ 5 hypothesis (H1-H6) — Formulated
✅ Paper 1 structure — Ready

---

## How to Cite

This work is published as a defensive publication (prior art) to prevent patenting of self-learning orchestration innovations.

### BibTeX

```bibtex
@misc{trinity2025queen,
  title = {Queen Self-Learning: Episode-Based Adaptation for Autonomous AI Systems},
  author = {{Trinity Project}},
  year = {2025},
  doi = {10.5281/zenodo.18939352},
  url = {https://doi.org/10.5281/zenodo.18939352},
  note = {Defensive Publication -- Part of Trinity S³AI Framework}
}

@misc{trinity2025lotus,
  title = {Lotus Cycle: Six-Phase Self-Learning Feedback Loop for Autonomous Orchestration},
  author = {{Trinity Project}},
  year = {2025},
  doi = {10.5281/zenodo.18939352},
  url = {https://doi.org/10.5281/zenodo.18939352},
  note = {Defensive Publication}
}

@misc{trinity2025h3,
  title = {Auto-Adaptation Prevents Byzantine Failures in Self-Learning Systems},
  author = {{Trinity Project}},
  year = {2025},
  doi = {10.5281/zenodo.18939352},
  url = {https://doi.org/10.5281/zenodo.18939352},
  note = {Defensive Publication}
}
```

### APA

```
Trinity Project. (2025). *Queen Self-Learning: Episode-Based Adaptation for Autonomous AI Systems* [Defensive Publication]. Zenodo. https://doi.org/10.5281/zenodo.18939352.

Trinity Project. (2025). *Lotus Cycle: Six-Phase Self-Learning Feedback Loop for Autonomous Orchestration* [Defensive Publication]. Zenodo. https://doi.org/10.5281/zenodo.18939352.
```

### MLA

```
Trinity Project. "Queen Self-Learning: Episode-Based Adaptation for Autonomous AI Systems." *Defensive Publication*, 2025, Zenodo, doi:10.5281/zenodo.18939352.
```

### IEEE

```
[1] Trinity Project, "Queen Self-Learning: Episode-Based Adaptation for Autonomous AI Systems," Zenodo, 2025. doi:10.5281/zenodo.18939352.
```

---

## Integration with Other Components

| Component | Interface | File |
|-----------|-----------|------|
| TRI-27 | Episode logging | `.trinity/queen/episodes.jsonl` |
| HSLM Farm | Senses input | `.trinity/queen/senses.json` |
| VSA | Episode similarity | Jaccard algorithm (in-memory) |

---

**φ² + 1/φ² = 3 | TRINITY**
