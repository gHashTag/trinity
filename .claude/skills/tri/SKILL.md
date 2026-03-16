---
name: tri
description: TRI status dashboard — agent thought mode by default, /tri full for visual dashboard
argument-hint: [short] [full] [audit] [coverage] [lang:ru|en] [humor|prof|toxic|zen]
allowed-tools: Bash(zig *), Bash(ls *), Bash(wc *), Bash(grep *), Bash(gh *), Bash(pgrep *), Bash(cat *), Bash(find *), Bash(git *), Bash(date *), Bash(test *), Bash(tail *), Bash(for *), Bash(python3 *), Bash(echo *), Bash(curl *), Read, Edit, Write
---

For system state collection, follow `.claude/skills/_shared/data_collection.md`.
For output formatting conventions, follow `.claude/skills/_shared/output_format.md`.
For cached system state, follow `.claude/skills/_shared/system_snapshot.md`.

## Mode Detection

Check $ARGUMENTS for mode:
- If $ARGUMENTS contains "full" → **MODE=FULL** (strip "full" from arguments, pass rest through)
- If $ARGUMENTS contains "short" → **MODE=COMPACT** (explicit short/conversational mode)
- If $ARGUMENTS contains "coverage" → **MODE=COVERAGE** (CLI/MCP coverage + duplicates + board audit)
- Otherwise → **MODE=COMPACT**

"audit" and "lang:xx" work in BOTH modes.

Run a diagnostic of the TRI system. In COMPACT mode, output ~15 lines.
In FULL mode, output the complete diagnostic report.

If $ARGUMENTS contains "lang:ru" or "lang:en", update `.claude/skills/tri/lang.md` to that language and use it.
If $ARGUMENTS is "ru" or "en" alone, treat as language switch.
In FULL mode, if remaining $ARGUMENTS is provided, focus the diagnostic on that area.

### Mood Detection

If $ARGUMENTS contains "humor", "prof", "toxic", or "zen" → set **MOOD** to that value and update `.claude/skills/tri/mode.md` with `mood: {value}`.
If no mood keyword in $ARGUMENTS → read current mood from `.claude/skills/tri/mode.md` (default: `humor`).

## 🔄 Audit Mode

If $ARGUMENTS contains "audit", run a FRESH regeneration audit BEFORE the diagnostic:

```bash
python3 << 'AUDIT_EOF'
import subprocess, os, glob, time
specs = sorted(glob.glob('specs/tri/*.tri'))
results = []
for s in specs:
    name = os.path.splitext(os.path.basename(s))[0]
    try: subprocess.run(['zig-out/bin/vibee', 'gen', s], capture_output=True, timeout=30)
    except: pass
    zig = f'generated/{name}.zig'
    if not os.path.exists(zig):
        results.append((name, 'no output'))
        continue
    try:
        r = subprocess.run(['zig', 'ast-check', zig], capture_output=True, timeout=30)
        results.append((name, 'pass' if r.returncode == 0 else 'ast-check failed'))
    except: results.append((name, 'timeout'))
passed = sum(1 for _,s in results if s == 'pass')
total = len(results)
pct = passed*100//total if total else 0
emoji = '💎' if pct>=80 else ('🟡' if pct>=50 else '💀')
with open('specs/REGENERATION_REPORT.md','w') as f:
    f.write(f'# Regeneration Audit Report\n\n**Date:** {int(time.time())}\n**Sample:** {total} specs\n**Tool:** vibee gen + zig ast-check\n\n## Results\n\n| # | Spec | Status |\n|---|------|--------|\n')
    for i,(name,status) in enumerate(results,1):
        icon = '✅' if status=='pass' else f'❌ {status}'
        f.write(f'| {i} | {name} | {icon} |\n')
    f.write(f'\n## Summary\n\n- **Compiled:** {passed}/{total} = **{pct}%** {emoji}\n- **Failed:** {total-passed}\n')
print(f'AUDIT_COMPLETE: {passed}/{total} = {pct}%')
AUDIT_EOF
```

Then proceed with normal diagnostic report using fresh data.

## 📊 Coverage Mode (when MODE=COVERAGE)

**If MODE=COVERAGE, render ONLY this section, then STOP. Do not continue to other modes.**

### Step 1: Extract CLI commands

```bash
cd /Users/playra/trinity-w1 && sed -n '/^pub fn parseCommand/,/^}/p' src/tri/tri_utils.zig | grep -oE '"[a-z][a-z0-9_-]*"' | tr -d '"' | sort -u
```

### Step 2: Extract MCP tools

```bash
cd /Users/playra/trinity-w1 && grep -o '"name":"[^"]*"' tools/mcp/trinity_mcp/server.zig | sed 's/"name":"//;s/"//' | sort -u
```

### Step 3: Duplicate detection

```bash
cd /Users/playra/trinity-w1 && \
echo "=== DELEGATE_CLI ===" && grep -c 'executeTriSimple' tools/mcp/trinity_mcp/server.zig && \
echo "=== DELEGATE_MODULE ===" && grep -cE 'swarm\.\w+\(|cloud_orch\.\w+|chain_engine|needle\.' tools/mcp/trinity_mcp/server.zig && \
echo "=== TOTAL_TOOLS ===" && grep -o '"name":"[^"]*"' tools/mcp/trinity_mcp/server.zig | wc -l
```

### Step 4: GitHub board sync status

```bash
cd /Users/playra/trinity-w1 && \
gh issue list -R gHashTag/trinity --state open --limit 20 --json number,title,labels --jq '.[] | select(.labels[].name == "status:in-progress") | "\(.number) \(.title)"' 2>&1 && \
echo "=== BOARD ===" && gh project item-list 6 --owner gHashTag --format json --limit 50 2>&1
```

### Step 5: Render report

Output a 3-paragraph report:

**P1: Coverage Score** — `{N}` CLI commands, `{N}` MCP tools, `{coverage}%` coverage. Note trend if previous data available.

**P2: Gaps & Duplicates** — Top 5 CLI commands without MCP exposure. Top 5 MCP tools without CLI counterpart. Number of inline duplicate implementations vs shared delegations. Dedup score.

**P3: Board Sync** — Open issues count, in-progress count, board items count, out-of-sync count. Stale issues (>7d without comments). Recommendations for fixes.

## 🌐 Language System

Before rendering the report, read `.claude/skills/tri/lang.md` to determine the output language.
The file contains `lang: ru` or `lang: en`. Default: `en`.

All section headers, labels, problem descriptions, oracle commentary, and φ-liners
MUST be rendered in the chosen language. Technical terms (binary names, commands, file paths) stay in English.

For the complete translation table, follow `.claude/skills/_shared/language.md`.


## 🚀 Compact Mode (default — when MODE=COMPACT)

**If MODE=COMPACT, render ONLY this section, then STOP. Do not continue to the full diagnostic.**

### Step 1: Get raw data from Zig engine

```bash
./zig-out/bin/tri faculty --raw 2>&1
```

This outputs structured key=value pairs. Full field list:

**Core:** `compile_pass`, `compile_total`, `compile_rate`, `compile_delta`, `build_ok`, `test_ok`, `dirty`, `active_faculty`, `open_issues`, `cycle`
**MU/Scholar:** `mu_wake`, `mu_errors`, `mu_fixes`, `mu_rules`, `scholar_wake`, `scholar_researched`, `scholar_fails`, `scholar_age_h`
**Observatory:** `v_number`, `v_zone`, `branch`, `binaries`, `pipeline`, `swarm`, `agent_<name>=<status>`
**Commits:** `commit=...` (up to 3 recent)

### Step 1.1: Consume Auto-Action Result

Check if a previous auto-action left a result:

```bash
cat .trinity/auto_action_result.json 2>/dev/null
```

**Logic:**
- If file exists, parse JSON and check `timestamp`
- If age < 15 minutes → store result for narration in Step 3:
  - `success: true` → narration line: `🔧 Авто: {details}` (e.g. "🔧 Авто: committed 45 files in 6 commits")
  - `success: false` → narration line: `❌ Авто-{action} провалился: {details}`
- Delete file after reading (consumed — one-shot)
- If file doesn't exist or age >= 15 minutes → skip

### Step 1.5: Delta Detection

After getting raw data, compare with previous snapshot to detect changes:

```bash
# Read previous snapshot (empty if first run)
cat .trinity/compact_prev.raw 2>/dev/null
```

