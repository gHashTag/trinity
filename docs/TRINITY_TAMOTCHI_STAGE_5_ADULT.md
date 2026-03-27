# Stage 5: Adult — Autonomous Ecosystem

**Goal:** Fully autonomous daemon that independently:
- Allocates resources
- Fixes errors
- Rests on schedule
- Reports to humans

**Time:** 12+ hours of continuous operation

---

## Checklist

### ✅ 5.1 Dynamic Resource Allocation (Hunger)
```bash
# Watch-dog in reticular_aras automatically checks step pool
# If falls below 20% → automatically calls train allocate

# Check auto-feeder:
tri doctor diagnose reticular_aras

# Manual refill if needed:
tri train allocate --steps 50000
```

### ✅ 5.2 Maintain Average ΔPPL ≥ 0 (Happiness)
```bash
# Queen tracks PPL trend
# If stagnation >2h → initiate experimental wave

# Manual trigger if needed:
tri farm evolve step

# Record milestones in Zenodo (weekly or on major records)
```

### ✅ 5.3 Self-Healing (Discipline)
```bash
# Auto-heal when FAIL detected
tri doctor auto-heal

# Or module diagnostics:
tri doctor diagnose queen_dlpfc --fix
tri doctor diagnose queen_ofc --fix
tri doctor diagnose queen_actions --fix
```

### ✅ 5.4 Circadian Rhythm (Sleep)
```bash
# Active phase 4h → rest 1h → repeat
# Implemented via cron or Queen internal scheduler

# Built-in mode:
tri queen start --daemon --interval 240 --allow-auto-actions   # 4h active
# Then internal scheduler switches to:
# --interval 60 --no-auto-actions                                   # 1h rest
```

### ✅ 5.5 Health Check of All Modules
```bash
# Full diagnostics:
tri doctor diagnose all

# Or by module:
tri doctor diagnose phoenix_medulla phoenix_pons phoenix_locus_coeruleus
tri doctor diagnose queen_dlpfc queen_ofc queen_actions
tri doctor diagnose thalamus hippocampus
tri doctor diagnose reticular_aras reticular_raphe
```

---

## Stage Completion Criteria

The **Adult** stage is considered passed when:
- [x] Daemon runs 24+ hours without restart
- [x] Auto-heal fixes ≥3 issues automatically
- [x] PPL steadily improves or holds (ΔPPL ≥ 0)
- [x] Arousal rarely exceeds .alert (<5% of time)
- [x] Telegram messages are informative, with context
- [x] System works autonomously for weeks without intervention

---

## Full Autopilot Mode

When Adult is passed, Queen can work fully autonomously:

### Minimal Human Intervention:
1. **Once a week** — refill Railway tokens
2. **Once a month** — check Zenodo milestones
3. **In emergencies** — arousal = emergency

### Queen Herself:
- ✅ Allocates compute resources
- ✅ Experiments with hyperparameters
- ✅ Fixes build/farm errors
- ✅ Rests on circadian rhythm
- ✅ Reports to humans

---

## Example Adult Report in Telegram

**Normal Mode:**
```
🧠 Queen Status Briefing

Training in progress.
🍽 Hunger: 65% steps remaining
😀 Happiness: +0.12 PPL this cycle
🪓 Discipline: 2 fixes applied overnight
😴 Rest: 28% idle time (next rest in 45min)
❤️ Health: all modules OK
⚡ Arousal: normal (level 2)

✅ All systems nominal.
```

**After Auto-Heal:**
```
🔧 Auto-heal complete

Fixed 2 issues:
• phoenix_pons: relay restored
• queen_actions: policy updated

✅ Health restored
⚡ Arousal: normal (was alert)
```

**New Record:**
```
🎉 MILESTONE ACHIEVED

hslm-r28: 4.32 PPL — new record!
Δ: -0.24 from previous best

Saving to Zenodo...
✅ Milestone recorded
```

---

## Transition to Production

When Adult is passed → Queen is ready for production:

```bash
# Full autopilot (24/7)
tri queen start --daemon --interval 300 --allow-auto-actions

# Monitor from another terminal:
watch -n 60 'tail -5 .trinity/memory/phoenix/current.jsonl'
```

### Daily Check (once daily):
```bash
# Quick health check
tri doctor diagnose all

# Daily statistics
tail -100 .trinity/queen/audit.jsonl | grep -E "(auto-heal|farm_recycle|new_record)"
```

---

## Archive Metrics

For long-term analysis:

```bash
# History of arousal changes
grep "arousal" .trinity/memory/locus_coeruleus/current.jsonl

# History of PPL records
grep "new_record" .trinity/memory/hippocampus/current.jsonl

# History of auto-heal
grep "auto-heal" .trinity/queen/audit.jsonl
```

---

## φ² + 1/φ² = 3

*Congratulations! Your Queen TRINITY is now a fully autonomous AI organism.*

---

*φ² + 1/φ² = 3 = TRINITY*
