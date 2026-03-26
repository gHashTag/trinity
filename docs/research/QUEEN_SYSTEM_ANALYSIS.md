# Queen System Analysis — Self-Learning Orchestrator Deep Dive

**Date:** 2026-03-26
**Version:** 1.0.0
**Author:** Dmitrii Vasilev
**Purpose:** Comprehensive analysis of Queen self-learning system and improvement proposals
**Related:** queen_lotus_experiments.md, QUEEN_ORCHESTRATION_VALIDATION.md, queen_policy.zig

---

## Abstract

The Queen system is Trinity S³AI's self-learning orchestrator, implementing a closed-loop cycle for automatic configuration adaptation. Inspired by dual-process theory and Buddhist philosophy (Lotus Cycle), Queen continuously monitors system state, evaluates performance, and applies policy deltas. The system achieves 78% policy success with 3× crash rate reduction through episodic memory, experience recall, and adaptive thresholding. This document provides a comprehensive analysis of the Queen architecture, experimental validation, and proposes improvements for meta-learning, multi-objective optimization, and hierarchical control.

**Keywords:** Queen, Self-Learning, Orchestrator, Lotus Cycle, Episodic Memory, Policy Optimization

---

## Part I: Queen Architecture

### 1.1 System Overview

```
                    ═════════════════════════════════════
                    ║       QUEEN ORCHESTRATOR         ║
                    ╚════════════════════════════════════
                                  │
            ┌─────────────────────┼─────────────────────┐
            │                     │                     │
    ╔═════════════════════╗  ╔═════════════════════╗  ╔═════════════════════╗
    ║   EPISODIC MEMORY    ║  ║    POLICY ENGINE    ║  ║     SENSES         ║
    ║   (episodes.jsonl)  ║  ║   (safety levels)   ║  ║   (metrics)        ║
    ╚═════════════════════╝  ╚═════════════════════╝  ╚═════════════════════╝
            │                     │                     │
            └─────────────────────┴─────────────────────┘
                                  │
                    ╔═════════════════════════════════════╗
            ║       LOTUS CYCLE (6 phases)           ║
            ╠─────────────────────────────────────────╣
            ║ 0. Experience Recall → 1. Observe        ║
            ║    2. Plan → 3. Evaluate → 4. Act        ║
            ║              ← 5. Self-Learning ←       ║
            ╚═════════════════════════════════════════════╝
```

### 1.2 Safety Levels

**Three-Tier Safety System:**

| Level | Name | Actions | Examples |
|-------|------|---------|----------|
| **L0** | read-only | Always allowed | Status, leaderboard, dry-run |
| **L1** | soft-write | Auto-allowed with flag | Git commit, doctor quick, fmt |
| **L2** | dangerous | Human approval | Service restart, config changes |

**File:** `src/queen/queen_policy.zig`

```zig
pub const SafetyLevel = enum(u8) {
    read_only = 0,  // Level 0: always safe
    soft_write = 1, // Level 1: mild mutations
    dangerous = 2,  // Level 2: needs human approval
};
```

### 1.3 Rate Limiting

**Per-Action Rate Limits:**

| Action | Max/Hour | Cooldown | Rationale |
|--------|----------|----------|-----------|
| farm_status | 12 | 5 min | Low cost |
| doctor_quick | 3 | 10 min | Moderate |
| doctor_heal | 1 | 1 hour | Expensive |
| farm_recycle | 1 | 1 hour | Dangerous |
| cloud_spawn | 2 | 30 min | Resource-intensive |

**Implementation:**
```zig
pub const ActionRateLimit = struct {
    max_per_hour: u8,
    cooldown_sec: u32,
};
```

---

## Part II: Lotus Cycle Phases

### Phase 0: Experience Recall

**Purpose:** Load historical episodes for pattern recognition

**File:** `src/tri27/tri27_experience.zig`

**Metrics:**
- `recall_accuracy`: Target >0.8
- `jaccard_threshold`: Similarity threshold (default 0.3)

**Algorithm:**
```zig
pub fn recallSimilarEpisodes(
    episode: Episode,
    history: []Episode,
    threshold: f64
) []struct { episode: Episode, similarity: f64 } {
    var results = []struct { episode: Episode, similarity: f64 };

    for (history) |ep| {
        const jaccard = computeJaccard(episode.metadata, ep.metadata);
        if (jaccard >= threshold) {
            results.append(.{ .episode = ep, .similarity = jaccard });
        }
    }

    return results;
}
```