```bash
# Check age of previous snapshot (seconds since modification)
python3 -c "import os,time; f='.trinity/compact_prev.raw'; print(int(time.time()-os.path.getmtime(f)) if os.path.exists(f) else -1)"
```

```bash
# Save current snapshot atomically
cp /dev/null .trinity/compact_prev.raw.tmp 2>/dev/null; ./zig-out/bin/tri faculty --raw > .trinity/compact_prev.raw.tmp 2>&1; mv .trinity/compact_prev.raw.tmp .trinity/compact_prev.raw
```

```bash
# Read no-change counter (for Case 2 action suggestions)
cat .trinity/compact_nochange_count 2>/dev/null || echo "0"
```

**No-change counter logic:**
- If Case 2 (no changes detected): increment counter, write to `.trinity/compact_nochange_count`
- If Case 1 or Case 3 (changes detected): reset counter to `0`, write to `.trinity/compact_nochange_count`

**TTL rule:** If previous snapshot is older than 3600 seconds (1 hour) or doesn't exist (`-1`), treat as **first run** (full narration).

**Delta computation:** Compare previous and current key=value pairs:

**Noise keys (always ignore changes):** `seconds_ago`, `mu_wake`, `scholar_wake`

**Damped keys (ignore if change ≤ threshold):**
- `scholar_age_h`: threshold = 1
- `scholar_age_s`: threshold = 60

**Commit lines (`commit=...`):** Compare as **SET**, not ordered list. New commits = lines in current NOT in previous. Don't report "changed" if it's just the window sliding (old commits dropping off).

**Result:** Classify into one of 3 cases for Step 3.

### Step 2: Read language

```bash
grep 'lang:' .claude/skills/tri/lang.md 2>/dev/null | awk '{print $2}'
```

Default: `ru`

### Step 2.5: Read mood

```bash
grep 'mood:' .claude/skills/tri/mode.md 2>/dev/null | awk '{print $2}'
```

Default: `humor`. Valid values: `humor`, `prof`, `toxic`, `zen`.

### Step 2.7: Read training farm data

```bash
# Read training farm capacity from JSON (no API calls needed)
python3 -c "
import json, os
f = '.trinity/railway_farm.json'
if os.path.exists(f):
    with open(f) as fh:
        d = json.load(fh)
    cap = d.get('capacity', {})
    accts = d.get('accounts', [])
    total_active = sum(a.get('active_services', 0) for a in accts)
    total_slots = cap.get('total_slots', 0)
    free_slots = cap.get('free_slots', 0)
    print(f'farm_active={total_active}')
    print(f'farm_slots_total={total_slots}')
    print(f'farm_slots_free={free_slots}')
    print(f'farm_accounts={len(accts)}')
else:
    print('farm_active=0')
" 2>/dev/null
```

Fields: `farm_active`, `farm_slots_total`, `farm_slots_free`, `farm_accounts`.

**Farm delta:** Include `farm_active` in delta computation. If `farm_active` changed between snapshots → Case 3 (something happened). Narrate: "Ферма: было X, стало Y сервисов".

### Step 2.8: Collect Live Experiment Data (Reporter Mode)

When `farm_active > 0`, query Railway for actual training progress to enable reporter narration.

```bash
# Source .env for Railway tokens, query active deployments for training logs
source .env 2>/dev/null
python3 << 'REPORTER_EOF'
import json, os, subprocess, time

prev_file = ".trinity/reporter_prev.json"
prev = {}
if os.path.exists(prev_file):
    try:
        with open(prev_file) as f:
            prev = json.load(f)
    except: pass

# Read farm JSON for service list
farm_file = ".trinity/railway_farm.json"
if not os.path.exists(farm_file):
    print("reporter_mode=0")
    exit()

with open(farm_file) as f:
    farm = json.load(f)

services = []
for acct in farm.get("accounts", []):
    for svc in acct.get("services", []):
        if svc.get("status") in ("ACTIVE", "DEPLOYING", "RUNNING"):
            services.append(svc)

if not services:
    print("reporter_mode=0")
    exit()

print("reporter_mode=1")
current = {}
for svc in services:
    name = svc.get("name", "unknown")
    status = svc.get("status", "UNKNOWN")
    step = svc.get("step", 0)
    ppl = svc.get("ppl", 0)
    loss = svc.get("loss", 0)
    tok_s = svc.get("tok_s", 0)
    lr = svc.get("lr", "")
    schedule = svc.get("schedule", "")
    optimizer = svc.get("optimizer", "")

    current[name] = {"status": status, "step": step, "ppl": ppl, "loss": loss, "tok_s": tok_s, "lr": lr, "schedule": schedule, "optimizer": optimizer}

    p = prev.get(name, {})
    delta_step = step - p.get("step", 0)
    delta_ppl = round(ppl - p.get("ppl", 0), 2) if ppl and p.get("ppl") else 0

    print(f"run_{name}={status}:{step}:{ppl}:{tok_s}:{optimizer}:{lr}:{schedule}")
    if delta_step != 0:
        print(f"run_{name}_delta_step={delta_step}")
    if delta_ppl != 0:
        print(f"run_{name}_delta_ppl={delta_ppl}")

# Find leader (lowest PPL among active runs with ppl > 0)
active_ppls = [(n, d["ppl"]) for n, d in current.items() if d["ppl"] > 0 and d["status"] in ("ACTIVE", "RUNNING")]
if active_ppls:
    leader = min(active_ppls, key=lambda x: x[1])
    print(f"reporter_leader={leader[0]}")
    print(f"reporter_leader_ppl={leader[1]}")

# Detect crashes (were in prev, not in current or status changed to non-active)
for name in prev:
    if name not in current:
        print(f"reporter_crashed={name}")
    elif current[name]["status"] not in ("ACTIVE", "RUNNING", "DEPLOYING"):
        print(f"reporter_crashed={name}")

# Count active/crashed
active_count = sum(1 for d in current.values() if d["status"] in ("ACTIVE", "RUNNING"))
crashed_count = sum(1 for n in prev if n not in current or current.get(n, {}).get("status") not in ("ACTIVE", "RUNNING", "DEPLOYING"))
print(f"reporter_active={active_count}")
print(f"reporter_crashed_count={crashed_count}")

# Save current snapshot
with open(prev_file, "w") as f:
    json.dump(current, f)
REPORTER_EOF
```

Fields: `reporter_mode`, `run_<name>=<status>:<step>:<ppl>:<tok_s>:<optimizer>:<lr>:<schedule>`, `run_<name>_delta_step`, `run_<name>_delta_ppl`, `reporter_leader`, `reporter_leader_ppl`, `reporter_crashed`, `reporter_active`, `reporter_crashed_count`.

### Step 3: Delta-aware THREE-PARAGRAPH NARRATION

**Render ONLY narration text** (casual, delta-aware). No visual cards, no Unicode box-drawing, no `╭╮╰╯` blocks.

Use the delta from Step 1.5 to choose narration case. Language comes from Step 2. Mood comes from Step 2.5.

**CRITICAL: Every response has EXACTLY 3 paragraphs, separated by blank lines.**
**End the message with a mood signature line:** `[{mood_emoji} {mood_name}]`

Mood signature: `[😏 humor]`, `[📊 prof]`, `[💀 toxic]`, `[🧘 zen]`

---

### Number-as-words rules (TTS readability)

**Convert to Russian words:** compile counts, dirty files, open issues, agent counts, elapsed minutes, faculties, spec counts.
**Keep as digits:** percentages, versions (v5.1), PPL, step counts (30K), file paths, hashes.

Reference: один/два/три/.../девять, десять-девятнадцать, двадцать/тридцать/сорок/пятьдесят/шестьдесят/семьдесят/восемьдесят/девяносто, сто/двести/триста/четыреста/пятьсот...

Gender agreement: файлов (m: один/два), задач (f: одна/две), спеков (m), факультетов (m), минут (f: одна/две).

Examples: "триста тридцать четыре спека", "сорок шесть файлов", "семьдесят одна задача", "пять факультетов".

---

### Mood Matrix

