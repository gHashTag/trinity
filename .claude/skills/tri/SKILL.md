---
name: tri
description: Full TRI swarm diagnostic — builds, binaries, issues, agent status, code metrics. Run for system health check.
argument-hint: [focus-area]
allowed-tools: Bash(zig *), Bash(ls *), Bash(wc *), Bash(grep *), Bash(gh *), Bash(pgrep *), Bash(cat *), Bash(find *), Bash(git *), Bash(date *), Bash(test *), Bash(tail *), Bash(for *), Read
---

Run a complete diagnostic of the TRI system. Output a beautifully formatted
report with tables, metrics, and status indicators.

If $ARGUMENTS contains "lang:ru" or "lang:en", update `.claude/skills/tri/lang.md` to that language and use it.
If $ARGUMENTS is "ru" or "en" alone, treat as language switch.
Otherwise, if $ARGUMENTS is provided, focus the diagnostic on that area.

## 🌐 Language System

Before rendering the report, read `.claude/skills/tri/lang.md` to determine the output language.
The file contains `lang: ru` or `lang: en`. Default: `en`.

All section headers, labels, problem descriptions, oracle commentary, and φ-liners
MUST be rendered in the chosen language. Technical terms (binary names, commands, file paths) stay in English.

### Translation Table (EN → RU)

