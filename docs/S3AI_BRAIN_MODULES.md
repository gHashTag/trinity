# S³AI Brain Modules

Trinity Self-Supervised Symbolic AI — autonomous cognitive system with 10 brain modules.

## Overview

S³AI implements a biologically-inspired cognitive architecture using Vector Symbolic Architecture (VSA)
and ternary computation {-1, 0, +1} for efficient reasoning.

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     Sensory Processing                        │
│                    ┌──────────────┐                          │
│                    │  HPC (HPC)  │                          │
│                    └──────┬───────┘                          │
│                           │                                  │
│                  ┌────────▼────────┐                           │
│                  │ Thalamus         │ ←──► ACC (Anterior    │
│         ┌────────►│  Hippocampus      │     Cingulate)     │
│         │          └──────┬───────┘     │     │             │
│         │                 │                │     │             │
│         │          ┌────────▼────────┐        │     │             │
│         │          │ Amygdala         │     │             │
│         │          │ Basal Ganglia    │     │             │
│         │          │ DLPFC             │     │             │
│         │          │ PCC               │     │             │
│         │          │ OFC               │     │             │
│         │          └──────┬───────────┘        │             │
│         │                 │                │     │             │
│         │          ┌────────▼────────┐        │     │             │
│         │          │ Insula            │     │             │
│         │          └──────┬───────────┘        │             │
│         │                 │                │     │             │
│         │          ┌────────▼────────┐        │     │             │
│         │          │ Queen Motor        │     │             │
│         │          │ Hypothalamus      │     │             │
│         │          └──────┬───────────┘        │             │
│         │                 │                │     │             │
│         │          ┌────────▼────────┐        │     │             │
│         │          │ Queen Telegraph    │     │             │
│         │          └──────┬───────────┘        │             │
│         │                 │                │     │             │
│         └─────────────────────────────────────────────────┘              │
└─────────────────────────────────────────────────────────────────────────┘
```

## Brain Modules

### 1. Insula (37 tests, 750 LOC)

**Location**: `src/tri/insula.zig`

**Function**: Internal state monitoring and metabolic regulation

- **TimingSnapshot**: Capture timing at different cognitive phases
- **measureState()**: Compute internal metrics (latency, alloc, action rate)
- **health()**: Return cell health status
- **CellHealth**: Track cycle count, last check, status

```zig
const state = try insula.measureState(allocator, cycle_start, &timing,
    actions_taken, actions_suppressed, total_cycles);