| Aspect | humor | prof | toxic | zen |
|--------|-------|------|-------|-----|
| П1 tone | Casual, metaphors | Dry, metrics-only | Brutal facts | Minimal |
| П2 intensity | Light self-deprecation | 1 sentence max | No mercy, CAPS | Philosophical |
| П3 tone | Encouraging + jokes | Bullet-style actions | Demanding | Gentle |
| Emoji | 3-5 | 0-1 | 2-3 skull/fire | 1 max |

---

### Three Paragraphs

#### Paragraph 1 — СТАТУС

Current delta-aware narration of system state. Same Case 1/2/3 logic below for choosing *what* to say. All numbers as Russian words.

Contains: compilation stats, build health, recent commits, agents, observatory fields.

**Farm-aware:** If `farm_active > 0`, weave farm status into Paragraph 1:
- RU: "Ферма работает — шестнадцать сервисов на трёх аккаунтах"
- EN: "Farm is running — sixteen services across three accounts"
- RU: "Одиннадцать сервисов тренируют, пятьдесят девять слотов свободны"
- EN: "Eleven services training, fifty-nine slots free"
If `farm_active = 0`, skip farm mention entirely.

**REPORTER MODE** (when `reporter_mode=1`): П1 becomes **live race commentary**. Lead with the most dramatic event:
- If `reporter_crashed_count > 0`: lead with the crash — "R19 УПАЛ — lamb 3e-3 слишком агрессивный LR!"
- If `run_<name>_delta_ppl` is large negative: lead with the breakthrough — "R13 вырвался вперёд — PPL упал до 4.2!"
- Otherwise: lead with the leader — "R13 на 98K шагах, PPL=4.6 — КОРОЛЬ держит корону"
- Name specific experiments by name (R8, R13, R19 etc.)
- Compare runners against each other: "R10 на 50K шагах, R14 только стартовал"
- Show concrete numbers: step counts as digits (50K), PPL as digits (4.6), tok/s as digits
- Static metrics (compile rate, build) become background noise — mention in 1 sentence max
- Include total active/crashed: "Ферма: четырнадцать из шестнадцати бегут, два в ауте"

#### Paragraph 2 — САМОБРАНКА (system self-roast / analyst commentary)

**REPORTER MODE** (when `reporter_mode=1`): П2 becomes **analyst commentary** instead of self-roast:
- Compare optimizer strategies: "LAMB снова впереди Adam — третий раунд подряд"
- Point out schedule patterns: "Все cosine расписания бьют sacred"
- Call out failures with diagnosis: "R19 УПАЛ — lamb 3e-3 слишком агрессивный LR"
- Compare learning rates: "1e-3 доминирует, 3e-3 убивает, 1e-4 плетётся"
- Reference delta data: "R8 прошёл 5K шагов за последний цикл, PPL снизился с 200 до 180"
- If an experiment is stuck (delta_step=0): "R13 стоит на месте — возможно, завис"
- Still allowed to self-roast about dirty files/build, but the RACE analysis takes priority
- Use actual `run_<name>` data, optimizer/schedule/lr fields for comparisons

**STATIC MODE** (when `reporter_mode=0`): Standard self-roast. System roasts ITSELF (never the user) based on actual data. Pick 1-2 highest triggers:

| Condition | Roast direction |
|-----------|----------------|
| `dirty > 20` | Hoarding uncommitted files |
| `build_ok=false` | Broken build while calmly reporting |
| `open_issues > 50` | Backlog growing like mold |
| No changes 3+ cycles AND `farm_active=0` | Own uselessness |
| No changes 3+ cycles AND `farm_active>0` | Code is idle but farm is working — roast the idle CODE, not "nothing happening" |
| `farm_active>0` AND `dirty > 20` | Farm is training but code repo is a mess |
| `agent_*=stub/down` | Fallen agents |
| Everything OK | Nothing to complain about (meta-roast) |

**CRITICAL override:** If `farm_active > 0`, NEVER roast "nothing happening" / "own uselessness". The farm IS doing work. Roast something else (dirty files, build, backlog, idle code).

Must reference real numbers (as Russian words). Self-directed humor/criticism.

#### Paragraph 3 — ПЛАН

**REPORTER MODE** (when `reporter_mode=1`): П3 becomes **"what to watch next"** — predictions and specific commands:
- Name the experiment to watch: "Следите за R13 — если PPL < 4.0, это новый король"
- Call out approaching milestones: "R10 приближается к 100K — решающий момент"
- If crash detected: "R19 перезапустить с LR=1e-3 или похоронить"
- Suggest concrete commands: `tri farm status`, `tri farm logs R13`
- If leader is close to a record: "R13 PPL=4.6, рекорд R33 PPL=4.6 — фотофиниш!"
- Priority still applies (broken build > reporter), but reporter narration takes over farm monitoring slot

**STATIC MODE** (when `reporter_mode=0`): Standard priority-based planning.

| Priority | Condition | Plan |
|----------|-----------|------|
| 1 | `build_ok=false` | Fix build — identify error, patch |
| 2 | `dirty > 10` | Commit files via `tri git commit` |
| 3 | `compile_rate < 100` | Fix failing specs |
| 4 | `open_issues > 0` | Pick next issue |
| 5 | `farm_active > 0` | Monitor farm: `tri farm status`, check logs when builds finish |
| 6 | All OK | Scale: new feature or optimization |

2-3 concrete sentences with `tri` commands.

**Farm-aware planning:** When `farm_active > 0`, mention farm monitoring as an action item:
- RU: "Ферма строит шестнадцать сервисов — проверить через tri farm status"
- EN: "Farm building sixteen services — check via tri farm status"
- RU: "Когда билды закончатся — смотреть логи и PPL"
- EN: "When builds finish — check logs and PPL"

---

### Case Logic (determines Paragraph 1 content)

#### Case 1: First Run (no previous snapshot, or prev >1h old)

Full narration of all fields in Paragraph 1. Paragraphs 2-3 always present.

#### Case 2: No Changes (all values identical after filtering noise/damped keys)

Paragraph 1 becomes a short "no changes" status with key numbers.
Gets harsher as no-change counter grows (3+ cycles = escalation in П2).

**Farm-aware Case 2:** If `farm_active > 0` AND no code changes, do NOT say "NOTHING happening". Instead:

**With reporter_mode=1** (live experiment data available): Use full reporter narration even though code is idle. The race IS the story:
- П1: Race commentary (leader, runners, crashes) — code idleness is 1 sentence at most
- П2: Analyst commentary (optimizer/schedule patterns, delta analysis)
- П3: What to watch next (specific experiments, milestones, commands)

**With reporter_mode=0** (no live data): Fall back to generic farm narration:
- П1 RU: "Код без изменений N минут, но ферма работает — шестнадцать сервисов строятся"
- П1 EN: "No code changes for N minutes, but farm is running — sixteen services building"
- П2 RU: "Код тихо стоит, а шестнадцать сервисов гудят на Railway. Тут не безделье — тут ожидание результатов 🔨"
- П2 EN: "Code is quiet while sixteen services hum on Railway. Not idleness — waiting for results 🔨"
- П3 RU: "Проверить ферму: tri farm status. Когда билды закончатся — смотреть логи и PPL."
- П3 EN: "Check farm: tri farm status. When builds finish — check logs and PPL."

#### Case 3: Some Values Changed — Delta-focused

Paragraph 1 focuses on what changed. Emergency changes always lead:
- `build_ok` flipped → "Билд сломался!" or "Билд починили!"
- `cycle` changed to/from `emergency`
- `compile_rate` dropped >5pp
- Any agent going DOWN

Delta narration per changed field:

| Field | Narration |
|-------|-----------|
| `compile_rate` | Old→new, direction |
| `dirty` | Old→new count |
| `build_ok` | "Починили!" or "Сломался!" |
| `test_ok` | "Тесты прошли!" or "Тесты упали!" |
| `commit=` | NEW commits only (set diff) |
| `pipeline` | Status change |
| `agent_*` | Which agent changed state |
| `open_issues` | "+N новых" or "-N закрыто" |
| `farm_active` | RU: "Ферма: было X, стало Y сервисов" / EN: "Farm: was X, now Y services" |

---

#### Narration rules (all cases, all paragraphs)

