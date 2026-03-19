# Trinity S³AI Brain Architecture

## Overview

Trinity's brain is a modular architecture inspired by biological neural systems. The brain consists of interconnected modules that process sensory input, make decisions, execute actions, and learn from experience.

## Module Hierarchy

```
                    ┌─────────────────────────────────────────────┐
                    │              QUEEN (Coordinator)           │
                    │         (queen_premotor, queen_vlpfc)      │
                    └───────────────────┬─────────────────────────┘
                                        │
        ┌───────────────────────────────┼───────────────────────────────┐
        │                               │                               │
        ▼                               ▼                               ▼
┌───────────────┐             ┌───────────────┐             ┌───────────────┐
│   SENSES      │             │     ACC      │             │    DLPFC      │
│ (queen_senses)│             │ (queen_acc)  │             │(queen_dlpfc)  │
│               │             │              │             │               │
│ 18 system     │             │ Conflict     │             │ Decision      │
│ monitors      │             │ Detection    │             │ Loop          │
└───────┬───────┘             └───────┬───────┘             └───────┬───────┘
        │                           │                               │
        │                           │                               │
        ▼                           ▼                               ▼
┌───────────────┐             ┌───────────────┐             ┌───────────────┐
│  HIPPOCAMPUS  │             │  OFC         │             │    MOTOR      │
│(hippocampus)  │             │(queen_ofc)   │             │(queen_motor)  │
│               │             │              │             │               │
│ Memory        │             │ Mood         │             │ Action        │
│ Storage       │             │ Inference    │             │ Execution     │
└───────────────┘             └───────────────┘             └───────────────┘
        │                           │                               │
        │                           │                               │
        ▼                           ▼                               ▼
┌───────────────┐             ┌───────────────┐             ┌───────────────┐
│ BASAL GANGLIA │             │   TELEGRAM    │             │    POLICY     │
│(basal_ganglia)│             │(queen_telegram)│             │(queen_policy) │
│               │             │              │             │               │
│ Action        │             │ Communication │             │ Rules         │
│ Selection     │             │ Channel      │             │ Engine        │
└───────────────┘             └───────────────┘             └───────────────┘
```

## Module Descriptions

### Core Modules

| Module | File | Purpose |
|--------|------|---------|
| **Queen** | `queen_premotor.zig` | Central coordinator, integrates all brain modules |
| **Senses** | `queen_senses.zig` | Aggregates 18 system monitors (build, tests, farm, etc.) |
| **ACC** | `queen_acc.zig` | Anterior Cingulate Cortex — conflict monitoring |
| **DLPFC** | `queen_dlpfc.zig` | Dorsolateral Prefrontal Cortex — decision loop |
| **OFC** | `queen_ofc.zig` | Orbitofrontal Cortex — mood inference, reward prediction |
| **Motor** | `queen_motor.zig` | Action execution, Telegram routing |

### Memory & Learning

| Module | File | Purpose |
|--------|------|---------|
| **Hippocampus** | `hippocampus.zig` | JSONL memory store, pattern storage/retrieval |
| **Policy** | `queen_policy.zig` | Rule engine, behavior constraints |
| **Tamagotchi** | `queen_tamagotchi.zig` | Self-care, health maintenance |

### Communication

| Module | File | Purpose |
|--------|------|---------|
| **Telegram** | `queen_telegram.zig` | Telegram bot interface, message formatting |
| **Cron** | `queen_cron.zig` | Scheduled tasks, heartbeat monitoring |

## Data Flow

### 1. Sensory Input Flow

```
External System → Senses (18 monitors)
                  ↓
              FacultySnapshot
                  ↓
              collectAllSenses()
                  ↓
              SenseResult
```

### 2. Decision Loop (DLPFC → ACC → Motor)

```
SenseResult → DLPFC (analyze)
                ↓
              ACC (check conflicts)
                ↓
          Motor (select action)
                ↓
            Execute
```

### 3. Memory Flow

```
Event → Hippocampus.write()
         ↓
      JSONL append
         ↓
    MemoryRecord (agent, kind, data, tags)
         ↓
      hippocampus.read()
```

### 4. Communication Flow

```
Event → OFC (mood inference)
         ↓
      sendReport() → Telegram
```

## Inter-Module Communication

### Event-Based Communication

Modules communicate through:
1. **Direct function calls** — For tightly coupled modules
2. **JSONL memory** — For persistent event logging
3. **Telegram messages** — For external notifications

### Key Data Structures

```zig
// Sense result — 18 system metrics
SenseResult {
    build_ok: bool,
    test_rate: u8,
    dirty_files: u16,
    open_issues: u16,
    agent_count: u8,
    farm_services: u8,
    farm_best_ppl: f32,
    arena_battles: u32,
    ouroboros_score: f32,
    // ... 9 more fields
}

// Memory record — persistent storage
MemoryRecord {
    id: []const u8,
    agent: []const u8,
    kind: MemoryKind,
    ts: u64,
    tags: [8][]const u8,
    data: []const u8,
    summary: []const u8,
    ttl: u64,
}

// Action candidate — decision making
ActionCandidate {
    kind: ActionKind,
    urgency: Urgency,
    suppressed: bool,
    confidence: f32,
}
```

## Testing Guidelines

### Unit Test Structure

Each brain module should have tests covering:
1. **Default values** — Struct initialization
2. **Edge cases** — Empty, zero, maximum values
3. **Enum values** — All variants tested
4. **Format functions** — String serialization
5. **Integration points** — File I/O, external calls

### Test Coverage Targets

| Module | Target Coverage | Current |
|--------|----------------|---------|
| hippocampus | 7% | 4.8% |
| queen_senses | 8% | 10.2% ✅ |
| queen_acc | 8% | 4.8% |
| queen_ofc | 8% | 4.8% |

### Running Tests

```bash
# Test all brain modules
zig test src/tri/hippocampus.zig
zig test src/tri/queen_senses.zig
zig test src/tri/queen_acc.zig
zig test src/tri/queen_ofc.zig

# Test all at once
zig build test
```

## Performance Considerations

### Hot Paths

1. **DLPFC decision loop** — Called every cycle, optimize for speed
2. **Hippocampus JSONL parsing** — I/O heavy, batch when possible
3. **Telegram message handling** — Network bound, use async

### Optimization Targets

- Minimize allocations in decision loop
- Use fixed buffers where size is known
- Batch memory operations
- Cache expensive computations (e.g., file reads)

## φ² + 1/φ² = 3 = TRINITY

The brain architecture embodies the Trinity identity through:
- **3-layer hierarchy** — Senses → Decisions → Actions
- **3 memory tiers** — Working, episodic, semantic
- **3 control loops** — Fast (reflex), medium (deliberation), slow (planning)

## References

- Module files: `src/tri/queen_*.zig`, `src/tri/hippocampus.zig`
- Type definitions: `src/tri/queen_types.zig`, `src/tri/faculty_types.zig`
- Testing: Each module file has inline tests at the bottom
