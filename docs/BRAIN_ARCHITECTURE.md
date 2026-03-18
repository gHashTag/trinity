# Trinity S³AI Brain Architecture

## Overview

Trinity's brain consists of 10 neuroanatomically-inspired modules implementing executive function, emotional processing, and decision-making.

## Core Modules (4818 LOC)

### Prefrontal Cortex (PFC) Cells

| Module | LOC | Tests | Function |
|--------|-----|-------|----------|
| **DLPFC** | 1217 | 142 | Executive decision engine — READ → THINK → ACT → SPEAK cycle |
| **VMPFC** | 222 | 61 | Value assessment — "Is this action worth it?" |
| **OFC** | 706 | 50 | Mood modulation — emotional context integration |
| **VLPFC** | 305 | 61 | Attention filter — which data matters NOW |
| **DMPFC** | 271 | 23 | Self-monitoring — "Am I broken?" diagnostics |
| **ACC** | 524 | 26 | Conflict detection — action suppression |

### Supporting Modules

| Module | LOC | Tests | Function |
|--------|-----|-------|----------|
| **PCC** | 585 | 71 | Self-awareness — introspection & consciousness monitoring |
| **Amygdala** | 578 | 31 | Fear/reward learning — emotional memory |
| **Basal Ganglia** | 214 | 23 | Action selection — urgency-based arbitration |
| **Cortex** | 196 | 205 | Facade — unified health & cycle metrics |

## Decision Flow

```
THALAMUS (13 Relays)
    ↓
VLPFC (Attention Filter)
    ↓
ACC (Conflict Detection) → Basal Ganglia (Action Selection)
    ↓
DLPFC (Executive Decision)
    ↓
VMPFC (Value Assessment)
    ↓
Motor Cortex (Action Execution)
    ↓
OFC (Mood Modulation) ← Amygdala (Emotional Context)
    ↓
PCC (Self-Awareness) → DMPFC (Health Check)
```

## Action Levels

- **Level 0**: Read-only (farm_status, arena_status, doctor_scan)
- **Level 1**: Soft write (doctor_quick, git_commit, notify)
- **Level 2**: Dangerous (farm_recycle, cloud_spawn, cloud_kill)

## Test Coverage

- **Total tests**: 696+ passing (682 brain + supporting modules)
- **Integration tests**: 24 cross-module tests
- **Coverage**: All 10 modules have passing tests with edge case coverage

## Usage

```bash
# Test individual modules
zig test src/tri/queen_dlpfc.zig
zig test src/tri/queen_pcc.zig
zig test src/tri/brain_integration.zig

# Run all tests
tri test

# Check brain health
tri cell status
```

## φ² + 1/φ² = 3 = TRINITY