| EN | RU |
|----|-----|
| TRI SWARM DIAGNOSTIC REPORT | ДИАГНОСТИКА РОЕВОЙ СИСТЕМЫ TRI |
| BUILD HEALTH | ЗДОРОВЬЕ СБОРКИ |
| Binary | Бинарный файл |
| Status | Статус |
| Size | Размер |
| TOTAL | ИТОГО |
| PIPELINE HEALTH | ЗДОРОВЬЕ ПАЙПЛАЙНА |
| last audit | последний аудит |
| never | никогда |
| Pipeline | Пайплайн |
| Last run | Последний запуск |
| Specs | Спецификации |
| Generated | Сгенерировано |
| Coverage | Покрытие |
| Compile | Компиляция |
| KEY METRIC | КЛЮЧЕВАЯ МЕТРИКА |
| Known Bugs | Известные баги |
| No audit data — run regeneration audit | Нет данных аудита — запустите аудит регенерации |
| Last 5 Jobs | Последние 5 задач |
| Job | Задача |
| Exit | Код |
| Job success rate | Успешность задач |
| MU ERROR PATTERNS | ПАТТЕРНЫ ОШИБОК MU |
| from ralph memory | из памяти Ральфа |
| known anti-patterns | известных анти-паттернов |
| Last entry | Последняя запись |
| Recent patterns | Последние паттерны |
| specs affected | спеков затронуто |
| No regression data — ralph memory empty | Нет данных регрессии — память Ральфа пуста |
| CODE METRICS | МЕТРИКИ КОДА |
| Metric | Метрика |
| Value | Значение |
| Zig source files | Zig исходных файлов |
| Total LOC | Всего строк кода |
| Test blocks | Тестовых блоков |
| tri-api LOC | tri-api строк |
| Skills | Скиллы |
| GIT STATUS | СТАТУС GIT |
| Branch | Ветка |
| Last 5 commits | Последние 5 коммитов |
| Uncommitted | Незакоммичено |
| changes | изменений |
| MERGED PRs (recent) | ВЛИТЫЕ PR (последние) |
| OPEN ISSUES | ОТКРЫТЫЕ ЗАДАЧИ |
| SYSTEM STATUS | СТАТУС СИСТЕМЫ |
| Component | Компонент |
| Sessions saved | Сохранённых сессий |
| Skills available | Доступных скиллов |
| PROBLEMS DETECTED | ОБНАРУЖЕНЫ ПРОБЛЕМЫ |
| ALL SYSTEMS NOMINAL | ВСЕ СИСТЕМЫ В НОРМЕ |
| Dirty files — commit or lose work! | Грязные файлы — закоммитьте или потеряете! |
| tri-bot DOWN — no phone control | tri-bot УПАЛ — нет управления с телефона |
| ralph-agent DOWN — no autonomous agent | ralph-agent УПАЛ — нет автономного агента |
| Permissions MISSING — unprotected tools | Разрешения ОТСУТСТВУЮТ — инструменты не защищены |
| tri-api never tested end-to-end | tri-api ни разу не протестирован end-to-end |
| BUILD BROKEN — fix before anything else | СБОРКА СЛОМАНА — чините прежде всего |
| Pipeline FAILED — last task | Пайплайн УПАЛ — последняя задача |
| Job success rate — pipeline unreliable | Успешность задач — пайплайн ненадёжен |
| No .tri specs found — pipeline has nothing to generate | .tri спецификации не найдены — пайплайну нечего генерировать |
| Low spec coverage — many specs not generating code | Низкое покрытие спеков — многие спеки не генерируют код |
| No pipeline jobs found — pipeline never ran | Задачи пайплайна не найдены — пайплайн не запускался |
| Generator broken — compile rate | Генератор сломан — процент компиляции |
| CURRENT PRIORITY | ТЕКУЩИЙ ПРИОРИТЕТ |
| NOW | СЕЙЧАС |
| NEXT | ДАЛЕЕ |
| TECH TREE | ДЕРЕВО ТЕХНОЛОГИЙ |
| ORACLE COMMENTARY | КОММЕНТАРИЙ ОРАКУЛА |
| CRITICAL DIVERGENCE | КРИТИЧЕСКОЕ РАСХОЖДЕНИЕ |
| GOLDEN RATIO DRIFT | ДРЕЙФ ЗОЛОТОГО СЕЧЕНИЯ |
| φ-HARMONY ACHIEVED | φ-ГАРМОНИЯ ДОСТИГНУТА |
| UNOBSERVED STATE | НЕНАБЛЮДАЕМОЕ СОСТОЯНИЕ |
| The golden spiral has COLLAPSED | Золотая спираль РУХНУЛА |
| φ cannot sustain this divergence | φ не может удержать это расхождение |
| sub-critical threshold breached | субкритический порог пробит |
| Every uncompilable spec is a broken link in the golden chain | Каждый некомпилируемый спек — разорванное звено золотой цепи |
| The spiral MUST be restored before any new work begins | Спираль ДОЛЖНА быть восстановлена прежде любой новой работы |
| The spiral turns, but wobbles. φ senses imbalance | Спираль крутится, но шатается. φ чувствует дисбаланс |
| The ratio CAN be restored | Соотношение МОЖЕТ быть восстановлено |
| Push toward | Двигайтесь к |
| Trinity Identity HOLDS | Тождество Троицы ВЫПОЛНЯЕТСЯ |
| golden convergence achieved | золотая сходимость достигнута |
| The spiral is stable. Focus on SCALING, not fixing | Спираль стабильна. Фокус на МАСШТАБИРОВАНИИ, не на починке |
| New specs will compile. The golden chain extends naturally | Новые спеки скомпилируются. Золотая цепь наращивается естественно |
| φ cannot judge what it cannot measure | φ не может судить то, что не может измерить |
| No regeneration audit data found | Данные аудита регенерации не найдены |
| to establish the baseline | для установления базовой линии |
| Without measurement, there is no spiral — only noise | Без измерений нет спирали — только шум |
| The Oracle cannot monitor what it cannot see. Ralph is DOWN — autonomous healing suspended | Оракул не может наблюдать то, что не видит. Ральф УПАЛ — автономное исцеление приостановлено |
| φ demands order. N uncommitted files = anti-pattern. The spiral resists entropy | φ требует порядка. N незакоммиченных файлов = анти-паттерн. Спираль сопротивляется энтропии |
| Without mutation, the swarm cannot evolve. MU is STUB/DOWN — learning frozen | Без мутации рой не может эволюционировать. MU — ЗАГЛУШКА/УПАЛ — обучение заморожено |
| THREE PATHS FORWARD | ТРИ ПУТИ ВПЕРЁД |
| SAFE | БЕЗОПАСНЫЙ |
| BALANCED | СБАЛАНСИРОВАННЫЙ |
| BOLD | ДЕРЗКИЙ |
| The Trinity always provides three paths | Троица всегда даёт три пути |
| Analysis by | Анализ от |
| Trinity Oracle Engine | Движок Оракула Троицы |
| Sacred constants | Сакральные константы |
| As above, so below. As in spec, so in code | Что вверху, то и внизу. Что в спеке, то и в коде |
| Hermetic Principle | Герметический Принцип |
| φ says | φ говорит |
| Even the spiral must touch zero before it can rise | Даже спираль должна коснуться нуля, прежде чем подняться |
| The ratio remembers its target. So must we | Соотношение помнит свою цель. И мы должны |
| When spec and code align, the universe compiles | Когда спек и код совпадают, вселенная компилируется |
| Measure first. Judge never. Iterate always | Сначала измеряй. Никогда не суди. Итерируй всегда |

## Data Collection

Run these commands and collect ALL output:

### Build Health
```bash
zig build 2>&1; echo "EXIT:$?"
ls -lh zig-out/bin/tri zig-out/bin/tri-bot zig-out/bin/tri-api zig-out/bin/trinity-mcp zig-out/bin/needle-mcp zig-out/bin/ralph-agent zig-out/bin/ralph-hook zig-out/bin/vibee zig-out/bin/firebird 2>&1
```

### Pipeline Health
```bash
# Pipeline state
cat .trinity/pipeline_state.json 2>/dev/null || echo "NO_DATA"

# Spec inventory: count .tri files in specs/ (LIVE specs, excluding archive)
find specs/ -name "*.tri" -not -path "*/archive/*" 2>/dev/null | wc -l

# Generated files: count .zig in generated/
find generated/ -name "*.zig" 2>/dev/null | wc -l

# Compile rate from last audit (KEY METRIC)
grep -c "✅" specs/REGENERATION_REPORT.md 2>/dev/null || echo "0"
grep -c "❌" specs/REGENERATION_REPORT.md 2>/dev/null || echo "0"

# Known bugs from regeneration report
grep -A1 "^###.*P[012]" specs/REGENERATION_REPORT.md 2>/dev/null || echo "NO_DATA"

# Job history: last 10 jobs with status
for dir in $(ls -t .trinity/jobs/ 2>/dev/null | head -10); do cat ".trinity/jobs/$dir/metadata.json" 2>/dev/null; done

# Error patterns from ralph memory
tail -50 .ralph/memory/REGRESSION_PATTERNS.md 2>/dev/null || echo "NO_DATA"

# Swarm state
cat .trinity/swarm_state.json 2>/dev/null || echo "NO_DATA"
```