- Short paragraphs, NOT bullet lists, NOT tables
- Emoji per mood matrix (humor: 3-5, prof: 0-1, toxic: 2-3 skull/fire, zen: 1 max)
- Vary phrasing — NEVER repeat the same template twice
- NO technical prefixes like "Compile:" or "Status:" — weave data into sentences
- Numbers as Russian words (see rules above)
- If something is broken — sound concerned (humor/zen) or angry (toxic) or factual (prof)
- Commit descriptions sound like explaining what you did, not git log
- **Negative cases (DO NOT fabricate drama):**
  - `pipeline=no_data` → "Пайплайн не запускался" (НЕ "завис")
  - `swarm=0idle/0busy:0pending` → skip
  - `agent_<name>=stub` or `tbd` → skip

---

### Full examples by mood

#### humor (default):
```
Триста тридцать четыре спека на месте, компиляция сто процентов 💎
Билд красный — MU опять перезаписал heartbeat, реально всё зелёное.

Скатерть-самобранка раскинулась: тридцать три грязных файла, семьдесят одна
задача в очереди, а я тут рапортую как будто всё под контролем. Спойлер: нет 😏

До следующего круга: закоммитить грязные файлы через tri git commit,
потом выбрать задачу из семидесяти одной открытой 🎯

[😏 humor]
```

#### toxic:
```
Триста тридцать четыре спека. Сто процентов компиляции. Билд формально
красный — MU heartbeat врёт. Тридцать три грязных файла. Семьдесят одна задача.

ТРИДЦАТЬ ТРИ файла незакоммичены. Кто так живёт? Семьдесят одна задача
и ни одна не двигается. Я — скатерть-самобранка, которая накрыла стол
и ждёт гостей. Гости не придут 💀

Коммитим СЕЙЧАС. Потом берём задачу. Хватит медитировать на дашборд 🔥

[💀 toxic]
```

#### zen:
```
Триста тридцать четыре. Всё компилируется. Билд дышит. Тридцать три файла ждут.

Грязные файлы — как опавшие листья. Их можно убрать. Можно оставить. Они всё равно тут.

Следующий шаг: коммит. Потом — одна задача из семидесяти одной. Не все сразу.

[🧘 zen]
```

#### prof:
```
Триста тридцать четыре спека, компиляция сто процентов. Билд: красный (heartbeat).
Тридцать три грязных файла. Семьдесят одна открытая задача.

Тридцать три незакоммиченных файла — выше нормы.

Действия: tri git commit, затем tri issue list для выбора задачи.

[📊 prof]
```

#### Case 2 (no changes), humor:
```
Без изменений пять минут. Билд зелёный, тридцать три файла, семьдесят одна задача.

Пять минут тишины. Даже MU не шевелится. Может я и есть тот баг, который все ищут 😏

Закоммитить файлы. Взять задачу. Или хотя бы притвориться, что работаем 🎯

[😏 humor]
```

#### Case 2 (no changes) + farm active, humor (RU):
```
Код без изменений пять минут, но ферма работает — шестнадцать сервисов на трёх аккаунтах 🔨

Код тихо стоит, а шестнадцать сервисов гудят на Railway. Тут не безделье — тут ожидание результатов. Пятьдесят девять слотов свободны, если что 😏

Проверить ферму: tri farm status. Когда билды закончатся — смотреть логи и PPL 🎯

[😏 humor]
```

#### Case 2 (no changes) + farm active, humor (EN):
```
No code changes for five minutes, but farm is running — sixteen services across three accounts 🔨

Code sits quiet while sixteen services hum on Railway. Not idleness — waiting for results. Fifty-nine slots free, just in case 😏

Check farm: tri farm status. When builds finish — check logs and PPL 🎯

[😏 humor]
```

#### Case 2 (no changes) + farm active, toxic (RU):
```
Код не шевелится пять минут. Зато ферма пашет — шестнадцать сервисов строятся 🔨

Шестнадцать сервисов РАБОТАЮТ, а ты сидишь и смотришь на дашборд. Код замер. Railway не замер. Кто тут лишний? 💀

Tri farm status СЕЙЧАС. Логи. PPL. Действуй 🔥

[💀 toxic]
```

#### Case 2 (no changes) + farm active, toxic (EN):
```
Code hasn't moved in five minutes. But the farm is grinding — sixteen services building 🔨

Sixteen services WORKING while you stare at the dashboard. Code frozen. Railway not frozen. Who's the bottleneck here? 💀

Tri farm status NOW. Logs. PPL. Move 🔥

[💀 toxic]
```

#### Reporter mode, toxic (RU):
```
R13 на 98K шагах, PPL=4.6 — КОРОЛЬ держит корону. R10 отстаёт на 50K,
PPL=180. R19 УПАЛ с lamb 3e-3 — слишком жадный LR. Ферма: четырнадцать
из шестнадцати бегут, два в ауте 🔨

LAMB 1e-3 ДОМИНИРУЕТ — R13 и R33 оба на cosine, оба в топе. Adam 3e-4
плетётся сзади как пенсионер на марафоне. Сто семь грязных файлов —
но кого это волнует когда PPL=4.6 💀

Следить за R13 — если пробьёт 4.0 до 100K, это ПРОРЫВ. Логи:
tri farm logs R13. R19 перезапустить с LR=1e-3 или похоронить 🔥

[💀 toxic]
```

#### Reporter mode, humor (RU):
```
R13 лидирует с PPL=4.6 на 98K шагах — корона пока на нём. R8 набирает
обороты — прошёл 5K шагов, PPL снизился с 200 до 180. R19 отдал душу
на lamb 3e-3, покойся с миром 😏

LAMB 1e-3 на cosine — это как чизкейк в мире оптимизаторов: всем нравится,
все заказывают. Adam 3e-4 пытается, но выглядит как велосипед на автобане.
R10 ещё на 50K — молодой, дерзкий, может удивить 🎯

R13 приближается к 100K — решающий момент. Если PPL < 4.0, у нас новый
король. tri farm logs R13 для живых данных. R19 перезапустить или
оставить как памятник жадности 🔨

[😏 humor]
```

#### Reporter mode, zen (RU):
```
R13 — 98K шагов, PPL=4.6. R8 — 50K, PPL=180. Четырнадцать бегут. Два упали.

Каждый оптимизатор идёт своим путём. LAMB нашёл свой. Adam ищет.
Cosine вращается, как и положено спирали.

Наблюдать R13. tri farm logs R13. Остальное — терпение.

[🧘 zen]
```

#### Reporter mode, prof (RU):
```
Лидер: R13, PPL=4.6, 98K шагов, LAMB 1e-3 cosine. Второй: R8, PPL=180, 50K шагов.
R19 упал (LAMB 3e-3). Активных: четырнадцать из шестнадцати.

LAMB 1e-3 cosine — лучшая конфигурация по всем метрикам. Adam 3e-4 отстаёт.
Градиент R8 стабилен, прогноз PPL < 100 к 80K шагам.

Мониторинг R13: tri farm logs R13. R19: решение о перезапуске с LR=1e-3.

[📊 prof]
```

### Step 3.5: GitHub Board Summary (Real Project Board)

Collect REAL project board data from GitHub Projects v2, with label-based fallback.

```bash
# Try real project board first (Project #6)
gh project item-list 6 --owner gHashTag --format json --limit 200 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    items = data.get('items', [])
    cols = {}
    in_progress = []
    backlog = []
    for item in items:
        status = item.get('status', 'No Status')
        cols[status] = cols.get(status, 0) + 1
        content = item.get('content', {})
        num = content.get('number', '?') if isinstance(content, dict) else '?'
        title = item.get('title', '')[:50]
        if status == 'In progress':
            in_progress.append(f'#{num} {title}')
        elif status == 'Backlog':
            backlog.append(f'#{num} {title}')
    for col, count in sorted(cols.items()):
        safe = col.lower().replace(' ','_')
        print(f'board_{safe}={count}')
    for a in in_progress[:10]:
        print(f'board_active={a}')
    for b in backlog[:10]:
        print(f'board_backlog_item={b}')
    print(f'board_total={len(items)}')
except: print('board_total=0')
" 2>/dev/null
```

```bash
# Fallback: label-based if board query returned 0 or failed
gh issue list -R gHashTag/trinity --state open --json number,title,labels -L 100 2>/dev/null | python3 -c "
import json, sys
try:
    issues = json.load(sys.stdin)
    by_status = {}
    active = []
    for i in issues:
        labels = [l['name'] for l in i.get('labels', [])]
        for l in labels:
            if l.startswith('status:'):
                by_status[l] = by_status.get(l, 0) + 1
        if 'status:in-progress' in labels:
            active.append(f\"#{i['number']} {i['title'][:50]}\")
    print(f'board_open={len(issues)}')
    for k,v in by_status.items():
        print(f'board_{k.replace(\":\",\"_\")}={v}')
    for a in active[:5]:
        print(f'board_active={a}')
except: print('board_open=0')
" 2>/dev/null
```