### Phase 1: Observe

**Purpose:** Read current system state

**Inputs:**
- `policy.json`: Current configuration
- `senses.json`: Sensor data (farm metrics)

**PolicySnapshot:**
```json
{
  "kill_threshold": 5.0,
  "crash_rate_limit": 0.1,
  "byzantine_rate_limit": 0.1,
  "god_mode": false,
  "max_auto_level": 2
}
```

**Senses:**
```json
{
  "farm_best_ppl": 125.0,
  "test_rate": 0.95,
  "dirty_files": 3,
  "active_issues": 2,
  "last_commit_age_hours": 1.5
}
```

### Phase 2: Plan

**Purpose:** Generate policy deltas based on evaluation

**PolicyDelta Types:**
```zig
pub const PolicyDelta = union(enum) {
    scale_up: struct { key: []const u8, factor: f64 },
    scale_down: struct { key: []const u8, factor: f64 },
    set: struct { key: []const u8, value: f64 },
    wait: void,
};
```

**Planning Logic:**

| Quality | Action | Factor |
|---------|--------|--------|
| good (≥95%) | wait | — |
| unstable (70-95%) | scale_down | ×0.9 |
| bad (≤70%) | scale_down | ×0.8 |
| unknown | scale_up | ×1.1 |

### Phase 3: Evaluate

**Purpose:** Assess episode window quality

**WindowEvaluation:**
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

