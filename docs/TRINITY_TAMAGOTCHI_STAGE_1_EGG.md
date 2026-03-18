# TRINITY Tamagotchi — Stage 1: EGG (0-10 minutes)

> "Just a speck of potential. Will it hatch?"

## Overview

| Attribute | Value |
|-----------|-------|
| **Emoji** | [EGG] |
| **Age Range** | 0-10 minutes |
| **Primary Focus** | Infrastructure validation, basic heartbeat |
| **Next Stage** | Baby (after successful first cycle) |

## Stage Description

The Egg stage is the most fragile moment in Queen's life. Before hatching, the daemon must prove it can execute even a single cycle without errors. This is the "hello world" phase — if `tri queen once` fails, the egg never hatches.

## Success Criteria Checklist

```zig
// Egg hatch requirements
const EggRequirements = struct {
    heartbeat_ok: bool = false,        // .trinity/queen/heartbeat.json created
    state_persisted: bool = false,     // .trinity/queen_state.json valid
    build_ok: bool = false,            // zig build succeeds
    no_crash: bool = false,            // process exits cleanly
};
```

- [ ] `tri queen once` executes without panic
- [ ] Heartbeat file created at `.trinity/queen/heartbeat.json`
- [ ] State file created at `.trinity/queen_state.json`
- [ ] All 12 senses collected successfully
- [ ] Zero error messages in stdout/stderr
- [ ] Exit code 0

## Key Metrics to Track

| Metric | Target | How to Measure |
|--------|--------|----------------|
| First heartbeat latency | < 5 seconds | `jq -r .last_heartbeat .trinity/queen/heartbeat.json` |
| State file size | ~200-500 bytes | `ls -l .trinity/queen_state.json` |
| Sense collection rate | 12/12 collected | Count non-null fields in output |
| Memory usage | < 10 MB RSS | `/usr/bin/time -l tri queen once` |

## Expected Behaviors

```
[EGG] Queen v4 — First Breath
========================================
Cycle: 1 | Stage: EGG | Time: 2026-03-19 12:00:00

Collecting senses...
  [OK] Build status
  [OK] Test coverage
  [OK] Git dirty count
  [OK] Open issues
  [OK] Agent count
  [OK] Farm services
  [OK] Best PPL
  [OK] Arena battles
  [OK] Ouroboros score
  [OK] Disk free
  [OK] Keys present
  [OK] Experience count

Heartbeat written to .trinity/queen/heartbeat.json
State saved to .trinity/queen_state.json

EGG HATCHED! Welcome to life, Queen.
Next: Run `tri queen start --daemon` for Baby stage.
```

## What's Happening Under the Hood

### 1. Brain Modules Loading
```zig
// Phase 1: Cortex initialization
const cortex = faculty_board.snapshot();

// Phase 2: Brainstem (Medulla, Pons) comes online
const heartbeat = queen_heartbeat.record();
```

### 2. Sense Collection (12 parallel reads)
```zig
const senses = queen_senses.collectAllSenses(allocator, cortex);
// Reads: build, tests, git, issues, agents, farm, arena, disk, keys...
```

### 3. State Persistence
```zig
// First heartbeat creates lifecycle file
queen_state.cycle = 1;
queen_state.last_heartbeat = now;
// Persisted to .trinity/queen_state.json
```

## Troubleshooting

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| "build failed" | zig build errors | Run `zig build` first, check Zig 0.15.x |
| "heartbeat.json not found" | Permission error | `mkdir -p .trinity/queen && chmod 755 .trinity` |
| "sense collection timeout" | Stuck subprocess | Check `df`, `gh` CLI availability |
| Exit code 1 | Panic in code | Run with `--debug` flag, check audit log |

## Transition to Baby Stage

**Trigger:** First successful `tri queen once` completion

**Baby unlocks:**
- Telegram integration (heartbeat reports)
- First daemon mode attempt
- 5-minute cycle intervals
- Basic auto-actions (doctor_quick only)

**Command to transition:**
```bash
tri queen start --daemon --interval 300
```

## Fun Facts

- The Egg stage has the lowest success rate (~60% on fresh clones)
- Most failures are due to missing `gh` CLI or expired tokens
- The heartbeat file format hasn't changed since v1 (backward compatible!)
- Egg stage is named after the literal "egg" in Tamagotchi — you have to wait for it to hatch
- The 10-minute window is arbitrary; a healthy Queen can hatch in 30 seconds

## Code Locations

| Component | File | Lines |
|-----------|------|-------|
| Main entry | `src/tri/queen.zig` | ~400 |
| Types | `src/tri/queen_types.zig` | ~550 |
| Senses | `src/tri/queen_senses.zig` | ~500 |
| Heartbeat | `src/tri/queen_heartbeat.zig` | ~200 |

---

**Next Stage:** [Baby](./TRINITY_TAMAGOTCHI_STAGE_2_BABY.md) — First words, first Telegram message!

*phi^2 + 1/phi^2 = 3 = TRINITY*
