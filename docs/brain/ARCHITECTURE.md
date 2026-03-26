# Trinity S³AI Brain Architecture

> **Wave 1 Complete** — Full neuroanatomical system with 6 PFC cells

---

## System Overview

Trinity S³AI Brain is a neuroanatomically-inspired AI system modeled after primate prefrontal cortex (PFC) architecture. It implements self-learning through the **Lotus Cycle** purification mechanism, with real-time **ARAS** vigilance scanning.

### Key Properties

| Property | Value |
|----------|-------|
| **Cell Count** | 6 PFC cells |
| **State Machine** | Lotus Cycle (5 states) |
| **Learning Mode** | Closed feedback loop |
| **Vigilance** | 5-minute ARAS sweeps |
| **Memory Model** | Vector Symbolic Architecture (VSA) |
| **Math Foundation** | φ² + 1/φ² = 3 (Trinity Identity) |

---

## Queen Prefrontal Cortex

The Queen module implements 6 specialized PFC (Prefrontal Cortex) cells, each with distinct cognitive functions:

### Cell Types

| Cell | ID | Full Name | Cognitive Function |
|------|---|----------|--------------|
| **dlpfc** | Dorsolateral PFC | Planning & task assignment — Episode orchestration |
| **vmpfc** | Ventromedial PFC | Valuation & φ-weighted scoring — Value judgment |
| **ofc** | Orbitofrontal Cortex | Mood inference & alerts — Emotional state |
| **vlpfc** | Ventrolateral PFC | Focus area filtering — Attention control |
| **dmpfc** | Dorsomedial PFC | Self-check & health grading — Meta-cognition |
| **acc** | Anterior Cingulate | Conflict detection — Error monitoring |

---

### dlpfc — Dorsolateral PFC

**Function**: Planning & task assignment — Episode orchestration

**Inputs**:
- Current episode state
- Episode queue
- Senses (other modules)

**Operations**:
- Generate task plans
- Assign to queues
- Orchestrate execution across Queen modules

**Integration**:
- Reads from `policy.json` — kill_threshold, crash_rate_limit, byzantine_rate_limit
- Reads from `senses.json` — farm_best_ppl, test_rate, dirty_files
- Writes to episodes.jsonl — Episode tracking

---

### vmpfc — Ventromedial PFC

**Function**: Valuation & φ-weighted scoring — Value judgment

**Inputs**:
- Task descriptions
- Context embeddings
- Historical performance data

**Operations**:
- φ-weighted scoring of options
- Compute confidence intervals
- Value ranking

**Output**:
- φ scores (0-1 range)
- Confidence scores
- Ranked recommendations

**Integration**:
- Reads from Queen Episodes
- Contributes to episode evaluation

---

### ofc — Orbitofrontal Cortex

**Function**: Mood inference & alerts — Emotional state

**Inputs**:
- Current situation (health, threats, goals)
- Task context
- Environmental factors

**Operations**:
- Emotion classification
- Alert generation
- Mood state transitions

**Output**:
- Current mood (e.g., ALERTED, CONFIDENT, ANXIOUS)
- Alert triggers
- Mood color codes

**Integration**:
- Reads from vmpfc outputs
- Triggers Queen responses based on mood
- Logs mood events to episodes.jsonl

---

### vlpfc — Ventrolateral PFC

**Function**: Focus area filtering — Attention control

**Inputs**:
- Current task context
- Environmental factors
- Attention budget

**Operations**:
- Filter stimuli based on salience
- Compute attention weights
- Generate focus targets

**Output**:
- Focus maps
- Attention allocations
- Mask patterns

**Integration**:
- Modulates sensory inputs
- Provides filtered context to other modules

---

### dmpfc — Dorsomedial PFC

**Function**: Self-check & health grading — Meta-cognition

**Inputs**:
- Self-performance metrics
- Task outcomes
- Health indicators

**Operations**:
- Health score computation (weighted average)
- Grade classification (GOOD, STABLE, UNSTABLE, BAD)
- Generate self-improvement goals
- Trigger corrective actions

**Output**:
- Health grade (0-1 scale)
- Component scores
- Meta-cognition events

**Integration**:
- Reads from Queen Episodes
- Implements grade feedback loop
- Triggers remediation based on grades

---

### acc — Anterior Cingulate

**Function**: Conflict detection — Error monitoring

**Inputs**:
- Queen logs
- Episode histories
- Action sequences

**Operations**:
- Pattern analysis
- Conflict detection
- Error attribution
- Alert generation

**Output**:
- Conflict probability
- Error classification
- Recommended actions

**Integration**:
- Monitors all Queen operations
- Logs conflicts to episodes.jsonl
- Provides real-time alerts

---

## Lotus Cycle

