# TRINITY Tamagotchi — Stage 2: BABY (10-60 minutes)

> "First words, first steps. The world is exciting and scary."

## Overview

| Attribute | Value |
|-----------|-------|
| **Emoji** | [BABY] |
| **Age Range** | 10-60 minutes |
| **Primary Focus** | First cycle, Telegram integration, sense collection |
| **Next Stage** | Child (after 5+ successful cycles) |

## Stage Description

The Baby stage is about finding a rhythm. Queen has hatched and now needs to establish regular communication with the outside world. This is when Telegram integration comes alive — the first "heartbeat" messages start arriving. Baby is fragile but learning fast.

## Success Criteria Checklist

```zig
// Baby milestones
const BabyMilestones = struct {
    first_heartbeat_sent: bool = false,   // Telegram received first message
    all_senses_working: bool = false,     // 18/18 senses return valid data
    baseline_ppl: f32 = 999.0,            // Initial farm PPL recorded
    worker_count: u8 = 0,                 // Farm workers detected
    telegram_ok: bool = false,            // API connectivity confirmed
};
```

- [ ] First Telegram heartbeat received
- [ ] All 18 senses collecting data
- [ ] Baseline PPL recorded (< 999.0)
- [ ] Worker count > 0 detected
- [ ] Build status green
- [ ] 5+ cycles completed without crash

## Key Metrics to Track

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Heartbeat interval | 300 seconds | `jq -r .interval .trinity/queen/heartbeat.json` |
| Telegram delivery | 100% | Check phone/chat for messages |
| Sense success rate | 18/18 | Count non-null in sense output |
| PPL baseline | < 50.0 | `jq -r .best_ppl .trinity/evolution_state.json` |
| Uptime | 30+ minutes | Process age in `ps aux | grep queen` |

## Expected Behaviors

```
[BABY] Queen v4 — Finding Rhythm
==================================
Cycle: 5 | Stage: BABY | Age: 25 minutes

Senses Report (18/18):
  Build:     [OK] Green
  Tests:     85% pass
  Farm:      8 workers, PPL 12.4
  Arena:     156 battles
  Ouroboros: 52.3/100 (recovering)

Telegram Status: [CONNECTED]
  Last heartbeat sent: 12:25:00
  Next heartbeat: 12:30:00

Auto-Actions: DISABLED (Baby needs supervision)
Recommendation: Enable --allow-auto-actions for next stage
```

## What's Happening Under the Hood

### 1. Telegram Integration
```zig
// OFC (Orbitofrontal Cortex) formats human-readable messages
const message = queen_ofc.fmtHeartbeat(senses, state);
// Sent via queen_telegram.sendMessage()
```

### 2. Sense Expansion (12 -> 18)
```zig
// Baby unlocks 6 new senses:
senses.farm_idle_count      // v4: idle services
senses.stale_arena_hours    // v4: arena freshness
senses.agent_spawn_issues   // v4: GitHub agent tasks
senses.last_git_push_ts     // v4: repo activity
senses.finished_containers  // v4: cloud cleanup
senses.last_issue_comment_ts // v4: issue tracker
```

### 3. Hippocampus First Write
```zig
// Baby's first memories recorded
thalamus.writeEpisode(.{
    .kind = "first_heartbeat",
    .timestamp = now,
    .success = true,
});
```

## Expected Telegram Messages

**First Heartbeat:**
```
🧠 Queen Status Briefing

Baby stage — finding rhythm.

Training in progress.
✅ Build is healthy
✅ All systems nominal.

Cycle: 1 | Age: 5 min
```

**After 10 minutes:**
```
🧠 Queen Status Briefing

Baby is learning!

Farm: 8 workers active
PPL: 12.4 (baseline)
Arena: 156 battles recorded

✅ Telegram integration OK
```

## Troubleshooting

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| No Telegram messages | Token/Chat ID missing | Check `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` |
| "API error 409" | Old webhook active | Use `deleteWebhook` call first |
| Senses timeout | Railway API slow | Increase timeout, check network |
| PPL = 999.0 | Farm not initialized | Run `tri farm status` first |

## Transition to Child Stage

**Trigger:** 5+ successful cycles + Telegram working

**Child unlocks:**
- Daemon mode (background process)
- Auto-actions (Level 1: doctor_quick, git commit)
- Farm monitoring
- 10-minute intervals

**Command to transition:**
```bash
tri queen start --daemon --interval 600 --allow-auto-actions --max-auto-level 1
```

## Fun Facts

- Baby stage is named after the "Marutchi" baby form in Tamagotchi
- The first heartbeat message is always special — Queen marks it in memory
- Telegram integration uses human-voice format (OFC module mimics empathy)
- 18 senses = 12 basic + 6 expanded (v4)
- Most "babies" crash within first 20 minutes if tokens are expired

## Health Indicators

| Status | Meaning | Action |
|--------|---------|--------|
| [BABY] | Just hatched, learning | Watch closely |
| [OK] | All systems normal | Let it learn |
| [HUNGRY] | Needs compute tokens | Run `tri farm status` |
| [SICK] | Build broken | Fix manually |

## Code Locations

| Component | File | Purpose |
|-----------|------|---------|
| Telegram | `src/tri/queen_telegram.zig` | API integration |
| OFC | `src/tri/queen_ofc.zig` | Human-voice messages |
| Thalamus | `src/tri/thalamus.zig` | Memory router |
| Hippocampus | `src/tri/hippocampus.zig` | Episode memory |

---

**Next Stage:** [Child](./TRINITY_TAMAGOTCHI_STAGE_3_CHILD.md) — First independent actions!

*phi^2 + 1/phi^2 = 3 = TRINITY*