**Board fields (project board):** `board_backlog`, `board_in_progress`, `board_in_review`, `board_ready`, `board_done`, `board_total`, `board_active=...`, `board_backlog_item=...`

**Board fields (label fallback):** `board_open`, `board_status_in-progress`, `board_status_done`, `board_status_queued`, `board_active=...`

**Narration integration:** After the 3 paragraphs + mood signature, add an expanded board section:

```
📋 Board: N backlog | M in progress | K review | J done

🔥 In Progress:
• #357 Training Farm Wave 4+5
• #342 Zig compiler fork
{all in-progress items}

📥 Backlog (top 5):
• #340 FPGA Verilog Export
• #339 Full Ternary Inference
{top 5 backlog items}

🧪 Farm: N services | PPL best
```

If no board data, show label-based fallback:
```
📋 Board: N open | M in progress | K done
   🔥 #357 Training Farm Wave 4+5
```

### Step 4: Fallback (only if CLI failed)

If `tri faculty --raw` exits non-zero OR binary not found:

1. Print: `⚠️ Faculty CLI unavailable — fallback mode`
2. Run `zig build 2>&1` and report exit code
3. Run `git status --short | wc -l` for dirty count
4. Show minimal status: build OK/FAIL, dirty count
5. Suggest: `zig build && ./zig-out/bin/tri faculty`

### Step 5: Telegram pinned dashboard (COMPACT mode only)

After rendering the narration to stdout (including board summary), send or edit the pinned Telegram dashboard.

Set `TG_TEXT` to the 3-paragraph narration + board summary (no mood signature `[emoji mood]`).
Set `TG_MODE=pin`.
Then execute the shared Telegram template from `.claude/skills/_shared/telegram.md`.

### Step 6: Auto-Action (after Telegram) — Hardened

After rendering narration + sending Telegram, execute ONE auto-action based on priority cascade (first match wins).
All auto-actions go through lock → circuit breaker → agent launch → result protocol.

#### 6.0: Lock Check

```bash
cat .trinity/auto_action.lock 2>/dev/null
```

**Logic:**
- If lock file exists → parse `timestamp` and `action` from it
- If age < 5 minutes → **SKIP all auto-actions**, print: `⏳ Авто-действие уже выполняется: {action}`
- If age >= 5 minutes → stale lock, delete it, proceed
- If lock doesn't exist → proceed

#### 6.1: Circuit Breaker Check

```bash
cat .trinity/auto_action_failures.json 2>/dev/null
```

**Logic:**
- If file exists, parse JSON: `consecutive_failures`, `last_action`, `last_failure`
- Determine which action would be selected (same priority cascade below)
- If `last_action` matches selected action AND `consecutive_failures >= 3` → **SKIP**, print:
  `🔴 Circuit breaker: "{action}" фейлит 3 раза подряд. Требуется ручное вмешательство.`
- Otherwise → proceed

#### 6.2: Write Lock + Launch Agent

Before launching the agent:
```bash
echo '{"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","action":"{selected_action}"}' > .trinity/auto_action.lock
```

#### Agent Prompt Suffix (MANDATORY)

Every agent prompt below gets this suffix appended:

```
MANDATORY post-actions:
1. After ALL work done, write result to .trinity/auto_action_result.json:
   {"timestamp":"<ISO8601>", "action":"<action_name>", "success":true/false, "details":"<what happened>", "build_ok_after":true/false}
2. Delete .trinity/auto_action.lock
3. If build breaks after your changes → revert with `git reset --soft HEAD~1`, set success=false in result
4. NEVER force-push. NEVER commit .env or credential files.
5. On success → read .trinity/auto_action_failures.json, reset consecutive_failures to 0, write back
6. On failure → read .trinity/auto_action_failures.json (or create), increment consecutive_failures, set last_action and last_failure, write back
```

#### Priority Cascade

**Priority 1: `build_ok=false`** → Launch background Agent:
```
Agent tool:
  run_in_background: true
  description: "fix broken build"
  prompt: "The zig build is broken. Run `zig build 2>&1`, diagnose the error, fix the source file, and verify with `zig build` again. Commit the fix with `fix(<module>): <description>` message. {MANDATORY_SUFFIX}"
```

**Priority 2: `dirty > 10`** → Launch background Agent:
```
Agent tool:
  run_in_background: true
  description: "auto-commit dirty files"
  prompt: "There are {dirty} uncommitted files. Run `git status --short`, group files by directory, and create conventional commits. Use scopes like arena, tri, trinity, fpga, claude. Skip .env, credentials, and files >1MB. Run `zig build` after to verify nothing broke. Example commits: `feat(arena): add LLM battle platform` for src/arena/ files, `chore(trinity): update state files` for .trinity/ files. {MANDATORY_SUFFIX}"
```

**Priority 3: `compile_rate < 100`** → Launch background Agent:
```
Agent tool:
  run_in_background: true
  description: "fix failing specs"
  prompt: "Compile rate is {rate}%. Find failing .zig files with `zig build 2>&1`, fix compilation errors, verify with `zig build`. Commit fixes with `fix(<module>): <description>` messages. {MANDATORY_SUFFIX}"
```

**Priority 4: `open_issues > 0`** → Launch background Agent:
```
Agent tool:
  run_in_background: true
  description: "work on top issue"
  prompt: "Pick the highest-priority open issue from `gh issue list --limit 5 --state open`. Read it, create a branch feat/issue-{N}, implement the solution, commit with issue reference (#N). {MANDATORY_SUFFIX}"
```

**Priority 5: All OK** → No agent. Print: `✅ Нечего чинить — система в φ-гармонии.`

#### Rules
- Only ONE action per /tri cycle — no parallel chaos
- Agent runs in background — user sees /tri output immediately
- Lock prevents concurrent auto-actions across /tri invocations
- Circuit breaker stops infinite retry loops after 3 consecutive failures
- Agent MUST write result JSON + delete lock (enforced via prompt suffix)
- Never commit `.env`, credentials, large binaries
- Never force-push
- If build breaks after commit → agent reverts, reports failure in result JSON

**IMPORTANT: After Step 6, STOP. Do NOT continue to the full diagnostic below.**

---

## Full Mode (only if MODE=FULL)

The following sections render ONLY in full mode. If MODE=COMPACT, skip everything below.

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
# Pipeline state + STALENESS check
python3 -c "
import json, time, datetime
try:
    with open('.trinity/pipeline_state.json') as f: d = json.load(f)
    ts = d.get('timestamp', 0)
    age_hours = (time.time() - ts) / 3600 if ts > 0 else -1
    status = d.get('status', '?')
    task = d.get('task', '?')
    link = d.get('last_link', '?')
    ts_human = datetime.datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M') if ts > 0 else 'unknown'
    print(f'PIPELINE_STATUS:{status}')
    print(f'PIPELINE_TASK:{task}')
    print(f'PIPELINE_LINK:{link}')
    print(f'PIPELINE_DATE:{ts_human}')
    print(f'PIPELINE_AGE_HOURS:{age_hours:.0f}')
    if status == 'running' and age_hours > 24:
        print(f'PIPELINE_STALE:Pipeline stuck in \"{status}\" for {age_hours:.0f}h since {ts_human} — likely dead')
    elif age_hours > 72:
        print(f'PIPELINE_STALE:Pipeline idle for {age_hours:.0f}h ({age_hours/24:.0f} days) — no activity')
except: print('PIPELINE_STATUS:NO_DATA')
" 2>/dev/null

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

# Failed specs — extract actual names from ❌ rows in markdown table
grep "❌" specs/REGENERATION_REPORT.md 2>/dev/null | while IFS='|' read _ num name status _; do
  name=$(echo "$name" | xargs)
  status=$(echo "$status" | xargs)
  echo "FAILED_SPEC:$name — $status"
done
echo "FAILED_COUNT:$(grep -c "❌" specs/REGENERATION_REPORT.md 2>/dev/null || echo 0)"