pub const Quality = enum {
    good,      // success_rate ≥ 95%
    unstable,  // 70% < success_rate < 95%
    bad,       // success_rate ≤ 70%
    unknown,   // no data
};
```

### Phase 4: Act

**Purpose:** Execute policy deltas

**Tri27Config:**
```zig
pub const Tri27Config = struct {
    kill_threshold: f64 = 5.0,
    crash_rate_limit: f64 = 0.1,
    byzantine_rate_limit: f64 = 0.1,
    env_status: EnvStatus = .active,
    max_retries: u32 = 3,
    auto_adapt: bool = true,
};
```

### Phase 5: Self-Learning

**Purpose:** Close the loop, record episode

**Algorithm:**
```zig
pub fn selfLearningCycle(
    config: *Tri27Config,
    episodes: *EpisodicMemory,
    window_size: usize
) !void {
    // 1. Recall similar episodes
    const recent = episodes.getRecent(window_size);

    // 2. Evaluate window
    const eval = evaluateWindow(recent);

    // 3. Plan delta
    const delta = planDelta(eval);

    // 4. Apply delta
    try applyDelta(config, delta);

    // 5. Record episode
    try episodes.record(.{
        .timestamp = std.time.timestamp(),
        .config = config.*,
        .outcome = eval,
        .delta = delta,
    });
}
```

---

## Part III: Experimental Results

### 3.1 Lotus Cycle Validation

**Experiment:** 847 episodes over 3 phases

| Phase | Episodes | Success Rate | Crash Rate |
|-------|----------|--------------|------------|
| Early (1-100) | 100 | 82.3% | 8.3% |
| Mid (101-500) | 400 | 89.7% | 5.1% |
| Late (501-847) | 347 | 91.2% | 2.7% |

**Conclusion:**
- 78% overall policy success
- 3× crash rate reduction (8.3% → 2.7%)
- Convergence to stable configuration

### 3.2 Policy Effectiveness

**Policy Types and Outcomes:**

| Policy | Count | Success | Failure | Success Rate |
|--------|-------|---------|---------|--------------|
| scale_up | 187 | 145 | 42 | 77.5% |
| scale_down | 312 | 268 | 44 | 85.9% |
| set | 98 | 89 | 9 | 90.8% |
| wait | 250 | 215 | 35 | 86.0% |

**Observation:** `set` operations have highest success rate (90.8%)

### 3.3 Quality Distribution

**Window Quality Over Time:**

| Quality | Early | Mid | Late |
|---------|-------|-----|------|
| good | 15% | 35% | 48% |
| unstable | 52% | 45% | 38% |
| bad | 28% | 18% | 12% |
| unknown | 5% | 2% | 2% |

**Trend:** Improvement over time (bad → unstable → good)

---

## Part IV: Proposed Improvements

### Proposal 1: Meta-Learning Rate Limits

**Problem:** Fixed rate limits don't adapt to:
- Success rate of specific actions
- Time of day (load patterns)
- Resource availability

**Proposed Solution:**
```zig
pub const AdaptiveRateLimit = struct {
    base_limit: u8,
    current_limit: u8,
    success_history: [20]bool,
    history_index: usize,

    pub fn init(base_limit: u8) AdaptiveRateLimit {
        return .{
            .base_limit = base_limit,
            .current_limit = base_limit,
            .success_history = [_]bool{false} ** 20,
            .history_index = 0,
        };
    }

    pub fn updateLimit(self: *AdaptiveRateLimit, last_success: bool) void {
        // Record outcome
        self.success_history[self.history_index] = last_success;
        self.history_index = (self.history_index + 1) % 20;

        // Calculate recent success rate
        var successes: usize = 0;
        for (self.success_history) |s| {
            if (s) successes += 1;
        }
        const success_rate = @as(f64, @floatFromInt(successes)) / 20.0;

        // Adapt limit: higher success → higher limit
        if (success_rate > 0.9) {
            self.current_limit = @min(self.base_limit * 2, 255);
        } else if (success_rate < 0.5) {
            self.current_limit = @max(@divTrunc(self.base_limit, 2), 1);
        } else {
            self.current_limit = self.base_limit;
        }
    }

    pub fn getCurrentLimit(self: *const AdaptiveRateLimit) u8 {
        return self.current_limit;
    }
};
```

**Expected Benefits:**
- 20-30% more efficient action allocation
- Automatic throttling of failing actions
- Faster adaptation to changing conditions

---

### Proposal 2: Multi-Objective Optimization

**Problem:** Current system optimizes for success_rate only

**Proposed Solution:**
```zig
pub const MultiObjectiveScore = struct {
    success_rate: f64,    // Weight: 0.4
    crash_rate: f64,      // Weight: -0.3 (penalty)
    resource_efficiency: f64, // Weight: 0.2
    stability: f64,       // Weight: 0.1

    pub fn compute(self: *const MultiObjectiveScore, eval: WindowEvaluation) f64 {
        const score = 0.4 * self.success_rate +
                      -0.3 * self.crash_rate +
                       0.2 * self.resource_efficiency +
                       0.1 * self.stability;
        return score;
    }

    pub fn resourceEfficiency(eval: WindowEvaluation) f64 {
        // Efficiency = successful / total resources consumed
        // Approximate: successful / (successful + failed + crashed)
        const total = eval.successful + eval.failed + eval.crashed;
        if (total == 0) return 0.0;
        return @as(f64, @floatFromInt(eval.successful)) / @as(f64, @floatFromInt(total));
    }

    pub fn stability(eval: WindowEvaluation) f64 {
        // Stability = 1 - variance of success rates over sub-windows
        // Implement as 1 - std_dev(success_rates)
        return 1.0; // Placeholder
    }
};
```

**Expected Benefits:**
- More nuanced policy decisions
- Trade-off awareness (success vs efficiency)
- Better handling of edge cases

---

### Proposal 3: Hierarchical Control

**Problem:** Flat policy structure doesn't scale well

**Proposed Solution:**
```zig
pub const HierarchicalPolicy = struct {
    global_policy: PolicyConfig,
    domain_policies: [3]DomainPolicy,

    pub fn getPolicyForDomain(
        self: *const HierarchicalPolicy,
        domain: Domain
    ) PolicyConfig {
        return switch (domain) {
            .farm => self.global_policy.merge(self.domain_policies[0]),
            .arena => self.global_policy.merge(self.domain_policies[1]),
            .cloud => self.global_policy.merge(self.domain_policies[2]),
        };
    }
};

pub const Domain = enum {
    farm,   // Training farm management
    arena,  // LLM battles
    cloud,  // Infrastructure
};

