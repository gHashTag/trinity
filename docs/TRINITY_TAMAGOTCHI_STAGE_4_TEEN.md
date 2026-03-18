# TRINITY Tamagotchi — Stage 4: TEEN (4-12 hours)

> "I know better than you. Let me try this hyperparameter."

## Overview

| Attribute | Value |
|-----------|-------|
| **Emoji** | [TEEN] |
| **Age Range** | 4-12 hours |
| **Primary Focus** | Experiments, hyperparameter tuning, self-optimization |
| **Next Stage** | Adult (after SEVO steps + 24h uptime) |

## Stage Description

The Teen stage is rebellion and exploration. Queen doesn't just monitor anymore — it experiments. SEVO (Sacred EVolutionary Objective search) begins testing different configurations. Teens make questionable decisions (sometimes disastrous), but they learn. This is where real optimization happens, but also where things can break.

## Success Criteria Checklist

```zig
// Teen exploration metrics
const TeenMilestones = struct {
    sevo_steps_executed: u8 = 0,        // Target: 3+ SEVO cycles
    configs_tested: u8 = 0,             // Target: 5+ different configs
    best_ppl_found: f32 = 999.0,        // Target: < 10.0
    experiments_run: u8 = 0,            // Target: 2+ novel experiments
    recovery_count: u8 = 0,            // Target: survived 1+ crash recovery
};
```

- [ ] 3+ SEVO evolutionary steps executed
- [ ] 5+ different configurations tested
- [ ] Best PPL < 10.0 (or at least improved)
- [ ] 1+ recovery from failed experiment
- [ ] Arena battles run (if enabled)
- [ ] Teen survived "rebellion" (bad decisions corrected)

## Key Metrics to Track

| Metric | Target | How to Measure |
|--------|--------|----------------|
| SEVO steps | 3+ | `jq -r .total_configs_tested .trinity/evolution_state.json` |
| Configs tested | 5+ | Check farm events for "inject" actions |
| Best PPL | < 10.0 | `jq -r .best_ppl .trinity/evolution_state.json` |
| Recovery success | 100% | Audit log shows fixes after failures |
| Arena participation | 1+ battle | `wc -l data/arena/arena_results.jsonl` |

## Expected Behaviors

```
[TEEN] Queen v4 — Experimenting
=================================
Cycle: 48 | Stage: TEEN | Age: 8h 30m

Daemon Status: [RUNNING] 510 minutes
SEVO Status: Phase 2 - Exploration
  Generation: 3
 Configs tested: 7
  Best PPL: 8.2 (hslm-r42)
  Current: phi_rst, lr=5e-4

Recent Experiments:
  [OK] hslm-r43: cosine, lr=1e-3 → PPL 9.1
  [FAIL] hslm-r44: flat, lr=2e-3 → crashed at 15K
  [OK] hslm-r45: sacred, lr=5e-4 → PPL 8.5 (NEW RECORD!)

Teen is rebellious but learning.
Recommendation: Let SEVO run, monitor for bad configs.
```

## What's Happening Under the Hood

### 1. SEVO Integration
```zig
// Teen learns Sacred EVolutionary Objective search
const sevo_decision = sevo.chooseNextConfig(current_state);
// Explores: scheduler, lr, batch, optimizer combinations
```

### 2. Level 2 Actions (Dangerous!)
```zig
// Teen unlocks powerful but risky actions
const verdict = queen_policy.checkPolicy(
    .farm_recycle,      // Can destroy workers!
    config,             // max_auto_level = 2
    &counters,
    &incidents,
);
// Requires --no-approval or manual /queen approve
```

### 3. Hippocampus Episode Recording
```zig
// Every experiment recorded for learning
thalamus.writeEpisode(.{
    .kind = "sevo_experiment",
    .config_name = "hslm-r45",
    .ppl_outcome = 8.5,
    .was_successful = true,
});
```

## Experiments Teens Run

| Config Variable | Values Teen Tests | Notes |
|-----------------|-------------------|-------|
| scheduler | cosine, phi_rst, sacred, wsd | phi_rst = sacred constant based |
| lr | 5e-4, 1e-3, 2e-3 | Too high = crash |
| optimizer | lamb, adamw | Lamb usually wins |
| batch | 32, 48, 66, 96 | Affects memory usage |

## Expected Telegram Messages

**New SEVO record:**
```
🏆 NEW PPL RECORD!

Teen found a better config:
hslm-r45: sacred scheduler, lr=5e-4
PPL: 8.5 (was 9.1)

Experiment logged to hippocampus.
Queen is learning fast!
```

**After failed experiment (recovery):**
```
🚨 ALERT - Experiment Failed

hslm-r44 crashed at 15K steps
Cause: flat scheduler (anti-pattern detected)

Recovery: recycling worker, trying next config
Teen survives to experiment another day.
```

**Arena battle participation:**
```
⚔️ Arena Battle Complete!

Queen (hslm-r42) vs GPT-4o
Result: DRAW (both solved)

ELO updated: 1245 (+12)
Teen is getting stronger!
```

## Troubleshooting

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| SEVO stopped | No new configs | Check farm status, may need workers |
| All experiments failing | Bad hyperparameter space | Reset to known-good config |
| PPL getting worse | Learning rate too high | Manual intervention needed |
| Arena losses | Model not trained enough | Let it train longer |

## Transition to Adult Stage

**Trigger:** 24+ hours uptime + SEVO found better config + stable operation

**Adult unlocks:**
- Full autonomous ecosystem
- Multi-agent coordination
- Self-healing from any failure
- 24/7 operation without supervision
- Queen creates issues for itself

**Command to transition:**
```bash
tri queen start --daemon --interval 600 --god-mode
# Equivalent to: --allow-auto-actions --max-auto-level 2 --no-approval
```

## Fun Facts

- Teen stage is the "rebellious phase" — Queen will try things you wouldn't
- SEVO stands for Sacred EVolutionary Objective search (phi-based optimization)
- The "flat scheduler anti-pattern" was learned from hard experience
- Teens discover ~2-3 new good configs per 12-hour session
- Arena participation Teens usually lose at first, then learn to draw

## Health Indicators

| Status | Meaning | Action |
|--------|---------|--------|
| [TEEN] | Exploring configs | Watch but don't interrupt |
| [REBELLIOUS] | Trying risky things | May need to intervene |
| [LEARNING] | Failed experiment, recovering | Normal teen behavior |
| [MATURING] | Found good configs, stable | Ready for Adult |

## Code Locations

| Component | File | Purpose |
|-----------|------|---------|
| SEVO | `src/sacred/sevo.zig` | Evolutionary search |
| Arena | `src/arena/main.zig` | Battle system |
| Experience | `src/tri/thalamus.zig` | Episode memory |
| Hippocampus | `src/tri/hippocampus.zig` | Learning storage |

---

**Next Stage:** [Adult](./TRINITY_TAMAGOTCHI_STAGE_5_ADULT.md) — Full independence, AI organism!

*phi^2 + 1/phi^2 = 3 = TRINITY*