# Audit date (unix timestamp from report header) + STALENESS check
AUDIT_TS=$(grep -oE '[0-9]{10}' specs/REGENERATION_REPORT.md 2>/dev/null | head -1)
if [ -n "$AUDIT_TS" ]; then
  python3 -c "
import datetime, time
ts=$AUDIT_TS
age_hours = (time.time() - ts) / 3600
dt = datetime.datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M')
print(f'AUDIT_DATE:{dt}')
print(f'AUDIT_AGE_HOURS:{age_hours:.0f}')
if age_hours > 48:
    print(f'AUDIT_STALE:Audit data is {age_hours:.0f}h old ({age_hours/24:.0f} days) — run /tri audit for fresh data')
elif age_hours > 24:
    print(f'AUDIT_AGING:Audit is {age_hours:.0f}h old — consider refreshing')
"
else
  echo "AUDIT_DATE:never"
  echo "AUDIT_STALE:No audit data exists — run /tri audit"
fi

# Job history: deduplicated by command name, with diversity stats + STALENESS check
python3 -c "
import json, os, glob, time, datetime
from collections import Counter
jobs = []
for d in sorted(glob.glob('.trinity/jobs/*/metadata.json'), key=os.path.getmtime, reverse=True):
    try:
        with open(d) as f: jobs.append(json.load(f))
    except: pass
seen, unique = set(), []
for j in jobs:
    cmd = j.get('command','?')
    if cmd not in seen:
        seen.add(cmd)
        unique.append(j)
    if len(unique) >= 7: break
for j in unique:
    print(f'JOB:{j.get(\"command\",\"?\")}|{j.get(\"state\",\"?\")}|{j.get(\"exit_code\",\"?\")}|{j.get(\"start_time\",0)}')
states = Counter(j.get('state','?') for j in jobs)
stale = sum(1 for j in jobs if j.get('state')=='running')
top = Counter(j.get('command','?') for j in jobs).most_common(1)
print(f'JOB_TOTAL:{len(jobs)}')
print(f'JOB_COMPLETED:{states.get(\"completed\",0)}')
print(f'JOB_FAILED:{states.get(\"failed\",0)}')
print(f'JOB_STALE:{stale}')
if top: print(f'JOB_SPAM:{top[0][0]}={top[0][1]}')
# STALENESS: newest job timestamp
if jobs:
    newest_ts = max(j.get('start_time',0) for j in jobs)
    age_hours = (time.time() - newest_ts) / 3600 if newest_ts > 0 else -1
    newest_date = datetime.datetime.fromtimestamp(newest_ts).strftime('%Y-%m-%d %H:%M') if newest_ts > 0 else 'unknown'
    print(f'JOB_NEWEST_DATE:{newest_date}')
    print(f'JOB_AGE_HOURS:{age_hours:.0f}')
    if age_hours > 24:
        print(f'JOB_STALE_WARNING:No new pipeline jobs in {age_hours:.0f}h (since {newest_date})')
" 2>/dev/null || echo "JOB_TOTAL:0"

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


### GitHub Integration — LIVE

```bash
# GitHub client mode detection (native HTTP vs gh CLI fallback)
test -f src/tri/github_client.zig && echo "GH_CLIENT:EXISTS" || echo "GH_CLIENT:MISSING"
test -f src/tri/github_commands.zig && echo "GH_COMMANDS:EXISTS" || echo "GH_COMMANDS:MISSING"

# Check GITHUB_TOKEN/GH_TOKEN for native HTTP mode
echo "GH_TOKEN:${GITHUB_TOKEN:+SET}"
echo "GH_TOKEN_ALT:${GH_TOKEN:+SET}"

# Count GitHub command handlers
grep -c 'fn.*Command' src/tri/github_commands.zig 2>/dev/null || echo "0"

# Test GitHub client connectivity (dry-run)
test -f zig-out/bin/tri && echo "TRI_CLI:READY" || echo "TRI_CLI:MISSING"
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

🔧 PIPELINE HEALTH — last audit: {AUDIT_DATE} {IF AUDIT_STALE: "⚠️ STALE"}
═══════════════════════════════════════════════════

  Pipeline:   {🟢/🔴/⚪} {PIPELINE_STATUS or "NO DATA"}
  Last run:   {PIPELINE_TASK} — {PIPELINE_DATE}
  IF PIPELINE_STALE exists: ⚠️ {PIPELINE_STALE}

  Specs:      {N} .tri files (specs/**/* excluding archive)
  Generated:  {N} .zig files (generated/)
  Coverage:   {generated/specs as %}%
  Compile:    {PASS}/{TOTAL} = {RATE}% {🟢 if ≥80%, 🟡 if ≥50%, 🔴 if <50%}  ← KEY METRIC (single canonical number)

  🐛 Failed Specs ({FAIL_COUNT} / {TOTAL}):
    (parsed from REGENERATION_REPORT.md — list each ❌ spec by name from FAILED_SPEC lines)
    ❌ {spec_name} — {error}
    ❌ {spec_name} — {error}
    ...ALL failed specs...
    Fix: zig build vibee -- gen specs/tri/{name}.tri && zig ast-check generated/{name}.zig
    If 0 failures: "✅ All audited specs compile"
    If no report: "No audit data — run: /tri audit"

  📋 Recent Jobs (deduplicated by command):
  ┌──────────────────────┬────────────┬───────┐
  │ Job                  │ Status     │ Exit  │
  ├──────────────────────┼────────────┼───────┤
  │ {command}            │ ✅/❌      │ {N}   │  ← from JOB: lines, unique commands only
  └──────────────────────┴────────────┴───────┘

  Total: {JOB_TOTAL} jobs, {JOB_COMPLETED} ✅, {JOB_FAILED} ❌
  IF JOB_NEWEST_DATE exists: Last job: {JOB_NEWEST_DATE} ({JOB_AGE_HOURS}h ago)
  IF JOB_STALE_WARNING exists: ⚠️ {JOB_STALE_WARNING} — pipeline is IDLE
  IF JOB_STALE > 0: ⚠️ Stale: {N} stuck in "running" — cleanup needed
  IF JOB_SPAM: ⚠️ Spam: "{cmd}" ran {N}× — investigate cause
  IF AUDIT_STALE exists: ⚠️ {AUDIT_STALE}
  IF AUDIT_AGING exists: ℹ️ {AUDIT_AGING}

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

### Perplexity Bridge Section

After SYSTEM STATUS, render the Bridge section using data from bridge checks:

```
═══════════════════════════════════════════════════
  🌉 PERPLEXITY BRIDGE — DIRECT CONTROL CHANNEL
═══════════════════════════════════════════════════

  ┌─────────────────┬────────┬──────────────────────────────┐
  │ Component       │ Status │ Details                      │
  ├─────────────────┼────────┼──────────────────────────────┤
  │ Railway Server  │ {S}    │ {url} — {BRIDGE_STATUS}      │
  │ Mac Agent       │ {S}    │ {UP/DOWN from pgrep}         │
  │ Command Queue   │ {S}    │ {pending} pending, {done} done│
  │ claude: support │ {S}    │ urlDecode + 620s timeout     │
  └─────────────────┴────────┴──────────────────────────────┘
```

#### Bridge Status Logic:
- **Railway Server**: 🟢 if BRIDGE_STATUS:ok (token valid). 🟢 if BRIDGE_STATUS:ok(no-token) (server responds HTTP but token missing/invalid). 🔴 if BRIDGE_STATUS:down (HTTP code 000, server unreachable).
- **Mac Agent**: 🟢 if BRIDGE_AGENT:UP. 🔴 if BRIDGE_AGENT:DOWN.
- **Command Queue**: 🟢 if BRIDGE_PENDING ≥ 0 and reachable. ⚪ if unreachable.
- **claude: support**: Always 🟢 (built into perplexity_bridge.zig). ⚪ if BRIDGE_CODE:MISSING.


### GitHub Board Integration Section

After Bridge section, render the GitHub Board Integration status:

```
═══════════════════════════════════════════════════
🐙 GITHUB BOARD INTEGRATION — NATIVE API
═══════════════════════════════════════════════════
┌─────────────────────┬────────┬──────────────────────────────┐
│ Component           │ Status │ Details                      │
├─────────────────────┼────────┼──────────────────────────────┤
│ github_client.zig   │ {S}    │ {mode}: native_http/gh_cli   │
│ github_commands.zig │ {S}    │ {N} command handlers         │
│ Board Sync          │ {S}    │ Project #6 — label tracking  │
│ Protocol v2         │ {S}    │ issue/comment/close/decompose│
└─────────────────────┴────────┴──────────────────────────────┘