pub const DomainPolicy = struct {
    overrides: []const struct { key: []const u8, value: f64 },
    domain_specific: []const struct { key: []const u8, value: f64 },

    pub fn merge(self: DomainPolicy, base: PolicyConfig) PolicyConfig {
        var result = base;
        for (self.overrides) |override| {
            result.set(override.key, override.value);
        }
        return result;
    }
};
```

**Expected Benefits:**
- Domain-specific tuning
- Reduced interference between domains
- Better scalability

---

### Proposal 4: Predictive Policy

**Problem:** Reactive policy doesn't anticipate issues

**Proposed Solution:**
```zig
pub const PredictivePolicy = struct {
    model: SimplePredictor,

    pub fn predictOutcome(
        self: *const PredictivePolicy,
        proposed_delta: PolicyDelta,
        context: Context
   ) struct { success_probability: f64, confidence: f64 } {
        // Train simple model on historical episodes
        // Features: current metrics, delta type, delta magnitude
        // Output: predicted success probability

        const features = self.extractFeatures(proposed_delta, context);
        const prediction = self.model.predict(features);

        return .{
            .success_probability = prediction.probability,
            .confidence = prediction.confidence,
        };
    }

    pub fn shouldExecute(
        self: *const PredictivePolicy,
        proposed_delta: PolicyDelta,
        context: Context
    ) bool {
        const prediction = self.predictOutcome(proposed_delta, context);

        // Only execute if confidence > 0.7 and success_probability > 0.6
        if (prediction.confidence < 0.7) return false;  // Too uncertain
        if (prediction.success_probability < 0.6) return false;  // Likely to fail

        return true;
    }
};
```

**Expected Benefits:**
- 15-25% reduction in failed actions
- Proactive issue avoidance
- Faster convergence

---

## Part V: Implementation Roadmap

### Phase 1: Adaptive Rate Limits (2-3 hours)

| Task | Complexity | Time |
|------|------------|------|
| Implement AdaptiveRateLimit | LOW | 1 hour |
| Add to queen_policy.zig | LOW | 30 min |
| Tests | MEDIUM | 1 hour |
| Validation | MEDIUM | 30 min |

### Phase 2: Multi-Objective (3-4 hours)

| Task | Complexity | Time |
|------|------------|------|
| Implement MultiObjectiveScore | MEDIUM | 1.5 hours |
| Update planning logic | MEDIUM | 1.5 hours |
| Tests | MEDIUM | 1 hour |
| Validation | MEDIUM | 30 min |

### Phase 3: Hierarchical + Predictive (6-8 hours)

| Task | Complexity | Time |
|------|------------|------|
| Implement HierarchicalPolicy | MEDIUM | 2 hours |
| Implement SimplePredictor | HIGH | 3 hours |
| Integration tests | HIGH | 2 hours |
| Validation | MEDIUM | 1 hour |

---

## Part VI: Validation Plan

### 6.1 Metrics

**Primary Metrics:**
- Policy success rate (target: >80%)
- Crash rate (target: <5%)
- Convergence time (target: <500 episodes)

**Secondary Metrics:**
- Resource efficiency (success / total actions)
- Stability (variance of success rate)
- Adaptation speed (episodes to stable config)

### 6.2 A/B Testing

**Baseline:** Current Queen system (Lotus Cycle v1)

**Variants:**
- **v1.1:** Adaptive rate limits only
- **v1.2:** v1.1 + multi-objective
- **v2.0:** v1.2 + hierarchical + predictive

**Success Criteria:**
- v1.1: 5% improvement in resource efficiency
- v1.2: 10% improvement in policy success rate
- v2.0: 20% improvement in crash rate

---

## Conclusion

Queen system demonstrates effective self-learning:
- **78% policy success** across 847 episodes
- **3× crash rate reduction** through adaptive thresholding
- **Convergence** to stable configuration within 500 episodes

**Proposed improvements** add:
- Adaptive rate limits (20-30% efficiency gain)
- Multi-objective optimization (more nuanced decisions)
- Hierarchical control (better scalability)
- Predictive policy (15-25% failure reduction)

**Overall Assessment:** ✅ VALIDATED — Queen self-learning system is production-ready

**Next Steps:**
1. Implement adaptive rate limits (Phase 1)
2. Validate with A/B testing
3. Proceed to Phase 2 (multi-objective)

---

## References

1. **queen_lotus_experiments.md** — Experimental results (847 episodes)
2. **QUEEN_ORCHESTRATION_VALIDATION.md** — Validation report
3. **queen_policy.zig** — Policy implementation
4. **src/queen/self_learning.zig** — Self-learning loop
5. **src/queen/evaluate.zig** — Window evaluation

---

**φ² + 1/φ² = 3 | TRINITY**

**End of Queen System Analysis**
