## Compact Mode — Narration Engine

**If MODE=COMPACT, render ONLY this module, then STOP. Do not continue to the full diagnostic.**

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
If `farm_active = 0`, skip farm mention entirely.

**REPORTER MODE** (when `reporter_mode=1`): П1 becomes **live race commentary**. Lead with the most dramatic event:
- If `reporter_crashed_count > 0`: lead with the crash
- If `run_<name>_delta_ppl` is large negative: lead with the breakthrough
- Otherwise: lead with the leader
- Name specific experiments by name (R8, R13, R19 etc.)
- Compare runners against each other
- Show concrete numbers: step counts as digits (50K), PPL as digits (4.6), tok/s as digits
- Static metrics (compile rate, build) become background noise — mention in 1 sentence max
- Include total active/crashed

#### Paragraph 2 — САМОБРАНКА (system self-roast / analyst commentary)

**REPORTER MODE** (when `reporter_mode=1`): П2 becomes **analyst commentary**:
- Compare optimizer strategies
- Point out schedule patterns
- Call out failures with diagnosis
- Compare learning rates
- Reference delta data
- If an experiment is stuck (delta_step=0): note it
- Still allowed to self-roast about dirty files/build, but race analysis takes priority

**STATIC MODE** (when `reporter_mode=0`): Standard self-roast. System roasts ITSELF (never the user):

| Condition | Roast direction |
|-----------|----------------|
| `dirty > 20` | Hoarding uncommitted files |
| `build_ok=false` | Broken build while calmly reporting |
| `open_issues > 50` | Backlog growing like mold |
| No changes 3+ cycles AND `farm_active=0` | Own uselessness |
| No changes 3+ cycles AND `farm_active>0` | Code is idle but farm is working — roast the idle CODE |
| `farm_active>0` AND `dirty > 20` | Farm is training but code repo is a mess |
| `agent_*=stub/down` | Fallen agents |
| Everything OK | Nothing to complain about (meta-roast) |

**CRITICAL override:** If `farm_active > 0`, NEVER roast "nothing happening". The farm IS doing work.

#### Paragraph 3 — ПЛАН

**REPORTER MODE** (when `reporter_mode=1`): П3 becomes **"what to watch next"** — predictions and specific commands.

**STATIC MODE** (when `reporter_mode=0`): Standard priority-based planning.

| Priority | Condition | Plan |
|----------|-----------|------|
| 1 | `build_ok=false` | Fix build |
| 2 | `dirty > 10` | Commit files via `tri git commit` |
| 3 | `compile_rate < 100` | Fix failing specs |
| 4 | `open_issues > 0` | Pick next issue |
| 5 | `farm_active > 0` | Monitor farm: `tri farm status` |
| 6 | All OK | Scale: new feature or optimization |

---

### Case Logic (determines Paragraph 1 content)

#### Case 1: First Run (no previous snapshot, or prev >1h old)
Full narration of all fields in Paragraph 1.

#### Case 2: No Changes (all values identical after filtering noise/damped keys)
Paragraph 1 becomes a short "no changes" status with key numbers.
Gets harsher as no-change counter grows (3+ cycles = escalation in П2).

**Farm-aware Case 2:** If `farm_active > 0` AND no code changes:
- **With reporter_mode=1**: Use full reporter narration even though code is idle.
- **With reporter_mode=0**: Fall back to generic farm narration.

#### Case 3: Some Values Changed — Delta-focused
Paragraph 1 focuses on what changed. Emergency changes always lead.

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
| `farm_active` | "Ферма: было X, стало Y сервисов" |

---

#### Narration rules (all cases, all paragraphs)

- Short paragraphs, NOT bullet lists, NOT tables
- Emoji per mood matrix
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

ТРИДЦАТЬ ТРИ файла незакоммичены. Кто так живёт? 💀

Коммитим СЕЙЧАС. Потом берём задачу. Хватит медитировать на дашборд 🔥

[💀 toxic]
```

#### zen:
```
Триста тридцать четыре. Всё компилируется. Билд дышит. Тридцать три файла ждут.

Грязные файлы — как опавшие листья. Их можно убрать. Можно оставить.

Следующий шаг: коммит. Потом — одна задача из семидесяти одной.

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

---

### Step 3.5: GitHub Board Summary

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

**Narration integration:** After the 3 paragraphs + mood signature, add an expanded board section:

```
📋 Board: N backlog | M in progress | K review | J done

🔥 In Progress:
• #357 Training Farm Wave 4+5
{all in-progress items}

📥 Backlog (top 5):
• #340 FPGA Verilog Export
{top 5 backlog items}

🧪 Farm: N services | PPL best
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
- If `last_action` matches selected action AND `consecutive_failures >= 3` → **SKIP**
- Otherwise → proceed

#### 6.2: Write Lock + Launch Agent

Before launching the agent:
```bash
echo '{"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","action":"{selected_action}"}' > .trinity/auto_action.lock
```

#### Agent Prompt Suffix (MANDATORY)

Every agent prompt gets this suffix appended:

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

**Priority 1: `build_ok=false`** → Launch background Agent to fix build
**Priority 2: `dirty > 10`** → Launch background Agent to auto-commit dirty files
**Priority 3: `compile_rate < 100`** → Launch background Agent to fix failing specs
**Priority 4: `open_issues > 0`** → Launch background Agent to work on top issue
**Priority 5: All clean** → Verify issue queue, launch if issues found

#### Rules
- Only ONE action per /tri cycle — no parallel chaos
- Agent runs in background — user sees /tri output immediately
- Lock prevents concurrent auto-actions across /tri invocations
- Circuit breaker stops infinite retry loops after 3 consecutive failures
- Agent MUST write result JSON + delete lock (enforced via prompt suffix)
- Never commit `.env`, credentials, large binaries
- Never force-push
- If build breaks after commit → agent reverts, reports failure in result JSON

**IMPORTANT: After Step 6, STOP. Do NOT continue to the full diagnostic.**