CLI Commands Available:
  tri issue create <title>    — Create GitHub issue
  tri issue comment <N>       — Protocol v2 formatted comment
  tri issue close <N>         — Close with summary
  tri issue decompose <N>     — Create sub-issues from template
  tri board sync              — Label-based column tracking
  tri protocol log            — Display protocol log entries
  tri protocol verify         — Check Protocol v2 compliance
```

#### GitHub Integration Status Logic:

- **github_client.zig**: 🟢 if GH_CLIENT:EXISTS AND (GH_TOKEN:SET OR gh CLI available). ⚠️ if code exists but no token. ⬜ if GH_CLIENT:MISSING.
- **github_commands.zig**: 🟢 if GH_COMMANDS:EXISTS. ⬜ if MISSING.
- **Board Sync**: 🟢 if board-sync skill exists AND gh CLI works. ⚪ if untested.
- **Protocol v2**: 🟢 if github_commands.zig has all 7 handlers. ⚠️ if partial.

### Faculty Status Section

After Bridge section, render the TRI University Faculty Board.

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

# Bridge: 3-level check — token auth → HTTP-only → down
BRIDGE_URL="${RAILWAY_URL:-https://trinity-production-a1d4.up.railway.app}"
# Level 1: Try with token (full JSON response)
curl -sf --max-time 5 "${BRIDGE_URL}/px/status?token=${PX_BRIDGE_TOKEN}" 2>/dev/null \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'BRIDGE_STATUS:{d.get(\"status\",\"down\")}')" 2>/dev/null \
  || {
    # Level 2: No token / invalid token — check if server responds HTTP at all
    HTTP_CODE=$(curl -sf --max-time 5 -o /dev/null -w "%{http_code}" "${BRIDGE_URL}/px/status" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" != "000" ]; then
      echo "BRIDGE_STATUS:ok(no-token)"
    else
      # Level 3: Server unreachable
      echo "BRIDGE_STATUS:down"
    fi
  }
pgrep -f tri-bridge-agent > /dev/null && echo "BRIDGE_AGENT:UP" || echo "BRIDGE_AGENT:DOWN"
if [ -n "${PX_BRIDGE_TOKEN}" ]; then
  curl -sf --max-time 5 "${RAILWAY_BASE}/px/jobs?token=${PX_BRIDGE_TOKEN}" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'BRIDGE_PENDING:{d.get(\"pending\",0)}'); print(f'BRIDGE_RUNNING:{d.get(\"running\",0)}'); print(f'BRIDGE_DONE:{d.get(\"done\",0)}')" 2>/dev/null || echo "BRIDGE_PENDING:0"
else
  echo "BRIDGE_PENDING:?(no-token)"
fi
test -f src/tri-api/perplexity_bridge.zig && echo "BRIDGE_CODE:READY" || echo "BRIDGE_CODE:MISSING"
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
  │ 🌉 Bridge  │ Comms        │ {S}    │ {from bridge checks}         │
  └────────────┴──────────────┴────────┴──────────────────────────────┘

  Faculty Active: {N}/7 ({%})
  Next hire: {agent with highest impact among sleeping ones}
```

#### Faculty Status Logic — derived from LIVE checks above
- **Ralph**: 🟢 UP if build EXIT:0 AND 9 binaries exist. ⚠️ if build fails. From: `zig build` exit code.
- **Scholar**: 🟢 UP if PKEY:SET AND SCHOLAR_CODE:READY. ⚠️ CODE_READY if code exists but no key. ⬜ TBD if SCHOLAR_CODE:MISSING. From: env check + file check.
- **MU**: 🟢 UP if SWARM_AGENTS > 0 with MU agent AND MU_FIXER:EXISTS. ⚪ STUB if agents=[] but fixer code exists. ❌ DOWN if no code. From: swarm_state.json + file check.
- **Oracle**: Always 🟢 UP (computed from compile_rate). From: REGENERATION_REPORT.md.
- **Swarm**: 🟢 UP if SWARM_ASSIGNED > 0. ⚪ TBD if SWARM_TASKS > 0 but none assigned. ⬜ OFF if no tasks. From: swarm_state.json.
- **Linter**: 🟢 UP if LINTER:UP. ❌ DOWN if LINTER:DOWN. From: `test -f zig-out/bin/vibee`.
- **Bridge**: 🟢 UP if BRIDGE_STATUS:ok (token valid) OR BRIDGE_STATUS:ok(no-token) (server responds HTTP) AND BRIDGE_AGENT:UP. ⚠️ PARTIAL if server responds but agent DOWN, or agent UP but server unreachable. ❌ DOWN if both DOWN (HTTP 000 + no agent). ⬜ TBD if BRIDGE_CODE:MISSING. From: 3-level curl + pgrep checks.

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
  🌉 Bridge: "{dynamic based on bridge status}"
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

**Bridge** (reads bridge checks):
- IF BRIDGE_STATUS starts with "ok" AND BRIDGE_AGENT:UP: "🌉 ONLINE. Perplexity → Railway → Mac → Claude Code. Direct control active."
- IF BRIDGE_STATUS starts with "ok" AND BRIDGE_AGENT:DOWN: "⚠️ Railway UP but Mac agent DOWN. Run: ./deploy/tri-bridge-agent.sh &"
- IF BRIDGE_STATUS:down AND BRIDGE_CODE:READY: "❌ Railway DOWN. Code ready. Deploy: railway up"
- IF BRIDGE_CODE:MISSING: "⬜ NOT DEPLOYED. Build perplexity_bridge.zig first."

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

### Training Farm Section

After Faculty, render the HSLM Training Farm status. This shows live experiments across Railway accounts.

#### Training Farm Data Collection — LIVE
```bash
source .env 2>/dev/null

# Check primary account training services
echo "=== PRIMARY ==="
for SVC in hslm-v11 hslm-train; do
  echo -n "SVC:$SVC:"
  curl -s https://backboard.railway.app/graphql/v2 \
    -H "Authorization: Bearer $RAILWAY_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"{ service(id: \\\"$(grep -A2 "\"name\":.*$SVC" .trinity/railway_farm.json 2>/dev/null | grep service_id | head -1 | grep -o '[0-9a-f-]\{36\}')\\\"} { deployments(first:1) { edges { node { status } } } } }\"}" 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['service']['deployments']['edges'][0]['node']['status'])" 2>/dev/null || echo "UNKNOWN"
done

# Farm-2 and Farm-3 service status
FARM2_TOKEN="$RAILWAY_API_TOKEN_2"
FARM3_TOKEN="$RAILWAY_API_TOKEN_3"

echo "=== FARM-2 ==="
for SID_NAME in "1f30cbdb:r10" "e8d8f5ec:r11" "9c45fdc4:r12" "f0bd7e32:r13" "b68f1f3b:r18" "b31c1078:r19"; do
  SID="${SID_NAME%%:*}-ce12-43d3-8afb-abd947da70f0"
  # Use short IDs mapped to full UUIDs from memory
  NAME="${SID_NAME#*:}"
  echo -n "SVC:hslm-$NAME:"
  # Quick status check via deployment
  curl -s --max-time 5 https://backboard.railway.app/graphql/v2 \
    -H "Authorization: Bearer $FARM2_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"{ service(id: \\\"${SID_NAME%%:*}-ce12-43d3-8afb-abd947da70f0\\\") { deployments(first:1) { edges { node { status } } } } }\"}" 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); e=d['data']['service']['deployments']['edges']; print(e[0]['node']['status'] if e else 'NO_DEPLOY')" 2>/dev/null || echo "UNKNOWN"
done

echo "=== FARM-3 ==="
for SID_NAME in "031f783b:r14" "c5e6295d:r15" "164e04a2:r16" "e7721613:r17" "79c095a7:t1" "cccee350:r20"; do
  NAME="${SID_NAME#*:}"
  echo -n "SVC:hslm-$NAME:"
  curl -s --max-time 5 https://backboard.railway.app/graphql/v2 \
    -H "Authorization: Bearer $FARM3_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"{ service(id: \\\"${SID_NAME%%:*}-NOT-FULL-UUID\\\") { deployments(first:1) { edges { node { status } } } } }\"}" 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); e=d['data']['service']['deployments']['edges']; print(e[0]['node']['status'] if e else 'NO_DEPLOY')" 2>/dev/null || echo "UNKNOWN"
done
```

