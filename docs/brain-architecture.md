# Trinity S³AI Brain Architecture

## Module Overview (1:1 Brain Mapping)

| Brain Structure | Trinity Module | Function |
|----------------|----------------|-----------|
| Thalamus | `thalamus.zig` | Sensor gateway — filters & routes incoming signals |
| VLPFC | `queen_vlpfc.zig` | Pattern recognition — familiar situations |
| DLPFC | `queen_dlpfc.zig` | Decision engine — selects actions |
| VMPFC | `queen_vmpfc.zig` | Value assessment — weighs options |
| DMPFC/ACC | `queen_acc.zig` | Conflict monitoring — detects action conflicts |
| OFC | `queen_ofc.zig` | Mood modulation — adjusts urgency |
| Motor Cortex | `queen_motor.zig` | Action execution — runs tri commands |
| Hippocampus | `hippocampus.zig` | Memory — stores/retrieves learning |
| Amygdala | `amygdala.zig` | Emotional learning — fear/reward |
| Basal Ganglia | `basal_ganglia.zig` | Action selection — winner-takes-all |
| **Insula** | `insula.zig` | **Interoception — internal state monitoring** |
| Locus Coeruleus | `phoenix_locus_coeruleus.zig` | Arousal/alert system |
| Reticular Formation | `reticular_*.zig` | Sleep/wake, arousal modulation |
| Phoenix Core | `phoenix_core.zig` | Sleep-wake daemon, issue processing |
| Cerebellum | `cerebellum.zig` | Timing, error correction |
 | Thalamus Relays | `thalamus.zig` | 18 sensory channels (farm, build, arena, etc.) |

## Complete Signal Flow

```
External World
    ↓
Thalamus (18 senses → filtered signals)
    ↓
VLPFC (pattern match: "have I seen this?")
    ↓
DLPFC (decide: "what action?")
    ↓
VMPFC (value: "is this worth it?")
    ↓
DMPFC/ACC (conflict check: "can these run together?")
    ↓
OFC (modulate: "how urgent?")
    ↓
Basal Ganglia (select winner)
    ↓
Motor Cortex (execute → tri command)
    ↓
Hippocampus (remember: "what happened?")
    ↓
Insula (measure: "how am I doing?") ← NEW
    ↓
Locus Coeruleus (alert: "should I wake up?")
```

## Insula Module — Interoception

### What is Interoception?

In neuroscience, the **insula cortex** monitors internal body states:
- Pulse (heart rate)
- Temperature (fever, chills)
- Fatigue (tiredness)
- Hunger/satiety
- Pain/pleasure

For Trinity, this means monitoring **internal system metrics**:
- Cycle latency (how fast am I thinking?)
- Memory usage (how much RAM am I using?)
- Action rate (how active am I?)
- Decision quality (am I making good choices?)

### Insula Data Structure

```zig
pub const InternalState = struct {
    // Timing (microseconds)
    cycle_latency_us: u64,
    thalamus_latency_us: u64,
    dlpfc_decision_us: u64,

    // Memory
    alloc_bytes: u64,
    alloc_count: u32,

    // Activity
    actions_taken: u32,
    actions_suppressed: u32,

    // Decision quality
    action_rate: f32,  // % of cycles with action

    // Timestamp
    measured_at: i64,
};
```

### Insula → Locus Coeruleus Integration

The Locus Coeruleus reads Insula metrics to adjust arousal:

```zig
pub fn evaluateInteroception(state: insula.InternalState) ArousalLevel {
    if (state.cycle_latency_us > 300_000) {  // >300ms
        return .alarm;     // "Too slow!"
    }
    if (state.alloc_bytes > 75_000_000) {    // >75MB
        return .emergency; // "Memory pressure!"
    }
    if (state.action_rate < 0.05) {           // <5%
        return .sleep;     // "Inactive"
    }
    return .alert;       // Normal monitoring
}
```

### Alert Thresholds

| Metric | Threshold | Response |
|--------|-----------|----------|
| Cycle latency | >300ms | ALARM — system is sluggish |
| Memory usage | >75MB | EMERGENCY — leak detected |
| Action rate | <5% | SLEEP — inactive mode |
| Decision time | >100ms | ALERT — slowing down |

## Running Queen

### One-Shot Cycle

```bash
# Single READ → THINK → ACT → SPEAK cycle
tri queen once
```

Output:
```
👑 Queen NORMAL — Cycle #42

🧬 Farm: 45/108 active, PPL 4.6 (R33)
🧠 Build: OK | Wake #1524
🔧 Action: farm status (Routine check)
  Result: OK (245ms)
```

### Daemon Mode (5-min cycles)

```bash
# Run continuously, sleeping 5 minutes between cycles
tri queen start --daemon --interval 300
```

### Auto-Actions (L2 allowed)

```bash
# Enable autonomous healing (dangerous actions need approval)
tri queen start --daemon --allow-auto-actions --max-level 2
```

### Check Status

```bash
# Show current Queen state
tri queen status
```

## Auto-Healing Scenario

When `--allow-auto-actions` is enabled, Queen can self-heal:

```
Cycle #1: Build broken → doctor_quick (auto-approved, L1)
  → Fixed 3 dirty files

Cycle #2: Farm crashed >3 workers → farm_recycle (needs approval, L2)
  → User approves via /queen approve
  → Recycled 5 idle workers

Cycle #3: PPL record (4.6 → 4.2) → notify (celebration)
  → Telegram: 🏆 NEW PPL RECORD: 4.2
```

## Data Collection (Phase 4)

**Before optimizing**, collect metrics for 1-2 weeks:

```bash
# Start daemon with Insula monitoring
tri queen start --daemon --interval 300

# Wait 2 weeks, then analyze:
cat .trinity/memory/insula/current.jsonl | jq -s '
  group_by(.measured_at | strftime("%Y-%m-%d")) |
  map({
    date: .[0].measured_at,
    avg_latency: map(.cycle_latency_us) | add / length
  })
'
```

**Only after data collection** can we optimize:
- Thalamus cache (if sensory latency is high)
- Hippocampus rotation (if memory is bloating)
- Decision batching (if action rate is low)

## φ² + 1/φ² = 3 = TRINITY = S³AI

The brain architecture embodies the Trinity identity:
- **3 input pathways** — Thalamus (18 senses), VLPFC (patterns), Hippocampus (memory)
- **3 decision layers** — VMPFC (value), ACC (conflict), DLPFC (choice)
- **3 output channels** — Motor (actions), OFC (mood), LC (arousal)

## References

- Module files: `src/tri/queen_*.zig`, `src/tri/insula.zig`, `src/tri/hippocampus.zig`
- Type definitions: `src/tri/queen_types.zig`, `src/tri/faculty_types.zig`
- Locus Coeruleus: `src/tri/phoenix_locus_coeruleus.zig`
- Testing: Each module file has inline tests at the bottom
