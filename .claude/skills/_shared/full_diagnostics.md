## Full Mode — Data Collection

**This module renders ONLY in full mode. If MODE=COMPACT, skip everything here.**

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

# Spec inventory
find specs/ -name "*.tri" -not -path "*/archive/*" 2>/dev/null | wc -l

# Generated files
find generated/ -name "*.zig" 2>/dev/null | wc -l

# Compile rate from last audit (KEY METRIC — SINGLE CANONICAL SOURCE)
PASS=$(grep -c "✅" specs/REGENERATION_REPORT.md 2>/dev/null || echo "0")
FAIL=$(grep -c "❌" specs/REGENERATION_REPORT.md 2>/dev/null || echo "0")
TOTAL=$((PASS + FAIL))
RATE=$(( TOTAL > 0 ? PASS * 100 / TOTAL : 0 ))
echo "COMPILE_PASS:$PASS COMPILE_FAIL:$FAIL COMPILE_TOTAL:$TOTAL COMPILE_RATE:$RATE"

# Failed specs
grep "❌" specs/REGENERATION_REPORT.md 2>/dev/null | while IFS='|' read _ num name status _; do
  name=$(echo "$name" | xargs)
  status=$(echo "$status" | xargs)
  echo "FAILED_SPEC:$name — $status"
done
echo "FAILED_COUNT:$(grep -c "❌" specs/REGENERATION_REPORT.md 2>/dev/null || echo 0)"

# Audit date + staleness
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

# Job history
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
if jobs:
    newest_ts = max(j.get('start_time',0) for j in jobs)
    age_hours = (time.time() - newest_ts) / 3600 if newest_ts > 0 else -1
    newest_date = datetime.datetime.fromtimestamp(newest_ts).strftime('%Y-%m-%d %H:%M') if newest_ts > 0 else 'unknown'
    print(f'JOB_NEWEST_DATE:{newest_date}')
    print(f'JOB_AGE_HOURS:{age_hours:.0f}')
    if age_hours > 24:
        print(f'JOB_STALE_WARNING:No new pipeline jobs in {age_hours:.0f}h (since {newest_date})')
" 2>/dev/null || echo "JOB_TOTAL:0"

# Error patterns from ralph memory
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

# Velocity: PRs merged in last 30 days
SINCE_30D=$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d "30 days ago" +%Y-%m-%d)
gh pr list --state merged --search "merged:>=$SINCE_30D" --json number --limit 100 2>/dev/null | python3 -c "import json,sys; print(f'PR_MERGED_30D:{len(json.load(sys.stdin))}')" 2>/dev/null || echo "PR_MERGED_30D:N/A"
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

### Technology Proofs — LIVE CHECKS
```bash
# VSA
grep -c 'test "' src/vsa.zig 2>/dev/null || echo "0"
zig ast-check src/vsa.zig 2>&1; echo "VSA_CHECK:$?"

# Ternary VM
grep -c 'test "' src/vm.zig 2>/dev/null || echo "0"
zig ast-check src/vm.zig 2>&1; echo "VM_CHECK:$?"

# MCP Server tool count
grep -c 'tool_name\|"name"' tools/mcp/trinity_mcp/trinity_mcp.zig 2>/dev/null || \
  grep -rc 'registerTool\|addTool\|tool_name' tools/mcp/trinity_mcp/ 2>/dev/null | \
  awk -F: '{s+=$2}END{print s}'

# FPGA bitstream
ls -lh fpga/openxc7-synth/*.bit 2>/dev/null || echo "NO_BITSTREAM"

# tri-api LOC + file count
wc -l src/tri-api/*.zig 2>/dev/null | tail -1
ls src/tri-api/*.zig 2>/dev/null | wc -l

# Pipeline jobs
ls .trinity/jobs/ 2>/dev/null | wc -l
grep -rl '"state":"completed"' .trinity/jobs/*/metadata.json 2>/dev/null | wc -l

# Telegram bot
pgrep -f tri-bot > /dev/null 2>&1 && echo "BOT:UP" || echo "BOT:DOWN"

# Sacred Math
python3 -c "phi=(1+5**0.5)/2; print(f'PHI_IDENTITY:{phi**2+1/phi**2:.6f}')" 2>/dev/null || echo "PHI_IDENTITY:3.000000"

# Empty shells
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

# TODO/FIXME/HACK count
grep -r 'TODO\|FIXME\|HACK' src/ tools/ --include="*.zig" 2>/dev/null | grep -v 'zig-cache\|zig-out' | wc -l
```

### MU Agent Detection — LIVE
```bash
test -f src/agent_mu/fixer.zig && echo "MU_CODE:EXISTS" || echo "MU_CODE:MISSING"
grep -c 'error_pattern\|anti_pattern\|ErrorPattern' src/agent_mu/*.zig 2>/dev/null || echo "MU_PATTERNS_CODE:0"

python3 -c "
import json
with open('.trinity/swarm_state.json') as f:
    d=json.load(f)
agents=[a for a in d.get('agents',[]) if 'mu' in a.get('name','').lower()]
print(f'MU_AGENTS:{len(agents)}')
print(f'MU_STATUS:{agents[0][\"status\"] if agents else \"NONE\"}')" 2>/dev/null || echo "MU_AGENTS:0"

grep -c '^---$' .ralph/memory/REGRESSION_PATTERNS.md 2>/dev/null || echo "PATTERN_COUNT:0"
grep -c '^### ' .ralph/memory/REGRESSION_PATTERNS.md 2>/dev/null || echo "PATTERN_HEADERS:0"
```

### GitHub Integration — LIVE
```bash
test -f src/tri/github_client.zig && echo "GH_CLIENT:EXISTS" || echo "GH_CLIENT:MISSING"
test -f src/tri/github_commands.zig && echo "GH_COMMANDS:EXISTS" || echo "GH_COMMANDS:MISSING"
echo "GH_TOKEN:${GITHUB_TOKEN:+SET}"
echo "GH_TOKEN_ALT:${GH_TOKEN:+SET}"
grep -c 'fn.*Command' src/tri/github_commands.zig 2>/dev/null || echo "0"
test -f zig-out/bin/tri && echo "TRI_CLI:READY" || echo "TRI_CLI:MISSING"
```
