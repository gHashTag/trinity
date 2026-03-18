# TRINITY Tamagotchi Report Template v2

> Enhanced rich report format with dynamic progress tracking and narrative flow

## Template Overview

This template is used by Queen daemon to generate engaging Telegram reports every 15 minutes. Each report tells a story of Queen's growth, farm status, and training progress.

---

## PLACEHOLDERS (Runtime Substitution)

| Placeholder | Source | Description |
|-------------|--------|-------------|
| `[ACTIVE_WORKERS]` | `thalamus.FarmStatus.active` | Number of running training services |
| `[TOTAL_WORKERS]` | `thalamus.FarmStatus.total_services` | Total farm services |
| `[CRASHED_COUNT]` | `thalamus.FarmStatus.crashed` | Crashed services needing attention |
| `[STALE_COUNT]` | `thalamus.FarmStatus.stale_count` | Services with stale PPL |
| `[BEST_PPL]` | `thalamus.FarmStatus.best_ppl` | Best perplexity achieved |
| `[BEST_SERVICE]` | `thalamus.FarmStatus.bestPplServiceStr()` | Service name with best PPL |
| `[HUNGER_PCT]` | Calculated from remaining steps | Steps remaining % |
| `[HAPPINESS_DELTA]` | Delta PPL this cycle | Change in PPL (negative = better) |
| `[AROUSAL_LEVEL]` | `locus_coeruleus.ArousalLevel` | Current arousal (0-5) |
| `[AROUSAL_LABEL]` | `ArousalLevel.label()` | "SLEEP" to "EMERGENCY" |
| `[GROWTH_STAGE]` | `GrowthStage.fromUptime()` | "Egg" to "Adult" |
| `[STAGE_EMOJI]` | `GrowthStage.emoji()` | Stage emoji |
| `[UPTIME_HOURS]` | `uptime_seconds / 3600` | Hours since Queen started |
| `[UPTIME_MINUTES]` | `uptime_seconds % 3600 / 60` | Remaining minutes |
| `[FIXES_APPLIED]` | Cycle fix counter | Problems resolved this cycle |
| `[EPISODES_COUNT]` | `hippocampus.countEpisodes()` | Memory episodes logged |
| `[MILESTONE]` | `GrowthStage.nextMilestone()` | Next growth milestone |
| `[NEXT_MOMENT]` | Estimated | When next report arrives |

---

## FULL REPORT TEMPLATE

```
[STAGE_EMOJI] TRINITY QUEEN — Tamagotchi Status Report
================================================================================

[STAGE_EMOJI] GROWTH STAGE: [GROWTH_STAGE] ([UPTIME_HOURS]h [UPTIME_MINUTES]m old)
   [MILESTONE_EMOJI] Next milestone: [MILESTONE]

[PROGRESS_EMOJI] PROGRESS DELTA: What Changed This Cycle
   Before: Hunger 100%, 0 workers active
   After:  Hunger [HUNGER_PCT]%, [ACTIVE_WORKERS] workers active
   [BAR] Farm is coming alive!

   [STORY_EMOJI] [NARRATIVE_SENTENCE]

[MEAL_EMOJI] HUNGER: [HUNGER_PCT]% steps remaining
   [STATUS_EMOJI] [HUNGER_MESSAGE]
   [BAR] [PROGRESS_BAR]

   Active workers: [ACTIVE_WORKERS]/[TOTAL_WORKERS]
   Crashed: [CRASHED_COUNT] | Stale: [STALE_COUNT]

[SMILE_EMOJI] HAPPINESS: [HAPPINESS_DELTA] PPL this cycle
   [TROPHY_EMOJI] Best: [BEST_SERVICE] @ PPL [BEST_PPL]
   [CHART_EMOJI] Trend: [TREND_MESSAGE]

[HAMMER_EMOJI] DISCIPLINE: [FIXES_APPLIED] fix(es) applied
   [STATUS_EMOJI] [DISCIPLINE_MESSAGE]

[HEART_EMOJI] HEALTH: [MODULE_STATUS]
   [MEDULLA_EMOJI] Medulla: [MEDULLA_STATUS]
   [PONS_EMOJI] Pons: [PONS_STATUS]
   [LC_EMOJI] Locus Coeruleus: [AROUSAL_LABEL]
   [HIPPOCAMPUS_EMOJI] Hippocampus: [EPISODES_COUNT] episodes

[BOLT_EMOJI] AROUSAL: [AROUSAL_LABEL] (level [AROUSAL_LEVEL]/5)
   [BRAIN_EMOJI] [AROUSAL_MESSAGE]

================================================================================
[SUMMARY_EMOJI] SUMMARY:
   [STAGE_SUMMARY]

   Farm: [ACTIVE_WORKERS] workers active, best PPL [BEST_PPL]
   Fixes: [FIXES_APPLIED] problems resolved

[FUN_EMOJI] FUN FACT:
   [RANDOM_FUN_FACT]

Next report: ~15 minutes ([NEXT_MOMENT])
```

