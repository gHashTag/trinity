---
name: tri
description: Full TRI swarm diagnostic — builds, binaries, issues, agent status, code metrics. Run for system health check.
argument-hint: [focus-area]
allowed-tools: Bash(zig *), Bash(ls *), Bash(wc *), Bash(grep *), Bash(gh *), Bash(pgrep *), Bash(cat *), Bash(find *), Bash(git *), Bash(date *), Bash(test *), Bash(tail *), Bash(for *), Bash(python3 *), Bash(echo *), Read, Edit, Write
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

## Data Collection — ALL DYNAMIC

CRITICAL: Every number in the report MUST come from a command run at diagnostic time.
NEVER hardcode numbers, NEVER use stale data, NEVER guess. If a command fails, show "N/A".

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

# Compile rate from last audit (KEY METRIC — SINGLE CANONICAL SOURCE)
# PASS = ✅ count, FAIL = ❌ count, TOTAL = PASS + FAIL (from REGENERATION_REPORT.md)
# This is THE compile rate. No other number. V-formula uses these exact numbers.
PASS=$(grep -c "✅" specs/REGENERATION_REPORT.md 2>/dev/null || echo "0")
FAIL=$(grep -c "❌" specs/REGENERATION_REPORT.md 2>/dev/null || echo "0")
TOTAL=$((PASS + FAIL))
RATE=$(( TOTAL > 0 ? PASS * 100 / TOTAL : 0 ))
echo "COMPILE_PASS:$PASS COMPILE_FAIL:$FAIL COMPILE_TOTAL:$TOTAL COMPILE_RATE:$RATE"

# Known bugs from regeneration report
grep -A1 "^###.*P[012]" specs/REGENERATION_REPORT.md 2>/dev/null || echo "NO_DATA"

# Job history: last 10 jobs with status
for dir in $(ls -t .trinity/jobs/ 2>/dev/null | head -10); do cat ".trinity/jobs/$dir/metadata.json" 2>/dev/null; done

# Error patterns from ralph memory — COUNT dynamically
grep -c "^###" .ralph/memory/REGRESSION_PATTERNS.md 2>/dev/null || echo "0"
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
gh issue list --state open --json number,title,labels --limit 15 2>/dev/null

# Velocity: PRs merged in last 30 days (DYNAMIC date)
SINCE_30D=$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d "30 days ago" +%Y-%m-%d)
gh pr list --state merged --search "merged:>=$SINCE_30D" --json number --limit 100 2>/dev/null | python3 -c "import json,sys; print(f'PR_MERGED_30D:{len(json.load(sys.stdin))}')" 2>/dev/null || echo "PR_MERGED_30D:N/A"
# Issues closed in last 30 days
gh issue list --state closed --search "closed:>=$SINCE_30D" --json number --limit 100 2>/dev/null | python3 -c "import json,sys; print(f'ISSUES_CLOSED_30D:{len(json.load(sys.stdin))}')" 2>/dev/null || echo "ISSUES_CLOSED_30D:N/A"
```

### System Status
```bash
pgrep -f tri-bot && echo "RUNNING" || echo "STOPPED"
pgrep -f ralph-agent && echo "RUNNING" || echo "STOPPED"
ls ~/.tri-api/sessions/*.json 2>/dev/null | wc -l
test -f CLAUDE.md && echo "EXISTS" || echo "MISSING"
test -f .tri-api/settings.json && echo "EXISTS" || echo "MISSING"
```

### Technology Proofs — LIVE CHECKS (run ALL of these)
```bash
# VSA: count test blocks AND check if they parse (ast-check, works in Zig 0.15)
grep -c 'test "' src/vsa.zig 2>/dev/null || echo "0"
zig ast-check src/vsa.zig 2>&1; echo "VSA_CHECK:$?"

# Ternary VM: count test blocks AND check parsing
grep -c 'test "' src/vm.zig 2>/dev/null || echo "0"
zig ast-check src/vm.zig 2>&1; echo "VM_CHECK:$?"

# MCP Server: count registered tools dynamically
grep -c 'tool_name\|"name"' tools/mcp/trinity_mcp/trinity_mcp.zig 2>/dev/null || \
  grep -rc 'registerTool\|addTool\|tool_name' tools/mcp/trinity_mcp/ 2>/dev/null | \
  awk -F: '{s+=$2}END{print s}'

# FPGA: check bitstream exists AND size
ls -lh fpga/openxc7-synth/*.bit 2>/dev/null || echo "NO_BITSTREAM"

# tri-api: LOC + file count
wc -l src/tri-api/*.zig 2>/dev/null | tail -1
ls src/tri-api/*.zig 2>/dev/null | wc -l

# Pipeline jobs: count + success rate
ls .trinity/jobs/ 2>/dev/null | wc -l
grep -rl '"state":"completed"' .trinity/jobs/*/metadata.json 2>/dev/null | wc -l