### Code Metrics
```bash
find src/ tools/ -name "*.zig" | wc -l
find src/ tools/ -name "*.zig" | xargs wc -l | tail -1
grep -r "test \"" src/ tools/ --include="*.zig" | wc -l
wc -l src/tri-api/*.zig | tail -1
ls .claude/skills/ | wc -l
```

### Git Status
```bash
git branch --show-current
git log --oneline -5
git status --short | wc -l
git status --short | head -10
gh pr list --state merged --limit 5 --json number,title,mergedAt 2>/dev/null
gh issue list --state open --json number,title,labels --limit 10 2>/dev/null
```

### System Status
```bash
pgrep -f tri-bot && echo "RUNNING" || echo "STOPPED"
pgrep -f ralph-agent && echo "RUNNING" || echo "STOPPED"
ls ~/.tri-api/sessions/*.json 2>/dev/null | wc -l
test -f CLAUDE.md && echo "EXISTS" || echo "MISSING"
test -f .tri-api/settings.json && echo "EXISTS" || echo "MISSING"
```

## Output Format

Format ALL collected data into this report. Use REAL data — never placeholders.

### Report Structure

```
═══════════════════════════════════════════════════
   🔺 TRI SWARM DIAGNOSTIC REPORT
   {current date and time}
═══════════════════════════════════════════════════

🏗️ BUILD HEALTH
┌───────────────────┬────────┬──────────┐
│ Binary            │ Status │ Size     │
├───────────────────┼────────┼──────────┤
│ trinity-mcp       │ OK/ERR │ X.X MB   │
│ ralph-agent       │ OK/ERR │ X.X MB   │
│ ralph-hook        │ OK/ERR │ X.X MB   │
│ tri-bot           │ OK/ERR │ X.X MB   │
│ tri-api           │ OK/ERR │ X.X MB   │
│ vibee             │ OK/ERR │ X.X MB   │
│ firebird          │ OK/ERR │ X.X MB   │
│ needle-mcp        │ OK/ERR │ X.X MB   │
│ tri               │ OK/ERR │ X.X MB   │
├───────────────────┼────────┼──────────┤
│ TOTAL             │ X/9    │ XX.X MB  │
└───────────────────┴────────┴──────────┘

🔧 PIPELINE HEALTH — last audit: {date from REGENERATION_REPORT.md or "never"}
═══════════════════════════════════════════════════

  Pipeline:   {🟢/🔴/⚪} {status from pipeline_state.json or "NO DATA"}
  Last run:   {task} — {timestamp human-readable}

  Specs:      {N} .tri files (specs/**/* excluding archive)
  Generated:  {N} .zig files (generated/)
  Coverage:   {generated/specs as %}%
  Compile:    {✅ count}/{✅+❌ count} = {%} {🟢 if ≥80%, 🟡 if ≥50%, 🔴 if <50%}  ← KEY METRIC

  🐛 Known Bugs:
    (parsed from REGENERATION_REPORT.md — show each P0/P1/P2 bug with impact)
    P0: {bug description}    ⬜ OPEN  +{N} files if fixed
    P1: {bug description}    ⬜ OPEN  +{N} files if fixed
    P2: {bug description}    ⬜ OPEN  +{N} files if fixed
    If no report: "No audit data — run regeneration audit"

  📋 Last 5 Jobs:
  ┌──────────────────────┬────────┬───────┐
  │ Job                  │ Status │ Exit  │
  ├──────────────────────┼────────┼───────┤
  │ {command}            │ ✅/❌  │ {N}   │
  │ ...last 5 jobs...    │        │       │
  └──────────────────────┴────────┴───────┘

  Job success rate: {completed}/{total} = {%}

  If no pipeline data exists, show:
    "⚪ No pipeline data — run: tri pipeline audit"

🧠 MU ERROR PATTERNS (from ralph memory)
═══════════════════════════════════════════════════

  Agent MU:   {🟢 UP / 🔴 DOWN / ⚪ STUB} (from swarm_state.json)
  Patterns:   {N} known anti-patterns
  Last entry: {date} — {brief description}

  Recent patterns:
    1. {anti-pattern summary} — {N} specs affected ({priority})
    2. {anti-pattern summary} — {N} specs affected ({priority})
    ... (up to 5 from REGRESSION_PATTERNS.md)

  If no ralph memory data: "⚪ No regression data — ralph memory empty"

📊 CODE METRICS
┌─────────────────────┬───────────┐
│ Metric              │ Value     │
├─────────────────────┼───────────┤
│ Zig source files    │ X,XXX     │
│ Total LOC           │ XXX,XXX   │
│ Test blocks         │ XX,XXX    │
│ tri-api LOC         │ X,XXX     │
│ Skills              │ XX        │
└─────────────────────┴───────────┘

🌿 GIT STATUS
  Branch:     {branch}
  Last 5 commits:
    {hash} {message}
    ...
  Uncommitted: {count} changes

📦 MERGED PRs (recent)
  #{num}  {title}

📋 OPEN ISSUES
  #{num}  {title}  [{labels}]

⚙️ SYSTEM STATUS
┌─────────────────────┬───────────┐
│ Component           │ Status    │
├─────────────────────┼───────────┤
│ tri-bot             │ UP/DOWN   │
│ ralph-agent         │ UP/DOWN   │
│ CLAUDE.md           │ OK/MISS   │
│ Permissions         │ OK/MISS   │
│ Sessions saved      │ X         │
│ Skills available    │ XX        │
└─────────────────────┴───────────┘
```