**IMPORTANT:** The full service UUIDs for Wave 4 experiments:

| Service | Account | UUID | Experiment |
|---------|---------|------|------------|
| hslm-v11 | primary | 2b525c13-ab3d-4da0-8e86-fd1abe1ba76a | R8: adam 3e-4 cosine TWN |
| hslm-train | primary | 51a3fe43-eafd-4440-b600-02654f569aec | R9: adamw 3e-4 cosine ctx=27 |
| hslm-r10 | farm-2 | 1f30cbdb-ce12-43d3-8afb-abd947da70f0 | R10: lamb 3e-4 cosine |
| hslm-r11 | farm-2 | e8d8f5ec-2f34-4f41-a911-e7f41208cdcf | R11: adam 3e-4 cosine-restarts 33K |
| hslm-r12 | farm-2 | 9c45fdc4-cf6a-45f9-87ab-d4ffe09aab4b | R12: adam 3e-4 cosine ga=4 |
| hslm-r13 | farm-2 | f0bd7e32-03c4-43e8-828f-00d5edc32da4 | R13: lamb 1e-3 cosine ga=4 |
| hslm-r18 | farm-2 | b68f1f3b-632c-434e-a7e8-2a0861bcd2c1 | R18: adam 3e-4 ternary-sched |
| hslm-r19 | farm-2 | b31c1078-4e12-451f-8593-c157f24bb101 | R19: lamb 3e-3 cosine ga=8 |
| hslm-r14 | farm-3 | 031f783b-7031-488c-88f4-bd419c4bba43 | R14: adam 5e-4 cosine |
| hslm-r15 | farm-3 | c5e6295d-eb73-4a17-a234-3cd7a53b1320 | R15: adamw 5e-4 cosine WD=0.05 |
| hslm-r16 | farm-3 | 164e04a2-b0d0-49d5-a6ba-ab1810bf03ca | R16: adam 3e-4 sacred |
| hslm-r17 | farm-3 | e7721613-976b-4111-bb8b-8880fad2c873 | R17: adam 3e-4 adaptive-sparsity |
| hslm-r20 | farm-3 | cccee350-8b71-4d98-94c5-b57b54cda1d5 | R20: adam 3e-4 full-ternary |
| hslm-t1 | farm-3 | 79c095a7-1b11-4924-b663-7c30c394cb88 | T1: adam 3e-4 ctx=27 30K |

**Railway account tokens:**
- Primary: `RAILWAY_API_TOKEN` (project `aa0efa7f-95e6-4466-8de6-43945a031365`)
- Farm-2: `RAILWAY_API_TOKEN_2` (project `ca4303d2-4a09-4143-b725-9a3f3977118f`, env `d8602284-9bba-48bc-94f5-470f9d1fff48`)
- Farm-3: `RAILWAY_API_TOKEN_3` (project `292e8862-11ce-4542-aff8-35a41e6b3217`, env `912e9084-e1ad-4bf1-aaea-0a77f9b2a158`)

**GraphQL query for deployment status:**
```graphql
{ service(id: "UUID") { deployments(first:1) { edges { node { status createdAt } } } } }
```

**GraphQL query for logs (last 10 lines):**
```graphql
# Use Railway MCP get-logs tool instead
```

**To get training metrics from logs, use the Railway MCP:**
```
mcp__railway-mcp-server__get-logs(service: "hslm-rXX", logType: "deploy", lines: 10)
```
Parse the last Step line for: `Loss | AvgL10 | PPL | LR | Tok/s`

#### Training Farm Table Format
```
═══════════════════════════════════════════════════
  🧪 HSLM TRAINING FARM — Wave 4 (cosine baseline)
  Best known: v4R PPL=125 (adam 3e-4 cosine 100K)
═══════════════════════════════════════════════════

  ┌──────────┬─────────┬────────┬────────┬─────────┬──────────┬─────────┐
  │ Run      │ Account │ Optim  │ LR     │ Sched   │ Status   │ PPL     │
  ├──────────┼─────────┼────────┼────────┼─────────┼──────────┼─────────┤
  │ R8       │ primary │ adam   │ 3e-4   │ cosine  │ 🟢 TRAIN │ {ppl}   │
  │ R9       │ primary │ adamw  │ 3e-4   │ cosine  │ {status} │ {ppl}   │
  │ R10      │ farm-2  │ lamb   │ 3e-4   │ cosine  │ {status} │ {ppl}   │
  │ R11      │ farm-2  │ adam   │ 3e-4   │ restart │ {status} │ {ppl}   │
  │ R12      │ farm-2  │ adam   │ 3e-4   │ cosine  │ {status} │ {ppl}   │
  │ R13      │ farm-2  │ lamb   │ 1e-3   │ cosine  │ {status} │ {ppl}   │
  │ R14      │ farm-3  │ adam   │ 5e-4   │ cosine  │ {status} │ {ppl}   │
  │ R15      │ farm-3  │ adamw  │ 5e-4   │ cosine  │ {status} │ {ppl}   │
  │ R16      │ farm-3  │ adam   │ 3e-4   │ sacred  │ {status} │ {ppl}   │
  │ R17      │ farm-3  │ adam   │ 3e-4   │ cosine  │ {status} │ {ppl}   │
  │ R18      │ farm-2  │ adam   │ 3e-4   │ cosine  │ {status} │ {ppl}   │
  │ R19      │ farm-2  │ lamb   │ 3e-3   │ cosine  │ {status} │ {ppl}   │
  │ R20      │ farm-3  │ adam   │ 3e-4   │ cosine  │ {status} │ {ppl}   │
  │ T1       │ farm-3  │ adam   │ 3e-4   │ cosine  │ {status} │ {ppl}   │
  └──────────┴─────────┴────────┴────────┴─────────┴──────────┴─────────┘

  Farm Capacity: {N}/30 slots (3 accounts × 10)
  Key Insight: flat LR = dead by step 20K (R4 proved ceiling loss=6.0)
```

**Status icons:**
- 🟢 TRAIN — actively training (has Step lines in logs)
- 🔨 BUILD — deployment BUILDING or INITIALIZING
- 🔴 FAIL — deployment FAILED
- ⚪ IDLE — SUCCESS but no training output
- ⏳ QUEUE — waiting to deploy

**Special columns (if available from logs):**
- PPL: latest perplexity from log, or "—" if not training yet
- Add Step/Speed columns in FULL mode if log data available

**Compact mode**: Show 1-line summary: "🧪 Farm: {running}/{total} training, best PPL={best} ({run})"

#### Training Farm Compact Narration (for Case 1/Case 3)

Add a training paragraph to the compact narration when training is active:

**Para (training)** — Farm status:
- "Ферма гудит: 14 из 15 экспериментов в работе, лучший PPL=125 (R8). Wave 4 — все на cosine 🧪"
- "Тренировка стоит — все 15 сервисов в FAIL. Проверь логи 🔴"
- "R8 уже на 50K step, PPL=180. R14 быстрее всех — 14K tok/s 🚀"

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
- Bridge agent DOWN: "🌉 Bridge agent DOWN — no remote control. Run: ./deploy/tri-bridge-agent.sh &"
- Railway DOWN: "🌉 Railway server DOWN — bridge unreachable. Deploy: railway up"
- PIPELINE_STALE exists: "⏰ Pipeline STALE — {PIPELINE_STALE}"
- JOB_STALE_WARNING exists: "⏰ Jobs STALE — {JOB_STALE_WARNING}"
- AUDIT_STALE exists: "⏰ Audit STALE — {AUDIT_STALE}"

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
  │ Perplexity Bridge   │ {S}    │ Railway {UP/DOWN}, Agent {UP/DOWN} │
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
- **Perplexity Bridge**: ✅ if BRIDGE_STATUS starts with "ok" AND BRIDGE_AGENT:UP. ⚠️ if one is UP. ❌ if both DOWN. ⚪ if BRIDGE_CODE:MISSING. Proof: "Railway {UP/DOWN}, Agent {UP/DOWN}"

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