---

## DYNAMIC NARRATIVE SENTENCES

Based on cycle state, choose one:

### When farm was hungry, now eating:
```
"Queen was starving, now she's feasting!"
"Farm came alive! Training steps detected."
"The hunger crisis is over. Workers are running."
```

### When workers just started:
```
"First training steps starting! Let's go!"
"Baby steps: workers are warming up."
"Farm is waking from slumber..."
```

### When PPL is improving:
```
"Training is converging beautifully!"
"PPL dropping like a stone. Excellent!"
"Queen is happy! Loss going down."
```

### When workers crashed:
```
"Some workers fell. Need attention!"
"Farm took a hit. Checking pulse..."
"Crashes detected. Investigation needed."
```

### When arousal high:
```
"Queen is alert! Monitoring closely."
"Elevated arousal. Issues detected."
"Calm down, Queen. All is well."
```

---

## HUNGER MESSAGES

| Hunger % | Message | Bar |
|----------|---------|-----|
| 80-100% | "Well-fed! [STEPS_LEFT]M steps left" | `████████████████████` |
| 60-79%  | "Satisfied. Plenty of training ahead" | `████████████████░░░░` |
| 40-59%  | "Half-full. Mid-training rhythm" | `████████████░░░░░░░░░` |
| 20-39%  | "Getting hungry. Consider recycle" | `█████░░░░░░░░░░░░░░░░` |
| 0-19%   | "STARVING! Inject workers now!" | `█░░░░░░░░░░░░░░░░░░░░░░` |

---

## HAPPINESS (TREND) MESSAGES

| PPL Range | Message | Emoji |
|-----------|---------|-------|
| < 3.0 | "PHENOMENAL! State of the art!" | `🏆` |
| 3.0-4.9 | "Excellent! Training converging well" | `📈` |
| 5.0-9.9 | "Good progress. Keep evolving." | `✅` |
| 10.0-19.9 | "Fair. Room for improvement." | `⚠️` |
| 20.0+ | "Needs attention. Consider recycle." | `🔧` |

---

## AROUSAL MESSAGES

| Level | Label | Message | Emoji |
|-------|-------|---------|-------|
| 0 | SLEEP | "Zzz... Dormant mode" | `⏱` |
| 1 | IDLE | "Relaxed, waiting for tasks" | `🔧` |
| 2 | NORMAL | "Calm and focused" | `✅` |
| 3 | ALERT | "Focused! Monitoring closely" | `👁` |
| 4 | ALARM | "Elevated! Issues detected" | `🚨` |
| 5 | EMERGENCY | "PANIC! Critical failure!" | `🔥` |

---

## STAGE-SPECIFIC SUMMARIES

### Egg (0-10 min):
```
"Queen is just hatching! Systems initializing."
```

### Baby (10-60 min):
```
"Queen is learning to walk. First cycles complete."
```

### Child (1-4h):
```
"Queen is growing well! Establishing routines."
```

### Teen (4-12h):
```
"Queen is gaining independence. Active experiments."
```

### Adult (12h+):
```
"Queen rules the kingdom! Fully autonomous."
```

---

## FUN FACTS (Random Rotation)

### Farm Lifecycle:
- "104 Railway services across 6 accounts = 1.56M steps/cycle"
- "LAMB 1e-3, cosine schedule = golden config (proven!)"
- "R33 PPL=4.6 is the true king (R5 was mirage)"
- "Max 3 attempts on new failures → then log & move on"