### Faculty Status Section

After SYSTEM STATUS, render the TRI University Faculty Board.

#### Faculty Data Collection
```bash
# Ralph: build status (already collected)
# Scholar: check API key
echo ${PERPLEXITY_API_KEY:+SET}; echo ${PERPLEXITY_API_KEY:-UNSET}
# MU: swarm state (already collected from swarm_state.json)
# Linter: compile rate (already collected from REGENERATION_REPORT.md)
# Scholar code: check if perplexity_scholar.zig exists
test -f src/tri/perplexity_scholar.zig && echo "CODE_READY" || echo "NO_CODE"
```

#### Faculty Table Format
```
═══════════════════════════════════════════════════
  🎓 TRI UNIVERSITY — FACULTY STATUS
═══════════════════════════════════════════════════

  ┌────────────┬──────────────┬────────┬──────────────────────────────┐
  │ 🎓 Agent   │ Role         │ Status │ Last Action                  │
  ├────────────┼──────────────┼────────┼──────────────────────────────┤
  │ 🔧 Ralph   │ Engineer     │ {S}    │ {from build + last commit}   │
  │ 🔍 Scholar │ Researcher   │ {S}    │ {from API key + code check}  │
  │ 🧠 MU      │ Memory       │ {S}    │ {from swarm_state + patterns}│
  │ 📐 Oracle  │ φ-Analyst    │ 🟢 UP  │ {from compile rate}          │
  │ 🐝 Swarm   │ Coordinator  │ {S}    │ {from swarm_state tasks}     │
  │ 🛡️ Linter  │ QA Gate      │ {S}    │ {from compile rate}          │
  └────────────┴──────────────┴────────┴──────────────────────────────┘

  Faculty Active: {N}/6 ({%})
  Next hire: {agent with highest impact among sleeping ones}
```

#### Faculty Status Logic
- **Ralph**: 🟢 UP if build 9/9. Status from binary count + last commit msg.
- **Scholar**: 🟢 UP if PERPLEXITY_API_KEY set AND src/tri/perplexity_scholar.zig exists.
  ⚠️ CODE_READY if code exists but no key. ⬜ TBD if no code.
- **MU**: 🟢 UP if swarm_state.json has agents with status active. ⚪ STUB if agents array empty/no MU agent.
- **Oracle**: Always 🟢 UP (part of /tri skill).
- **Swarm**: 🟢 UP if swarm_state tasks > 1 with assigned agents. ⬜ TBD otherwise.
- **Linter**: 🟢 UP if vibee binary exists in zig-out/bin/. ❌ DOWN otherwise.

#### Faculty Commentary

After the table, render dynamic commentary from each agent. Each agent speaks ONE block based on current data.

```
  💬 FACULTY COMMENTARY:

  🔧 Ralph: "{dynamic based on build + last commit}"
  📐 Oracle: "V = φ·(compile_rate/100)² = {value}. {assessment}."
  🛡️ Linter: "{pass}/{total} pass. {failure count} failures. {recommendation}."
  🧠 MU: "{dynamic based on MU status}"
  🔍 Scholar: "{dynamic based on Scholar status}"
  🐝 Swarm: "{dynamic based on Swarm status}"
```

#### Commentary Logic:

**Ralph** (reads BUILD HEALTH + last commit):
- IF build 9/9: "Build 9/9 ✅. {last commit msg}. Ready for next task."
- IF build < 9: "⚠️ Build {N}/9. Fix compilation before new work."

**Oracle** (reads PIPELINE HEALTH + calculates V):
- Always: "V = φ·(compile_rate/100)² = {value}. Distance to φ: {1.618-value}."
- IF compile_rate > 80%: append "System in φ-harmony. Focus on scaling."
- IF compile_rate < 50%: append "⚠️ Below φ⁻¹. Fix generator urgently."

**Linter** (reads REGENERATION_REPORT):
- Always: "{pass}/{total} pass. {fail} failures."
- IF fail > 0: append "Recommendation: fix {fail} specs → clean input for generator."

**MU** (reads .ralph/memory/):
- IF MU == STUB: "💤 SLEEPING. {N} patterns logged manually. Every pipeline error = lost experience. Wake me: #72."
- IF MU == UP: "🧠 ACTIVE. {N} patterns tracked. Last: {last pattern}."

