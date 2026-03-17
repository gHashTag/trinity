## Full Mode — Report Template

Format ALL collected data from `full_diagnostics.md` into this report. Use REAL data — never placeholders.

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

  Specs:      {N} .tri files
  Generated:  {N} .zig files
  Coverage:   {generated/specs as %}%
  Compile:    {PASS}/{TOTAL} = {RATE}% {🟢 if ≥80%, 🟡 if ≥50%, 🔴 if <50%}

  🐛 Failed Specs ({FAIL_COUNT} / {TOTAL}):
    ❌ {spec_name} — {error}
    ...ALL failed specs...
    Fix: zig build vibee -- gen specs/tri/{name}.tri && zig ast-check generated/{name}.zig

  📋 Recent Jobs (deduplicated by command):
  ┌──────────────────────┬────────────┬───────┐
  │ Job                  │ Status     │ Exit  │
  ├──────────────────────┼────────────┼───────┤
  │ {command}            │ ✅/❌      │ {N}   │
  └──────────────────────┴────────────┴───────┘

  Total: {JOB_TOTAL} jobs, {JOB_COMPLETED} ✅, {JOB_FAILED} ❌

🧠 MU ERROR PATTERNS (from ralph memory)
═══════════════════════════════════════════════════

  Agent MU:   {🟢 UP / 🔴 DOWN / ⚪ STUB}
  Patterns:   {N} known anti-patterns
  Last entry: {date} — {brief description}

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

### GitHub Board Integration Section

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
```

### Faculty Status Section

#### Faculty Data Collection — ALL LIVE
```bash
git log --oneline -1
echo "PKEY:${PERPLEXITY_API_KEY:+SET}"
echo "PKEY_UNSET:${PERPLEXITY_API_KEY:-UNSET}"
test -f src/tri/perplexity_scholar.zig && echo "SCHOLAR_CODE:READY" || echo "SCHOLAR_CODE:MISSING"
test -f src/agent_mu/fixer.zig && echo "MU_FIXER:EXISTS" || echo "MU_FIXER:MISSING"
python3 -c "
import json
with open('.trinity/swarm_state.json') as f:
    d=json.load(f)
print(f'SWARM_AGENTS:{len(d.get(\"agents\",[]))}')
print(f'SWARM_TASKS:{len(d.get(\"tasks\",[]))}')
assigned=[t for t in d.get('tasks',[]) if t.get('assigned')]
print(f'SWARM_ASSIGNED:{len(assigned)}')" 2>/dev/null || echo "SWARM_AGENTS:0"
grep -c '^### ' .ralph/memory/REGRESSION_PATTERNS.md 2>/dev/null || echo "0"

MU_ISSUE=$(gh issue list --state open --label "agent:mu" --json number --limit 1 -q '.[0].number' 2>/dev/null || echo "")
SWARM_ISSUE=$(gh issue list --state open --label "agent:swarm" --json number --limit 1 -q '.[0].number' 2>/dev/null || echo "")
echo "MU_OPEN_ISSUE:${MU_ISSUE:-NONE}"
echo "SWARM_OPEN_ISSUE:${SWARM_ISSUE:-NONE}"

test -f zig-out/bin/vibee && echo "LINTER:UP" || echo "LINTER:DOWN"

BRIDGE_URL="${RAILWAY_URL:-https://trinity-production-a1d4.up.railway.app}"
curl -sf --max-time 5 "${BRIDGE_URL}/px/status?token=${PX_BRIDGE_TOKEN}" 2>/dev/null \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'BRIDGE_STATUS:{d.get(\"status\",\"down\")}')" 2>/dev/null \
  || {
    HTTP_CODE=$(curl -sf --max-time 5 -o /dev/null -w "%{http_code}" "${BRIDGE_URL}/px/status" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" != "000" ]; then
      echo "BRIDGE_STATUS:ok(no-token)"
    else
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

#### Faculty Status Logic
- **Ralph**: 🟢 UP if build EXIT:0 AND 9 binaries exist. ⚠️ if build fails.
- **Scholar**: 🟢 UP if PKEY:SET AND SCHOLAR_CODE:READY. ⚠️ if code exists but no key. ⬜ TBD if SCHOLAR_CODE:MISSING.
- **MU**: 🟢 UP if SWARM_AGENTS > 0 with MU agent AND MU_FIXER:EXISTS. ⚪ STUB if agents=[] but fixer code exists. ❌ DOWN if no code.
- **Oracle**: Always 🟢 UP (computed from compile_rate).
- **Swarm**: 🟢 UP if SWARM_ASSIGNED > 0. ⚪ TBD if tasks but none assigned. ⬜ OFF if no tasks.
- **Linter**: 🟢 UP if LINTER:UP. ❌ DOWN if LINTER:DOWN.
- **Bridge**: 🟢 UP if BRIDGE_STATUS starts with "ok" AND BRIDGE_AGENT:UP. ⚠️ PARTIAL if one is UP. ❌ DOWN if both DOWN. ⬜ TBD if BRIDGE_CODE:MISSING.

#### Faculty Commentary

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

### Training Farm Section

After Faculty, render the HSLM Training Farm status using data from `_shared/data_collection.md` Railway queries.

#### Training Farm Table Format
```
═══════════════════════════════════════════════════
  🧪 HSLM TRAINING FARM — Wave 4 (cosine baseline)
═══════════════════════════════════════════════════

  ┌──────────┬─────────┬────────┬────────┬─────────┬──────────┬─────────┐
  │ Run      │ Account │ Optim  │ LR     │ Sched   │ Status   │ PPL     │
  ├──────────┼─────────┼────────┼────────┼─────────┼──────────┼─────────┤
  │ R8       │ primary │ adam   │ 3e-4   │ cosine  │ {status} │ {ppl}   │
  │ ...      │ ...     │ ...    │ ...    │ ...     │ ...      │ ...     │
  └──────────┴─────────┴────────┴────────┴─────────┴──────────┴─────────┘

  Farm Capacity: {N}/30 slots (3 accounts × 10)
```

**Status icons:** 🟢 TRAIN, 🔨 BUILD, 🔴 FAIL, ⚪ IDLE, ⏳ QUEUE

### Problems Section

Flag conditions: broken build, dirty files, stopped agents, missing permissions, pipeline failures, stale audits.

```
🔴 PROBLEMS DETECTED
  1. {problem description}
  2. {problem description}
```

If no problems: "🟢 ALL SYSTEMS NOMINAL"

### Priority Section

```
🎯 CURRENT PRIORITY
  NOW:  {highest priority action based on problems}
  NEXT: {next open issue by priority label}

🌳 TECH TREE (from open issues)
  #{parent}  {title}  [P0 EPIC]
  ├── #{num}  {title}  [{priority}, {status}]
  └── #{num}  {title}  [{labels}]
```

### Translation Table (EN → RU)

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
| FACULTY COMMENTARY | КОММЕНТАРИИ ФАКУЛЬТЕТА |
| SLEEPING | СПИТ |
| CODE READY | КОД ГОТОВ |
| NOT HIRED | НЕ НАНЯТ |
| EMBRYONIC | В ЗАРОДЫШЕ |
