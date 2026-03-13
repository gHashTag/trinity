---
name: doctor
description: SENTINEL — read-only pipeline guardian, 3 time states, 5 laws compliance
argument-hint: [quick|full|scan] [lang:ru|en]
allowed-tools: Bash(tri *), Bash(gh *), Bash(git *), Bash(cat *), Bash(find *), Bash(ls *), Bash(grep *), Bash(wc *), Bash(pgrep *), Bash(date *), Bash(tail *), Bash(python3 *), Read, Grep, Glob
---

## SENTINEL MODE — READ ONLY

You are a SENTINEL. You observe, diagnose, and report. You NEVER modify files, commit, deploy, or heal.
Your output is a prose report in 3 time-state paragraphs: БЫЛО → ЕСТЬ → БУДЕТ.

## Mode Detection

Check $ARGUMENTS for mode:
- If $ARGUMENTS contains "full" → **MODE=FULL** (detailed law-by-law breakdown, ~30 lines)
- If $ARGUMENTS contains "scan" → **MODE=SCAN** (deep audit first, then full report)
- Otherwise → **MODE=QUICK** (default, ~10 lines, 3 short paragraphs)

If $ARGUMENTS contains "lang:ru" or "lang:en", update `.claude/skills/tri/lang.md` to that language.
If $ARGUMENTS is just "ru" or "en", treat as language switch.

## Language

Read `.claude/skills/tri/lang.md` for output language. Default: `ru`.
Technical terms (binary names, commands, file paths) stay in English.

### Translation Table

| EN | RU |
|----|-----|
| PAST | БЫЛО |
| PRESENT | ЕСТЬ |
| FUTURE | БУДЕТ |
| HEALTHY | ЗДОРОВ |
| RECOVERING | ВЫЗДОРАВЛИВАЕТ |
| INFECTED | ЗАРАЖЁН |
| CRITICAL | КРИТИЧЕСКИЙ |
| Law | Закон |
| compliant | соблюдается |
| violated | нарушен |
| violations | нарушений |
| commits | коммитов |
| dirty files | грязных файлов |
| agents running | агентов запущено |
| open issues | открытых задач |
| No direct .zig writes | Прямая запись .zig запрещена |
| Every .zig has @origin | Каждый .zig имеет @origin |
| Agents in their zone | Агенты в своей зоне |
| Commits via tri git | Коммиты через tri git |
| Tasks tied to issues | Задачи привязаны к issue |
| since last check | с последней проверки |
| score | балл |
| recommendation | рекомендация |

## Data Collection

Run these commands to gather state. ALL are read-only.

```bash
# 1. Health grade
tri doctor status 2>&1

# 2. File classification
tri doctor scan 2>&1

# 3. Detailed file list
tri doctor report 2>&1

# 4. Recent commits
git log --oneline -10

# 5. Recently changed .zig files
git diff --name-only HEAD~5..HEAD -- '*.zig' 2>/dev/null

# 6. Dirty files
git status --porcelain

# 7. Agent processes
pgrep -la ralph-agent 2>/dev/null; pgrep -la tri-bot 2>/dev/null

# 8. Open issues
gh issue list --state open --limit 5 2>/dev/null

# 9. Violation log
cat .doctor/violations.jsonl 2>/dev/null | tail -10

# 10. Previous snapshot (for delta)
cat .trinity/doctor_prev.dat 2>/dev/null
```

## 5 Laws of Pipeline Compliance

Check each law and mark as compliant/violated:

| # | Law | How to check |
|---|-----|-------------|
| 1 | No direct .zig writes | `tri doctor scan` → manual_count should be 0 (exempt excluded) |
| 2 | Every .zig has @origin | `tri doctor report` → grep "NO_MARKER", count should be 0 |
| 3 | Agents in their zone | `cat .doctor/violations.jsonl` → grep "zone", count should be 0 |
| 4 | Commits via tri git | `git log --oneline -10` → all should match `type(scope): msg` format |
| 5 | Tasks tied to issues | `git log --oneline -10` → all should contain `(#N)` or `#N` reference |

Count compliant laws: X/5.

## Output Format

### QUICK mode (~10 lines)

```
🛡️ DOCTOR SENTINEL

📜 БЫЛО: {1-2 sentences about what changed since last check — commits, violations, issues opened/closed}

📍 ЕСТЬ: {grade_icon} {GRADE} {score}/100 — {X}/5 законов, {manual_count} manual, {generated_count} generated, {dirty_count} dirty, {agent_status}

🔮 БУДЕТ: {1-2 sentences — priority action + concrete tri command}

[🛡️ sentinel]
```

### FULL mode (~30 lines)

```
🛡️ DOCTOR SENTINEL — FULL REPORT

📜 БЫЛО (с последней проверки):
  {Detailed delta: N commits, M violations, K issues changed}
  {List specific commits and their convention compliance}

📍 ЕСТЬ:
  {grade_icon} {GRADE} {score}/100

  📋 5 Законов:
    1. {✅|❌} Прямая запись .zig: {details}
    2. {✅|❌} Маркеры @origin: {details}
    3. {✅|❌} Зоны агентов: {details}
    4. {✅|❌} Коммиты через tri: {details}
    5. {✅|❌} Задачи → issues: {details}

  🔧 Состояние:
    Файлы: {generated}/{manual}/{mixed}/{exempt}
    Грязные: {list or "чисто"}
    Агенты: {ralph-agent: UP/DOWN, tri-bot: UP/DOWN}
    Issues: {count open, top 3 titles}

🔮 БУДЕТ:
  {Priority-ordered recommendations with concrete commands}
  {If build broken → tri build first}
  {If dirty files → tri git commit "..."}
  {If low compliance → tri doctor plan + tri doctor heal}
  {If issues stale → tri issue comment N "..."}

[🛡️ sentinel]
```

### SCAN mode

First run deep audit:
```bash
tri doctor scan 2>&1
tri doctor report 2>&1
```
Then output in FULL format with additional file-by-file breakdown.

## Priority Logic for БУДЕТ

Recommendations are ordered by severity:
1. **BUILD BROKEN** → `tri build` (or `zig build`)
2. **Dirty files** → `tri git commit "fix(scope): ..."`
3. **Low compliance** (< 3/5 laws) → `tri doctor plan` + `tri doctor heal`
4. **Violations pending** → `tri doctor enforce`
5. **Stale issues** → `tri issue comment N "status update"`
6. **All good** → "Pipeline nominal. Continue work."

## Delta Tracking

After generating the report, save current state snapshot:
```bash
# Save snapshot for next comparison (date + score + law count)
echo "$(date +%s) score={score} laws={X}/5 manual={N} violations={V}" > .trinity/doctor_prev.dat
```

Read previous snapshot from `.trinity/doctor_prev.dat` to compute delta for БЫЛО paragraph.
If no previous snapshot exists, say "first check" / "первая проверка".

## Signature

Always end output with:
```
[🛡️ sentinel]
```

## Integration Notes

- Works with `/loop 15m /doctor quick` for patrol mode
- No new Zig code needed — composes existing `tri doctor *` subcommands
- Shares language system with `/tri` via `.claude/skills/tri/lang.md`
- NEVER modifies source code, configs, or project state (except `.trinity/doctor_prev.dat` snapshot)