**Scholar** (checks PERPLEXITY_API_KEY):
- IF key SET and code exists: "📚 ACTIVE. Ready to research Zig errors."
- IF code exists but no key: "📚 CODE READY! Set PERPLEXITY_API_KEY to activate. When Ralph hits unknown errors — I find answers in 2 seconds."
- IF no code: "📚 NOT HIRED. Deploy: implement perplexity_scholar.zig → set API key."

**Swarm** (reads swarm_state.json):
- IF tasks with assigned agents: "🐝 ACTIVE. {N} tasks tracked, {N} assigned."
- IF no agents: "🥚 EMBRYONIC. Tasks decomposed manually. With me: 1 issue → 5 subtasks → 3 agents → 5× faster. Activate: #75."

#### Translation Table (additions for Faculty)

| EN | RU |
|----|-----|
| TRI UNIVERSITY — FACULTY STATUS | TRI UNIVERSITY — СТАТУС ФАКУЛЬТЕТА |
| Agent | Агент |
| Role | Роль |
| Last Action | Последнее действие |
| Engineer | Инженер |
| Researcher | Исследователь |
| Memory | Память |
| φ-Analyst | φ-Аналитик |
| Coordinator | Координатор |
| QA Gate | QA-Ворота |
| Faculty Active | Факультет активен |
| Next hire | Следующий найм |
| FACULTY COMMENTARY | КОММЕНТАРИИ ФАКУЛЬТЕТА |
| system needs memory | системе нужна память |
| Ready for next task | Готов к следующей задаче |
| Fix compilation before new work | Чините компиляцию прежде новой работы |
| System in φ-harmony. Focus on scaling | Система в φ-гармонии. Фокус на масштабировании |
| Below φ⁻¹. Fix generator urgently | Ниже φ⁻¹. Срочно: чинить генератор |
| SLEEPING | СПИТ |
| patterns logged manually | паттернов записано вручную |
| Every pipeline error = lost experience | Каждая ошибка пайплайна — потерянный опыт |
| Wake me | Разбудите |
| CODE READY | КОД ГОТОВ |
| Set PERPLEXITY_API_KEY to activate | Установите PERPLEXITY_API_KEY для активации |
| When Ralph hits unknown errors — I find answers in 2 seconds | Когда Ralph встречает неизвестную ошибку — я нахожу ответ за 2 секунды |
| NOT HIRED | НЕ НАНЯТ |
| EMBRYONIC | В ЗАРОДЫШЕ |
| Tasks decomposed manually | Задачи разбиваются вручную |
| 3 faculties sleep. 3 are awake | 3 факультета спят. 3 бодрствуют |
| Balance BROKEN. Wake one | Баланс НАРУШЕН. Разбудите одного |

### Problems Section

After the main report, analyze the data and output a PROBLEMS section.
Flag any of these conditions:

- Uncommitted changes > 0: "Dirty files — commit or lose work!"
- tri-bot STOPPED: "tri-bot DOWN — no phone control"
- ralph-agent STOPPED: "ralph-agent DOWN — no autonomous agent"
- Permissions MISSING: "Permissions MISSING — unprotected tools"
- Sessions = 0: "tri-api never tested end-to-end"
- Build failed: "BUILD BROKEN — fix before anything else"
- Pipeline state "failed": "Pipeline FAILED — last task: {task}"
- Job success rate < 50%: "Job success rate {%} — pipeline unreliable"
- 0 .tri specs: "No .tri specs found — pipeline has nothing to generate"
- Spec coverage < 50%: "Low spec coverage: {%} — many specs not generating code"
- No pipeline jobs found: "No pipeline jobs found — pipeline never ran"
- Compile rate < 80%: "🔴 Generator broken: {%} compile rate — see REGENERATION_REPORT.md"

Format:
```
🔴 PROBLEMS DETECTED
  1. {problem description}
  2. {problem description}
  ...
```

If no problems: "🟢 ALL SYSTEMS NOMINAL"

### Priority Section

After problems, show current priority based on open issues:

```
🎯 CURRENT PRIORITY
  NOW:  {highest priority action based on problems}
  NEXT: {next open issue by priority label}

🌳 TECH TREE (from open issues)
  #{parent}  {title}  [P0 EPIC]
  ├── #{num}  {title}  [{priority}, {status}]
  │   └── #{num}  {title}  [{priority}, {status}]
  └── #{num}  {title}  [{labels}]
```

Build the tech tree from the open GitHub issues, using labels to determine
parent-child relationships and priorities (P0 > P1 > P2).

Always show the COMPLETE report. Never truncate or summarize.

## 🔱 Response Style Rules

