---
name: status
description: Live system dashboard — ouroboros score, verdict, agents, build health, recommendations
argument-hint: [quick|full] [lang:ru|en]
allowed-tools: Bash(zig *), Bash(zig-out/*), Bash(git *), Bash(gh *), Bash(pgrep *), Bash(cat *), Bash(ls *), Bash(wc *), Bash(tail *), Bash(find *), Bash(date *), Read, Grep, Glob
---

## Mode Detection

Check $ARGUMENTS:
- "full" → **MODE=FULL** (detailed per-dimension breakdown + history + recommendations)
- "quick" or empty → **MODE=QUICK** (compact 20-line dashboard)
- "lang:ru" or "lang:en" → set language (read from `.claude/skills/tri/lang.md`, default: ru)

## Data Collection

Run ALL of these in parallel (they are independent):

```bash
# 1. Ouroboros state
cat .trinity/ouroboros_state.json 2>/dev/null || echo '{"cycle":0}'

# 2. Verdict score (live)
zig-out/bin/tri ouroboros --dry-run 2>&1

# 3. Ouroboros status
zig-out/bin/tri ouroboros status 2>&1

# 4. Build health
zig build --summary none 2>&1; echo "EXIT:$?"

# 5. Git state
git status --porcelain | wc -l
git log --oneline -3

# 6. Agents alive
pgrep -la ralph-agent 2>/dev/null; pgrep -la tri-bot 2>/dev/null; pgrep -la trinity-mcp 2>/dev/null

# 7. Verdict history trend
cat .trinity/verdict_history.json 2>/dev/null | tail -c 500

# 8. Experience count
find .trinity/experience -name '*.json' 2>/dev/null | wc -l
```

## QUICK Mode Output (default)

Compact dashboard, ~20 lines:

```
🐍 OUROBOROS DASHBOARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Score:      {score}/100 {emoji} {level}
  Cycle:      {cycle} | Strategy: {strategy}
  Stagnation: {stag}/3
  Build:      {pass|fail}
  Dirty:      {N} files
  Agents:     {list or "none"}
  Experience: {N} episodes

  Weakest:    {dimension} ({dim_score}/100) ← next target
  Rx:         {prescription one-liner}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  {timestamp} | tri ouroboros
```

## FULL Mode Output

Everything from QUICK, plus:

### Per-Dimension Breakdown
Table with all 5 dimensions (BUILD, TEST, CHURN, SPEC_COV, DOCTOR), their scores, status (STRONG/OK/WEAK/CRITICAL), and weight.

### Score History
Last 5 entries from `.trinity/verdict_history.json` as mini sparkline or table:
```
  History: 52 → 58 → 72 → 88 → 99.4
           ↑6   ↑14  ↑16  ↑11.4
```

### Recommendations

Based on current state, generate 3 actionable recommendations:

1. **If score < 70**: "Run `tri ouroboros --cycles 5` to auto-fix weakest dimensions"
2. **If score 70-89**: "Run `tri ouroboros --cycles 3 --dimension {weakest}` to target {weakest}"
3. **If score >= 90 but < 95**: "Almost LEGENDARY. Run `tri ouroboros` for final push"
4. **If score >= 95**: "LEGENDARY. Snake is resting. Monitor with `/status`"
5. **If build broken**: "URGENT: Build broken. Run `tri ouroboros --cycles 1 --dimension BUILD`"
6. **If dirty files > 20**: "High churn. Run `tri ouroboros --dimension CHURN`"
7. **If agents not running**: "Start agents: `tri agent start ralph`"
8. **If stagnation >= 2**: "Strategy rotation imminent. Consider `tri ouroboros --dimension {different}`"

### Git Activity
Last 3 commits with timestamps.

### Next Actions
Bullet list of concrete `tri` commands to run based on the data above.

## Language

Read `.claude/skills/tri/lang.md` for language preference (default: ru).

| EN | RU |
|----|-----|
| OUROBOROS DASHBOARD | ДАШБОРД УРОБОРОСА |
| Score | Счёт |
| Cycle | Цикл |
| Strategy | Стратегия |
| Stagnation | Стагнация |
| Build | Сборка |
| Dirty files | Грязные файлы |
| Agents | Агенты |
| Experience | Опыт |
| Weakest | Слабейшее |
| Recommendations | Рекомендации |
| History | История |
| Next Actions | Следующие действия |
| Snake is resting | Змей отдыхает |
| Almost LEGENDARY | Почти LEGENDARY |
| Build broken | Сборка сломана |

## Session Memory

After each `/status` run, note key metrics for next session:
- Current score and level
- Which dimensions improved/regressed
- What recommendations were given
- Any anomalies (score drops, build failures, stagnation)

This builds context for the next conversation's `/status` call.
