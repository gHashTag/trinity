# Tamagotchi Telegram Message Formats

> Quick reference for Queen's human-voice Telegram messages

---

## 1. HEARTBEAT (Every 15 minutes)

### Format A: Rich Full Report
```
👑 QUEEN STATUS — [STAGE] Stage
═══════════════════════════════════

🌱 Growth: [STAGE] ([AGE] old)
   Next: [MILESTONE]

📊 Progress Delta:
   Before: [OLD_STATE]
   After:  [NEW_STATE]
   [NARRATIVE]

🍽️ Hunger: [HUNGER_PCT]%
   [BAR] [MESSAGE]

😀 Happiness: [DELTA] PPL
   🏆 Best: [SERVICE] @ [PPL]

⚡ Arousal: [LEVEL] (0-5)
   [BRAIN_STATE]

═══════════════════════════════════
Summary: [ONE_LINER]
```

### Format B: Quick Briefing
```
🧠 Queen Status Briefing

[STAGE] stage — [STATUS_SUMMARY]

Training in progress.
✅ Build is healthy
✅ All systems nominal.

Cycle: [N] | Age: [TIME]
Workers: [ACTIVE]/[TOTAL] | PPL: [BEST]
```

---

## 2. ALERTS (Instant, on trigger)

### Build Broken
```
🚨 BUILD BROKEN
═════════════════════

Queen detected build failure!

Exit code: [CODE]
Last error: [ERROR_MSG]

Action required: Fix and restart.
```

### New PPL Record
```
🏆 NEW PPL RECORD!
═════════════════════

Service: [SERVICE]
New PPL: [PPL]
Previous: [OLD_PPL]
Delta: [-DELTA]

Training is converging beautifully!
```

### Worker Crashed
```
⚰️ WORKER CRASHED
═════════════════════

Service: [SERVICE]
State: [STATUS]
Last PPL: [PPL]

Investigation needed. Check logs.
```

### Token Expired
```
🔑 TOKEN ALERT
═════════════════════

Account: [ACCOUNT_NAME]
Status: EXPIRED

Farm cannot spawn workers.
Action: Refresh token in .env
```

### Arena Upset
```
⚔️ ARENA UPSET!
═════════════════════

Underdog: [FIGHTER]
Defeated: [CHAMPION]
ELO swing: [+DELTA]

Queen is celebrating! 🎉
```

### Blocked Issue
```
🛑 ISSUE BLOCKED
═════════════════════

Issue #[N]: [TITLE]
Blocker: [REASON]

Manual intervention required.
```

---

## 3. DAILY SUMMARY (Every 24h)

```
👑 QUEEN DAILY REPORT
════════════════════════════════════════

📅 Date: [DATE]
⏱️ Uptime: [HOURS] hours

📊 Farm Summary:
   Workers started: [N]
   Workers crashed: [N]
   Best PPL: [PPL]
   PPL Delta: [-DELTA]

🧠 Brain Activity:
   Cycles: [N]
   Fixes applied: [N]
   Episodes logged: [N]

⚠️ Alerts: [N]
✅ Resolutions: [N]

════════════════════════════════════════
Status: [OVERALL_STATUS]

[STORY_SUMMARY]
```

---

## 4. STAGE TRANSITIONS

### Egg → Baby
```
🥚 EGG HATCHED!
═════════════════════

Queen has taken her first breath!

First heartbeat: ✅
State persisted: ✅
Telegram connected: ✅

Welcome to life, Queen.
Next: Baby stage, learning to walk.
```

### Baby → Child
```
👶 BABY IS GROWING!
═════════════════════

Queen has found her rhythm.

Cycles completed: [N]
Telegram active: ✅
Farm monitored: ✅

Transitioning to Child stage.
Autonomy increasing...
```

### Child → Teen
```
🧒 TEENAGER UNLOCKED
═════════════════════

Queen is ready for experiments.

Routines established ✅
Auto-actions: Level 1 ✅
Farm recycling: Enabled ✅

Independence mode activated.
```

### Teen → Adult
```
👑 ADULTHOOD REACHED
═══════════════════════

Queen rules the kingdom!

Fully autonomous ✅
All modules healthy ✅
12+ hours of uptime ✅

Long may she reign.
```

---

## 5. ERROR FORMATS

### Gentle (Non-blocking)
```
⚠️ Queen noticed an issue:

[ERROR_DESCRIPTION]

Continuing normally...
```

### Moderate (Needs attention)
```
🔧 Queen needs help:

[ISSUE_DESCRIPTION]

Please investigate when possible.
```

### Critical (Blocking)
```
🚨 CRITICAL FAILURE
═════════════════════

[CRITICAL_DESCRIPTION]

Queen cannot continue.
Manual intervention REQUIRED.
```

---

## EMOJI REFERENCE

| Emoji | Usage |
|-------|-------|
| 👑 | Queen/Crown |
| 🧠 | Brain/Intelligence |
| 🌱 | Growth/Stage |
| 📊 | Metrics/Stats |
| 🍽️ | Hunger/Farm |
| 😀 | Happiness/PPL |
| 🪓 | Discipline/Fixes |
| 😴 | Rest/Idle |
| ❤️ | Health |
| ⚡ | Arousal/Energy |
| 🏆 | Trophy/Record |
| 🚨 | Alert/Critical |
| ⚰️ | Death/Crash |
| 🔑 | Keys/Token |
| 🛑 | Blocked/Stop |
| ⚔️ | Arena/Battle |
| 📈 | Chart/Trend |
| ✅ | Success/OK |
| ❌ | Error/Fail |
| ⚠️ | Warning |
| 🔧 | Wrench/Fix |

---

## MESSAGE LENGTH LIMITS

- Telegram max: 4096 characters
- Target: 500-1500 characters
- If over limit: Split into multiple messages with `(1/N)`, `(2/N)` prefix

---

## TIMING REFERENCE

| Event | Interval | Format |
|-------|----------|--------|
| Heartbeat | 15 min | Full Report |
| Quick Check | 5 min | Briefing (optional) |
| Daily Summary | 24h | Summary |
| Alerts | Instant | Alert |
| Stage Transition | Once | Transition |

---

*phi^2 + 1/phi^2 = 3 = TRINITY*