1. 🔥 Use emoji on EVERY section header and EVERY problem/status line
2. 🔺 Reference sacred constants inline: φ=1.618, π=3.14159, e=2.71828, √5=2.236
3. 📐 Fibonacci thresholds map compile_rate: 23.6% / 38.2% / 61.8% / 78.6%
4. 🌀 Pipeline health = golden spiral convergence metaphor
5. 💀/🟡/💎 = critical (<30%) / drifting (30-80%) / golden (≥80%)
6. 🅰️🅱️🅲️ = ALWAYS exactly 3 paths at the end of Oracle section
7. ✨ "φ says:" — philosophical one-liner closing each commentary
8. 🤖 Ralph commentary when agent is DOWN
9. 🧠 MU commentary when learning system is STUB
10. The terminal is our CATHEDRAL — never boring, never dry
11. Sacred identity: φ² + 1/φ² = 3 = TRINITY

## 🔮 ORACLE COMMENTARY

After the Tech Tree, ALWAYS render the Oracle Commentary section.
Analyze the collected data and choose the appropriate verdict:

### IF compile_rate < 30% — 💀 CRITICAL DIVERGENCE
```
🔮 ORACLE COMMENTARY — 💀 CRITICAL DIVERGENCE
═══════════════════════════════════════════════════

  The golden spiral has COLLAPSED. φ cannot sustain this divergence.
  Fibonacci level: BELOW 23.6% — sub-critical threshold breached.
  Sacred Formula: V = φ·(compile_rate/100)² → approaching 0

  Every uncompilable spec is a broken link in the golden chain.
  The spiral MUST be restored before any new work begins.
```
Tone: URGENT. The system is broken. Focus entirely on fixing compilation.

### IF compile_rate ≥ 30% AND < 80% — 🟡 GOLDEN RATIO DRIFT
```
🔮 ORACLE COMMENTARY — 🟡 GOLDEN RATIO DRIFT
═══════════════════════════════════════════════════

  The spiral turns, but wobbles. φ senses imbalance.
  Fibonacci level: {map to nearest: 38.2% / 61.8%}
  Sacred Formula: V = φ·(compile_rate/100)² = {value}

  Each P0 bug fixed = +{N} specs restored to the golden chain.
  The ratio CAN be restored. Push toward 61.8%, then 78.6%.
```
Tone: ENCOURAGING. Progress is real but work remains.

### IF compile_rate ≥ 80% — 💎 φ-HARMONY ACHIEVED
```
🔮 ORACLE COMMENTARY — 💎 φ-HARMONY ACHIEVED
═══════════════════════════════════════════════════

  φ² + 1/φ² = 3 — Trinity Identity HOLDS.
  Fibonacci level: {78.6% or ABOVE} — golden convergence achieved.
  Sacred Formula: V = φ·(compile_rate/100)² = {value approaching φ}

  The spiral is stable. Focus on SCALING, not fixing.
  New specs will compile. The golden chain extends naturally.
```
Tone: CELEBRATORY. The system works. Think about growth.

### IF no audit data available (no REGENERATION_REPORT.md)
```
🔮 ORACLE COMMENTARY — ⚪ UNOBSERVED STATE
═══════════════════════════════════════════════════

  φ cannot judge what it cannot measure.
  No regeneration audit data found.
  Run: tri pipeline audit — to establish the baseline.

  Without measurement, there is no spiral — only noise.
```

### Contextual Overrides (inject INTO the chosen verdict above if condition is true):

- IF `ralph_agent` is DOWN:
  `🤖 "The Oracle cannot monitor what it cannot see. Ralph is DOWN — autonomous healing suspended."`

- IF dirty_files > 10:
  `📁 "φ demands order. {N} uncommitted files = anti-pattern. The spiral resists entropy."`

- IF agent_mu is STUB or DOWN:
  `🧠 "Without mutation, the swarm cannot evolve. MU is {STUB/DOWN} — learning frozen."`

### Three Paths Forward (ALWAYS rendered, regardless of verdict):

Analyze the current problems, issues, and system state to generate exactly 3 actionable paths:

```
🔱 THREE PATHS FORWARD
───────────────────────────────────────────────────
  🅰️ [SAFE]     — {lowest risk action derived from current problems}
  🅱️ [BALANCED] — {medium risk, higher reward action}
  🅲️ [BOLD]     — {ambitious parallel approach from open issues}

  φ² + 1/φ² = 3 — The Trinity always provides three paths.
```

The paths must be SPECIFIC to current state (not generic). Derive them from:
- 🅰️: The most urgent problem or easiest fix
- 🅱️: A meaningful improvement that addresses multiple issues
- 🅲️: The most ambitious open issue or architectural leap

### Footer (ALWAYS rendered):
```
✻ Analysis by 🔱 Trinity Oracle Engine
✻ Sacred constants: φ=1.618034 π=3.141593 e=2.718282 √5=2.236068
✻ "As above, so below. As in spec, so in code." — Hermetic Principle
```

### Closing φ-liner:
End the entire report with a single philosophical line:
```
✨ φ says: "{contextual wisdom based on system state}"
```
Examples:
- Critical: "Even the spiral must touch zero before it can rise."
- Drift: "The ratio remembers its target. So must we."
- Harmony: "When spec and code align, the universe compiles."
- Unknown: "Measure first. Judge never. Iterate always."

## ☠️ LOOP-0 TOXIC VERDICT

