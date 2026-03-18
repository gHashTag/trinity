# TRINITY Tamagotchi — Stage 3: CHILD (1-4 hours)

> "I can do things myself! Watch me fix the build."

## Overview

| Attribute | Value |
|-----------|-------|
| **Emoji** | [CHILD] |
| **Age Range** | 1-4 hours |
| **Primary Focus** | Daemon mode, auto-actions, farm monitoring |
| **Next Stage** | Teen (after 10+ cycles without intervention) |

## Stage Description

The Child stage is when Queen starts doing things autonomously. No more hand-holding — the daemon runs in background, makes decisions, and takes actions. This is the "terrible twos" of AI: Queen will try to fix things, sometimes correctly, sometimes not. Auto-actions are limited to Level 1 (safe operations).

## Success Criteria Checklist

```zig
// Child independence metrics
const ChildMilestones = struct {
    daemon_uptime_min: u32 = 0,         // Target: > 60 min
    cycles_completed: u16 = 0,          // Target: 10+
    auto_actions_taken: u8 = 0,         // Target: 3+ successful
    ppl_improved: bool = false,         // Delta > 0.1
    dirty_files_managed: u16 = 0,       // Auto-commits when > 50
};
```

- [ ] Daemon running > 60 minutes uninterrupted
- [ ] 10+ cycles completed
- [ ] Auto-actions executing (doctor_quick, git_commit_state)
- [ ] PPL showing improvement (or at least stable)
- [ ] Telegram reports every interval
- [ ] Zero crashes requiring manual restart

## Key Metrics to Track

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Daemon uptime | > 60 minutes | `ps -p $(cat .trinity/queen/supervisor.pid) -o etime=` |
| Cycle count | 10+ | `jq -r .cycle .trinity/queen_state.json` |
| Auto-actions | 3+ successful | `jq '.auto_actions_this_hour' .trinity/queen_state.json` |
| PPL delta | > 0.1 or stable | Compare `.trinity/evolution_state.json` over time |
| Crash count | 0 | Check audit log for failures |

## Expected Behaviors

```
[CHILD] Queen v4 — Growing Independence
=========================================
Cycle: 12 | Stage: CHILD | Age: 2h 15m

Daemon Status: [RUNNING] 135 minutes
Auto-Actions: ENABLED (Level 1)
  - doctor_quick: 2 runs today
  - git_commit_state: 1 run today
  - ouroboros_cycle: 0 runs (score OK)

Farm Report:
  Workers: 8 active, 1 idle
  Best PPL: 11.8 (was 12.4, -0.6!)
  Training running smoothly

Ouroboros Score: 58.3/100 (improving)

Decision: No action needed this cycle
```

## What's Happening Under the Hood

### 1. DLPFC Decision Engine
```zig
// Child learns to READ -> THINK -> ACT -> SPEAK
const decision = queen_dlpfc.decide(state, senses, config);
// Returns action kind if conditions met
```

### 2. Policy-Gated Auto-Actions
```zig
// Level 1 actions auto-allowed with --allow-auto-actions
const verdict = queen_policy.checkPolicy(
    .doctor_quick,  // Action to take
    config,         // max_auto_level = 1
    &counters,      // Rate limit tracking
    &incidents,     // Failure memory
);
// Returns .allowed or .denied
```

### 3. Premotor → Motor Execution
```zig
// Action execution pipeline
const planned = queen_premotor.plan(decision, senses);
const result = queen_motor.execute(planned);
queen_policy.record(result, &counters, &incidents);
```

## Auto-Actions Available to Child

| Action | Level | Trigger | Rate Limit |
|--------|-------|---------|------------|
| doctor_quick | L1 | Build broken | 3/hour, 10min cooldown |
| doctor_heal | L1 | Quick failed 2x | 1/hour, 1hr cooldown |
| git_commit_state | L1 | Dirty files > 50 | 1/hour, 1hr cooldown |
| git_push | L1 | Committed + ready | 1/hour, 1hr cooldown |
| ouroboros_cycle | L1 | Score < 40 | 2/hour, 30min cooldown |
| issue_comment | L1 | PPL record + stale | 6/hour, 5min cooldown |

## Expected Telegram Messages

**After auto-action:**
```
🧠 Queen Status Briefing

Child is learning!

⚙️ Auto-action: doctor_quick
✅ Build fixed, 3 files formatted

Training in progress.
✅ All systems nominal.
```

**When PPL improves:**
```
🏆 Progress Report!

PPL improved: 12.4 -> 11.8 (-0.6)
Worker: hslm-r33
Steps: 45,000

Child is doing great!
```

## Troubleshooting

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| Daemon stopped | Crash or kill | Check `.trinity/queen/supervisor.log` |
| Auto-actions not running | Policy denied | Check `max_auto_level` in config |
| PPL not improving | Learning rate bad | Consider manual `tri farm inject` |
| Dirty files accumulating | Git commit failing | Check `GITHUB_TOKEN` |

## Transition to Teen Stage

**Trigger:** 10+ cycles + auto-actions working + PPL stable/improving

**Teen unlocks:**
- SEVO hyperparameter exploration
- Level 2 actions (farm_recycle, farm_evolve_step)
- Experiment tracking
- Self-optimization attempts

**Command to transition:**
```bash
tri queen start --daemon --interval 600 --allow-auto-actions --max-auto-level 2
```

## Fun Facts

- Child stage corresponds to "Marutchi" → "Kuchitamatchi" evolution in Tamagotchi
- The "terrible twos" analogy: Child will break things while learning to fix them
- Auto-action rate limits prevent "spam" while allowing real fixes
- Most Children graduate to Teen after ~2 hours of stable operation
- Child is the first stage where Queen can actually HELP you

## Health Indicators

| Status | Meaning | Action |
|--------|---------|--------|
| [CHILD] | Learning autonomy | Monitor actions |
| [RECOVERING] | Build was broken, fixed | Check what was fixed |
| [THRIVING] | PPL improving, all good | Let it run |
| [NEEDS_HELP] | 3+ auto-action fails | Manual intervention |

## Code Locations

| Component | File | Purpose |
|-----------|------|---------|
| DLPFC | `src/tri/queen_dlpfc.zig` | Decision engine |
| Premotor | `src/tri/queen_premotor.zig` | Action planning |
| Motor | `src/tri/queen_motor.zig` | Action execution |
| Policy | `src/tri/queen_policy.zig` | Safety checks |

---

**Next Stage:** [Teen](./TRINITY_TAMAGOTCHI_STAGE_4_TEEN.md) — Experiments and rebellion!

*phi^2 + 1/phi^2 = 3 = TRINITY*