# Telegram bot: live check
pgrep -f tri-bot > /dev/null 2>&1 && echo "BOT:UP" || echo "BOT:DOWN"

# Sacred Math: compute φ²+1/φ² live
python3 -c "phi=(1+5**0.5)/2; print(f'PHI_IDENTITY:{phi**2+1/phi**2:.6f}')" 2>/dev/null || echo "PHI_IDENTITY:3.000000"

# Empty shells: spec has NO corresponding .zig in generated/ with >10 LOC
# Method: count .tri specs that lack a generated .zig counterpart OR whose .zig is <10 lines
python3 -c "
import os, glob
specs = glob.glob('specs/tri/*.tri')
empty = 0
for s in specs:
    name = os.path.splitext(os.path.basename(s))[0]
    zig = f'generated/{name}.zig'
    if not os.path.exists(zig):
        empty += 1
    elif sum(1 for _ in open(zig)) < 10:
        empty += 1
print(f'EMPTY_SHELLS:{empty}/{len(specs)}')
" 2>/dev/null || echo "EMPTY_SHELLS:N/A"

# TODO/FIXME/HACK count: LIVE scan (ONLY manual src/ and tools/, EXCLUDE generated/ and zig-out/)
grep -r 'TODO\|FIXME\|HACK' src/ tools/ --include="*.zig" 2>/dev/null | grep -v 'zig-cache\|zig-out' | wc -l
```

### MU Agent Detection — LIVE
```bash
# Check if MU agent binary exists and has error detection code
test -f src/agent_mu/fixer.zig && echo "MU_CODE:EXISTS" || echo "MU_CODE:MISSING"
grep -c 'error_pattern\|anti_pattern\|ErrorPattern' src/agent_mu/*.zig 2>/dev/null || echo "MU_PATTERNS_CODE:0"

# Check swarm_state for MU agent registration
python3 -c "
import json
with open('.trinity/swarm_state.json') as f:
    d=json.load(f)
agents=[a for a in d.get('agents',[]) if 'mu' in a.get('name','').lower()]
print(f'MU_AGENTS:{len(agents)}')
print(f'MU_STATUS:{agents[0][\"status\"] if agents else \"NONE\"}')" 2>/dev/null || echo "MU_AGENTS:0"

# Count actual patterns in ralph memory (LIVE, not cached)
grep -c '^---$' .ralph/memory/REGRESSION_PATTERNS.md 2>/dev/null || echo "PATTERN_COUNT:0"
grep -c '^### ' .ralph/memory/REGRESSION_PATTERNS.md 2>/dev/null || echo "PATTERN_HEADERS:0"
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
  Compile:    {PASS}/{TOTAL} = {RATE}% {🟢 if ≥80%, 🟡 if ≥50%, 🔴 if <50%}  ← KEY METRIC (single canonical number)

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

#### Faculty Data Collection — ALL LIVE
```bash
# Ralph: build exit code (from Build Health) + last commit message
git log --oneline -1

# Scholar: check API key + code existence
echo "PKEY:${PERPLEXITY_API_KEY:+SET}"
echo "PKEY_UNSET:${PERPLEXITY_API_KEY:-UNSET}"
test -f src/tri/perplexity_scholar.zig && echo "SCHOLAR_CODE:READY" || echo "SCHOLAR_CODE:MISSING"

# MU: swarm state (from swarm_state.json) + code check + pattern count
test -f src/agent_mu/fixer.zig && echo "MU_FIXER:EXISTS" || echo "MU_FIXER:MISSING"
python3 -c "
import json
with open('.trinity/swarm_state.json') as f:
    d=json.load(f)
print(f'SWARM_AGENTS:{len(d.get(\"agents\",[]))}')
print(f'SWARM_TASKS:{len(d.get(\"tasks\",[]))}')
assigned=[t for t in d.get('tasks',[]) if t.get('assigned')]
print(f'SWARM_ASSIGNED:{len(assigned)}')" 2>/dev/null || echo "SWARM_AGENTS:0"

# MU pattern count: actual entries in ralph memory
grep -c '^### ' .ralph/memory/REGRESSION_PATTERNS.md 2>/dev/null || echo "0"

# Dynamic issue references for Faculty Commentary (NEVER hardcode issue numbers)
# Find open issues by agent label — used in MU/Swarm/Scholar commentary
MU_ISSUE=$(gh issue list --state open --label "agent:mu" --json number --limit 1 -q '.[0].number' 2>/dev/null || echo "")
SWARM_ISSUE=$(gh issue list --state open --label "agent:swarm" --json number --limit 1 -q '.[0].number' 2>/dev/null || echo "")
echo "MU_OPEN_ISSUE:${MU_ISSUE:-NONE}"
echo "SWARM_OPEN_ISSUE:${SWARM_ISSUE:-NONE}"

# Linter: vibee binary check
test -f zig-out/bin/vibee && echo "LINTER:UP" || echo "LINTER:DOWN"
```

IMPORTANT: Faculty "Last Action" column MUST use live data:
- Ralph: "Build {exit}/9, last: {git log -1 msg}"  — from build + git
- Scholar: "Code {EXISTS/MISSING}, API key {SET/UNSET}" — from checks above
- MU: "{N} patterns in memory, fixer {EXISTS/MISSING}" — from grep + file check
- Oracle: "V={computed}, compile {rate}%" — from REGENERATION_REPORT
- Swarm: "{N} tasks, {N} assigned, {N} agents" — from swarm_state.json
- Linter: "vibee {size}, {pass}/{total} specs" — from binary + report

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

#### Faculty Status Logic — derived from LIVE checks above
- **Ralph**: 🟢 UP if build EXIT:0 AND 9 binaries exist. ⚠️ if build fails. From: `zig build` exit code.
- **Scholar**: 🟢 UP if PKEY:SET AND SCHOLAR_CODE:READY. ⚠️ CODE_READY if code exists but no key. ⬜ TBD if SCHOLAR_CODE:MISSING. From: env check + file check.
- **MU**: 🟢 UP if SWARM_AGENTS > 0 with MU agent AND MU_FIXER:EXISTS. ⚪ STUB if agents=[] but fixer code exists. ❌ DOWN if no code. From: swarm_state.json + file check.
- **Oracle**: Always 🟢 UP (computed from compile_rate). From: REGENERATION_REPORT.md.
- **Swarm**: 🟢 UP if SWARM_ASSIGNED > 0. ⚪ TBD if SWARM_TASKS > 0 but none assigned. ⬜ OFF if no tasks. From: swarm_state.json.
- **Linter**: 🟢 UP if LINTER:UP. ❌ DOWN if LINTER:DOWN. From: `test -f zig-out/bin/vibee`.

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
- Always: "V = φ·(PASS/TOTAL)² = {value}. Distance to φ: {1.618-value}." (use actual PASS/TOTAL from REGENERATION_REPORT.md, NOT /100)
- IF compile_rate > 80%: append "System in φ-harmony. Focus on scaling."
- IF compile_rate < 50%: append "⚠️ Below φ⁻¹. Fix generator urgently."

**Linter** (reads REGENERATION_REPORT):
- Always: "{pass}/{total} pass. {fail} failures."
- IF fail > 0: append "Recommendation: fix {fail} specs → clean input for generator."

**MU** (reads .ralph/memory/ + checks open issues):
- Run: `gh issue list --state open --label "agent:mu" --json number,title --limit 1 2>/dev/null` to find current MU issue
- IF MU == STUB AND open MU issue exists: "💤 SLEEPING. {N} patterns logged manually. Every pipeline error = lost experience. Wake me: #{open_issue}."
- IF MU == STUB AND no open MU issue: "💤 SLEEPING. {N} patterns logged manually. Every pipeline error = lost experience. Create an issue to wake me."
- IF MU == UP: "🧠 ACTIVE. {N} patterns tracked. Last: {last pattern}."

**Scholar** (checks PERPLEXITY_API_KEY):
- IF key SET and code exists: "📚 ACTIVE. Ready to research Zig errors."
- IF code exists but no key: "📚 CODE READY! Set PERPLEXITY_API_KEY to activate. When Ralph hits unknown errors — I find answers in 2 seconds."
- IF no code: "📚 NOT HIRED. Deploy: implement perplexity_scholar.zig → set API key."

**Swarm** (reads swarm_state.json + checks open issues):
- Run: `gh issue list --state open --label "agent:swarm" --json number,title --limit 1 2>/dev/null` to find current Swarm issue
- IF tasks with assigned agents: "🐝 ACTIVE. {N} tasks tracked, {N} assigned."
- IF no agents AND open Swarm issue exists: "🥚 EMBRYONIC. Tasks decomposed manually. With me: 1 issue → 5 subtasks → 3 agents → 5× faster. Activate: #{open_issue}."
- IF no agents AND no open Swarm issue: "🥚 EMBRYONIC. Tasks decomposed manually. With me: 1 issue → 5 subtasks → 3 agents → 5× faster. Create an issue to activate."

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
- ralph-agent STOPPED: "ralph-agent DOWN — no autonomous agent. Recovery: nohup ./zig-out/bin/ralph-agent &"
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
  Sacred Formula: V = φ·(PASS/TOTAL)² → approaching 0

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
  Sacred Formula: V = φ·(PASS/TOTAL)² = {value}

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
  Sacred Formula: V = φ·(PASS/TOTAL)² = {value approaching φ}

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
# Count empty shells: specs with NO generated .zig counterpart or .zig <10 LOC
python3 -c "
import os, glob
specs = glob.glob('specs/tri/*.tri')
empty = 0
for s in specs:
    name = os.path.splitext(os.path.basename(s))[0]
    zig = f'generated/{name}.zig'
    if not os.path.exists(zig) or sum(1 for _ in open(zig)) < 10:
        empty += 1
print(f'LOOP0_EMPTY:{empty}/{len(specs)}')
" 2>/dev/null || echo "LOOP0_EMPTY:N/A"
# Count TODO/FIXME/HACK in MANUAL code only (exclude generated/, zig-out/, zig-cache/)
grep -r "TODO\|FIXME\|HACK" src/ tools/ --include="*.zig" 2>/dev/null | grep -v 'zig-cache\|zig-out' | wc -l
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

### Historical Baselines — READ FROM FILE (not hardcoded)
```bash
# Read baselines from persistent file
cat .trinity/baselines.json 2>/dev/null || echo "NO_BASELINES"

# Get git tag history for version dates
git tag --sort=-creatordate --format='%(refname:short) %(creatordate:short)' 2>/dev/null | head -5

# Get historical compile rates from git log of REGENERATION_REPORT.md
git log --oneline --all -- specs/REGENERATION_REPORT.md 2>/dev/null | head -5
```

The baselines file `.trinity/baselines.json` stores version snapshots as JSON array:
```json
[{"version":"v0.1","date":"2026-02-28","compile_rate":15,"specs":50,"loc":20000,"tests":100,"binaries":5},...]
```

**AUTO-UPDATE RULE**: After each /tri run, if the current compile_rate differs from
the latest baseline by ≥5pp, OR specs count changed by ≥20, OR binaries changed,
append a new baseline entry to `.trinity/baselines.json` with current data.
Use `python3` to read, append, and write the JSON file.

Show the last 2 baselines + NOW column in the evolution table. If no baselines file
exists, show only the NOW column with a note "No historical data — first run".

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

  📉 VELOCITY (all counts from DYNAMIC date ranges, not hardcoded)
    Commits (7d):  {N} (from: git log --since="7 days ago")
    Commits (30d): {N} (from: git log --since="30 days ago")
    Issues closed (30d): {ISSUES_CLOSED_30D} (from: gh issue list --search "closed:>=$SINCE_30D")
    PRs merged (30d): {PR_MERGED_30D} (from: gh pr list --search "merged:>=$SINCE_30D")
    Velocity: {PR_MERGED_30D / 4.3} PR/week

  🏆 DELTA vs LAST VERSION
    Compile rate: {old}% → {new}% ({+/-}N pp)
    Specs:        {old} → {new} ({+/-}N)
    LOC:          {old}K → {new}K ({+/-}NK)
    Tests:        {old} → {new} ({+/-}N)
```

### Technology Proof Logic — ALL FROM LIVE COMMANDS:

Each row's status and proof MUST come from the "Technology Proofs — LIVE CHECKS" commands above.
Map command outputs to statuses:

- **VIBEE Codegen**: ✅ if compile_rate ≥ 80%, ⚠️ if ≥ 50%, ❌ if < 50%. Proof: "{pass}/{total} specs compile"
- **Zig 0.15 Build**: ✅ if build EXIT:0 AND all 9 binaries exist. ❌ if EXIT:1. Proof: "{N}/9 binaries, {sum of sizes}MB"
- **VSA Operations**: ✅ if VSA_CHECK:0 (ast-check passes). ⚠️ if test count > 0 but VSA_CHECK != 0. ❌ if no tests. Proof: "{N} test blocks, ast-check: {OK/FAIL}"
- **Ternary VM**: ✅ if VM_CHECK:0 (ast-check passes). Same logic as VSA. Proof: "{N} test blocks, ast-check: {OK/FAIL}"
- **MCP Server**: ✅ if trinity-mcp binary exists AND tool count > 0. Proof: "{N} tools, binary {size}MB"
- **FPGA Synthesis**: ✅ if .bit file exists. ⚪ if no bitstream. Proof: "{filename} ({size})"
- **tri-api**: ✅ if tri-api binary exists. Proof: "{LOC} LOC, {N} files"
- **Pipeline**: ✅ if success_rate ≥ 80%, ⚠️ if > 0 jobs, ❌ if 0 jobs. Proof: "{completed}/{total} jobs, {%}%"
- **Telegram Bot**: ✅ if BOT:UP. ❌ if BOT:DOWN. Proof: "PID active" or "not running"
- **Sacred Math**: ✅ always (computed). Proof: "φ²+1/φ²={PHI_IDENTITY value}"

NEVER use "API ready", "working + untested" or similar vague phrases unless the
actual command returned inconclusive results.

### Auto-Update Baselines
After rendering the report, check if a new baseline should be saved:
```bash
python3 -c "
import json, os, time
baseline_path = '.trinity/baselines.json'
baselines = json.load(open(baseline_path)) if os.path.exists(baseline_path) else []
last = baselines[-1] if baselines else {}
# Current values — REPLACE these with actual collected data
current = {
    'version': 'v' + time.strftime('%Y%m%d'),
    'date': time.strftime('%Y-%m-%d'),
    'compile_rate': COMPILE_RATE,  # from grep counts
    'specs': SPEC_COUNT,
    'generated': GEN_COUNT,
    'loc': LOC_COUNT,
    'tests': TEST_COUNT,
    'binaries': BIN_COUNT,
    'binaries_total': 9
}
# Only save if significant change from last baseline
need_save = (
    not last
    or abs(current['compile_rate'] - last.get('compile_rate', 0)) >= 5
    or abs(current['specs'] - last.get('specs', 0)) >= 20
    or current['binaries'] != last.get('binaries', 0)
)
if need_save:
    baselines.append(current)
    with open(baseline_path, 'w') as f:
        json.dump(baselines, f, indent=2)
    print(f'BASELINE_SAVED: {current[\"version\"]}')
else:
    print('BASELINE_SKIP: no significant change')
"
```
Replace COMPILE_RATE, SPEC_COUNT, etc. with actual values from data collection.
This ensures the evolution table always has real historical data.