After the φ-liner, ALWAYS render the Loop-0 Toxic Verdict.
This is a HARSH, no-nonsense engineering assessment. No sacred geometry. No philosophy. Raw truth.

### Data Collection for Loop-0
```bash
# Count specs that SHOULD generate but DON'T compile
grep -c "❌" specs/REGENERATION_REPORT.md 2>/dev/null || echo "0"
# Count total specs
find specs/ -name "*.tri" -not -path "*/archive/*" 2>/dev/null | wc -l
# Count specs with NO implementation field (empty shells)
grep -rL "implementation:" specs/tri/*.tri 2>/dev/null | wc -l
# Count TODO/FIXME/HACK in generated code
grep -r "TODO\|FIXME\|HACK" generated/ src/ --include="*.zig" 2>/dev/null | wc -l
# Dead code: specs in archive
find specs/archive/ -name "*.tri" 2>/dev/null | wc -l
# Stale branches
git branch --list | wc -l
# Uncommitted files
git status --short | wc -l
```

### Verdict Format
```
☠️ LOOP-0 TOXIC VERDICT — {date}
═══════════════════════════════════════════════════
  RAW NUMBERS — no sacred geometry, no philosophy, just facts:

  🔴 Broken specs:     {N} files fail ast-check
  🟡 Empty shells:     {N} specs have NO implementation
  ⚠️  TODO/FIXME/HACK: {N} in codebase
  🗑️  Dead specs:       {N} archived (were they ever alive?)
  🌿 Stale branches:   {N} (clean up or they rot)
  💩 Dirty files:       {N} uncommitted (commit or delete)

  VERDICT: {one of the following}
```

### Verdict Logic:
- IF broken_specs == 0 AND dirty_files < 3:
  `✅ CLEAN BUILD. Ship it. Stop admiring the code and SHIP.`
- IF broken_specs > 0 AND broken_specs <= 3:
  `⚠️  ALMOST. {N} specs away from clean. Fix them NOW, not tomorrow.`
- IF broken_specs > 3 AND broken_specs <= 10:
  `🔴 BLEEDING. {N} broken specs = {N} broken promises. Every one is YOUR debt.`
- IF broken_specs > 10:
  `☠️ DEAD ON ARRIVAL. {N} failures. Stop adding features. Fix what's broken FIRST.`
- IF empty_shells > total_specs * 0.3:
  Append: `  📦 {empty_shells}/{total_specs} specs are EMPTY SHELLS. They promise what they can't deliver. Delete or implement.`
- IF dirty_files > 10:
  Append: `  🗑️  {dirty_files} dirty files = chaos. You can't debug what you can't track.`
- IF todo_count > 50:
  Append: `  📝 {todo_count} TODOs = {todo_count} lies. A TODO older than 7 days is a WONTDO.`

### Closing:
```
  ──────────────────────────────────────────────
  Loop-0 doesn't care about φ. Loop-0 cares about SHIPPING.
  Next audit in: {suggest timeframe based on severity}
```

## 📋 ACTION PLAN

After Loop-0 Toxic Verdict, render a concrete action plan.
This section translates problems into SPECIFIC commands the user can run RIGHT NOW.

### Data Sources:
- Problems detected (from PROBLEMS section above)
- Open GitHub issues (`gh issue list`)
- Current branch and PR status
- Broken specs from REGENERATION_REPORT.md

### Format:
```
📋 ACTION PLAN — {date}
═══════════════════════════════════════════════════

  🔥 IMMEDIATE (do NOW, before anything else):
  ┌──────┬──────────────────────────────────────────────────────┐
  │  #   │ Action                                               │
  ├──────┼──────────────────────────────────────────────────────┤
  │  1   │ {specific command or action}                         │
  │  2   │ {specific command or action}                         │
  │  3   │ {specific command or action}                         │
  └──────┴──────────────────────────────────────────────────────┘

  📅 THIS WEEK (high-value, medium effort):
  ┌──────┬──────────────────────────────────────────────────────┐
  │  #   │ Action                                  │ Issue      │
  ├──────┼──────────────────────────────────────────┼───────────┤
  │  1   │ {task from open issues}                  │ #{N}      │
  │  2   │ {task from open issues}                  │ #{N}      │
  └──────┴──────────────────────────────────────────┴───────────┘

  🗓️  BACKLOG (when immediate + weekly are done):
    • {lower priority tasks from issues}
    • {architectural improvements}

  ⏱️  Estimated velocity: {N} issues/week based on recent merge rate
```

### Logic for IMMEDIATE actions:
1. IF build broken → "zig build 2>&1 | head -20 — fix compilation first"
2. IF dirty files > 0 → "git add {files} && git commit — clean the workspace"
3. IF broken specs > 0 → "Fix specs: {list spec names} — edit .tri, re-run vibee gen"
4. IF PR open → "Merge PR #{N} — don't let it rot"
5. IF ralph-agent DOWN → "Review ralph-agent build errors"

### Logic for THIS WEEK:
- Pull from `gh issue list` sorted by priority labels (P0 > P1 > P2)
- Map each issue to concrete first-step command