**5-State Purification** — From raw task to purified action

**States**:
1. **Queued** — Task waiting in queue
2. **Diagnosing** — Analyzing task requirements
3. **Refining** — Executing purification
4. **Verifying** — Checking results
5. **Purified** — Task complete
6. **Blocked** — Error — needs intervention

**Flow**:
```
Input Episode → Diagnosing → Refining → Verifying → Purified (success) or Blocked (failure)
```

**Phase 1: Observe**
- **File**: `src/tri/queen/observe.zig`
- **Reads**: `policy.json`, `senses.json`
- **Outputs**: Episode queue, current states

**Phase 2: Plan**
- **File**: `src/tri/queen/plan.zig`
- **Input**: Episode queue, historical performance
- **Output**: `PolicyDelta[]` — scale_up, scale_down, set, wait

**Phase 3: Evaluate**
- **File**: `src/tri/queen/evaluate.zig`
- **Input**: Episode, PolicyDelta
- **Output**: WindowEvaluation — good, unstable, bad, unknown

**Phase 4: Act**
- **File**: `src/tri/queen/act.zig`
- **Input**: WindowEvaluation, Tri27Config
- **Output**: Executed action

**Phase 5: Self-Learning**
- **File**: `src/tri/queen/self_learning.zig`
- **Closed Loop**:
  ```
  Episodes → episodes.jsonl
    → loadRecentEpisodes(20)
    → evaluateWindow() → WindowEvaluation
    → generatePlan() → PolicyDelta[]
    → applyPolicyDelta() → Tri27Config
    → saveConfig() → tri27_config.json
    → Episode about self-learning_cycle
  ```
- **Tri27Config**:
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

---

## ARAS Vigilance

**5-Minute Sweep** — Continuous health and threat scanning

**Monitored Dimensions** (12 total):
1. `dlpfc.health` — Planning quality
2. `vmpfc.confidence` — Scoring accuracy
3. `ofc.stability` — Mental state consistency
4. `vlpfc.focus` — Attention stability
5. `dlpfc.decision_speed` — Choice latency
6. `vlpfc.salience` — Stimulus filtering
7. `dmpfc.health` — Self-assessment
8. `dmpfc.decision_speed` — Self-correction
9. `ofc.conflict_rate` — Error frequency
10. `ofc.stability` — State coherence
11. `acc.conflict_prob` — Conflict probability
12. `tri27.errors` — Execution errors

**Alert Thresholds**:
- **Critical**: Immediate action required
- **Warning**: Monitor closely
- **Normal**: Continued observation

**Integration**:
- Real-time monitoring of all PFC outputs
- Triggers Queen responses to alerts
- Logs health events to episodes.jsonl

---

## TRI Cognitive System

**Integration**: TRI-27 ↔ Queen (Episode tracking)

**Memory Model**: Vector Symbolic Architecture (VSA)
- Bind/unbind operations for associative memory
- Bundle operations for consensus

**Files**:
- `src/tri27/coptic.zig` — Coptic register mapping
- `src/tri27/episode.zig` — Episode tracking interface

---

## Health Scoring

**Formula**:
```
health = 0.4 × dlPFC.health
       + 0.3 × vmpfc.confidence
       + 0.2 × ofc.stability
       + 0.1 × vlpfc.focus
       - 0.05 × dmpfc.decision_speed
       - 0.05 × dmpfc.health
       - 0.05 × dmpfc.decision_speed
       - 0.05 × ofc.conflict_rate
       - 0.1 × ofc.stability
       - 0.1 × acc.conflict_prob
       - 0.1 × tri27.errors
```

**Grade Classifications**:
- **90-100**: HEALTHY
- **70-89**: RECOVERING
- **50-69**: INFECTED
- **0-49**: CRITICAL

**Evaluation Criteria**:
- **good**: success_rate ≥ 95%
- **stable**: 70% < success_rate < 95%
- **bad**: success_rate ≤ 70%
- **unknown**: No data

---

## Interconnections

**PFC → VSA**: Episode tracking
**PFC → OFC**: Mood → Conflict monitoring
**VSA → TRI-27**: Bind operations for task context
**Queen ↔ OFC**: Error logging, self-correction triggers

**Files**:
- `.trinity/queen/policy.json` — Queen configuration
- `.trinity/queen/senses.json` — Sensory inputs
- `.trinity/queen/episodes.jsonl` — Episode history

---

## References

- **Implementation**: `src/tri/queen/observe.zig`, `src/tri/queen/plan.zig`, `src/tri/queen/evaluate.zig`, `src/tri/queen/act.zig`, `src/tri/queen/self_learning.zig`
- **TRI-27 Integration**: `src/tri27/coptic.zig`, `src/tri27/episode.zig`