```

### 2. Amygdala (127 tests, 3000 LOC)

**Location**: `src/tri/amygdala.zig`

**Function**: Emotional processing and fear conditioning

- **Emotion**: Basic emotion types (fear, reward, neutral, anger, joy)
- **Valence**: -100 to +100 intensity scale
- **FearMemory**: One-shot fear learning from aversive events
- **shouldAvoid()**: Check if action should be avoided based on fear associations
- **modulateMood()**: Adjust OFC mood based on emotional context

```zig
const valence = amygdala.Valence.fear(85);
if (amygdala.shouldAvoid(&action_candidate, allocator)) {
    // Suppress this action
}
```

### 3. Basal Ganglia (74 tests, 1500 LOC)

**Location**: `src/tri/basal_ganglia.zig`

**Function**: Action selection and impulse suppression

- **ActionCandidate**: Potential actions with urgency, value, cost, suppression
- **ActionKind**: Read-only vs Soft Write vs Dangerous actions
- **selectAction()**: Choose best action from candidates
- **conflictDetect()**: Find conflicting actions
- **Urgency**: critical, high, normal, low

```zig
const selected = basal_ganglia.selectAction(&candidates);
if (selected.suppressed) {
    // Action was suppressed
}
```

### 4. Hippocampus (81 tests, 2500 LOC)

**Location**: `src/tri/hippocampus.zig`

**Function**: Memory formation, consolidation, and retrieval

- **MemoryRecord**: Store observations, episodes, with tags
- **MemoryKind**: observation, episode, goal, reflection
- **read()**: Query memory by kind, tag filter, limit
- **consolidate()**: Replay episodes for learning
- **generateId()**: Create unique IDs for records

```zig
const memories = try hippocampus.read(allocator, .{
    .kind_filter = "emo:fear",
    .limit = 50,
});
```

### 5. Hypothalamus (6 tests, 350 LOC)

**Location**: `src/tri/hypothalamus.zig`

**Function**: Homeostatic regulation and command orchestration

- **CommandRegistry**: 130+ commands with categories
- **CommandMetadata**: Name, category, risk level, min/max args
- **registerAllCommands()**: Register all Trinity commands
- **checkPolicy()**: Verify if action is allowed (rate limit, cooldown, escalation)

```zig
var registry = try hypothalamus.registerAllCommands(allocator);
const verdict = hypothalamus.checkPolicy(action, config, counters, incidents);
```

### 6. Thalamus (275 tests, 4000 LOC)

**Location**: `src/tri/thalamus.zig`

**Function**: Sensory integration and signal routing

- **LocusCoeruleus**: Arousal level (sleep, idle, normal, alert, alarm, emergency)
- **MetabolismAlert**: Health alerts from hippocampus
- **getMetabolismAlerts()**: Fetch recent health warnings
- **parseHealthStat()**: Parse health metrics from data
- **detectConflicts()**: Find action conflicts
- **countEpisodes()**: Count memory consolidation episodes

```zig
const arousal = thalamus.getLocusArousal();
if (arousal == .alert) {
    // Activate DLPFC for immediate action
}
```

### 7. Queen ACC (Anterior Cingulate Cortex)

**Location**: `src/tri/queen_acc.zig`

**Function**: Conflict detection and cognitive control

- **ActionCounters**: Track action frequency and timing
- **ErrorMonitor**: Track errors by severity and threshold
- **detectConflicts()**: Find action conflicts
- **generateControlSignals()**: Generate control signals for actions
- **ActionLevel**: Read-only, Soft Write, Dangerous actions

```zig
const signals = try queen_acc.generateControlSignals(allocator, &candidates, &monitor);
```

### 8. Queen DLPFC (Dorsolateral Prefrontal Cortex)

**Location**: `src/tri/queen_dlpfc.zig`

**Function**: Decision making and planning

- **DecisionContext**: Current state, senses, goals, history
- **DecisionMaker**: Generate decisions based on context
- **evaluateOptions()**: Score action options
- **generatePlan()**: Create action plan
- **ActionKind**: Classification of actions

```zig
const decision = try queen_dlpfc.makeDecision(allocator, state);
```

### 9. Queen PCC (Posterior Cingulate Cortex)

**Location**: `src/tri/queen_pcc.zig`

**Function**: Self-awareness and consciousness simulation

- **SelfModel**: Identity, current state, capabilities, goals, learning state
- **ConsciousnessState**: Status, stuck duration, learning rate
- **diagnoseConsciousness()**: Analyze current state
- **describeSelf()**: Generate self-description
- **learnFromActionResult()**: Update model based on results

```zig
const consciousness = queen_pcc.diagnoseConsciousness(allocator, state);
```

### 10. Queen OFC (Orbitofrontal Cortex)

**Location**: `src/tri/queen_ofc.zig`

**Function**: Mood modulation and reward processing

- **Mood**: calm, focused, agitated, excited, tired
- **MoodManager**: Track mood changes and suggest actions
- **applyReward()**: Update mood based on reward/punishment
- **MoodTransition**: State transitions between moods

```zig
try queen_ofc.applyReward(allocator, .positive, 10);
```

## Integration

The brain modules communicate through shared structures:

1. **VSA Vectors**: All modules use `src/vsa.zig` for vector operations
2. **Ternary Computation**: {-1, 0, +1} for efficient VSA operations
3. **Hippocampus**: Shared memory accessed by all modules
4. **Command Registry**: Hypothalamus coordinates all actions

## Testing

Run brain module tests:

```bash
zig test src/tri/insula.zig
zig test src/tri/amygdala.zig
zig test src/tri/basal_ganglia.zig
zig test src/tri/hippocampus.zig
zig test src/tri/thalamus.zig
```

All modules: 600+ tests passing (100%)

## Performance

- SIMD acceleration: 14-17x speedup for VSA operations
- Ternary encoding: 1.58 bits/trit (20x compression vs float32)
- Memory pooling: Reuse allocations for hot paths
- Lazy evaluation: Defer computation until needed

## Running Tests

```bash
# Run all brain module tests
zig test src/tri/insula.zig
zig test src/tri/amygdala.zig
zig test src/tri/basal_ganglia.zig
zig test src/tri/hippocampus.zig
zig test src/tri/hypothalamus.zig
zig test src/tri/thalamus.zig
zig test src/tri/queen_actions.zig
zig test src/tri/queen_acc.zig
zig test src/tri/queen_dlpfc.zig
zig test src/tri/queen_pcc.zig
zig test src/tri/queen_policy.zig
```

```bash
# Run all S³AI tests
zig build test src/tri/insula.zig src/tri/amygdala.zig \
  src/tri/basal_ganglia.zig src/tri/hippocampus.zig \
  src/tri/hypothalamus.zig src/tri/thalamus.zig
```

## Performance Benchmarking

```bash
# Run performance benchmarks
zig test src/tri/perf_benchmark.zig

# Benchmark VSA operations
zig test src/vsa.zig -fnsimd-test
```

## Future Work

1. **Neural Symbol Grounding**: Map symbols to VSA vectors
2. **Temporal Sequences**: Add sequence prediction to hippocampus
3. **Attention Mechanism**: Implement attention-based selection
4. **Meta-Learning**: Learn how to learn efficiently
5. **Memory Consolidation**: Implement sleep-wake cycle for hippocampus
6. **Emotional Regulation**: Add mood state machine to amygdala
7. **Action Selection**: Improve conflict resolution in basal ganglia
8. **Planning**: Add multi-step planning to DLPFC

## References

- VSA Spec: `specs/tri/vsa.tri`
- HSLM Training: `src/hslm/`
- FPGA Synthesis: `fpga/openxc7-synth/`
- This Doc: `docs/S3AI_BRAIN_MODULES.md`