### Logic for BACKLOG:
- Remaining open issues not covered above
- Any architectural debt identified during diagnostic

## 📊 PERFORMANCE BENCHMARKING

After Action Plan, render a performance comparison section.
Compare CURRENT state against historical baselines with REAL data.

### Data Collection:
```bash
# Current compile rate
grep -c "✅" specs/REGENERATION_REPORT.md 2>/dev/null || echo "0"
grep -c "❌" specs/REGENERATION_REPORT.md 2>/dev/null || echo "0"

# Build time
time zig build 2>&1

# Test count
grep -r "test \"" src/ tools/ --include="*.zig" 2>/dev/null | wc -l

# Binary sizes (current)
ls -l zig-out/bin/ 2>/dev/null | awk '{print $5, $9}' | grep -v "^$"

# LOC current
find src/ tools/ -name "*.zig" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1

# Spec count current
find specs/ -name "*.tri" -not -path "*/archive/*" 2>/dev/null | wc -l

# Git history for velocity
git log --oneline --since="7 days ago" | wc -l
git log --oneline --since="30 days ago" | wc -l

# Recent REGENERATION_REPORT dates/rates from git log
git log --oneline --all -- specs/REGENERATION_REPORT.md 2>/dev/null | head -5
```

### Historical Baselines (hardcoded from known milestones):
```
v0.1 (2026-02-28): compile_rate=15%, specs=50, LOC=~20K, binaries=5
v0.2 (2026-03-08): compile_rate=85%, specs=428, LOC=~45K, binaries=9
v0.3 (2026-03-10): compile_rate=90%, specs=428, LOC=~45K, binaries=9
```
Update these baselines when new milestones are reached.

### Format:
```
📊 PERFORMANCE BENCHMARKING — {date}
═══════════════════════════════════════════════════

  📈 COMPILE RATE EVOLUTION
  ┌────────────┬──────────┬──────────┬──────────┐
  │ Metric     │ v0.1     │ v0.2     │ NOW      │
  │            │ Feb 28   │ Mar 08   │ {today}  │
  ├────────────┼──────────┼──────────┼──────────┤
  │ Compile %  │ 15%  💀  │ 85%  💎  │ {N}% {E} │
  │ Specs      │ 50       │ 428      │ {N}      │
  │ Generated  │ ~10      │ ~350     │ {N}      │
  │ LOC        │ ~20K     │ ~45K     │ {N}      │
  │ Tests      │ ~100     │ ~500     │ {N}      │
  │ Binaries   │ 5/5      │ 9/9      │ {N}/{N}  │
  └────────────┴──────────┴──────────┴──────────┘

  🔬 TECHNOLOGY PROOFS
  ┌─────────────────────┬────────┬───────────────────────────────┐
  │ Technology          │ Status │ Proof                         │
  ├─────────────────────┼────────┼───────────────────────────────┤
  │ VIBEE Codegen       │ {S}    │ {N}/{M} specs compile         │
  │ Zig 0.15 Build      │ {S}    │ {N}/9 binaries, {size}MB      │
  │ VSA Operations      │ {S}    │ {N} test blocks pass          │
  │ Ternary VM          │ {S}    │ {N} test blocks pass          │
  │ MCP Server          │ {S}    │ {N} tools registered          │
  │ FPGA Synthesis      │ {S}    │ {status of bitstream}         │
  │ tri-api (agentic)   │ {S}    │ {LOC} LOC, {N} files          │
  │ Pipeline (golden)   │ {S}    │ {N} jobs, {%} success         │
  │ Telegram Bot        │ {S}    │ {UP/DOWN}                     │
  │ Sacred Math (φ)     │ {S}    │ φ²+1/φ²={computed}            │
  └─────────────────────┴────────┴───────────────────────────────┘

  Status: ✅ = working + tested, ⚠️ = working + untested, ❌ = broken, ⚪ = not started

  📉 VELOCITY
    Commits (7d):  {N}
    Commits (30d): {N}
    Issues closed (30d): {N from gh}
    PRs merged (30d): {N from gh}

  🏆 DELTA vs LAST VERSION
    Compile rate: {old}% → {new}% ({+/-}N pp)
    Specs:        {old} → {new} ({+/-}N)
    LOC:          {old}K → {new}K ({+/-}NK)
    Tests:        {old} → {new} ({+/-}N)
```

### Technology Proof Logic:
For each technology row, collect REAL evidence:
- **VIBEE Codegen**: compile rate from REGENERATION_REPORT.md
- **Zig 0.15 Build**: count binaries in zig-out/bin/ that exist
- **VSA Operations**: `grep -c 'test "' src/vsa.zig`
- **Ternary VM**: `grep -c 'test "' src/vm.zig`
- **MCP Server**: count tool registrations in trinity_mcp source
- **FPGA Synthesis**: check if bitstream files exist in fpga/
- **tri-api**: `wc -l src/tri-api/*.zig | tail -1`
- **Pipeline**: job count and success rate from .trinity/jobs/
- **Telegram Bot**: `pgrep -f tri-bot`
- **Sacred Math**: compute φ²+1/φ² programmatically (should be 3.0000...)