### Training Dynamics:
- "Ternary {-1,0,+1} = 1.58 bits/trit, 20x memory savings"
- "cosine schedule ONLY — flat LR = dead by 20K steps"
- "HSLM train: 1.95M params = 386 KB checkpoint"
- "Non-monotonic scaling: sometimes smaller = better"

### Queen Growth:
- "Baby → Child happens at 1h uptime (not age!)"
- "Adult stage unlocks at 12h — fully autonomous"
- "Queen has 5 brainstem modules: Medulla, Pons, LC, Hippocampus, OFC"
- "Each heartbeat = 18 senses collected in parallel"

### Anti-Patterns:
- "openFPGALoader --cable xpc → ALWAYS FAILS"
- "fxload -D flag → ALWAYS FAILS (use lowercase -d)"
- "CPLD 0xFFFE is normal for DLC10 clones, not a bug!"
- "Old binary killed 4 leaders at 30K (kill_ppl_30k bug fixed)"

---

## NEXT ACTIONS (Dynamic)

### If farm still hungry (< 20%):
```
"Action: Run `tri farm inject` to spawn more workers"
```

### If workers crashing (> 3):
```
"Action: Check `tri farm status` for crash logs"
```

### If PPL improving (> 0.5 delta):
```
"Celebration! New PPL record achieved! 🎉"
```

### If arousal > ALERT:
```
"Action: Review alerts, check module health"
```

### If health < 80%:
```
"Action: Run `tri doctor heal` to fix modules"
```

---

## IMPLEMENTATION NOTES

### Format Function Signature:
```zig
pub fn formatTamagotchiReportV2(
    allocator: Allocator,
    uptime_seconds: i64,
    farm_status: thalamus.FarmStatus,
    previous_metrics: ?TamagotchiMetrics,  // For delta calculation
    fixes_applied: u32,
    idle_ratio: f32,
    module_health: ModuleHealth,
    arousal: locus_coeruleus.ArousalLevel,
) ![]const u8
```

### Delta Calculation:
```zig
// If previous_metrics exists, calculate change
const hunger_delta = if (previous_metrics) |prev|
    @as(f32, @floatFromInt(current_steps)) - @as(f32, @floatFromInt(prev.hunger_steps_remaining))
else
    0.0;

const happiness_delta = if (previous_metrics) |prev|
    current_best_ppl - prev.happiness_best_ppl
else
    0.0;
```

### Progress Bar Helper:
```zig
fn progressBar(percentage: f32, width: u8) []const u8 {
    const filled = @intFromFloat(percentage * @as(f32, @floatFromInt(width)) / 100.0);
    const empty = width - filled;
    return "█" ** filled ++ "░" ** empty;
}
```

---

## EXAMPLE OUTPUT

```
👑 TRINITY QUEEN — Tamagotchi Status Report
================================================================================

🧒 GROWTH STAGE: Child (1h 15m old)
   📊 Next milestone: Teen @ 4h

📈 PROGRESS DELTA: What Changed This Cycle
   Before: Hunger 100%, 0 workers active
   After:  Hunger 45%, 52 workers active
   ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░ Farm is coming alive!

   🌱 Queen was starving, now she's feasting!

🍽️ HUNGER: 45% steps remaining
   ✅ Half-full. Mid-training rhythm
   ▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░

   Active workers: 52/104
   Crashed: 3 | Stale: 7

😀 HAPPINESS: -2.1 PPL this cycle
   🏆 Best: hslm-r33 @ PPL 4.6
   📈 Trend: Excellent! Training converging well

🪓 DISCIPLINE: 2 fixes applied
   🔧 2 problems resolved this cycle

❤️ HEALTH: All modules OK
   ✅ Medulla: heartbeat 30s ago
   ✅ Pons: bridge active
   ✅ Locus Coeruleus: NORMAL arousal
   ✅ Hippocampus: 42 episodes logged

⚡ AROUSAL: NORMAL (level 2/5)
   🧠 Calm and focused

================================================================================
📋 SUMMARY:
   Queen is growing well! Establishing routines.

   Farm: 52 workers active, best PPL 4.6
   Fixes: 2 problems resolved

🎲 FUN FACT:
   LAMB 1e-3, cosine schedule = golden config (proven!)

Next report: ~15 minutes (12:30 UTC)
```

---

*phi^2 + 1/phi^2 = 3 = TRINITY*
